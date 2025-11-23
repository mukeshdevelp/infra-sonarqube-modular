# Deployment Steps - SonarQube Infrastructure

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **Jenkins Server** (local or cloud) with:
   - AWS credentials configured (credentialsId: `aws-credentials`)
   - GitHub credentials configured (credentialsId: `github-user-password`)
   - Python 3 with `python3-venv` package installed
   - AWS CLI installed
   - Terraform installed
   - Ansible installed (or will be installed via venv)
3. **Terraform Backend** (S3 bucket) already created
4. **SSH Key Pair** (`sonarqube-key`) already exists in AWS

## 🚀 Step-by-Step Deployment

### Option 1: Using Jenkins Pipeline (Recommended)

#### Step 1: Configure Jenkins Credentials

1. Go to Jenkins → Manage Jenkins → Credentials
2. Add AWS credentials:
   - ID: `aws-credentials`
   - Type: AWS Credentials
   - Access Key ID: Your AWS Access Key
   - Secret Access Key: Your AWS Secret Key
3. Add GitHub credentials:
   - ID: `github-user-password`
   - Type: Username with password
   - Username: Your GitHub username
   - Password: Your GitHub token/password

#### Step 2: Create Jenkins Pipeline Job

1. Go to Jenkins → New Item
2. Select "Pipeline"
3. Name: `sonarqube-infrastructure-pipeline`
4. Configure:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: `https://github.com/mukeshdevelp/infra-sonarqube-modular.git`
   - Credentials: `github-user-password`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

#### Step 3: Run the Pipeline

1. Click "Build Now" on the pipeline job
2. Monitor the stages:
   - ✅ Git Checkout - Terraform Repo
   - ✅ AWS CLI Test & Terraform Init
   - ✅ Terraform Formatting
   - ✅ Terraform Validate
   - ✅ Terraform Plan
   - ✅ Terraform Apply (creates infrastructure + Image Builder EC2)
   - ✅ Store Private IPs
   - ✅ Git Checkout - Ansible Repo
   - ✅ Setup Virtualenv & Install Ansible dependencies
   - ✅ Install SonarQube on Image Builder EC2 (15-30 minutes)
   - ✅ Create AMI and Launch Private Instances

#### Step 4: Verify Deployment

After pipeline completes:
```bash
# Get ALB DNS
terraform output -raw alb_dns_name

# Get Private Instance IPs
terraform output -json aws_private_instance_ip

# Access SonarQube
curl http://<ALB_DNS>
```

---

### Option 2: Manual Deployment (Local)

#### Step 1: Clone Repositories

```bash
# Clone Terraform repo
cd /home/mukesh/Desktop
git clone https://github.com/mukeshdevelp/infra-sonarqube-modular.git
cd infra-sonarqube-modular

# Clone Ansible repo (will be done automatically in pipeline)
cd ..
git clone https://github.com/mukeshdevelp/ansible-assignment-5-v2.git
```

#### Step 2: Configure AWS Credentials

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Step 3: Initialize Terraform

```bash
cd infra-sonarqube-modular
terraform init --reconfigure
```

#### Step 4: Review and Apply Infrastructure (Phase 1)

```bash
# Format and validate
terraform fmt
terraform validate

# Plan
terraform plan

# Apply (creates infrastructure + Image Builder EC2)
terraform apply --auto-approve
```

**Expected Output:**
- VPC, Subnets, NAT Gateway, IGW created
- Security Groups and NACLs created
- ALB and Target Group created
- Image Builder EC2 created in Public Subnet A
- SSH key created at `.ssh/sonarqube-key.pem`

#### Step 5: Get Image Builder EC2 IP

```bash
terraform output -raw image_builder_public_ip
# or
terraform output -raw public_ip_of_bastion
```

#### Step 6: Setup Ansible Environment

```bash
# Navigate to Ansible repo
cd ../ansible-assignment-5-v2

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install boto3 botocore ansible
ansible-galaxy collection install amazon.aws
```

#### Step 7: Install SonarQube on Image Builder EC2

```bash
# Set environment variables
export WORKSPACE=$(pwd)
export ANSIBLE_HOST_KEY_CHECKING=False

# Wait for instance to be ready (optional)
ansible-inventory -i aws_ec2.yml --list

# Run playbook on Image Builder EC2
ansible-playbook -i aws_ec2.yml site.yml \
    --limit _image_builder \
    --private-key=../infra-sonarqube-modular/.ssh/sonarqube-key.pem \
    -u ubuntu \
    --forks=1 \
    -v
```

**This will take 15-30 minutes** to install:
- Java 21
- PostgreSQL 18
- SonarQube 25.9.0
- UFW configuration

#### Step 8: Create AMI and Launch Private Instances (Phase 2)

