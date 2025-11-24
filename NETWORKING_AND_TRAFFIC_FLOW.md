# Networking and Traffic Flow Architecture

## Subnet Configuration

### VPC Overview
- **VPC CIDR:** 10.0.0.0/16
- **Region:** us-east-1
- **DNS Support:** Enabled
- **DNS Hostnames:** Enabled

---

## Subnet Details

### Public Subnet A
- **CIDR:** 10.0.1.0/24
- **Availability Zone:** us-east-1a
- **Route Table:** Public Route Table (routes to IGW)
- **Public IP on Launch:** Yes
- **Resources:**
  - ALB (Application Load Balancer)
  - Bastion Host (public_ec2)
  - NAT Gateway

### Public Subnet B
- **CIDR:** 10.0.2.0/24
- **Availability Zone:** us-east-1b
- **Route Table:** Public Route Table (routes to IGW)
- **Public IP on Launch:** Yes
- **Resources:**
  - ALB (Application Load Balancer)

### Private Subnet A
- **CIDR:** 10.0.3.0/24
- **Availability Zone:** us-east-1a
- **Route Table:** Private Route Table (routes to NAT Gateway)
- **Public IP on Launch:** No
- **Resources:**
  - SonarQube Server A (private_server_a)

### Private Subnet B
- **CIDR:** 10.0.4.0/24
- **Availability Zone:** us-east-1b
- **Route Table:** Private Route Table (routes to NAT Gateway)
- **Public IP on Launch:** No
- **Resources:**
  - SonarQube Server B (private_server_b)

---

## Route Tables

### Public Route Table
**Associated Subnets:** Public Subnet A, Public Subnet B

| Destination | Target | Purpose |
|------------|--------|---------|
| 0.0.0.0/0 | Internet Gateway | Internet access for public subnets |
| 10.0.0.0/16 | Local | VPC internal routing |
| 173.0.0.0/16 | VPC Peering | Route to peered VPC (if peering exists) |

### Private Route Table
**Associated Subnets:** Private Subnet A, Private Subnet B

| Destination | Target | Purpose |
|------------|--------|---------|
| 0.0.0.0/0 | NAT Gateway | Internet access via NAT (outbound only) |
| 10.0.0.0/16 | Local | VPC internal routing |
| 173.0.0.0/16 | VPC Peering | Route to peered VPC (if peering exists) |

---

## Security Groups

### Public Security Group (public_sg)
**Attached to:** ALB, Bastion Host

#### Ingress Rules:
| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 80 | TCP | 0.0.0.0/0 | HTTP access to ALB |
| 443 | TCP | 0.0.0.0/0 | HTTPS access to ALB |
| 22 | TCP | Whitelisted IPs | SSH to bastion host |

#### Egress Rules:
| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 0-65535 | All | 0.0.0.0/0 | All outbound traffic |

### Private Security Group (private_sg)
**Attached to:** Private SonarQube Servers

#### Ingress Rules:
| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 9000 | TCP | public_sg | SonarQube traffic from ALB |
| 22 | TCP | public_sg | SSH from bastion host |
| 22 | TCP | 173.0.0.0/16 | SSH from peered VPC |
| 9000 | TCP | Self (private_sg) | SonarQube inter-instance communication |
| 5432 | TCP | Self (private_sg) | PostgreSQL inter-instance communication |
| 5432 | TCP | 173.0.0.0/16 | PostgreSQL from peered VPC |
| 80 | TCP | 10.0.0.0/16 | HTTP from VPC (internal) |
| 1024-65535 | TCP | 10.0.0.0/16 | Ephemeral ports (return traffic) |
| ICMP | ICMP | 10.0.0.0/16 | Ping for diagnostics |

#### Egress Rules:
| Port | Protocol | Destination | Purpose |
|------|----------|-------------|---------|
| 0-65535 | All | 0.0.0.0/0 | All outbound traffic |

---

## Network ACLs (NACLs)

### Public NACL
**Associated Subnets:** Public Subnet A, Public Subnet B

