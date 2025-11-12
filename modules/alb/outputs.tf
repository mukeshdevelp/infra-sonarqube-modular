# gives the output of alb dns name and target group arn
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "target_group_arn" {
  description = "ARN of the ALB target group for SonarQube"
  value = aws_lb_target_group.tg.arn
}
output "alb_listener" {
  value = aws_lb_listener.listener
}