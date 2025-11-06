#root/outputs.tf
output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Access SonarQube via this ALB URL"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The ID of the VPC"
}
output "asg_id" {
  description = "The ID of the SonarQube Auto Scaling Group"
  value       = module.sonarqube_asg.asg_id
}
output "sonarqube_asg_name" {
  value       = module.compute.asg_name
  description = "The name of the Auto Scaling Group for SonarQube"
}

output "sonarqube_launch_template_id" {
  description = "The ID of the SonarQube EC2 Launch Template"
  value       = aws_launch_template.sonarqube_lt.id
}
output "alb_target_group_arn" {
  description = "The ARN of the SonarQube target group"
  value       = aws_lb_target_group.sonarqube_tg.arn
}