#### Ingress Rules:
| Rule # | Protocol | Port | Source | Action |
|--------|----------|------|--------|--------|
| 110 | TCP | 22 | Whitelisted IPs | Allow SSH |
| 120 | TCP | 80 | 0.0.0.0/0 | Allow HTTP |
| 130 | TCP | 443 | 0.0.0.0/0 | Allow HTTPS |
| 1700 | TCP | 22 | 173.0.0.0/16 | Allow SSH from peered VPC |
| 1800 | TCP | 22 | 10.0.0.0/16 | Allow SSH from VPC |
| 200 | ICMP | All | 0.0.0.0/0 | Allow ICMP (ping) |
| 210 | UDP | 53 | 0.0.0.0/0 | Allow DNS (UDP) |
| 220 | TCP | 53 | 0.0.0.0/0 | Allow DNS (TCP) |
| 230 | TCP | 1024-65535 | 0.0.0.0/0 | Allow ephemeral ports (return traffic) |
| 240 | UDP | 1024-65535 | 0.0.0.0/0 | Allow ephemeral ports (return traffic) |

#### Egress Rules:
| Rule # | Protocol | Port | Destination | Action |
|--------|----------|------|-------------|--------|
| 100 | All | All | 0.0.0.0/0 | Allow all egress |
| 110 | ICMP | All | 0.0.0.0/0 | Allow ICMP |
| 120 | UDP | 53 | 0.0.0.0/0 | Allow DNS (UDP) |
| 130 | TCP | 53 | 0.0.0.0/0 | Allow DNS (TCP) |

### Private NACL
**Associated Subnets:** Private Subnet A, Private Subnet B

#### Ingress Rules:
| Rule # | Protocol | Port | Source | Action |
|--------|----------|------|--------|--------|
| 100 | All | All | 10.0.0.0/16 | Allow all from VPC |
| 105 | ICMP | All | 10.0.0.0/16 | Allow ICMP from VPC |
| 108 | TCP | 22 | 10.0.1.0/24 | Allow SSH from public subnet A |
| 109 | TCP | 22 | 10.0.2.0/24 | Allow SSH from public subnet B |
| 110 | TCP | 22 | 10.0.0.0/16 | Allow SSH from VPC |
| 111 | TCP | 22 | Whitelisted IPs | Allow SSH from external |
| 112 | TCP | 22 | 173.0.0.0/16 | Allow SSH from peered VPC |
| 120 | TCP | 9000 | 10.0.0.0/16 | Allow SonarQube from VPC |
| 130 | TCP | 5432 | 10.0.0.0/16 | Allow PostgreSQL from VPC |
| 131 | TCP | 5432 | 173.0.0.0/16 | Allow PostgreSQL from peered VPC |
| 190 | All | All | 173.0.0.0/16 | Allow all from peered VPC |
| 200 | ICMP | All | 10.0.0.0/16 | Allow ICMP from VPC |
| 201 | ICMP | All | 0.0.0.0/0 | Allow ICMP from everywhere |

#### Egress Rules:
| Rule # | Protocol | Port | Destination | Action |
|--------|----------|------|-------------|--------|
| 100 | All | All | 0.0.0.0/0 | Allow all egress |
| 110 | TCP | 22 | 0.0.0.0/0 | Allow SSH egress |
| 120 | TCP | 8080 | 0.0.0.0/0 | Allow port 8080 egress |
| 130 | TCP | 9000 | 0.0.0.0/0 | Allow SonarQube egress |
| 140 | TCP | 5432 | 0.0.0.0/0 | Allow PostgreSQL egress |
| 150 | TCP | 80 | 0.0.0.0/0 | Allow HTTP egress |
| 160 | TCP | 443 | 0.0.0.0/0 | Allow HTTPS egress |
| 170 | UDP | 53 | 0.0.0.0/0 | Allow DNS (UDP) egress |
| 171 | TCP | 53 | 0.0.0.0/0 | Allow DNS (TCP) egress |
| 180 | ICMP | All | 0.0.0.0/0 | Allow ICMP egress |
| 190 | All | All | 173.0.0.0/16 | Allow all to peered VPC |

---

## Traffic Flow Diagrams

### 1. Internet to SonarQube (User Access)

