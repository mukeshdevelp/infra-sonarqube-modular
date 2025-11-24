output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Access SonarQube via this ALB URL"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}


output "launch_template_id" {
  description = "Launch Template ID for SonarQube instances"
  value       = module.compute.launch_template_id
}
output "aws_private_instance_ip" {
  description = "these are the private isntacne ips"
  value       = module.compute.private_ips
}
output "user" {
  value = ["ubuntu", "ubuntu"]
}

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = module.compute.bastion_public_ip
}

output "bastion_public_dns" {
  description = "Public DNS name of bastion host"
  value       = module.compute.bastion_public_dns
}
