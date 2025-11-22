#############################################
# CREATE VPC PEERING CONNECTION
#############################################

resource "aws_vpc_peering_connection" "this" {
  vpc_id      = var.requester_vpc_id
  peer_vpc_id = var.accepter_vpc_id

  
  auto_accept = var.auto_accept

  tags = merge({
    Name = var.name
  }, var.tags)
}

#############################################
# ROUTES IN REQUESTER VPC (173/16 → 10/16)
#############################################

resource "aws_route" "requester_routes" {
  count = length(var.requester_route_tables)
  
  route_table_id            = var.requester_route_tables[count.index]
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

#############################################
# ROUTES IN ACCEPTER VPC (10/16 → 173/16)
#############################################

resource "aws_route" "accepter_routes" {
  count = length(var.accepter_route_tables)

  route_table_id            = var.accepter_route_tables[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
  
  # Ensure peering connection is established before adding routes
  # Note: This route is ADDED to the route table, not replacing existing routes
  # The route table should already have 0.0.0.0/0 → NAT Gateway route
  depends_on = [aws_vpc_peering_connection.this]
}
