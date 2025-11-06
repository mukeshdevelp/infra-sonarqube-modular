#subnet/main.tf
# Subnets (2 Public, 2 Private) #done

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnets_cidrs[0]
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags = {

    Name = "${var.subnet_name[0]}"
    access = "${var.access[0]}"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnets_cidrs[1]
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.subnet_name[1]}"
    access = "${var.access[1]}"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnets_cidrs[0]
  availability_zone = var.availability_zones[0]
  tags = {
    Name = "${var.subnet_name[2]}"
    access = "${var.access[2]}"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = var.vpc_id
  cidr_block        = var.private_subnets_cidrs[1]
  availability_zone = var.availability_zones[1]
  tags = {
    Name = "${var.subnet_name[3]}"
    access = "${var.access[3]}"
  }
}



