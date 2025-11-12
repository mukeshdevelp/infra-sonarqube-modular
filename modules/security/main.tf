# creating public and private  and db security groups

resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.everywhere_host
  }
  ingress{
    description = "ephemeral ports"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.everywhere_host
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.everywhere_host
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_host
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # note - cidr block should be a list
    cidr_blocks = var.everywhere_host
  }
  tags = {
    Name = "sonarqube-public-sg"
    attached_to = "pub-subnet-1 and pub-subnet-2"
    availibility = "1a 1b"
  }
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow ALB to EC2 traffic"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }
  # Allow SSH from the bastion/public SG only
  ingress {
    description     = "SSH from bastion SG"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  # Allow SonarQube (9000) and Postgres (5432) traffic within the private SG (self)
  ingress {
    description = "SonarQube port from private SG"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    self        = true
  }
  ingress {
    description = "Postgres port from private SG"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.everywhere_host
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.everywhere_host
  }

  tags = {
    Name = "sonarqube-private-sg"
    attached_to = "pri-subnet-1 and pri-subnet-2"
    availibility = "1a 1b"
  }
}


resource "aws_security_group" "postgres_sg" {
  name        = "postgres-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # Allow PostgreSQL only from the private SG (instances running DB/SonarQube)
    security_groups = [aws_security_group.private_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # note - cidr block should be a list
    cidr_blocks = var.everywhere_host
  }
  tags = {
    Name = "sonarqube-db-sg"
    attached_to = "pri-db-subnet-1 and pri-db-subnet-2"
    availibility = "1a 1b"
  }
}


# Network ACLs (Simplified)

resource "aws_network_acl" "public_nacl" {
  vpc_id = var.vpc_id
  # Allow SSH from whitelisted IPs, HTTP/HTTPS from everywhere and allow all egress
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.allowed_host[0]
    from_port  = 22
    to_port    = 22
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
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
    attached_to = "public subnets a and b"
    access = "public"
  }
}

resource "aws_network_acl" "private_nacl" {
  vpc_id = var.vpc_id
  # Allow internal VPC traffic in private subnets (assume var.everywhere_host contains appropriate VPC CIDRs)
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.everywhere_host[0]
    from_port  = 0
    to_port    = 0
  }
  # Allow SSH from the bastion/public IPs (restrict to whitelisted public IPs)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.allowed_host[0]
    from_port  = 22
    to_port    = 22
  }
  # Allow SonarQube and DB ports within private subnets
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = var.everywhere_host[0]
    from_port  = 9000
    to_port    = 9000
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = var.everywhere_host[0]
    from_port  = 5432
    to_port    = 5432
  }
  # all allow egress
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  # ssh egress
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  # 8080 egress
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 8080
    to_port    = 8080
  }
  # sonarqube egress
  egress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 9000
    to_port    = 9000
  }
  # db port
  egress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  tags = {
    Name = "private-nacl"
    attached_to = "private subnet a and b"
    access = "private"
  }
}



resource "aws_network_acl_association" "pub_subnet_a_association" {
  subnet_id      = var.pub_subnet_a_association  # Reference to your subnet
  network_acl_id = aws_network_acl.public_nacl.id  # Reference to your NACL
}

resource "aws_network_acl_association" "pub_subnet_b_association" {
  subnet_id      = var.pub_subnet_b_association   # Reference to your subnet
  network_acl_id = aws_network_acl.public_nacl.id   # Reference to your NACL
}

resource "aws_network_acl_association" "pri_subnet_a_association" {
  subnet_id      = var.pri_subnet_a_association   # Reference to your subnet
  network_acl_id = aws_network_acl.private_nacl.id   # Reference to your NACL
}

resource "aws_network_acl_association" "pri_subnet_b_association" {
  subnet_id      = var.pri_subnet_b_association   # Reference to your subnet
  network_acl_id = aws_network_acl.private_nacl.id  # Reference to your NACL
}