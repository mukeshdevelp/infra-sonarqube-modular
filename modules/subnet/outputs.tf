#subnet/outputs.tf

# list is flowing up or down for usage
output "public_subnets" {
    description = "values of list of the public subnets"
    value = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
}

output "private_subnets" {
    description = "values of list o the private subnets"
    value = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
}
