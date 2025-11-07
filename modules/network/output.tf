# outputting nat gateway ip
output "nat_gateway_id" {
  value = aws_nat_gateway.nat_gw.id
}
