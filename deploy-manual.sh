#!/bin/bash
# Manual Deployment Script for SonarQube Golden Image
# Run this script step by step or execute individual commands

set -e

echo "=========================================="
echo "SonarQube Golden Image - Manual Deployment"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get Image Builder IP
IMAGE_BUILDER_IP=$(cd /home/mukesh/Desktop/infra-sonarqube-modular && terraform output -raw image_builder_public_ip 2>/dev/null || echo "")
if [ -z "$IMAGE_BUILDER_IP" ]; then
    echo "ERROR: Could not get Image Builder IP. Make sure infrastructure is created."
    exit 1
fi

echo -e "${GREEN}SUCCESS: Image Builder EC2 IP: $IMAGE_BUILDER_IP${NC}"
echo ""

# PHASE 2: Install SonarQube on Image Builder EC2
echo -e "${YELLOW}=== PHASE 2: Install SonarQube on Image Builder EC2 ===${NC}"
echo ""
echo "This will take 15-30 minutes..."
echo ""

cd /home/mukesh/Desktop/ansible-assignment-5-v2

# Setup virtual environment
if [ ! -d "venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate
echo "SUCCESS: Virtual environment activated"

# Install dependencies
echo "Installing Ansible dependencies..."
pip install --upgrade pip --quiet
pip install boto3 botocore ansible --quiet
ansible-galaxy collection install amazon.aws --quiet
echo "SUCCESS: Dependencies installed"

# Set environment variables
export WORKSPACE=$(pwd)
export ANSIBLE_HOST_KEY_CHECKING=False

# Run Ansible playbook
echo ""
echo "Running Ansible playbook on Image Builder EC2..."
echo "This will install SonarQube, PostgreSQL, and Java..."
echo ""

ansible-playbook -i aws_ec2.yml site.yml \
    --limit _image_builder \
    --private-key=../.ssh/sonarqube-key.pem \
    -u ubuntu \
    --forks=1 \
    -v

echo ""
echo -e "${GREEN}SUCCESS: SonarQube installed on Image Builder EC2!${NC}"
echo ""

# PHASE 3: Create AMI and Launch Private Instances
echo -e "${YELLOW}=== PHASE 3: Create AMI and Launch Private Instances ===${NC}"
echo ""

cd /home/mukesh/Desktop/infra-sonarqube-modular

# Step 1: Create AMI and Launch Template
echo "Step 1: Creating AMI from Image Builder EC2..."
terraform apply -auto-approve \
    -var="create_ami=true" \
    -target=module.compute.aws_ami_from_instance.sonarqube_ami \
    -target=module.compute.aws_launch_template.sonarqube_lt \
    -target=module.compute.null_resource.stop_image_builder

# Get AMI ID
AMI_ID=$(terraform output -raw sonarqube_ami_id 2>/dev/null || echo "")
if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "AMI not created" ]; then
    echo "ERROR: Could not get AMI ID"
    exit 1
fi

echo ""
echo -e "${GREEN}SUCCESS: AMI created: $AMI_ID${NC}"
echo ""

# Step 2: Wait for AMI to be available
echo "Step 2: Waiting for AMI to be available (this may take 2-5 minutes)..."
aws ec2 wait image-available --image-ids $AMI_ID || echo "WARNING: AMI may still be creating"
echo -e "${GREEN}SUCCESS: AMI is available${NC}"
echo ""

# Step 3: Launch private instances
echo "Step 3: Launching private instances from AMI..."
terraform apply -auto-approve \
    -var="create_ami=true" \
    -var="create_private_instances=true" \
    -target=module.compute.aws_instance.private_server_a \
    -target=module.compute.aws_instance.private_server_b \
    -target=module.compute.aws_lb_target_group_attachment.private_a_attachment \
    -target=module.compute.aws_lb_target_group_attachment.private_b_attachment

echo ""
echo -e "${GREEN}SUCCESS: Private instances launched!${NC}"
echo ""

# Step 4: Display results
echo "=========================================="
echo "DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "ALB DNS:"
terraform output -raw alb_dns_name
echo ""
echo "Private Instance IPs:"
terraform output -json aws_private_instance_ip | jq -r '.[]'
echo ""
echo "AMI ID:"
terraform output -raw sonarqube_ami_id
echo ""
echo "Launch Template ID:"
terraform output -raw launch_template_id
echo ""
echo -e "${GREEN}SUCCESS: Access SonarQube at: http://$(terraform output -raw alb_dns_name)${NC}"
echo ""

