
# creating igw, elasic ip to attach to nat and route tables also attaching them to respective subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id
  tags   = { 
    Name = "sonarqube-igw" 
    gateway_type = "main-internet-gateway"
    access = "public"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { 
    Name = "nat-eip" 
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(var.public_subnets, 0)
  tags          = { 
    Name = "sonarqube-nat"
    attatched_to = "public-subnet-1a" 
    access = "public ssh access for private subnets"
  }
}

# public route table creation
resource "aws_route_table" "public_rt" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
    
  }
  tags = {
    Name = "sonarqube-public-route-table"
    attatched_to = "public-subnet-1 and public-subnet-2"

  }
}

# private route table creation
resource "aws_route_table" "private_rt" {
  vpc_id = var.vpc_id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "sonarqube-private-route-table"
    attatched_to = "public-subnet-1 and public-subnet-2"

  }
}

# associating public rt to public a subnet
resource "aws_route_table_association" "public_a" {
  subnet_id      = element(var.public_subnets, 0)
  route_table_id = aws_route_table.public_rt.id
  
}

# associating public rt to public b subnet
resource "aws_route_table_association" "public_b" {
  subnet_id      = element(var.public_subnets, 1)
  route_table_id = aws_route_table.public_rt.id
}

# associating private rt to private-a subnet
resource "aws_route_table_association" "private_a" {
  subnet_id      = element(var.private_subnets, 0)
  route_table_id = aws_route_table.private_rt.id
}
# associating private rt to private-b subnet
resource "aws_route_table_association" "private_b" {
  subnet_id      = element(var.private_subnets, 1)
  route_table_id = aws_route_table.private_rt.id
}
