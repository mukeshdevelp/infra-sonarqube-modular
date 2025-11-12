# just outputting the key pair name
output "key_name" {
  value = aws_key_pair.key.key_name
}
output "key_location" {
  value = local_file.private_key.filename
}

output "private_key_pem" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}