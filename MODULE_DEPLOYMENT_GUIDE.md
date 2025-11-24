# Module Deployment Guide - Step by Step

This guide shows you how to deploy Terraform modules one by one to understand dependencies and test incrementally.

## Module Dependency Order

```
1. VPC (no dependencies)
   ↓
2. Keypair (no dependencies - can run in parallel with VPC)
   ↓
3. Network (depends on: VPC)
   ↓
4. Security (depends on: VPC)
   ↓
5. ALB (depends on: VPC, Security)
   ↓
6. Compute (depends on: VPC, Security, Keypair, ALB)
```

## Step-by-Step Deployment

### Prerequisites

```bash
# Initialize Terraform
terraform init

# Verify your configuration
terraform validate
```

---

## Step 1: Deploy VPC Module

**What it creates:**
- VPC
- Public Subnets (A & B)
- Private Subnets (A & B)

**Command:**
```bash
terraform apply -target=module.vpc
```

**Verify:**
```bash
# Check VPC was created
terraform output vpc_id

# Or using AWS CLI
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=sonarqube-vpc" --query 'Vpcs[*].[VpcId,CidrBlock]' --output table
```

---

## Step 2: Deploy Keypair Module

**What it creates:**
- EC2 Key Pair (AWS)
- Private key file (local: `../.ssh/sonarqube-key.pem`)

**Command:**
```bash
terraform apply -target=module.keypair
```

**Verify:**
```bash
# Check key pair exists
aws ec2 describe-key-pairs --key-names sonarqube-key

# Check local key file
ls -la ../.ssh/sonarqube-key.pem
```

**Note:** This can run in parallel with VPC since it has no dependencies.

---

## Step 3: Deploy Network Module

**What it creates:**
- Internet Gateway (IGW)
- NAT Gateway
- Elastic IP for NAT
- Public Route Table
- Private Route Table
- Route Table Associations

**Dependencies:** Requires VPC to exist

**Command:**
```bash
terraform apply -target=module.network
```

**Verify:**
```bash
# Check IGW
aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=sonarqube-igw" --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId]' --output table

# Check NAT Gateway (takes 2-3 minutes to become available)
aws ec2 describe-nat-gateways --filter "Name=tag:Name,Values=sonarqube-nat" --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' --output table
```

---

## Step 4: Deploy Security Module

**What it creates:**
- Public Security Group
- Private Security Group
- Public NACL
- Private NACL
- NACL Associations

**Dependencies:** Requires VPC to exist

**Command:**
```bash
terraform apply -target=module.security
```

**Verify:**
```bash
# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=public-sg" --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' --output table
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=sonarqube-private-sg" --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]' --output table

# Check NACLs
aws ec2 describe-network-acls --filters "Name=tag:Name,Values=public-nacl" --query 'NetworkAcls[*].[NetworkAclId,VpcId]' --output table
aws ec2 describe-network-acls --filters "Name=tag:Name,Values=private-nacl" --query 'NetworkAcls[*].[NetworkAclId,VpcId]' --output table
```

---

## Step 5: Deploy ALB Module

**What it creates:**
- Application Load Balancer
- Target Group
- ALB Listener

**Dependencies:** Requires VPC and Security modules

**Command:**
```bash
terraform apply -target=module.alb
```

**Verify:**
```bash
# Check ALB
aws elbv2 describe-load-balancers --names sonarqube-alb --query 'LoadBalancers[*].[LoadBalancerName,DNSName,State.Code]' --output table

# Check Target Group
aws elbv2 describe-target-groups --names sonarqube-tg --query 'TargetGroups[*].[TargetGroupName,Port,Protocol,HealthCheckPath]' --output table

# Get ALB DNS
terraform output -raw alb_dns_name
```

---

## Step 6: Deploy Compute Module

**What it creates:**
- Bastion Host (public EC2)
- Image Builder EC2 (for Ansible installation)
- Private SonarQube Instances (2 instances)
- Launch Template
- Target Group Attachments

**Dependencies:** Requires VPC, Security, Keypair, and ALB modules

**Command:**
```bash
terraform apply -target=module.compute
```

**Verify:**
```bash
# Check bastion host
terraform output -raw bastion_public_ip

# Check Image Builder EC2
terraform output -raw image_builder_public_ip

# Check private instances
terraform output -json aws_private_instance_ip

# List all EC2 instances
aws ec2 describe-instances --filters "Name=tag:env,Values=sonarqube" --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,PublicIpAddress]' --output table
```

---

## Complete Deployment

Once all modules are deployed individually, you can verify everything:

```bash
# Show all outputs
terraform output

# Show plan (should show no changes)
terraform plan

# If you want to apply everything at once next time
terraform apply
```

---

## Destroying Modules (Reverse Order)

To destroy modules one by one (reverse order):

```bash
# 1. Destroy Compute
terraform destroy -target=module.compute

# 2. Destroy ALB
terraform destroy -target=module.alb

# 3. Destroy Security
terraform destroy -target=module.security

# 4. Destroy Network
terraform destroy -target=module.network

# 5. Destroy Keypair
terraform destroy -target=module.keypair

# 6. Destroy VPC (last)
terraform destroy -target=module.vpc
```

**Or destroy everything at once:**
```bash
terraform destroy
```

---

## Troubleshooting

### If a module fails:

1. **Check dependencies:**
   ```bash
   terraform graph | grep -A 5 "module.NAME"
   ```

2. **Check what resources will be created:**
   ```bash
   terraform plan -target=module.NAME
   ```

3. **Check state:**
   ```bash
   terraform state list | grep "module.NAME"
   ```

### Common Issues:

- **NAT Gateway taking time:** Wait 2-3 minutes after creating network module before proceeding
- **Key file permissions:** Ensure `../.ssh/sonarqube-key.pem` has `400` permissions
- **Security group dependencies:** ALB and Compute modules need Security module first

---

## Quick Reference Commands

```bash
# Initialize
terraform init

# Validate
terraform validate

# Plan specific module
terraform plan -target=module.vpc

# Apply specific module
terraform apply -target=module.vpc

# Show state for module
terraform state list | grep "module.vpc"

# Show outputs
terraform output

# Refresh state
terraform refresh
```