```
Internet User
    │
    │ HTTP Request (Port 80)
    ▼
┌─────────────────────────────────────┐
│  Internet Gateway (IGW)             │
└──────────────┬──────────────────────┘
               │
               │ Route: 0.0.0.0/0 → IGW
               ▼
┌─────────────────────────────────────┐
│  Public Route Table                 │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
┌──────────────┐  ┌──────────────┐
│ Public       │  │ Public       │
│ Subnet A     │  │ Subnet B     │
│ 10.0.1.0/24  │  │ 10.0.2.0/24  │
│              │  │              │
│ ┌──────────┐ │  │ ┌──────────┐ │
│ │   ALB    │ │  │ │   ALB    │ │
│ │ (Public) │ │  │ │ (Public) │ │
│ └────┬─────┘ │  │ └────┬─────┘ │
└──────┼───────┘  └──────┼───────┘
       │                  │
       │ Port 80 → 9000   │
       │ (Load Balanced)  │
       └──────────┬───────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌──────────────┐      ┌──────────────┐
│ Private      │      │ Private      │
│ Subnet A     │      │ Subnet B     │
│ 10.0.3.0/24  │      │ 10.0.4.0/24  │
│              │      │              │
│ ┌──────────┐ │      │ ┌──────────┐ │
│ │SonarQube │ │      │ │SonarQube │ │
│ │Server A  │ │      │ │Server B  │ │
│ │:9000     │ │      │ │:9000     │ │
│ └──────────┘ │      │ └──────────┘ │
└──────────────┘      └──────────────┘
```

**Traffic Path:**
1. User → Internet → IGW
2. IGW → Public Route Table → Public Subnets
3. ALB (Public Subnets) receives HTTP request on port 80
4. ALB forwards to Target Group (port 9000)
5. Target Group distributes to Private Servers (port 9000)
6. Response follows reverse path

**Security Checks:**
- Public NACL: Allows port 80 ingress
- Public SG: Allows port 80 from 0.0.0.0/0
- Private SG: Allows port 9000 from public_sg
- Private NACL: Allows port 9000 from VPC CIDR

---

### 2. SSH Access to Private Instances (via Bastion)

```
User/Admin
    │
    │ SSH (Port 22)
    │ From: Whitelisted IP
    ▼
┌─────────────────────────────────────┐
│  Internet Gateway (IGW)             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Public Subnet A (10.0.1.0/24)      │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  Bastion Host                 │   │
│  │  (public_ec2)                 │   │
│  │  Public IP: X.X.X.X           │   │
│  └───────────┬──────────────────┘   │
└──────────────┼───────────────────────┘
               │
               │ SSH (Port 22)
               │ From: public_sg
               ▼
┌─────────────────────────────────────┐
│  Private Route Table                │
│  (Routes via NAT for outbound)      │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
┌──────────────┐  ┌──────────────┐
│ Private      │  │ Private      │
│ Subnet A     │  │ Subnet B     │
│ 10.0.3.0/24  │  │ 10.0.4.0/24  │
│              │  │              │
│ ┌──────────┐ │  │ ┌──────────┐ │
│ │SonarQube │ │  │ │SonarQube │ │
│ │Server A  │ │  │ │Server B  │ │
│ │:22       │ │  │ │:22       │ │
│ └──────────┘ │  │ └──────────┘ │
└──────────────┘  └──────────────┘
```

**Traffic Path:**
1. User → IGW → Public Subnet A
2. Bastion Host receives SSH connection
3. From Bastion → Private Subnets (via VPC routing)
4. SSH to Private Server A or B

**Security Checks:**
- Public NACL: Allows port 22 from whitelisted IPs
- Public SG: Allows port 22 from whitelisted IPs
- Private SG: Allows port 22 from public_sg
- Private NACL: Allows port 22 from public subnet CIDRs

---

### 3. Private Instance Outbound Traffic (Internet Access)

```
┌──────────────┐
│ Private      │
│ Subnet A/B   │
│              │
│ ┌──────────┐ │
│ │SonarQube │ │
│ │Server    │ │
│ └────┬─────┘ │
└──────┼───────┘
       │
       │ Outbound Request
       │ (e.g., apt-get update)
       ▼
┌─────────────────────────────────────┐
│  Private Route Table                 │
│  Route: 0.0.0.0/0 → NAT Gateway     │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  NAT Gateway                         │
│  (In Public Subnet A)                │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Public Route Table                  │
│  Route: 0.0.0.0/0 → IGW             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Internet Gateway (IGW)              │
└──────────────┬──────────────────────┘
               │
               ▼
            Internet
```

**Traffic Path:**
1. Private Instance → Private Route Table
2. Private Route Table → NAT Gateway (in Public Subnet A)
3. NAT Gateway → Public Route Table → IGW
4. IGW → Internet
5. Response follows reverse path (via NAT Gateway)

**Security Checks:**
- Private SG: Allows all egress
- Private NACL: Allows all egress
- Public NACL: Allows ephemeral ports (1024-65535) for return traffic

---

### 4. VPC Peering Traffic Flow

