# consists ami id, launch template and asg

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
}
# bastion host
resource "aws_instance" "public_ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.small_instance_size
  # change here
  subnet_id              = var.public_subnet_a_id
  vpc_security_group_ids = [var.public_security_group]
  key_name               = var.key_name
  associate_public_ip_address = true

  tags = {
    Name = "public-ec2-instance"
    type = "bastion host"
  }
 
}

# launch template
resource "aws_launch_template" "lt" {
  name_prefix            = "sonarqube-lt-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.sonarqube_instance_size
  key_name               = var.key_name
  vpc_security_group_ids = var.private_sg_id
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y docker.io git
    sudo systemctl enable docker
    sudo systemctl start docker

    docker run -d --name sonarqube -p 9000:9000 sonarqube:lts

  EOF
  )
  tags = {
    launch_template = "sonarqube-launch-template"
    situated_in = "private subnet"
    sec_grp = "private and postgres"
  }
  
}
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
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sonarqube-instance"
    propagate_at_launch = true
  }

  
}
