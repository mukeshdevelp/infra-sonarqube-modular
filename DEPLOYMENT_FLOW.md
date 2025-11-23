# SonarQube Deployment Flow - Golden Image Approach

## Overview
This deployment uses a "Golden Image" approach where SonarQube is pre-installed in an AMI,
then instances are launched from that AMI in private subnets.

## Complete Flow

### PHASE 1: Infrastructure Setup (Terraform)
1. ✅ Create VPC with public and private subnets
2. ✅ Create NAT Gateway, IGW, Route Tables
3. ✅ Create Security Groups (public + private)
4. ✅ Create **Image Builder EC2** in PUBLIC subnet
   - Instance: `image_builder_ec2`
   - Subnet: Public Subnet A
   - Public IP: Yes (for Ansible access)
   - Purpose: Build SonarQube AMI

### PHASE 2: Ansible Installation (Jenkins - Local)
5. ✅ Connect to Image Builder EC2 (direct SSH - no ProxyJump needed)
6. ✅ Install SonarQube role via Ansible
7. ✅ Verify SonarQube is running

### PHASE 3: AMI & Launch Template Creation (Terraform)
8. ✅ Create AMI from Image Builder EC2 (`aws_ami_from_instance`)
9. ✅ Create Launch Template using the AMI
10. ✅ (Optional) Stop/Terminate Image Builder EC2

### PHASE 4: Deploy Private Instances (Terraform)
11. ✅ Launch 2 EC2 instances in PRIVATE subnets using Launch Template
    - Instance A: Private Subnet A (10.0.3.0/24)
    - Instance B: Private Subnet B (10.0.4.0/24)
    - Both have SonarQube pre-installed from AMI

### PHASE 5: ALB Configuration (Already Done)
12. ✅ ALB in PUBLIC subnets (internet-facing)
13. ✅ Target Group on port 9000
14. ✅ **Both private instances attached to ALB Target Group**
15. ✅ ALB Listener (port 80) → Target Group → Private Instances (port 9000)

## Network Flow
```
Internet → ALB (Public Subnets, port 80) 
         → Target Group (port 9000)
         → Private Instance A (10.0.3.x, port 9000)
         → Private Instance B (10.0.4.x, port 9000)
```

## Getting Private Instance IPs

### Method 1: Terraform Output
```bash
terraform output aws_private_instance_ip
```

### Method 2: AWS CLI
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=private-server-1a,private-server-1b" \
  --query 'Reservations[*].Instances[*].[PrivateIpAddress]' \
  --output text
```

### Method 3: Ansible Dynamic Inventory
The `aws_ec2.yml` will automatically discover instances with tag `env=sonarqube`

## Key Resources

- **Image Builder EC2**: `aws_instance.image_builder_ec2` (public subnet)
- **SonarQube AMI**: `aws_ami_from_instance.sonarqube_ami`
- **Launch Template**: `aws_launch_template.sonarqube_lt`
- **Private Instances**: `aws_instance.private_server_a` and `private_server_b`
- **ALB**: `aws_lb.alb` (internet-facing)
- **Target Group**: `aws_lb_target_group.tg` (port 9000)
- **Attachments**: Both instances attached to target group

## Benefits

✅ Faster deployment (no installation on each instance)
✅ Consistent configuration (same AMI for all instances)
✅ Works with local Jenkins (public EC2 accessible)
✅ ALB provides load balancing and high availability