```
┌─────────────────────────────────────┐
│  Existing VPC (173.0.0.0/16)        │
│  VPC ID: vpc-00f02dc789ed26995     │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  Resource in Peered VPC      │   │
│  │  IP: 173.0.X.X               │   │
│  └───────────┬──────────────────┘   │
└──────────────┼───────────────────────┘
               │
               │ Traffic to 10.0.0.0/16
               │ Route: 10.0.0.0/16 → Peering
               ▼
┌─────────────────────────────────────┐
│  VPC Peering Connection             │
│  (pcx-xxxxx)                        │
└──────────────┬──────────────────────┘
               │
               │ Traffic to 173.0.0.0/16
               │ Route: 173.0.0.0/16 → Peering
               ▼
┌─────────────────────────────────────┐
│  New VPC (10.0.0.0/16)             │
│                                      │
│  ┌──────────────────────────────┐   │
│  │  Private Route Table          │   │
│  │  Route: 173.0.0.0/16 → Peering│   │
│  └───────────┬──────────────────┘   │
│              │                       │
│              ▼                       │
│  ┌──────────────────────────────┐   │
│  │  Private Subnets              │   │
│  │  SonarQube Servers            │   │
│  │  IP: 10.0.3.X / 10.0.4.X     │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Traffic Path (Peered VPC → New VPC):**
1. Resource in Peered VPC (173.0.0.0/16) → Route Table
2. Route Table → VPC Peering Connection
3. VPC Peering → Private Route Table (New VPC)
4. Private Route Table → Private Subnets
5. Access to SonarQube Servers (10.0.3.X / 10.0.4.X)

**Allowed Traffic:**
- SSH (Port 22) from 173.0.0.0/16 to private instances
- PostgreSQL (Port 5432) from 173.0.0.0/16 to private instances
- All traffic within VPC CIDR (10.0.0.0/16)

---

### 5. ALB Health Check Flow

```
┌─────────────────────────────────────┐
│  ALB (Public Subnets)               │
│                                      │
│  Health Check:                       │
│  - Path: /api/system/status         │
│  - Port: 9000                        │
│  - Protocol: HTTP                    │
│  - Interval: 30s                     │
│  - Timeout: 10s                     │
│  - Healthy: 2                        │
│  - Unhealthy: 5                      │
└──────────────┬──────────────────────┘
               │
               │ Health Check Request
               │ GET /api/system/status
               │ Port 9000
               ▼
┌─────────────────────────────────────┐
│  Target Group                       │
│  (Port 9000)                        │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
        ▼             ▼
┌──────────────┐  ┌──────────────┐
│ Private      │  │ Private      │
│ Server A     │  │ Server B     │
│ :9000        │  │ :9000        │
└──────────────┘  └──────────────┘
```

**Health Check Process:**
1. ALB sends health check every 30 seconds
2. Target: `/api/system/status` on port 9000
3. Expected response: HTTP 200
4. If 2 consecutive successful checks → Healthy
5. If 5 consecutive failed checks → Unhealthy
6. Unhealthy targets are removed from rotation

---

### 6. Inter-Instance Communication (Private Subnets)

```
┌──────────────┐
│ Private      │
│ Subnet A     │
│              │
│ ┌──────────┐ │
│ │SonarQube │ │
│ │Server A  │ │
│ │10.0.3.X  │ │
│ └────┬─────┘ │
└──────┼───────┘
       │
       │ Port 9000 or 5432
       │ Within VPC (10.0.0.0/16)
       ▼
┌─────────────────────────────────────┐
│  VPC Internal Routing               │
│  (Local Route)                      │
└──────────────┬──────────────────────┘
               │
               ▼
