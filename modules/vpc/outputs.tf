output "vpc_id" {
  value = aws_vpc.sonarqube_vpc.id
}

output "public_subnets" {
  value = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "private_subnets" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
output "vpc_cidr_block" {
  value = aws_vpc.sonarqube_vpc.cidr_block
}
