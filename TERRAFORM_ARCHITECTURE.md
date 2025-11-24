# Terraform Infrastructure Architecture

## Overview
This Terraform configuration creates a modular SonarQube infrastructure on AWS in the `us-east-1` region with VPC peering support.

## Region
- **Primary Region:** `us-east-1`
- **Both VPCs:** Must be in `us-east-1` for peering to work

---

## Module Structure

```
infra-sonarqube-modular/
├── main.tf                    # Root module - orchestrates all modules
├── provider.tf                 # AWS provider configuration (us-east-1)
├── variables.tf               # Root module variables
├── terraform.tfvars           # Variable values
├── outputs.tf                 # Root module outputs
└── modules/
    ├── vpc/                   # VPC and Subnets
    ├── network/               # IGW, NAT Gateway, Route Tables
    ├── security/              # Security Groups and NACLs
    ├── keypair/               # EC2 Key Pair
    ├── compute/               # EC2 Instances and Launch Templates
    ├── alb/                   # Application Load Balancer
    └── peering/               # VPC Peering Connection
```

---

## Module Dependency Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Root Module (main.tf)                    │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
    ┌───────┐          ┌─────────┐        ┌──────────┐
    │  VPC  │          │ KEYPAIR │        │ DATA    │
    │ Module│          │ Module  │        │ SOURCES │
    └───┬───┘          └────┬────┘        └────┬─────┘
        │                   │                   │
        │                   │                   │
        ▼                   │                   │
    ┌─────────┐             │                   │
    │ NETWORK │             │                   │
    │ Module  │             │                   │
    └────┬────┘             │                   │
         │                  │                   │
         │                  │                   │
         ▼                  │                   │
    ┌──────────┐            │                   │
    │ SECURITY │            │                   │
    │ Module   │            │                   │
    └────┬─────┘            │                   │
         │                  │                   │
         │                  │                   │
         ├──────────────────┼──────────────────┤
         │                  │                   │
         ▼                  ▼                   ▼
    ┌─────────┐        ┌──────────┐      ┌──────────┐
    │   ALB   │        │ COMPUTE  │      │ PEERING │
    │ Module  │        │ Module   │      │ Module  │
    └─────────┘        └──────────┘      └──────────┘
