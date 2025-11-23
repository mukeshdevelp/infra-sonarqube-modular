# consists ami id, launch template and asg

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
}
# Image Builder EC2 - Public subnet for Ansible installation
# This EC2 will be used to build the SonarQube AMI
resource "aws_instance" "image_builder_ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.sonarqube_instance_size  # Use sonarqube size for image building
  subnet_id              = var.public_subnet_a_id
  vpc_security_group_ids = [var.public_security_group]
  key_name               = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "sonarqube-image-builder"
    type = "image-builder"
    env  = "sonarqube"
    role = "ami-builder"
  }
 
}


# AMI Creation from Image Builder EC2
# This will be created AFTER Ansible installs SonarQube on image_builder_ec2
# Only create AMI when create_ami is true (set after Ansible installation)
resource "aws_ami_from_instance" "sonarqube_ami" {
  count                = var.create_ami ? 1 : 0
  name                 = "sonarqube-ami-${formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())}"
  source_instance_id   = aws_instance.image_builder_ec2.id
  snapshot_without_reboot = false  # Reboot to ensure clean state
  
  depends_on = [aws_instance.image_builder_ec2]
  
  tags = {
    Name = "SonarQube Golden Image"
    env  = "sonarqube"
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

# Launch Template for SonarQube instances using the custom AMI
resource "aws_launch_template" "sonarqube_lt" {
  count                  = var.create_ami ? 1 : 0
  name_prefix            = "sonarqube-lt-"
  image_id               = aws_ami_from_instance.sonarqube_ami[0].id  # Use custom AMI instead of base Ubuntu
  instance_type          = var.sonarqube_instance_size
  key_name               = var.key_name
  vpc_security_group_ids = var.private_sg

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "sonarqube-instance"
      env  = "sonarqube"
      role = "sonarqube-postgres"
    }
  }
  
  depends_on = [aws_ami_from_instance.sonarqube_ami]
}

# Stop Image Builder EC2 after AMI and Launch Template are created
# This saves costs since the instance is no longer needed after AMI creation
resource "null_resource" "stop_image_builder" {
  count = var.create_ami ? 1 : 0
  
  # Stop the instance after Launch Template is created
  # Triggers when Launch Template ID changes (after creation)
  triggers = {
    launch_template_id = aws_launch_template.sonarqube_lt[0].id
    ami_id             = aws_ami_from_instance.sonarqube_ami[0].id
    instance_id        = aws_instance.image_builder_ec2.id
  }
  
  # Use AWS CLI to stop the instance (AWS credentials from Jenkins environment)
  # Jenkins sets AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY via withCredentials
  provisioner "local-exec" {
    command = <<-EOT
      echo "Stopping Image Builder EC2 after AMI and Launch Template creation..."
      aws ec2 stop-instances \
        --instance-ids ${aws_instance.image_builder_ec2.id} \
        --region us-east-1 \
        || echo "Warning: Failed to stop instance (may already be stopped or credentials not set)"
      echo "✅ Image Builder EC2 stop command executed"
    EOT
  }
  
  depends_on = [
    aws_ami_from_instance.sonarqube_ami,
    aws_launch_template.sonarqube_lt
  ]
}

# Private EC2 instances launched using Launch Template (with SonarQube pre-installed from AMI)
# These instances are created AFTER the AMI is built from image_builder_ec2
# They will only be created when the AMI exists (after Ansible installation)
#
# Instance Placement:
# - private_server_a → Private Subnet 1a (us-east-1a, 10.0.3.0/24)
# - private_server_b → Private Subnet 1b (us-east-1b, 10.0.4.0/24)
resource "aws_instance" "private_server_a" {
  count                  = var.create_private_instances && var.create_ami ? 1 : 0  # Only create after AMI is ready
  ami                    = aws_ami_from_instance.sonarqube_ami[0].id  # Use custom AMI with SonarQube
  instance_type          = var.sonarqube_instance_size
  subnet_id              = var.private_subnets[0]  # Private Subnet 1a (10.0.3.0/24)
  vpc_security_group_ids = var.private_sg
  key_name               = var.key_name

  tags = {
    Name = "private-server-1a"
    az   = "1a"
    env  = "sonarqube"
    role = "sonarqube-postgres"  # Both services on same instance
    subnet = "private-subnet-1a"
    launched_from = "launch-template"
  }
  
  depends_on = [aws_launch_template.sonarqube_lt]
}

resource "aws_instance" "private_server_b" {
  count                  = var.create_private_instances && var.create_ami ? 1 : 0  # Only create after AMI is ready
  ami                    = aws_ami_from_instance.sonarqube_ami[0].id  # Use custom AMI with SonarQube
  instance_type          = var.sonarqube_instance_size
  subnet_id              = var.private_subnets[1]  # Private Subnet 1b (10.0.4.0/24)
  vpc_security_group_ids = var.private_sg
  key_name               = var.key_name

  tags = {
    Name = "private-server-1b"
    az   = "1b"
    env  = "sonarqube"
    role = "sonarqube-postgres"  # Both services on same instance
    subnet = "private-subnet-1b"
    launched_from = "launch-template"
  }
  
  depends_on = [aws_launch_template.sonarqube_lt]
}

# Attach private instances to ALB target group (SonarQube listens on port 9000)
# Only attach when both instances exist (require both create_ami and create_private_instances)
resource "aws_lb_target_group_attachment" "private_a_attachment" {
  count            = var.create_private_instances && var.create_ami ? 1 : 0
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.private_server_a[0].id
  port             = 9000
}

resource "aws_lb_target_group_attachment" "private_b_attachment" {
  count            = var.create_private_instances && var.create_ami ? 1 : 0
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.private_server_b[0].id
  port             = 9000
}
# Launch template is available above for future ASG use
# Direct instances are used for Ansible installation via Jenkins pipeline
/*
# auto scaling group
resource "aws_autoscaling_group" "asg" {
  name                = "sonarqube-asg"
  desired_capacity    = var.desired_number
  max_size            = var.max_number
  min_size            = var.min_number
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [var.target_group_arn]
  health_check_type   = "EC2"
  
  launch_template {
    id      = aws_launch_template.lt.id
    version = aws_launch_template.lt.latest_version
  }

  tag {
    key                 = "Name"
    value               = "sonarqube-instance"
    propagate_at_launch = true
  }

  depends_on = []
}
*/