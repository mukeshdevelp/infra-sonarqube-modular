output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Access SonarQube via this ALB URL"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
