# creating public and private  and db security groups

resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow HTTP, HTTPS, SSH"
  vpc_id      = var.vpc_id
  # tcp for everyone
  ingress {
      from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  
    cidr_blocks = var.everywhere_host
  }
  # http for every one
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.everywhere_host
  }
  # ssh for allowed hosts
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_host
  }
  # all rgress
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
  # sonarqube port
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
    # Allow SSH from the public (bastion) security group
    security_groups = [aws_security_group.public_sg.id]
  }

  # Also allow SSH from the requester VPC CIDR (peer VPC)
  # vpc peering connection ssh
  ingress {
    description = "SSH from requester VPC CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.peered_vpc_cidr]
  }

  # Allow SonarQube (9000) and Postgres (5432) traffic within the private SG (self)
  ingress {
    description = "SonarQube port from private SG"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    self        = true
  }
  # PostgreSQL access from private SG (self)
  ingress {
    description = "Postgres port from private SG"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
  }
  # PostgreSQL access from peered VPC
  ingress {
    description = "Postgres port from peered VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.peered_vpc_cidr]
  }
  # HTTP from VPC only (for internal communication)
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
  
  # Ephemeral ports from VPC only (for return traffic from outbound connections)
  ingress{
    description = "ephemeral ports from VPC"
    from_port   = 1024
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
  ingress {
    description     = "Ping for diagnostics (optional)"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    cidr_blocks     = [var.vpc_cidr_block]
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


# Network ACLs (Simplified)

resource "aws_network_acl" "public_nacl" {
  vpc_id = var.vpc_id
  # Allow SSH from whitelisted IPs, HTTP/HTTPS from everywhere and allow all egress
  
  # allowed host ingress
  ingress {
    protocol   = "tcp"
    rule_no    = 110 
    action     = "allow"
    cidr_block = var.allowed_host[0]
    from_port  = 22
    to_port    = 22
  }
  # peer vpc ssh
  ingress {
    protocol   = "tcp"
    rule_no    = 1700
    action     = "allow"
    cidr_block = var.peered_vpc_cidr
    from_port  = 22
    to_port    = 22
  }
  # vpc cidr ssh
  ingress {
    protocol   = "tcp"
    rule_no    = 1800
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 22
    to_port    = 22
  }
  # allowed host ssh
  ingress {
    protocol   = "tcp"
    rule_no    = 2000
    action     = "allow"
    cidr_block = var.allowed_host[0]
    from_port  = 22
    to_port    = 22
  }
  # tcp 80 and 443 ingress
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
  # all egress (catch-all)
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  # ICMP egress (ping)
  egress {
    protocol   = "icmp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  # DNS egress (UDP port 53)
  egress {
    protocol   = "udp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
  # DNS egress (TCP port 53)
  egress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
  # ICMP ingress (ping replies)
  ingress {
    protocol   = "icmp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  # DNS ingress (UDP port 53) - for DNS responses
  ingress {
    protocol   = "udp"
    rule_no    = 210
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
  # DNS ingress (TCP port 53) - for DNS responses
  ingress {
    protocol   = "tcp"
    rule_no    = 220
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
  # TCP ingress on ephemeral ports (1024-65535) - for return traffic from outbound connections
  ingress {
    protocol   = "tcp"
    rule_no    = 230
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  # UDP ingress on ephemeral ports (1024-65535) - for return traffic from outbound connections
  ingress {
    protocol   = "udp"
    rule_no    = 240
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  tags = {
    Name = "public-nacl"
    attached_to = "public subnets a and b"
    access = "public"
  }
}

resource "aws_network_acl" "private_nacl" {
  vpc_id = var.vpc_id
  # Allow internal VPC traffic in private subnets (VPC CIDR only, NOT from internet)
  # all allow ingress from VPC CIDR only
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }
  # ICMP from VPC CIDR (allows ping from bastion host)
  ingress {
    protocol   = "icmp"
    rule_no    = 105
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }
  # SSH from public subnet CIDR (allows bastion host specifically)
  ingress {
    protocol   = "tcp"
    rule_no    = 108
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 22
    to_port    = 22
  }
  # SSH from public subnet 1b CIDR
  ingress {
    protocol   = "tcp"
    rule_no    = 109
    action     = "allow"
    cidr_block = var.public_subnet_b_cidr
    from_port  = 22
    to_port    = 22
  }
  # SSH from VPC CIDR (allows bastion host in public subnet)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 22
    to_port    = 22
  }
  # SSH from allowed hosts (external IPs)
  ingress {
    protocol   = "tcp"
    rule_no    = 111
    action     = "allow"
    cidr_block = var.allowed_host[0]
    from_port  = 22
    to_port    = 22
  }
  # SSH from peering VPC
  ingress {
    protocol   = "tcp"
    rule_no    = 112
    action     = "allow"
    cidr_block = var.peered_vpc_cidr
    from_port  = 22
    to_port    = 22
  }
  # all peer vpc ingress
  ingress {
    protocol   = "-1"
    rule_no    = 190
    action     = "allow"
    cidr_block = var.peered_vpc_cidr
    from_port  = 0
    to_port    = 0
  }
  # Allow SonarQube and DB ports from VPC and peered VPC only (NOT from internet)
  # sonarqube port from VPC (ALB will route traffic)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 9000
    to_port    = 9000
  }
  # db port from VPC
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 5432
    to_port    = 5432
  }
  # db port from peered VPC
  ingress {
    protocol   = "tcp"
    rule_no    = 131
    action     = "allow"
    cidr_block = var.peered_vpc_cidr
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
  # http egress from everywhere
  egress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # https egress from everywhere
  egress {
    protocol   = "tcp"
    rule_no    = 160
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  # DNS egress (UDP port 53)
  egress {
    protocol   = "udp"
    rule_no    = 170
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
  # DNS egress (TCP port 53)
  egress {
    protocol   = "tcp"
    rule_no    = 171
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
  # ICMP egress (ping)
  egress {
    protocol   = "icmp"
    rule_no    = 180
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  # ICMP ingress (ping replies) from VPC CIDR
  ingress {
    protocol   = "icmp"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.vpc_cidr_block
    from_port  = 0
    to_port    = 0
  }
  # ICMP ingress (ping replies) from everywhere (for general connectivity)
  ingress {
    protocol   = "icmp"
    rule_no    = 201
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  # all traffic egress from peer vpc
  egress {
    protocol   = "-1"
    rule_no    = 190
    action     = "allow"
    cidr_block = var.peered_vpc_cidr
    from_port  = 0
    to_port    = 0
  }
  # TCP ingress on ephemeral ports (1024-65535) - for return traffic from outbound connections via NAT Gateway
  ingress {
    protocol   = "tcp"
    rule_no    = 250
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  # UDP ingress on ephemeral ports (1024-65535) - for return traffic from outbound connections via NAT Gateway
  ingress {
    protocol   = "udp"
    rule_no    = 260
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
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
