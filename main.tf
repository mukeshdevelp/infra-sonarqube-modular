
# Root Module (main.tf)

module "vpc" {
  source                     = "./modules/vpc"
  vpc_cidr_block             = var.vpc_cidr_block
  public_subnet_a_az         = var.public_subnet_a_az
  public_subnet_a_cidr_block = var.public_subnet_a_cidr_block

  public_subnet_b_az         = var.public_subnet_b_az
  public_subnet_b_cidr_block = var.public_subnet_b_cidr_block



  private_subnet_a_cidr_block = var.private_subnet_a_cidr_block

  private_subnet_a_az = var.private_subnet_a_az

  private_subnet_b_cidr_block = var.private_subnet_b_cidr_block

  private_subnet_b_az = var.private_subnet_b_az
}

module "network" {
  source          = "./modules/network"
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets

}

module "security" {
  source                   = "./modules/security"
  vpc_id                   = module.vpc.vpc_id
  allowed_host             = var.whitelisted_ip
  everywhere_host          = var.all_hosts
  pub_subnet_a_association = module.vpc.public_subnets[0]
  pub_subnet_b_association = module.vpc.public_subnets[1]
  pri_subnet_a_association = module.vpc.private_subnets[0]
  pri_subnet_b_association = module.vpc.private_subnets[1]

}

module "keypair" {
  source = "./modules/keypair"
  # pointing the child module variable to root module variable
  key_name     = var.key_pair_name
  key_location = var.ec2_key_location
}

module "compute" {
  source          = "./modules/compute"
  private_subnets = module.vpc.private_subnets

  private_sg = [module.security.private_sg_id, module.security.postgres_sg_id]

  target_group_arn = module.alb.target_group_arn

  public_subnet_a_id = module.vpc.public_subnets[0]

  public_security_group = module.security.public_sg_id

  key_name = module.keypair.key_name

  sonarqube_instance_size = var.instance_size_big_for_sonarqube

  # for asg
  desired_number = var.desired_number
  max_number     = var.max_number
  min_number     = var.min_number
  alb_listener   = [module.alb.alb_listener]
}

module "alb" {
  source         = "./modules/alb"
  vpc_id         = module.vpc.vpc_id
  public_subnets = module.vpc.public_subnets
  public_sg_id   = module.security.public_sg_id

}

data "aws_vpc" "existing_vpc" {
  filter {
    name = "tag:Name"
    values = ["project-vpc"]
  }
}

# FETCH ROUTE TABLES OF EXISTING VPC
data "aws_route_tables" "existing_vpc_rts" {
  vpc_id = data.aws_vpc.existing_vpc.id
}

module "vpc_peering" {
  source = "./modules/peering"

 
  # REQUESTER → EXISTING VPC (173.0.0.0/16)
  

  requester_vpc_id   = data.aws_vpc.existing_vpc.id
  requester_vpc_cidr = "173.0.0.0/16"

  requester_route_tables = data.aws_route_tables.existing_vpc_rts.ids
  

  #########################################
  # ACCEPTER → NEW VPC (10.0.0.0/16)
  #########################################

  accepter_vpc_id   = module.vpc.vpc_id     # <-- Your newly created VPC
  accepter_vpc_cidr = module.vpc.vpc_cidr_block # usually 10.0.0.0/16

  accepter_route_tables = module.network.private_rt_id
  # OR hardcode:
  # accepter_route_tables = ["rtb-yyyyyyy"]

  #########################################
  # META CONFIG
  #########################################

  name        = "peering-173-to-10"
  peer_region = "us-east-1"
  auto_accept = true

  tags = {
    Project = "sonarqube-deployment"
    Owner   = "Mukesh"
  }
}




