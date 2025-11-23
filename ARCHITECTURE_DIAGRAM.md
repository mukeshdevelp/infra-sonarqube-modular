# SonarQube Infrastructure - Architecture & Network Flow Diagram

## 🏗️ Complete Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS VPC (10.0.0.0/16)                             │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    PUBLIC SUBNETS                                     │  │
│  │                                                                         │  │
│  │  ┌──────────────────────────┐    ┌──────────────────────────┐        │  │
│  │  │  Public Subnet A         │    │  Public Subnet B          │        │  │
│  │  │  (10.0.1.0/24)           │    │  (10.0.2.0/24)            │        │  │
│  │  │  us-east-1a              │    │  us-east-1b               │        │  │
│  │  │                          │    │                          │        │  │
│  │  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │        │  │
│  │  │  │  NAT Gateway       │  │    │  │                    │  │        │  │
│  │  │  │  (Elastic IP)      │  │    │  │                    │  │        │  │
│  │  │  └────────────────────┘  │    │  │                    │  │        │  │
│  │  │                          │    │  │                    │  │        │  │
│  │  │  ┌────────────────────┐  │    │  │  ┌──────────────┐  │  │        │  │
│  │  │  │  Application       │  │    │  │  │  Application│  │  │        │  │
│  │  │  │  Load Balancer     │  │    │  │  │  Load        │  │  │        │  │
│  │  │  │  (ALB)             │  │    │  │  │  Balancer     │  │  │        │  │
│  │  │  │  Port: 80          │  │    │  │  │  (ALB)        │  │  │        │  │
│  │  │  └────────────────────┘  │    │  │  └──────────────┘  │  │        │  │
│  │  │                          │    │  │                    │  │        │  │
│  │  │  ┌────────────────────┐  │    │  │                    │  │        │  │
│  │  │  │  Image Builder    │  │    │  │                    │  │        │  │
│  │  │  │  EC2 Instance     │  │    │  │                    │  │        │  │
│  │  │  │  (Public IP)      │  │    │  │                    │  │        │  │
│  │  │  │  - SonarQube      │  │    │  │                    │  │        │  │
│  │  │  │  - PostgreSQL     │  │    │  │                    │  │        │  │
│  │  │  │  - For AMI Build  │  │    │  │                    │  │        │  │
│  │  │  └────────────────────┘  │    │  │                    │  │        │  │
│  │  │                          │    │  │                    │  │        │  │
│  │  │  Route Table:           │    │  │  Route Table:      │  │        │  │
│  │  │  0.0.0.0/0 → IGW        │    │  │  0.0.0.0/0 → IGW   │  │        │  │
│  │  └──────────────────────────┘    └──────────────────────────┘        │  │
│  │                                                                         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    PRIVATE SUBNETS                                    │  │
│  │                                                                         │  │
│  │  ┌──────────────────────────┐    ┌──────────────────────────┐        │  │
│  │  │  Private Subnet A        │    │  Private Subnet B         │        │  │
│  │  │  (10.0.3.0/24)           │    │  (10.0.4.0/24)            │        │  │
│  │  │  us-east-1a              │    │  us-east-1b               │        │  │
│  │  │                          │    │                          │        │  │
│  │  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │        │  │
│  │  │  │  SonarQube EC2      │  │    │  │  SonarQube EC2      │  │        │  │
│  │  │  │  Instance A         │  │    │  │  Instance B         │  │        │  │
│  │  │  │  (No Public IP)     │  │    │  │  (No Public IP)     │  │        │  │
│  │  │  │                      │  │    │  │                      │  │        │  │
│  │  │  │  - SonarQube        │  │    │  │  - SonarQube        │  │        │  │
│  │  │  │    (Port 9000)      │  │    │  │    (Port 9000)      │  │        │  │
│  │  │  │  - PostgreSQL        │  │    │  │  - PostgreSQL        │  │        │  │
│  │  │  │    (Port 5432)       │  │    │  │    (Port 5432)      │  │        │  │
│  │  │  │  - From Golden AMI   │  │    │  │  - From Golden AMI   │  │        │  │
│  │  │  └────────────────────┘  │    │  │  └────────────────────┘  │        │  │
│  │  │                          │    │  │                          │        │  │
│  │  │  Route Table:           │    │  │  Route Table:           │        │  │
│  │  │  0.0.0.0/0 → NAT GW     │    │  │  0.0.0.0/0 → NAT GW     │        │  │
│  │  └──────────────────────────┘    └──────────────────────────┘        │  │
│  │                                                                         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Internet Gateway (IGW)                              │  │
│  │                    Attached to VPC                                    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │
                          ┌─────────▼─────────┐
                          │   Internet        │
                          └───────────────────┘
