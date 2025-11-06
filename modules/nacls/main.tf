#nacl/main.tf
# Define the public NACL
resource "aws_network_acl" "public_nacl" {
  vpc_id = var.vpc_id
  
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "public-nacl"
  }
}

# Define the private NACL
resource "aws_network_acl" "private_nacl" {
  vpc_id = var.vpc_id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.private_cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "private-nacl"
  }
}

# Associate NACL with public subnets
resource "aws_network_acl_association" "public_assoc" {
  for_each       = toset(var.public_subnets)
  network_acl_id = aws_network_acl.public_nacl.id
  subnet_id      = each.value
}

# Associate NACL with private subnets
resource "aws_network_acl_association" "private_assoc" {
  for_each       = toset(var.private_subnets)
  network_acl_id = aws_network_acl.private_nacl.id
  subnet_id      = each.value
}
