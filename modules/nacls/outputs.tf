#nacl/outputs.tf
output "public_nacl_id" {
  value = aws_network_acl.public_nacl.id
  description = "The ID of the public NACL."
}

output "private_nacl_id" {
  value = aws_network_acl.private_nacl.id
  description = "The ID of the private NACL."
}
