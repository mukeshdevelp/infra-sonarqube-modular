# Output: Bastion Host Public and Private IPs
output "public_ec2_ip" {
  description = "Public IP of the EC2 Bastion Host"
  value       = aws_instance.public_ec2.public_ip
}
# private ip of bastion host
output "private_ec2_ip" {
  description = "Private IP of the EC2 Bastion Host"
  value       = aws_instance.public_ec2.private_ip
}

# outputs.tf
output "private_ips" {
  value = [aws_instance.private_server_b.private_ip, aws_instance.private_server_a.private_ip]
}