```

---

## Detailed Module Architecture

### 1. VPC Module (`modules/vpc/`)
**Purpose:** Creates the VPC and subnets

**Resources:**
- `aws_vpc.sonarqube_vpc` - Main VPC (10.0.0.0/16)
- `aws_subnet.public_a` - Public Subnet A (10.0.1.0/24, us-east-1a)
- `aws_subnet.public_b` - Public Subnet B (10.0.2.0/24, us-east-1b)
- `aws_subnet.private_a` - Private Subnet A (10.0.3.0/24, us-east-1a)
- `aws_subnet.private_b` - Private Subnet B (10.0.4.0/24, us-east-1b)

**Outputs:**
- `vpc_id`
- `public_subnets` [subnet_a_id, subnet_b_id]
- `private_subnets` [subnet_a_id, subnet_b_id]
- `vpc_cidr_block`

**Dependencies:** None (foundation module)

---

### 2. Network Module (`modules/network/`)
**Purpose:** Creates internet gateway, NAT gateway, and route tables

**Resources:**
- `aws_internet_gateway.igw` - Internet Gateway
- `aws_eip.nat_eip` - Elastic IP for NAT Gateway
- `aws_nat_gateway.nat_gw` - NAT Gateway (in public subnet A)
- `aws_route_table.public_rt` - Public Route Table (routes to IGW)
- `aws_route_table.private_rt` - Private Route Table (routes to NAT)
- `aws_route_table_association.public_a` - Associate public subnet A
- `aws_route_table_association.public_b` - Associate public subnet B
- `aws_route_table_association.private_a` - Associate private subnet A
- `aws_route_table_association.private_b` - Associate private subnet B

**Outputs:**
- `private_rt_id` - Used for VPC peering routes
- `nat_gateway_id`
- `internet_gw_id`

**Dependencies:** 
- Requires: `module.vpc` (vpc_id, public_subnets, private_subnets)

---

### 3. Security Module (`modules/security/`)
**Purpose:** Creates security groups and network ACLs

**Resources:**
- `aws_security_group.public_sg` - Public Security Group
  - Ingress: HTTP (80), HTTPS (443), SSH (22) from whitelisted IPs
  - Egress: All traffic
- `aws_security_group.private_sg` - Private Security Group
  - Ingress: Port 9000 from public_sg (ALB), SSH from public_sg (bastion), Port 5432 (PostgreSQL), Port 9000 (self), Port 5432 (self)
  - Egress: All traffic
- `aws_network_acl.public_nacl` - Public NACL
- `aws_network_acl.private_nacl` - Private NACL
- NACL Associations for all subnets

**Outputs:**
- `public_sg_id`
- `private_sg_id`

**Dependencies:**
- Requires: `module.vpc` (vpc_id, vpc_cidr_block, subnets for associations)

---

### 4. Keypair Module (`modules/keypair/`)
**Purpose:** Creates EC2 key pair and saves private key locally

**Resources:**
- `tls_private_key.key` - Generates RSA 4096-bit key
- `aws_key_pair.key` - AWS Key Pair
- `null_resource.ssh_directory` - Creates .ssh directory
- `local_file.private_key` - Saves private key to file

**Outputs:**
- `key_name`

**Dependencies:** None

---

### 5. ALB Module (`modules/alb/`)
**Purpose:** Creates Application Load Balancer

**Resources:**
- `aws_lb.alb` - Application Load Balancer (in public subnets)
- `aws_lb_target_group.tg` - Target Group (port 9000, health check: /api/system/status)
- `aws_lb_listener.listener` - HTTP Listener (port 80)

**Outputs:**
- `alb_dns_name`
- `target_group_arn`
- `alb_listener`

**Dependencies:**
- Requires: `module.vpc` (vpc_id, public_subnets)
- Requires: `module.security` (public_sg_id)

---

### 6. Compute Module (`modules/compute/`)
**Purpose:** Creates EC2 instances and launch templates

**Resources:**
- `data.aws_ami.ubuntu` - Ubuntu 22.04 AMI lookup
- `aws_instance.public_ec2` - Bastion Host (in public subnet A)
- `aws_instance.private_server_a` - Private Server A (in private subnet A)
- `aws_instance.private_server_b` - Private Server B (in private subnet B)
- `aws_launch_template.sonarqube_lt` - Launch Template for future ASG use
- `aws_lb_target_group_attachment.private_a_attachment` - Attach server A to ALB
- `aws_lb_target_group_attachment.private_b_attachment` - Attach server B to ALB

**Outputs:**
- `launch_template_id`
- `private_ips` [server_a_ip, server_b_ip]
- `bastion_public_ip`

**Dependencies:**
- Requires: `module.vpc` (private_subnets, public_subnets[0])
- Requires: `module.security` (private_sg_id, public_sg_id)
- Requires: `module.keypair` (key_name)
- Requires: `module.alb` (target_group_arn)

---

### 7. Peering Module (`modules/peering/`)
**Purpose:** Creates VPC peering connection (optional)

**Resources:**
- `aws_vpc_peering_connection.this` - VPC Peering Connection
- `aws_route.requester_routes` - Routes in existing VPC (173.0.0.0/16 → 10.0.0.0/16)
- `aws_route.accepter_routes` - Routes in new VPC (10.0.0.0/16 → 173.0.0.0/16)

**Dependencies:**
- Requires: `data.aws_vpc.existing_vpc` (VPC ID: vpc-00f02dc789ed26995)
- Requires: `module.vpc` (vpc_id, vpc_cidr_block)
- Requires: `module.network` (private_rt_id)
- **Conditional:** Only created if `existing_vpc_id != ""`

---

## Data Sources

1. **`data.aws_availability_zones.available`**
   - Purpose: Get available AZs in us-east-1
   - Used by: VPC module (fallback for AZ selection)

2. **`data.aws_vpc.existing_vpc`**
   - Purpose: Lookup existing VPC for peering
   - VPC ID: vpc-00f02dc789ed26995
   - Region: us-east-1
   - Conditional: Only if `existing_vpc_id != ""`

3. **`data.aws_route_tables.existing_vpc_rts`**
   - Purpose: Get route tables of existing VPC
   - Used by: Peering module for route configuration

---

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet (0.0.0.0/0)                     │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │ Internet      │
                    │ Gateway (IGW)│
                    └───────┬───────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐    ┌──────────────┐
│ Public       │   │ Public       │    │ NAT Gateway  │
│ Subnet A     │   │ Subnet B     │    │ (Public A)   │
│ 10.0.1.0/24  │   │ 10.0.2.0/24  │    │              │
│ us-east-1a   │   │ us-east-1b   │    └──────┬───────┘
│              │   │              │           │
│ ┌──────────┐ │   │ ┌──────────┐ │           │
│ │  ALB     │ │   │ │  ALB     │ │           │
│ │ (Public) │ │   │ │ (Public) │ │           │
│ └────┬─────┘ │   │ └────┬─────┘ │           │
│      │       │   │      │       │           │
│ ┌────▼─────┐ │   │      │       │           │
│ │ Bastion  │ │   │      │       │           │
│ │ Host     │ │   │      │       │           │
│ └──────────┘ │   │      │       │           │
└──────────────┘   └──────┼───────┘           │
                          │                   │
                          │                   ▼
        ┌─────────────────┼──────────┐  ┌──────────────┐
        │                 │          │  │ Private      │
        ▼                 ▼          │  │ Subnet A     │
┌──────────────┐  ┌──────────────┐  │  │ 10.0.3.0/24  │
│ Private      │  │ Private     │  │  │ us-east-1a   │
│ Subnet A     │  │ Subnet B     │  │  │              │
│ 10.0.3.0/24  │  │ 10.0.4.0/24  │  │  │ ┌──────────┐ │
│ us-east-1a   │  │ us-east-1b   │  │  │ │ SonarQube│ │
│              │  │              │  │  │ │ Server A │ │
│ ┌──────────┐ │  │ ┌──────────┐ │  │  │ └──────────┘ │
│ │ SonarQube│ │  │ │ SonarQube│ │  │  └──────────────┘
│ │ Server A │ │  │ │ Server B │ │  │
│ └──────────┘ │  │ └──────────┘ │  │
└──────────────┘  └──────────────┘  │
                                    │
                                    ▼
                            ┌──────────────┐
                            │ Private      │
                            │ Subnet B     │
                            │ 10.0.4.0/24  │
                            │ us-east-1b   │
                            │              │
                            │ ┌──────────┐ │
                            │ │ SonarQube│ │
                            │ │ Server B │ │
                            │ └──────────┘ │
                            └──────────────┘
```

