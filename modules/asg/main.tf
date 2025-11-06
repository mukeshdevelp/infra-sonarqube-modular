#asg/main.tf
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
