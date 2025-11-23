# AWS SonarQube Infrastructure Diagram

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           INTERNET (0.0.0.0/0)                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ HTTP/HTTPS (80, 443)
                                        │ SSH (22)
                                        │
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    EXISTING VPC (Peered VPC)                                        │
│                    CIDR: 173.0.0.0/16                                               │
│                    Name: project-vpc                                                │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐  │
│  │                    Jenkins Server                                            │  │
│  │                    (EC2 Instance)                                            │  │
│  │                    - Runs Jenkins Pipeline                                   │  │
│  │                    - Executes Terraform & Ansible                            │  │
│  └──────────────────────────────────────────────────────────────────────────────┘  │
│                                        │                                            │
│                                        │ VPC Peering Connection                     │
│                                        │ (173.0.0.0/16 ↔ 10.0.0.0/16)              │
└────────────────────────────────────────┼────────────────────────────────────────────┘
                                         │
                                         │
┌────────────────────────────────────────┼────────────────────────────────────────────┐
│                    SONARQUBE VPC (New VPC)                                          │
│                    CIDR: 10.0.0.0/16                                                 │
│                    Name: sonarqube-vpc                                              │
│                    Region: us-east-1                                                 │
│                                                                                     │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                    Internet Gateway (IGW)                                   │   │
│  │                    Name: sonarqube-igw                                     │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        │                                            │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                    PUBLIC SUBNET A                                          │   │
│  │                    CIDR: 10.0.1.0/24                                       │   │
│  │                    AZ: us-east-1a                                          │   │
│  │                    Route Table: public-route-table                         │   │
│  │                    NACL: public-nacl                                       │   │
│  │                                                                             │   │
│  │  ┌──────────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Bastion Host (EC2)                                                  │  │   │
│  │  │  Instance Type: t2.micro                                             │  │   │
│  │  │  Security Group: public-sg                                           │  │   │
│  │  │  Public IP: Yes                                                      │  │   │
│  │  │  Purpose: SSH access to private instances                           │  │   │
│  │  └──────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                             │   │
│  │  ┌──────────────────────────────────────────────────────────────────────┐  │   │
│  │  │  NAT Gateway                                                         │  │   │
│  │  │  Name: sonarqube-nat                                                 │  │   │
│  │  │  Elastic IP: nat-eip                                                 │  │   │
│  │  │  Purpose: Internet access for private subnets                       │  │   │
│  │  └──────────────────────────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        │                                            │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                    PUBLIC SUBNET B                                          │   │
│  │                    CIDR: 10.0.2.0/24                                       │   │
│  │                    AZ: us-east-1b                                          │   │
│  │                    Route Table: public-route-table                         │   │
│  │                    NACL: public-nacl                                       │   │
│  │                                                                             │   │
│  │  ┌──────────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Application Load Balancer (ALB)                                      │  │   │
│  │  │  Name: sonarqube-alb-internet                                         │  │   │
│  │  │  Type: Internet-facing                                                │  │   │
│  │  │  Security Group: public-sg                                            │  │   │
│  │  │  Listener: Port 80 (HTTP) → Target Group (Port 9000)                │  │   │
│  │  │  Target Group: sonarqube-tg                                           │  │   │
│  │  │  Health Check: / (Port 9000)                                         │  │   │
│  │  └──────────────────────────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        │                                            │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                    PRIVATE SUBNET A                                        │   │
│  │                    CIDR: 10.0.3.0/24                                       │   │
│  │                    AZ: us-east-1a                                          │   │
│  │                    Route Table: private-route-table                        │   │
│  │                    NACL: private-nacl                                      │   │
│  │                                                                             │   │
│  │  ┌──────────────────────────────────────────────────────────────────────┐  │   │
│  │  │  SonarQube Server 1 (EC2)                                            │  │   │
│  │  │  Instance Type: t3.large                                            │  │   │
│  │  │  Name: private-server-1a                                             │  │   │
│  │  │  Security Group: private-sg                                           │  │   │
│  │  │  Services:                                                           │  │   │
│  │  │    - SonarQube (Port 9000)                                           │  │   │
│  │  │    - PostgreSQL (Port 5432)                                          │  │   │
│  │  │  Attached to: ALB Target Group                                        │  │   │
│  │  │  Access: Via VPC Peering (from Jenkins)                              │  │   │
│  │  └──────────────────────────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        │                                            │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                    PRIVATE SUBNET B                                        │   │
│  │                    CIDR: 10.0.4.0/24                                       │   │
│  │                    AZ: us-east-1b                                          │   │
│  │                    Route Table: private-route-table                        │   │
│  │                    NACL: private-nacl                                      │   │
│  │                                                                             │   │
│  │  ┌──────────────────────────────────────────────────────────────────────┐  │   │
│  │  │  SonarQube Server 2 (EC2)                                             │  │   │
│  │  │  Instance Type: t3.large                                             │  │   │
│  │  │  Name: private-server-1b                                             │  │   │
│  │  │  Security Group: private-sg                                           │  │   │
│  │  │  Services:                                                           │  │   │
│  │  │    - SonarQube (Port 9000)                                           │  │   │
│  │  │    - PostgreSQL (Port 5432)                                          │  │   │
│  │  │  Attached to: ALB Target Group                                        │  │   │
│  │  │  Access: Via VPC Peering (from Jenkins)                              │  │   │
│  │  └──────────────────────────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
│  ┌────────────────────────────────────────────────────────────────────────────┐   │
│  │                    VPC PEERING CONNECTION                                   │   │
│  │                    Name: peering-173-to-10                                 │   │
│  │                    Requester: Existing VPC (173.0.0.0/16)                  │   │
│  │                    Accepter: SonarQube VPC (10.0.0.0/16)                  │   │
│  │                    Auto Accept: Yes                                         │   │
│  │                                                                             │   │
│  │  Routes Added:                                                             │   │
│  │    - Existing VPC Route Tables: 10.0.0.0/16 → Peering Connection         │   │
│  │    - Private Route Table: 173.0.0.0/16 → Peering Connection              │   │
│  └────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Network Flow

