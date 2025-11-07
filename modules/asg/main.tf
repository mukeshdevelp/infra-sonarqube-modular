#asg/main.tf
/*
resource "aws_autoscaling_group" "sonarqube_asg" {
  name               = var.asg_name
  desired_capacity   = var.desired_capacity
  max_size           = var.max_size
  min_size           = var.min_size
  vpc_zone_identifier = var.private_subnets
  target_group_arns  = [var.target_group_arn]
  health_check_type  = "EC2"

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.asg_name
    propagate_at_launch = true
  }

  depends_on = [var.lb_listener_arn]
}
*/
# for ssh in static add this block
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Bastion Host for SSH access to private instances
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id # module.sonarqube_compute.ami_id  # Reuse the same AMI
  instance_type = "t3.micro"
  key_name      = var.key_name
  subnet_id     = var.public_subnet_a # First public subnet
  vpc_security_group_ids = [var.public_sg_id]

  tags = {
    Name = "bastion-host-for-sonarqube"
    type = "bastion-host"
  }
}
# edit has to done here
# Public ASG
resource "aws_autoscaling_group" "sonarqube_asg" {
  name               = var.asg_name
  desired_capacity   = var.desired_capacity
  max_size           = var.max_size
  min_size           = var.min_size
  target_group_arns  = [var.target_group_arn]
  vpc_zone_identifier = var.private_subnets
  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }
  #depends_on = [var.lb_listener_arn]
}

