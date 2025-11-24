# Get available availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# creating vpc and subents
resource "aws_vpc" "sonarqube_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { 
    Name = "sonarqube-vpc"
    env = "sonarqube-env" 
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.sonarqube_vpc.id
  cidr_block              = var.public_subnet_a_cidr_block
  availability_zone       = var.public_subnet_a_az != "" ? var.public_subnet_a_az : data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { 
    Name = "sonar-public-subnet-a"
    az = "1a"
    access ="public"
    attatched_to = "public-security-group" 
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.sonarqube_vpc.id
  cidr_block              = var.public_subnet_b_cidr_block
  availability_zone       = var.public_subnet_b_az != "" ? var.public_subnet_b_az : data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { 
    Name = "sonar-public-subnet-b"
    az = "1b"
    access ="public"
    attatched_to = "public-security-group" 
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.sonarqube_vpc.id
  cidr_block        = var.private_subnet_a_cidr_block
  availability_zone = var.private_subnet_a_az != "" ? var.private_subnet_a_az : data.aws_availability_zones.available.names[0]
  tags = { 
    Name = "sonar-private-subnet-a"
    az = "1a"
    access ="through-bastion-host"
    attatched_to = "private-security-group" 
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.sonarqube_vpc.id
  cidr_block        = var.private_subnet_b_cidr_block
  availability_zone = var.private_subnet_b_az != "" ? var.private_subnet_b_az : data.aws_availability_zones.available.names[1]
  tags = { 
    Name = "sonar-private-subnet-b"
    az = "1b"
    access ="through-bastion-host"
    attatched_to = "private-security-group" 
  }
}