---

## VPC Peering Architecture

```
┌─────────────────────────────────────┐
│   Existing VPC (173.0.0.0/16)       │
│   VPC ID: vpc-00f02dc789ed26995     │
│   Region: us-east-1                  │
│                                      │
│   ┌──────────────────────────────┐  │
│   │ Route Tables (Requester)     │  │
│   │ Route: 10.0.0.0/16 → Peering │  │
│   └──────────────────────────────┘  │
└───────────────┬─────────────────────┘
                │
                │ VPC Peering Connection
                │ (pcx-xxxxx)
                │
┌───────────────▼─────────────────────┐
│   New VPC (10.0.0.0/16)             │
│   VPC ID: module.vpc.vpc_id        │
│   Region: us-east-1                 │
│                                      │
│   ┌──────────────────────────────┐  │
│   │ Private Route Table          │  │
│   │ Route: 173.0.0.0/16 → Peering│  │
│   └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

---

## Resource Dependencies

### Creation Order:
1. **VPC Module** → Creates VPC and subnets (foundation)
2. **Keypair Module** → Creates key pair (independent)
3. **Network Module** → Creates IGW, NAT, route tables (depends on VPC)
4. **Security Module** → Creates security groups and NACLs (depends on VPC)
5. **ALB Module** → Creates load balancer (depends on VPC, Security)
6. **Compute Module** → Creates EC2 instances (depends on VPC, Security, Keypair, ALB)
7. **Peering Module** → Creates VPC peering (depends on VPC, Network, optional)

### Data Flow:
```
VPC → Network → Security → ALB
  ↓       ↓        ↓
  └───────┴────────┴──→ Compute
         │
         └──→ Peering (optional)
