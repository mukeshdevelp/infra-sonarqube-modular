#!/bin/bash
# Test script to debug inventory issues

echo "=== Testing Dynamic Inventory Configuration ==="
echo ""

# Check AWS credentials
echo "1. Checking AWS credentials..."
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "   ERROR: AWS credentials not set!"
else
    echo "   OK: AWS credentials are set"
fi

# Check region
echo ""
echo "2. Checking region..."
echo "   Region in aws_ec2.yml: us-east-1"

# Test AWS CLI directly
echo ""
echo "3. Testing AWS CLI query (all instances with tag:env=sonarqube)..."
aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:env,Values=sonarqube" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0],Tags[?Key==`env`].Value|[0],PrivateIpAddress]' \
    --output table 2>&1

echo ""
echo "4. Testing AWS CLI query (running instances only)..."
aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:env,Values=sonarqube" "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
    --output table 2>&1

echo ""
echo "5. Testing Ansible inventory with verbose output..."
ANSIBLE_DEBUG=1 ansible-inventory -i aws_ec2.yml --list -v 2>&1 | head -50
