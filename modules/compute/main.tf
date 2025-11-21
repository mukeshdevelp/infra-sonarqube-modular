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
  vpc_security_group_ids = var.private_sg
  
  tags = {
    Name = "private-server-1a"
    az = "1a"
  }
}

resource "aws_instance" "private_server_b" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.large"
  subnet_id     = var.private_subnets[1]
  
  vpc_security_group_ids = var.private_sg
  key_name = var.key_name
  
  tags = {
    Name = "private-server-1b"
    az = "1b"
  }
}
resource "aws_instance" "private_server_a" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.large"
  subnet_id     = var.private_subnets[0]
  
  vpc_security_group_ids = var.private_sg
  key_name = var.key_name
 
  tags = {
    Name = "private-server-1a"
    az = "1a"
  }
}
# Attach private instances to ALB target group (SonarQube listens on port 9000)
resource "aws_lb_target_group_attachment" "private_a_attachment" {
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.private_server_a.id
  port             = 9000
}

resource "aws_lb_target_group_attachment" "private_b_attachment" {
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.private_server_b.id
  port             = 9000
}
# Launch Template (SonarQube EC2)

resource "aws_launch_template" "sonarqube_lt" {
  name                   = "sonarqube-lt-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = "t3.large"
  key_name               = var.key_name
  vpc_security_group_ids = [ var.public_security_group]
  # remove this block at last...before creating in
  # Ensure user data is properly base64 encoded using base64encode()
  
  tags = {
    launch_template = "sonarqube-launch-template"
    situated_in = "private subnet"
    sec_grp = "private and postgres"
  }
  
}
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