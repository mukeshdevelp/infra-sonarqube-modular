#security_groups/outputs.tf
output "public_sg_id" {
  value = aws_security_group.public_sg
}

output "private_sg_id" {
  value = aws_security_group.private_sg
}
output "postgres_sg_id" {
  value = aws_security_group.postgres_sg
}