### 1. Internet → SonarQube Access
```
Internet (User)
    ↓ HTTP/HTTPS (Port 80/443)
Internet Gateway
    ↓
ALB (Public Subnet B)
    ↓ HTTP (Port 80)
ALB Listener
    ↓ Forward to Target Group
SonarQube Server 1 or 2 (Port 9000)
    ↓
Response back through ALB → Internet
```

### 2. Jenkins → Private Servers (Ansible Deployment)
```
Jenkins Server (173.0.0.0/16)
    ↓ SSH (Port 22)
VPC Peering Connection
    ↓
Private Subnet A/B (10.0.3.0/24 or 10.0.4.0/24)
    ↓
SonarQube Server 1 or 2
    ↓
Ansible Playbook Execution
    - Install Java
    - Install PostgreSQL
    - Install & Configure SonarQube
```

### 3. Private Servers → Internet (Package Updates)
```
SonarQube Server (Private Subnet)
    ↓ Outbound Traffic
Private Route Table
    ↓ 0.0.0.0/0
NAT Gateway (Public Subnet A)
    ↓
Internet Gateway
    ↓
Internet (Package Repositories)
```

## Security Groups

### Public Security Group (public-sg)
- **Inbound:**
  - HTTP (Port 80) from 0.0.0.0/0
  - HTTPS (Port 443) from 0.0.0.0/0
  - SSH (Port 22) from whitelisted IPs (103.87.45.36/32, 173.0.0.0/16)
- **Outbound:**
  - All traffic (0.0.0.0/0)

### Private Security Group (private-sg)
- **Inbound:**
  - SonarQube (Port 9000) from public-sg (ALB)
  - SSH (Port 22) from public-sg (Bastion) and peered VPC (173.0.0.0/16)
  - PostgreSQL (Port 5432) from private-sg (self) and peered VPC
  - HTTP (Port 80) from VPC CIDR
  - Ephemeral ports (1024-65535) from VPC and Internet (for return traffic)
- **Outbound:**
  - All traffic (0.0.0.0/0)

## Network ACLs

### Public NACL
- **Ingress:** All traffic from 0.0.0.0/0
- **Egress:** All traffic to 0.0.0.0/0

### Private NACL
- **Ingress:**
  - All traffic from VPC CIDR (10.0.0.0/16)
  - ICMP from VPC CIDR
  - SSH (Port 22) from public subnets and peered VPC (173.0.0.0/16)
  - All traffic from peered VPC (173.0.0.0/16)
  - SonarQube (Port 9000) from VPC
  - PostgreSQL (Port 5432) from VPC
  - Ephemeral ports (1024-65535) from 0.0.0.0/0 (for return traffic)
- **Egress:**
  - All traffic to 0.0.0.0/0

## Route Tables

### Public Route Table
- **Routes:**
  - 0.0.0.0/0 → Internet Gateway
- **Associated Subnets:**
  - Public Subnet A (10.0.1.0/24)
  - Public Subnet B (10.0.2.0/24)

### Private Route Table
- **Routes:**
  - 0.0.0.0/0 → NAT Gateway (for internet access)
  - 173.0.0.0/16 → VPC Peering Connection (for Jenkins access)
- **Associated Subnets:**
  - Private Subnet A (10.0.3.0/24)
  - Private Subnet B (10.0.4.0/24)

## Key Components Summary

| Component | Type | Details |
|-----------|------|---------|
| **VPC** | Network | CIDR: 10.0.0.0/16, Region: us-east-1 |
| **Public Subnets** | Network | 2 subnets across 2 AZs (10.0.1.0/24, 10.0.2.0/24) |
| **Private Subnets** | Network | 2 subnets across 2 AZs (10.0.3.0/24, 10.0.4.0/24) |
| **Internet Gateway** | Network | Provides internet access to public subnets |
| **NAT Gateway** | Network | Provides internet access to private subnets |
| **VPC Peering** | Network | Connects Jenkins VPC (173.0.0.0/16) to SonarQube VPC |
| **ALB** | Load Balancer | Internet-facing, routes traffic to SonarQube instances |
| **Bastion Host** | Compute | t2.micro in public subnet for SSH access |
| **SonarQube Servers** | Compute | 2x t3.large instances in private subnets |
| **Security Groups** | Security | 2 SGs (public-sg, private-sg) |
| **Network ACLs** | Security | 2 NACLs (public-nacl, private-nacl) |

## Deployment Flow

1. **Terraform Apply** (via Jenkins)
   - Creates VPC, subnets, IGW, NAT Gateway
   - Creates security groups and NACLs
   - Creates ALB and target groups
   - Creates EC2 instances (Bastion + 2 SonarQube servers)
   - Establishes VPC peering connection
   - Configures route tables

2. **Ansible Playbook** (via Jenkins)
   - Connects to private servers via VPC peering
   - Installs Java on SonarQube servers
   - Installs and configures PostgreSQL
   - Installs and configures SonarQube
   - Starts services

3. **Access**
   - Users access SonarQube via ALB DNS name
   - Jenkins accesses servers via VPC peering for deployment

## High Availability

- **Multi-AZ Deployment:** Servers in 2 availability zones (us-east-1a, us-east-1b)
- **Load Balancing:** ALB distributes traffic across 2 SonarQube instances
- **Health Checks:** ALB monitors target health on port 9000
- **Redundancy:** NAT Gateway, IGW, and route tables ensure network redundancy

