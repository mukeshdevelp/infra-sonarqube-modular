# just outputting the key pair name
output "key_name" {
  value = aws_key_pair.key.key_name
}
