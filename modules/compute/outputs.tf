# Output: Launch Template ID
output "launch_template_id" {
  description = "Launch Template ID for SonarQube instances"
  value       = aws_launch_template.sonarqube_lt.id
}

# Output: Private Instance IPs
output "private_ips" {
  description = "Private IPs of instances launched in private subnets"
  value       = [aws_instance.private_server_a.private_ip, aws_instance.private_server_b.private_ip]
}

# Output: Bastion Host Public IP
output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.public_ec2.public_ip
}

# Output: Bastion Host Public DNS
output "bastion_public_dns" {
  description = "Public DNS name of bastion host"
  value       = aws_instance.public_ec2.public_dns
}
