output "alb_dns_name" {
  value       = module.alb.alb_dns_name
  description = "Access SonarQube via this ALB URL"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_ip_of_bastion" {
  description = "Public IP of the Image Builder EC2 (for Ansible installation)"
  value       = module.compute.image_builder_public_ip
}

output "image_builder_public_ip" {
  description = "Public IP of the Image Builder EC2"
  value       = module.compute.image_builder_public_ip
}

output "sonarqube_ami_id" {
  description = "AMI ID of the SonarQube golden image"
  value       = module.compute.sonarqube_ami_id
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