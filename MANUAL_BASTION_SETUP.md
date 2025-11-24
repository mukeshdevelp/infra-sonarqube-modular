# Manual Bastion Setup Guide

## Complete Manual Workflow

### Prerequisites
- Infrastructure created via Terraform
- SSH key available: `sonarqube-key.pem`
- AWS credentials (for dynamic inventory)

---

## Step-by-Step Manual Process

### 1. Get Bastion Information

```bash
cd /path/to/infra-sonarqube-modular

# Get bastion details
BASTION_IP=$(terraform output -raw bastion_public_ip)
BASTION_DNS=$(terraform output -raw bastion_public_dns)

echo "Bastion IP: $BASTION_IP"
echo "Bastion DNS: $BASTION_DNS"
```

### 2. SSH into Bastion

```bash
SSH_KEY="/path/to/sonarqube-key.pem"
chmod 400 "$SSH_KEY"

ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    ubuntu@$BASTION_DNS
```

### 3. Install Software on Bastion

**Once connected to bastion, run these commands:**

```bash
# Update system
sudo apt-get update

# Install Python and pip
sudo apt-get install -y python3-pip python3-venv git

# Upgrade pip
python3 -m pip install --user --upgrade pip

# Install Ansible and AWS SDK
python3 -m pip install --user ansible boto3 botocore

# Install Ansible AWS collection
export PATH="$HOME/.local/bin:$PATH"
ansible-galaxy collection install amazon.aws

# Verify installation
ansible --version
python3 -c "import boto3; print('boto3 installed')"
```

### 4. Copy Ansible Files to Bastion

**From your local machine (new terminal, don't close bastion SSH):**

```bash
# Navigate to Ansible repo
cd /path/to/ansible-assignment-5-v2

# Copy files to bastion
scp -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    -r site.yml \
       aws_ec2.yml \
       ansible.cfg \
       roles/ \
    ubuntu@$BASTION_DNS:~/ansible-playbook/
```

### 5. Copy SSH Key to Bastion (if not already done)

```bash
# From local machine
scp -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    "$SSH_KEY" \
    ubuntu@$BASTION_DNS:~/.ssh/sonarqube-key.pem

# Fix permissions on bastion
ssh -i "$SSH_KEY" \
    -o StrictHostKeyChecking=no \
    ubuntu@$BASTION_DNS \
    "chmod 400 ~/.ssh/sonarqube-key.pem"
```

### 6. Configure AWS Credentials on Bastion

**Back on bastion host (in your SSH session):**

```bash
cd ~/ansible-playbook

# Set AWS credentials (get from Jenkins or AWS Console)
export AWS_ACCESS_KEY_ID="your-access-key-here"
export AWS_SECRET_ACCESS_KEY="your-secret-key-here"
export AWS_DEFAULT_REGION="us-east-1"
export ANSIBLE_HOST_KEY_CHECKING=False

# Add pip bin to PATH
export PATH="$HOME/.local/bin:$PATH"
```

### 7. Discover Instances

```bash
# List discovered instances
ansible-inventory -i aws_ec2.yml --list

# Visual representation
ansible-inventory -i aws_ec2.yml --graph
```

### 8. Test Connectivity

```bash
# Ping all discovered instances
ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key=~/.ssh/sonarqube-key.pem
```

### 9. Run Ansible Playbook

```bash
# Install SonarQube on all private instances
ansible-playbook -i aws_ec2.yml -u ubuntu --private-key=~/.ssh/sonarqube-key.pem site.yml
```

### 10. Verify Installation

```bash
# Check SonarQube service status
ansible -i aws_ec2.yml _sonarqube -m shell -a "systemctl status sonarqube --no-pager" -u ubuntu --private-key=~/.ssh/sonarqube-key.pem

# Check if SonarQube is running
ansible -i aws_ec2.yml _sonarqube -m shell -a "curl -s http://localhost:9000 | head -20" -u ubuntu --private-key=~/.ssh/sonarqube-key.pem
```

---

## Quick Reference: All Commands in One Place

### On Local Machine:

```bash
# 1. Get bastion info
cd /path/to/infra-sonarqube-modular
BASTION_DNS=$(terraform output -raw bastion_public_dns)
SSH_KEY="/path/to/sonarqube-key.pem"

# 2. SSH into bastion
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$BASTION_DNS

# 3. Copy files (in another terminal)
cd /path/to/ansible-assignment-5-v2
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r \
    site.yml aws_ec2.yml ansible.cfg roles/ \
    ubuntu@$BASTION_DNS:~/ansible-playbook/
```

### On Bastion Host:

```bash
# 1. Install software
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv git
python3 -m pip install --user --upgrade pip
python3 -m pip install --user ansible boto3 botocore
export PATH="$HOME/.local/bin:$PATH"
ansible-galaxy collection install amazon.aws

# 2. Configure AWS credentials
cd ~/ansible-playbook
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
export ANSIBLE_HOST_KEY_CHECKING=False

# 3. Run Ansible
ansible-inventory -i aws_ec2.yml --list
ansible -i aws_ec2.yml _sonarqube -m ping -u ubuntu --private-key=~/.ssh/sonarqube-key.pem
ansible-playbook -i aws_ec2.yml -u ubuntu --private-key=~/.ssh/sonarqube-key.pem site.yml
```

---

## Troubleshooting

### Issue: Ansible not found
```bash
export PATH="$HOME/.local/bin:$PATH"
# Or add to ~/.bashrc for persistence
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: AWS credentials not working
```bash
# Test AWS access
aws sts get-caller-identity
# If fails, check credentials are exported correctly
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
```

### Issue: Cannot reach private instances
```bash
# Test SSH directly from bastion
ssh -i ~/.ssh/sonarqube-key.pem ubuntu@10.0.3.129
# If fails, check security groups allow SSH from bastion
```

---

## Notes

- The pipeline already does all of this automatically
- Manual setup is useful for debugging or learning
- AWS credentials are needed for dynamic inventory to work
- All Ansible operations run from bastion, not from Jenkins

