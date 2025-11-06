# modules/compute/outputs.tf

output "key_pair_id" {
  description = "The ID of the EC2 key pair."
  value       = aws_key_pair.sonarqube_key.id
}

output "private_key_path" {
  description = "Local file path to the private key."
  value       = local_file.private_key.filename
}

output "launch_template_id" {
  description = "ID of the launch template."
  value       = aws_launch_template.sonarqube_lt.id
}

output "launch_template_name" {
  description = "Name of the launch template."
  value       = aws_launch_template.sonarqube_lt.name
}