```

## 🔄 Network Flow Diagrams

### 1. Internet Access Flow (Private Instances → Internet)

```
Private Instance (10.0.3.x or 10.0.4.x)
    │
    │ Outbound Traffic (e.g., apt update, yum install)
    │
    ▼
Private Route Table
    │
    │ Route: 0.0.0.0/0 → NAT Gateway
    │
    ▼
NAT Gateway (in Public Subnet A)
    │
    │ Routes through Elastic IP
    │
    ▼
Public Route Table
    │
    │ Route: 0.0.0.0/0 → Internet Gateway
    │
    ▼
Internet Gateway (IGW)
    │
    │
    ▼
Internet
```

### 2. ALB Traffic Flow (Internet → SonarQube)

```
Internet User
    │
    │ HTTP Request (Port 80)
    │ http://sonarqube-alb-xxxxx.us-east-1.elb.amazonaws.com
    │
    ▼
Internet Gateway (IGW)
    │
    │
    ▼
Application Load Balancer (ALB)
    │
    │ In Public Subnets (A & B)
    │ Port: 80 (HTTP)
    │
    ▼
ALB Listener
    │
    │ Forward to Target Group
    │
    ▼
Target Group
    │
    │ Port: 9000 (SonarQube)
    │ Health Check: / (port 9000)
    │
    ├─────────────────┬─────────────────┐
    │                 │                 │
    ▼                 ▼                 ▼
Private Instance A  Private Instance B  (More instances if scaled)
(10.0.3.x)         (10.0.4.x)
Port: 9000         Port: 9000
SonarQube          SonarQube
```

### 3. Ansible Installation Flow (Jenkins → Image Builder EC2)

```
Local Jenkins Server
    │
    │ SSH Connection (Port 22)
    │ Direct connection (no ProxyJump needed)
    │
    ▼
Internet Gateway (IGW)
    │
    │
    ▼
Public Subnet A
    │
    │
    ▼
Image Builder EC2 Instance
    │
    │ Public IP: x.x.x.x
    │ Security Group: Allows SSH from Jenkins IP
    │
    ▼
Ansible Playbook Execution
    │
    │ Installs:
    │ - Java 21
    │ - PostgreSQL 18
    │ - SonarQube 25.9.0
    │ - UFW Configuration
    │
    ▼
SonarQube Running on Image Builder
    │
    │ Port 9000 (accessible via public IP)
    │
    ▼
AMI Creation (via Terraform)
    │
    │ Creates Golden Image with SonarQube pre-installed
    │
    ▼
Launch Template
    │
    │ Uses the Golden AMI
    │
    ▼
Private Instances (A & B)
    │
    │ Both have SonarQube pre-installed
    │
    ▼
ALB Target Group Attachment
    │
    │ Both instances registered
    │
    ▼
Traffic Distribution
```

### 4. VPC Peering Flow (Optional - for Jenkins in Peered VPC)

```
Jenkins Server (in Peered VPC: 173.0.0.0/16)
    │
    │ SSH Connection
    │
    ▼
VPC Peering Connection
    │
    │ Route: 173.0.0.0/16 ↔ 10.0.0.0/16
    │
    ▼
Private Subnet (10.0.3.x or 10.0.4.x)
    │
    │ (If Jenkins needs direct access to private instances)
    │
    ▼
Private Instance
```

## 📊 Component Details

### Security Groups

#### Public Security Group (ALB & Image Builder)
```
Inbound Rules:
- Port 80: 0.0.0.0/0 (HTTP - ALB)
- Port 22: Whitelisted IPs (SSH - Image Builder)
- Port 9000: Whitelisted IPs (Direct SonarQube access - Image Builder)

Outbound Rules:
- All traffic: 0.0.0.0/0
```

#### Private Security Group (SonarQube Instances)
```
Inbound Rules:
- Port 22: From Peered VPC CIDR (173.0.0.0/16) - SSH
- Port 9000: From Public Security Group (ALB) - SonarQube
- Port 5432: From Private Subnets (10.0.0.0/16) - PostgreSQL (if needed)

Outbound Rules:
- All traffic: 0.0.0.0/0 (via NAT Gateway)
```

### Route Tables

#### Public Route Table
```
Routes:
- 0.0.0.0/0 → Internet Gateway (IGW)

Associations:
- Public Subnet A
- Public Subnet B
```

#### Private Route Table
```
Routes:
- 0.0.0.0/0 → NAT Gateway (for internet access)
- 173.0.0.0/16 → VPC Peering Connection (if configured)

