#routes/outputs.tf
output "public_route_table_associations" {
  value = [
    aws_route_table_association.public_a.id,
    aws_route_table_association.public_b.id
  ]
}

output "private_route_table_associations" {
  value = [
    aws_route_table_association.private_a.id,
    aws_route_table_association.private_b.id
  ]
}
# problem
/*
output "igw_id" {
  value = module.vpc.igw_id
}
*/
# problem
/*
output "nat_gateway_id" {
  value =            module.vpc.nat_gateway_id
}
*/
output "public_rt_id" {
  value = aws_route_table.public.id
}
output "private_rt_id" {
  value = aws_route_table.private.id
}