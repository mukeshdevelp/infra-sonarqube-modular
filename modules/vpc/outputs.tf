# vpc/outputs.tf
# outputting vpc block #done
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.sonarqube_vpc.id
}
# igw id
output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}
# nat id
output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.nat_gw.id
}
# elastic ip with nat id
output "nat_eip" {
  description = "Elastic IP for NAT Gateway"
  value       = aws_eip.nat_eip.public_ip
}
