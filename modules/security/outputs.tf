output "public_sg_id" {
  description = "public security group id"
  value = aws_security_group.public_sg.id
}

# In module/security/outputs.tf
output "private_sg_id" {
  description = "Private security group ID"
  value       = aws_security_group.private_sg.id
}

output "postgres_sg_id" {
  description = "Postgres security group ID"
  value       = aws_security_group.postgres_sg.id
}

