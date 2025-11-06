# vpc/main.tf
resource "aws_vpc" "sonarqube_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name

  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.sonarqube_vpc.id
  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# elastic ip for nat gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { 
    Name = "${var.vpc_name}-nat-eip"
  }
}

# NAT Gateway (for Private Subnets)

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  # receives from the subnet module
  subnet_id     = var.public_subnets[0]
  tags = {
    Name = "${var.vpc_name}-nat"
  }
}





