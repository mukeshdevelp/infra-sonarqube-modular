# alb/outputs.tf
output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "The ARN of the ALB target group"
  value       = aws_lb_target_group.this.arn
}

output "alb_arn" {
  description = "The ARN of the ALB"
  value       = aws_lb.this.arn
}

output "target_group_health_check_path" {
  description = "The health check path for the target group"
  value       = aws_lb_target_group.this.health_check[0].path
}

output "target_group_health_check_port" {
  description = "The health check port for the target group"
  value       = aws_lb_target_group.this.health_check[0].port
}

output "alb_id" {
  description = "The ID of the ALB"
  value       = aws_lb.this.id
}
