output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Access SonarQube via this ALB URL"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_ip_of_bastion" {
  description = "this is the public ip of bastion host"
  value       = module.compute.public_ec2_ip
}
output "aws_private_instance_ip" {
  description = "these are the private isntacne ips"
  value       = module.compute.private_ips
}
output "user" {
  value = ["ubuntu", "ubuntu"]
}