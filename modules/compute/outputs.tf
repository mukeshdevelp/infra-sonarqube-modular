# Output: Image Builder EC2 Public and Private IPs
output "image_builder_public_ip" {
  description = "Public IP of the Image Builder EC2 (for Ansible installation)"
  value       = aws_instance.image_builder_ec2.public_ip
}

output "image_builder_private_ip" {
  description = "Private IP of the Image Builder EC2"
  value       = aws_instance.image_builder_ec2.private_ip
}

# Output: AMI ID
output "sonarqube_ami_id" {
  description = "AMI ID of the SonarQube golden image"
  value       = var.create_ami ? aws_ami_from_instance.sonarqube_ami[0].id : null
}

# Output: Launch Template ID
output "launch_template_id" {
  description = "Launch Template ID for SonarQube instances"
  value       = var.create_ami ? aws_launch_template.sonarqube_lt[0].id : null
}

# Output: Private Instance IPs (launched from Launch Template)
output "private_ips" {
  description = "Private IPs of instances launched in private subnets"
  value       = var.create_private_instances ? [aws_instance.private_server_a[0].private_ip, aws_instance.private_server_b[0].private_ip] : []
}

# Output: Private Instance IDs (for querying)
output "private_instance_ids" {
  description = "Instance IDs of private SonarQube instances"
  value       = var.create_private_instances ? [aws_instance.private_server_a[0].id, aws_instance.private_server_b[0].id] : []
}