```

---

## Key Configuration Details

### CIDR Blocks:
- **New VPC:** 10.0.0.0/16
- **Public Subnet A:** 10.0.1.0/24
- **Public Subnet B:** 10.0.2.0/24
- **Private Subnet A:** 10.0.3.0/24
- **Private Subnet B:** 10.0.4.0/24
- **Peered VPC:** 173.0.0.0/16

### Availability Zones:
- **Primary AZ:** us-east-1a (Public A, Private A)
- **Secondary AZ:** us-east-1b (Public B, Private B)
- **Fallback:** Uses `data.aws_availability_zones` if specified AZs are invalid

### Instance Types:
- **Bastion Host:** t2.micro
- **SonarQube Servers:** t3.large

### Ports:
- **ALB Listener:** 80 (HTTP)
- **SonarQube:** 9000
- **PostgreSQL:** 5432
- **SSH:** 22

---

## Outputs

### Root Module Outputs:
- `alb_dns_name` - ALB DNS for accessing SonarQube
- `vpc_id` - VPC ID
- `launch_template_id` - Launch Template ID
- `aws_private_instance_ip` - Private instance IPs
- `bastion_public_ip` - Bastion host public IP
- `user` - Default user (ubuntu)

---

## Deployment Flow

1. **Terraform Init** → Initialize providers and modules
2. **Terraform Plan** → Show planned changes
3. **Terraform Apply** → Create infrastructure:
   - VPC and subnets
   - Network components (IGW, NAT, routes)
   - Security groups and NACLs
   - Key pair
   - ALB and target group
   - EC2 instances (bastion + 2 private servers)
   - VPC peering (if existing_vpc_id provided)
4. **Ansible Installation** → Install SonarQube on private instances via dynamic inventory

---

## Important Notes

1. **Region:** All resources are in `us-east-1`
2. **VPC Peering:** Both VPCs must be in `us-east-1` for peering to work
3. **Availability Zones:** Uses data source as fallback if specified AZs are invalid
4. **Dynamic Inventory:** Ansible uses `aws_ec2.yml` to discover instances by tags (`env=sonarqube`)
5. **SSH Key:** Stored at `${WORKSPACE}/.ssh/sonarqube-key.pem`
6. **Primary Task:** Install SonarQube using dynamic inventory on private instances

---

## Module Communication

```
Root Module (main.tf)
    │
    ├─→ VPC Module
    │   └─→ Outputs: vpc_id, subnets, cidr_block
    │
    ├─→ Network Module
    │   ├─→ Input: vpc_id, subnets
    │   └─→ Output: private_rt_id (for peering)
    │
    ├─→ Security Module
    │   ├─→ Input: vpc_id, subnets, cidr_blocks
    │   └─→ Output: public_sg_id, private_sg_id
    │
    ├─→ Keypair Module
    │   └─→ Output: key_name
    │
    ├─→ ALB Module
    │   ├─→ Input: vpc_id, public_subnets, public_sg_id
    │   └─→ Output: target_group_arn, alb_dns_name
    │
    ├─→ Compute Module
    │   ├─→ Input: subnets, security_groups, key_name, target_group_arn
    │   └─→ Output: private_ips, bastion_public_ip
    │
    └─→ Peering Module (optional)
        ├─→ Input: existing_vpc_id, new_vpc_id, route_tables
        └─→ Creates: VPC peering connection and routes
```

---

## Security Architecture

### Security Groups:
- **Public SG:** Allows HTTP/HTTPS from internet, SSH from whitelisted IPs
- **Private SG:** Allows port 9000 from ALB, SSH from bastion, PostgreSQL from self

### Network ACLs:
- **Public NACL:** Allows HTTP/HTTPS ingress, SSH from whitelisted IPs, all egress
- **Private NACL:** Allows VPC CIDR traffic, SSH from public subnets, ports 9000/5432 from VPC

---

## High-Level Architecture Diagram

```
                    Internet
                       │
                       ▼
                  ┌─────────┐
                  │   ALB   │ (Public Subnets)
                  └────┬────┘
                       │ Port 80 → 9000
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
  ┌─────────┐    ┌─────────┐    ┌─────────┐
  │Bastion  │    │Private  │    │Private  │
  │Host     │    │Server A │    │Server B │
  │(Public) │    │(Private)│    │(Private)│
  └────┬────┘    └────┬────┘    └────┬────┘
       │              │              │
       │ SSH          │              │
       └──────────────┴──────────────┘
                      │
                      ▼
              ┌───────────────┐
              │  SonarQube    │
              │  Instances    │
              │  (Ansible)    │
              └───────────────┘
```

---

## Terraform State Management

- **Backend:** S3 (sonarqube-terraform-state-12)
- **Region:** eu-central-1 (for state bucket)
- **Encryption:** Enabled
- **Locking:** Enabled (use_lockfile = true)

---

## Variable Flow

```
terraform.tfvars
    │
    ├─→ Root variables.tf
    │       │
    │       └─→ Module Variables
    │               │
    │               ├─→ VPC Module
    │               ├─→ Network Module
    │               ├─→ Security Module
    │               ├─→ Keypair Module
    │               ├─→ Compute Module
    │               ├─→ ALB Module
    │               └─→ Peering Module
```

---

This architecture provides a modular, scalable infrastructure for deploying SonarQube with proper network isolation, security, and high availability.