/*
# going to write it again


# Terraform Backend

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }

  backend "s3" {
    bucket         = "sonarqube-terraform-state-1"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    //dynamodb_table = "terraform-locks"
    use_lockfile = true
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  
}


# VPC

resource "aws_vpc" "sonarqube_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "sonarqube-vpc"
  }
}


# Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.sonarqube_vpc.id
  tags = {
    Name = "sonarqube-igw"
  }
}

# Subnets (2 Public, 2 Private)

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.sonarqube_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.sonarqube_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.sonarqube_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.sonarqube_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private-subnet-b"
  }
}

#
# NAT Gateway (for Private Subnets)

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "nat-eip" }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_a.id
  tags = {
    Name = "sonarqube-nat"
  }
}


# Route Tables & Associations

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sonarqube_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.sonarqube_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Groups

# Public SG (ALB, SSH)
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = aws_vpc.sonarqube_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["103.87.45.36/32"] # Change this
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "public-sg" }
}

# Private SG (EC2, internal app)
resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow inbound from ALB"
  vpc_id      = aws_vpc.sonarqube_vpc.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}
# Security Group for PostgreSQL
resource "aws_security_group" "postgres_sg" {
  name        = "postgres-sg"
  description = "Allow PostgreSQL access from SonarQube instances"
  vpc_id      = aws_vpc.sonarqube_vpc.id

  # Allow PostgreSQL traffic only from the private_sg (SonarQube EC2)
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.private_sg.id]
  }

  # Allow outbound traffic (DB can reach out if needed)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-sg"
  }
}


# Network ACLs (Simplified)

resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.sonarqube_vpc.id
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

resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.sonarqube_vpc.id
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/16"
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


# Key Pair

resource "tls_private_key" "sonarqube_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "sonarqube_key" {
  key_name   = "sonarqube-key"
  public_key = tls_private_key.sonarqube_key.public_key_openssh
}

# Optional: save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.sonarqube_key.private_key_pem
  filename        = ".ssh/sonarqube-key.pem"
  file_permission = "0600"
}



# Application Load Balancer (ALB)

resource "aws_lb" "sonarqube_alb" {
  name               = "sonarqube-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id
  ]
  tags = {
  Name = "sonarqube-alb" }
}

resource "aws_lb_target_group" "sonarqube_tg" {
  name     = "sonarqube-tg"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = aws_vpc.sonarqube_vpc.id
  health_check {
    path = "/"
    port = "9000"
  }
  tags = {
    Name = "sonarqube-tg"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.sonarqube_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sonarqube_tg.arn
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template (SonarQube EC2)

resource "aws_launch_template" "sonarqube_lt" {
  name                   = "sonarqube-lt-"
  image_id           	 = data.aws_ami.ubuntu # Replace with the correct Ubuntu AMI or machine ami ID
  instance_type          = "t3.large"
  key_name               = aws_key_pair.sonarqube_key.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  # remove this block at last...before creating in
  # Ensure user data is properly base64 encoded using base64encode()
  user_data = base64encode(<<-EOF
    #!/bin/bash
   
    sudo apt-get update -y
    sudo apt-get install -y docker.io git
    sudo systemctl enable docker
    sudo systemctl start docker

    docker run -d --name sonarqube -p 9000:9000 sonarqube:lts
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "sonarqube-instance" }
  }
}


# Auto Scaling Group (ASG)

resource "aws_autoscaling_group" "sonarqube_asg" {
  name             = "sonarqube-asg"
  desired_capacity = 2
  max_size         = 3
  min_size         = 1
  vpc_zone_identifier = [
    aws_subnet.private_subnet_a.id,
    aws_subnet.private_subnet_b.id
  ]
  target_group_arns = [aws_lb_target_group.sonarqube_tg.arn]
  health_check_type = "EC2"

  launch_template {
    id      = aws_launch_template.sonarqube_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "sonarqube-instance"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.alb_listener]
}


# Outputs

output "alb_dns_name" {
  value       = aws_lb.sonarqube_alb.dns_name
  description = "Access SonarQube via this ALB URL"
}

output "vpc_id" {
  value = aws_vpc.sonarqube_vpc.id
}
*/