┌──────────────┐
│ Private      │
│ Subnet B     │
│              │
│ ┌──────────┐ │
│ │SonarQube │ │
│ │Server B  │ │
│ │10.0.4.X  │ │
│ └──────────┘ │
└──────────────┘
```

**Traffic Path:**
1. Server A (10.0.3.X) → VPC Local Route
2. VPC Routing → Server B (10.0.4.X)
3. Direct communication within VPC

**Allowed Ports:**
- Port 9000 (SonarQube inter-instance)
- Port 5432 (PostgreSQL replication/sync)
- Port 80 (HTTP internal)
- Ephemeral ports (1024-65535) for return traffic

---

## Traffic Flow Summary

### Inbound Traffic Flows:

1. **Internet → SonarQube:**
   - Internet → IGW → Public Subnets → ALB (Port 80) → Target Group → Private Servers (Port 9000)

2. **SSH to Bastion:**
   - Internet → IGW → Public Subnet A → Bastion Host (Port 22)

3. **SSH to Private Instances:**
   - Bastion → Private Subnets → Private Servers (Port 22)

4. **From Peered VPC:**
   - Peered VPC (173.0.0.0/16) → VPC Peering → Private Route Table → Private Subnets

### Outbound Traffic Flows:

1. **Private Instances → Internet:**
   - Private Subnets → Private Route Table → NAT Gateway → Public Route Table → IGW → Internet

2. **Bastion → Internet:**
   - Public Subnet A → Public Route Table → IGW → Internet

3. **ALB → Internet:**
   - Public Subnets → Public Route Table → IGW → Internet

### Internal Traffic Flows:

1. **ALB → Private Servers:**
   - ALB (Public) → Private Subnets → Private Servers (Port 9000)

2. **Bastion → Private Servers:**
   - Bastion (Public) → Private Subnets → Private Servers (Port 22)

3. **Inter-Instance:**
   - Private Server A → VPC Local Route → Private Server B (Ports 9000, 5432)

---

## IP Address Ranges

### Subnet IP Ranges:
- **Public Subnet A:** 10.0.1.0 - 10.0.1.255 (256 IPs)
- **Public Subnet B:** 10.0.2.0 - 10.0.2.255 (256 IPs)
- **Private Subnet A:** 10.0.3.0 - 10.0.3.255 (256 IPs)
- **Private Subnet B:** 10.0.4.0 - 10.0.4.255 (256 IPs)

### Reserved IPs:
- **.0:** Network address
- **.1:** VPC router
- **.2:** DNS server
- **.3:** Reserved for future use
- **.255:** Broadcast address

### Typical IP Assignments:
- **Bastion Host:** 10.0.1.X (Public Subnet A)
- **NAT Gateway:** 10.0.1.X (Public Subnet A)
- **ALB:** 10.0.1.X, 10.0.2.X (Public Subnets A & B)
- **Private Server A:** 10.0.3.X (Private Subnet A)
- **Private Server B:** 10.0.4.X (Private Subnet B)

---

## Port Mapping

| Service | Port | Protocol | Source | Destination |
|---------|------|----------|--------|-------------|
| HTTP (ALB) | 80 | TCP | Internet (0.0.0.0/0) | ALB |
| HTTPS (ALB) | 443 | TCP | Internet (0.0.0.0/0) | ALB |
| SonarQube | 9000 | TCP | ALB (public_sg) | Private Servers |
| PostgreSQL | 5432 | TCP | Private SG (self) | Private Servers |
| SSH (Bastion) | 22 | TCP | Whitelisted IPs | Bastion |
| SSH (Private) | 22 | TCP | Bastion (public_sg) | Private Servers |
| DNS | 53 | UDP/TCP | VPC | Internet |

---

## Network ACL Evaluation Order

NACLs are **stateless** and evaluated in **rule number order** (lowest to highest):

### Public NACL Evaluation:
1. Rule 110: SSH from whitelisted IPs → **Allow**
2. Rule 120: HTTP (80) → **Allow**
3. Rule 130: HTTPS (443) → **Allow**
4. Rule 1700: SSH from peered VPC → **Allow**
5. Rule 1800: SSH from VPC → **Allow**
6. Rule 200: ICMP → **Allow**
7. Rule 210-240: DNS and ephemeral ports → **Allow**
8. **Default Deny** (implicit deny all)

### Private NACL Evaluation:
1. Rule 100: All from VPC → **Allow** (catches most traffic)
2. Rule 105-112: SSH rules → **Allow**
3. Rule 120: SonarQube (9000) → **Allow**
4. Rule 130-131: PostgreSQL (5432) → **Allow**
5. Rule 190: All from peered VPC → **Allow**
6. Rule 200-201: ICMP → **Allow**
7. **Default Deny** (implicit deny all)

**Note:** Rule 100 in Private NACL allows all VPC traffic, making rules 120 and 130 somewhat redundant, but they're kept for explicit documentation.

---

## Security Group Evaluation

Security Groups are **stateful** and evaluated **permissively**:

### Public Security Group:
- **Ingress:** Explicitly allowed ports (80, 443, 22)
- **Egress:** All traffic allowed
- **Stateful:** Return traffic automatically allowed

### Private Security Group:
- **Ingress:** 
  - Port 9000 from public_sg (ALB)
  - Port 22 from public_sg (Bastion)
  - Port 22 from peered VPC
  - Ports 9000, 5432 from self
  - Port 5432 from peered VPC
  - Port 80 and ephemeral ports from VPC
- **Egress:** All traffic allowed
- **Stateful:** Return traffic automatically allowed

---

## Traffic Flow Examples

### Example 1: User Accesses SonarQube
```
User Browser
    │
    │ GET http://alb-dns-name/
    │ Port 80
    ▼
