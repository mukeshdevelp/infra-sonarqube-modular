# consists alb target groups and listeners

resource "aws_lb" "alb" {
  name               = "sonarqube-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.public_sg_id]
  subnets            = var.public_subnets
  tags = {
    Name = "sonarqube-alb-intenet-facing"
    type = "load balancer"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "sonarqube-tg"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = "/api/system/health"
    port = "9000"
  }
  tags = {
    access = "through alb"
    subnet = "private"
    open_port = "9000 and 5432"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