```bash
# Go back to Terraform directory
cd ../infra-sonarqube-modular

# Step 1: Create AMI from Image Builder EC2
terraform apply -auto-approve \
    -var="create_ami=true" \
    -target=module.compute.aws_ami_from_instance.sonarqube_ami \
    -target=module.compute.aws_launch_template.sonarqube_lt

# Wait for AMI to be available (2-5 minutes)
AMI_ID=$(terraform output -raw sonarqube_ami_id)
aws ec2 wait image-available --image-ids $AMI_ID

# Step 2: Launch private instances and attach to ALB
terraform apply -auto-approve \
    -var="create_ami=true" \
    -var="create_private_instances=true" \
    -target=module.compute.aws_instance.private_server_a \
    -target=module.compute.aws_instance.private_server_b \
    -target=module.compute.aws_lb_target_group_attachment.private_a_attachment \
    -target=module.compute.aws_lb_target_group_attachment.private_b_attachment \
    -target=module.compute.null_resource.stop_image_builder
```

**Expected Output:**
- AMI created from Image Builder EC2
- Launch Template created
- 2 Private instances launched (from AMI)
- Both instances attached to ALB Target Group
- Image Builder EC2 stopped automatically

#### Step 9: Verify Deployment

```bash
# Get ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "SonarQube URL: http://$ALB_DNS"

# Get Private Instance IPs
terraform output -json aws_private_instance_ip

# Test ALB health
curl -I http://$ALB_DNS

# Check AMI ID
terraform output -raw sonarqube_ami_id

# Check Launch Template ID
terraform output -raw launch_template_id
```

---

## 🔍 Verification Commands

### Check Infrastructure Status

```bash
# List all EC2 instances
aws ec2 describe-instances \
    --filters "Name=tag:env,Values=sonarqube" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],PrivateIpAddress,PublicIpAddress]' \
    --output table

# Check ALB status
aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?contains(LoadBalancerName, `sonarqube`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
    --output table

# Check Target Group health
TG_ARN=$(terraform output -raw target_group_arn 2>/dev/null || aws elbv2 describe-target-groups --names sonarqube-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

### Check SonarQube Access

```bash
# Get ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTP access
curl -I http://$ALB_DNS

# Test SonarQube (should return HTML)
curl http://$ALB_DNS | head -20
```

### Check Image Builder EC2 Status

```bash
# Should be stopped after AMI creation
aws ec2 describe-instances \
    --filters "Name=tag:type,Values=image-builder" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name]' \
    --output table
```

---

## 🛠️ Troubleshooting

### If Image Builder EC2 is not stopping:

```bash
# Manually stop it
INSTANCE_ID=$(terraform output -raw image_builder_instance_id 2>/dev/null || \
    aws ec2 describe-instances \
        --filters "Name=tag:type,Values=image-builder" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text)
aws ec2 stop-instances --instance-ids $INSTANCE_ID
```

### If AMI creation fails:

```bash
# Check instance status
aws ec2 describe-instances \
    --instance-ids $(terraform state show module.compute.aws_instance.image_builder_ec2 | grep id | head -1 | awk '{print $3}')

# Verify SonarQube is running on Image Builder
IMAGE_BUILDER_IP=$(terraform output -raw image_builder_public_ip)
ssh -i .ssh/sonarqube-key.pem ubuntu@$IMAGE_BUILDER_IP "curl -s http://localhost:9000 | head -10"
```

### If private instances are not reachable:

```bash
# Check security groups
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=private-sg" \
    --query 'SecurityGroups[0].IpPermissions'

# Check NACL rules
aws ec2 describe-network-acls \
    --filters "Name=tag:Name,Values=private-nacl" \
    --query 'NetworkAcls[0].Entries[?Egress==`false`]'
```

---

## 📊 Expected Timeline

- **Phase 1 (Terraform Apply)**: 5-10 minutes
- **Phase 2 (Ansible Installation)**: 15-30 minutes
- **Phase 3 (AMI Creation)**: 2-5 minutes
- **Phase 4 (Instance Launch)**: 2-3 minutes
- **Total**: ~25-50 minutes

---

## ✅ Success Criteria

After deployment, you should have:

1. ✅ VPC with public and private subnets
2. ✅ NAT Gateway in public subnet
3. ✅ ALB in public subnets (internet-facing)
4. ✅ Image Builder EC2 in public subnet (stopped after AMI creation)
5. ✅ AMI created with SonarQube pre-installed
6. ✅ Launch Template using the AMI
7. ✅ 2 Private instances in private subnets (from AMI)
8. ✅ Both private instances attached to ALB Target Group
9. ✅ SonarQube accessible via ALB DNS

---

## 🔄 Cleanup (if needed)

```bash
# Destroy all resources
terraform destroy --auto-approve

# Or destroy specific resources
terraform destroy -target=module.compute.aws_instance.private_server_a
terraform destroy -target=module.compute.aws_instance.private_server_b
terraform destroy -target=module.compute.aws_ami_from_instance.sonarqube_ami
```

---

## 📝 Important Notes

1. **Image Builder EC2** will be automatically stopped after AMI creation
2. **AMI creation** takes 2-5 minutes - wait for it to be in "available" state
3. **Private instances** are launched from the AMI, so they have SonarQube pre-installed
4. **ALB DNS** is the only way to access SonarQube (private instances have no public IPs)
5. **Security**: All inbound 0.0.0.0/0 access has been removed - only whitelisted IPs can access