Internet Gateway
    │
    │ Route: 0.0.0.0/0 → IGW
    ▼
Public Route Table
    │
    │ Distributes across AZs
    ▼
ALB (Public Subnets A & B)
    │
    │ Health Check: /api/system/status
    │ Port 80 → 9000
    ▼
Target Group
    │
    │ Load Balancing
    ├─→ Private Server A (10.0.3.X:9000)
    └─→ Private Server B (10.0.4.X:9000)
```

### Example 2: Admin SSH to Private Server
```
Admin Machine (Whitelisted IP)
    │
    │ ssh -i key.pem ubuntu@bastion-public-ip
    │ Port 22
    ▼
Internet Gateway
    │
    ▼
Bastion Host (Public Subnet A)
    │
    │ ssh -i key.pem ubuntu@10.0.3.X
    │ Port 22
    │ (From public_sg)
    ▼
Private Server A (Private Subnet A)
```

### Example 3: Private Server Downloads Updates
```
Private Server A
    │
    │ apt-get update
    │ Outbound HTTPS (443)
    ▼
Private Route Table
    │
    │ Route: 0.0.0.0/0 → NAT Gateway
    ▼
NAT Gateway (Public Subnet A)
    │
    │ Source NAT
    │ Public IP: NAT Gateway EIP
    ▼
Public Route Table
    │
    │ Route: 0.0.0.0/0 → IGW
    ▼
Internet Gateway
    │
    ▼
Internet (apt repositories)
```

### Example 4: Peered VPC Accesses PostgreSQL
```
Resource in Peered VPC (173.0.X.X)
    │
    │ PostgreSQL Connection
    │ Port 5432
    │ Destination: 10.0.3.X
    ▼
Peered VPC Route Table
    │
    │ Route: 10.0.0.0/16 → VPC Peering
    ▼
VPC Peering Connection
    │
    │ Route: 173.0.0.0/16 → VPC Peering
    ▼
Private Route Table (New VPC)
    │
    │ Local Route: 10.0.3.0/24
    ▼
Private Server A (10.0.3.X:5432)
```

---

## Network Performance Considerations

### Latency:
- **Same AZ:** < 1ms (Private Server A ↔ Private Server B in same AZ)
- **Cross-AZ:** ~1-2ms (Private Server A ↔ Private Server B across AZs)
- **Via ALB:** +1-2ms (ALB adds minimal latency)
- **Via NAT:** +1-2ms (NAT Gateway adds minimal latency)

### Bandwidth:
- **ALB:** Up to 2.5 Gbps per AZ
- **NAT Gateway:** Up to 45 Gbps
- **VPC Peering:** Up to 25 Gbps

### High Availability:
- **ALB:** Spans 2 AZs (Public Subnets A & B)
- **Private Servers:** 1 per AZ for redundancy
- **NAT Gateway:** Single AZ (Public Subnet A) - consider adding second for HA

---

## Troubleshooting Traffic Flow

### Common Issues:

1. **Cannot access SonarQube from Internet:**
   - Check: ALB security group allows port 80
   - Check: Private security group allows port 9000 from public_sg
   - Check: Target group health checks passing
   - Check: Instances are in "healthy" state in target group

2. **Cannot SSH to private instances:**
   - Check: Bastion security group allows SSH from your IP
   - Check: Private security group allows SSH from public_sg
   - Check: Private NACL allows SSH from public subnet CIDRs
   - Check: Route tables are correctly associated

3. **Private instances cannot reach Internet:**
   - Check: NAT Gateway is running
   - Check: Private route table has route to NAT Gateway
   - Check: NAT Gateway is in public subnet
   - Check: IGW is attached to VPC

4. **VPC Peering not working:**
   - Check: Both VPCs are in us-east-1
   - Check: Route tables have routes to peered VPC CIDR
   - Check: Security groups allow traffic from peered VPC
   - Check: NACLs allow traffic from peered VPC

---

This document provides a complete overview of networking and traffic flow in the SonarQube infrastructure.