Associations:
- Private Subnet A
- Private Subnet B
```

## 🚀 Deployment Flow (Golden Image Approach)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: Infrastructure Setup                │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
              Terraform Apply (First Run)
                          │
                          ├─→ VPC, Subnets Created
                          ├─→ NAT Gateway Created (Public Subnet A)
                          ├─→ IGW Created & Attached
                          ├─→ Route Tables Created & Associated
                          ├─→ Security Groups Created
                          ├─→ ALB Created (Public Subnets)
                          ├─→ Target Group Created
                          └─→ Image Builder EC2 Created (Public Subnet A)
                                    │
                                    │ Public IP: x.x.x.x
                                    │
┌───────────────────────────────────▼───────────────────────────────┐
│              PHASE 2: SonarQube Installation                      │
└───────────────────────────────────────────────────────────────────┘
                          │
                          ▼
              Jenkins Pipeline (Local)
                          │
                          ├─→ Checkout Ansible Repo
                          ├─→ Setup Python Virtual Environment
                          └─→ Run Ansible Playbook
                                    │
                                    │ SSH to Image Builder EC2
                                    │ (Direct connection - no ProxyJump)
                                    │
                                    ├─→ Install Java 21
                                    ├─→ Install PostgreSQL 18
                                    ├─→ Install SonarQube 25.9.0
                                    ├─→ Configure UFW
                                    └─→ Start SonarQube
                                    │
┌───────────────────────────────────▼───────────────────────────────┐
│              PHASE 3: AMI Creation & Instance Launch              │
└───────────────────────────────────────────────────────────────────┘
                          │
                          ▼
              Terraform Apply (Second Run)
                          │
                          ├─→ Create AMI from Image Builder EC2
                          │   (with SonarQube pre-installed)
                          │
                          ├─→ Create Launch Template
                          │   (using the Golden AMI)
                          │
                          └─→ Launch 2 EC2 Instances
                                    │
                                    ├─→ Instance A (Private Subnet A)
                                    ├─→ Instance B (Private Subnet B)
                                    │   Both from Golden AMI
                                    │
                                    └─→ Attach to ALB Target Group
                                                │
┌───────────────────────────────────────────────▼───────────────────┐
│              PHASE 4: Traffic Routing                            │
└───────────────────────────────────────────────────────────────────┘
                          │
                          ▼
              Internet → ALB → Target Group → Private Instances
                          │
                          └─→ Load Balanced SonarQube Access
```

## 🔐 Network ACLs (NACLs)

### Public NACL
```
Inbound:
- Port 80: 0.0.0.0/0 (HTTP)
- Port 443: 0.0.0.0/0 (HTTPS)
- Port 22: Whitelisted IPs (SSH)
- Ephemeral Ports (1024-65535): 0.0.0.0/0 (Return traffic)

Outbound:
- All traffic: 0.0.0.0/0
```

### Private NACL
```
Inbound:
- Port 22: From Peered VPC (SSH)
- Port 9000: From Public Subnets (SonarQube from ALB)
- Port 5432: From Private Subnets (PostgreSQL)
- Ephemeral Ports (1024-65535): 0.0.0.0/0 (Return traffic for apt/yum)

Outbound:
- All traffic: 0.0.0.0/0
```

## 📝 Key Points

1. **NAT Gateway**: Located in Public Subnet A, provides internet access for private instances
2. **ALB**: Internet-facing, in public subnets, routes traffic to private instances
3. **Image Builder EC2**: In public subnet for direct Ansible access from local Jenkins
4. **Private Instances**: Launch from Golden AMI, no installation needed
5. **High Availability**: Instances in different AZs (1a and 1b)
6. **Security**: Private instances have no public IPs, accessed only via ALB

## 🌐 IP Address Ranges

- **VPC CIDR**: 10.0.0.0/16
- **Public Subnet A**: 10.0.1.0/24 (us-east-1a)
- **Public Subnet B**: 10.0.2.0/24 (us-east-1b)
- **Private Subnet A**: 10.0.3.0/24 (us-east-1a)
- **Private Subnet B**: 10.0.4.0/24 (us-east-1b)
- **Peered VPC**: 173.0.0.0/16 (if configured)

## 🔄 Port Flow Summary

```
Internet (Port 80) → ALB (Port 80) → Target Group (Port 9000) → Private Instances (Port 9000)
Private Instances → NAT Gateway → IGW → Internet (for apt/yum updates)
Jenkins (Port 22) → Image Builder EC2 (Port 22) → Ansible Installation
```

