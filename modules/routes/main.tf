#routes/main.tf dikkat yha hai
# Define Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags = {
    Name = "public-route-table"
  }
}

# Creates a route in the specified AWS route table 
resource "aws_route_table" "private" {
  vpc_id = var.vpc_id
  tags = {
    Name = "private-route-table"
  }
}

# Creates a route in the specified AWS route table 
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.igw_id  # Internet Gateway ID
}

# Route for Private Subnet Access via NAT Gateway
resource "aws_route" "nat_gateway_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_id  # NAT Gateway ID
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = var.public_subnets[0]
  route_table_id = aws_route_table.public
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = var.public_subnets[1]
  route_table_id = aws_route_table.public
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = var.private_subnets[0]
  route_table_id = aws_route_table.private
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = var.private_subnets[1]
  route_table_id = aws_route_table.private
}
