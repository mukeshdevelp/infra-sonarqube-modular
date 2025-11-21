# outputting nat gateway ip
output "nat_gateway_id" {
  value = aws_nat_gateway.nat_gw.id
}
output "internet_gw_id" {
  value = aws_internet_gateway.igw.id
}
output "internet_gw_attachment_vpc" {
  value = aws_internet_gateway.igw.vpc_id
}
output "nat_gw_attatchment" {
  value = aws_nat_gateway.nat_gw.subnet_id
}
output "private_rt_id" {
  value = aws_route_table.private_rt.id
}