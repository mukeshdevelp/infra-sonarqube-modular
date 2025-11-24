#!/bin/bash

# Script to store IP addresses from Terraform outputs
# This script extracts IPs and stores them in a file for later use

set -e

# Output file to store IPs
IP_FILE="${WORKSPACE:-.}/stored_ips.txt"
ENV_FILE="${WORKSPACE:-.}/ips.env"

echo "=========================================="
echo "Storing IP addresses from Terraform outputs"
echo "=========================================="
echo ""

# Initialize output files
> "$IP_FILE"
> "$ENV_FILE"

# Function to get Terraform output safely
get_output() {
    local output_name=$1
    terraform output -raw "$output_name" 2>/dev/null || echo "N/A"
}

# Function to get JSON output safely
get_json_output() {
    local output_name=$1
    terraform output -json "$output_name" 2>/dev/null || echo "[]"
}

# Get ALB DNS
ALB_DNS=$(get_output "alb_dns_name")
if [ "$ALB_DNS" != "N/A" ] && [ -n "$ALB_DNS" ]; then
    echo "ALB_DNS=$ALB_DNS" >> "$ENV_FILE"
    echo "ALB DNS: $ALB_DNS" >> "$IP_FILE"
    echo "SUCCESS: ALB DNS stored: $ALB_DNS"
else
    echo "WARNING: ALB DNS not available yet"
    echo "ALB_DNS=N/A" >> "$ENV_FILE"
fi

# Get Bastion Public IP
BASTION_IP=$(get_output "bastion_public_ip")
if [ "$BASTION_IP" != "N/A" ] && [ -n "$BASTION_IP" ]; then
    echo "BASTION_PUBLIC_IP=$BASTION_IP" >> "$ENV_FILE"
    echo "Bastion Public IP: $BASTION_IP" >> "$IP_FILE"
    echo "SUCCESS: Bastion IP stored: $BASTION_IP"
else
    echo "WARNING: Bastion IP not available yet"
    echo "BASTION_PUBLIC_IP=N/A" >> "$ENV_FILE"
fi

# Get Bastion Public DNS
BASTION_DNS=$(get_output "bastion_public_dns")
if [ "$BASTION_DNS" != "N/A" ] && [ -n "$BASTION_DNS" ]; then
    echo "BASTION_PUBLIC_DNS=$BASTION_DNS" >> "$ENV_FILE"
    echo "Bastion Public DNS: $BASTION_DNS" >> "$IP_FILE"
    echo "SUCCESS: Bastion DNS stored: $BASTION_DNS"
else
    echo "WARNING: Bastion DNS not available yet"
    echo "BASTION_PUBLIC_DNS=N/A" >> "$ENV_FILE"
fi

# Get Image Builder Public IP
IMAGE_BUILDER_IP=$(get_output "image_builder_public_ip")
if [ "$IMAGE_BUILDER_IP" != "N/A" ] && [ -n "$IMAGE_BUILDER_IP" ]; then
    echo "IMAGE_BUILDER_PUBLIC_IP=$IMAGE_BUILDER_IP" >> "$ENV_FILE"
    echo "Image Builder Public IP: $IMAGE_BUILDER_IP" >> "$IP_FILE"
    echo "SUCCESS: Image Builder IP stored: $IMAGE_BUILDER_IP"
else
    echo "WARNING: Image Builder IP not available yet"
    echo "IMAGE_BUILDER_PUBLIC_IP=N/A" >> "$ENV_FILE"
fi

# Get Private Instance IPs (JSON array)
PRIVATE_IPS_JSON=$(get_json_output "aws_private_instance_ip")
if [ "$PRIVATE_IPS_JSON" != "[]" ] && [ -n "$PRIVATE_IPS_JSON" ]; then
    # Extract IPs from JSON array using jq if available, otherwise use basic parsing
    if command -v jq &> /dev/null; then
        PRIVATE_IPS=$(echo "$PRIVATE_IPS_JSON" | jq -r '.[]' | tr '\n' ' ')
        PRIVATE_IP_ARRAY=$(echo "$PRIVATE_IPS_JSON" | jq -r '.[]')
    else
        # Basic parsing without jq
        PRIVATE_IPS=$(echo "$PRIVATE_IPS_JSON" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tr '\n' ' ')
        PRIVATE_IP_ARRAY=$(echo "$PRIVATE_IPS_JSON" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    fi
    
    if [ -n "$PRIVATE_IPS" ]; then
        echo "PRIVATE_IPS=$PRIVATE_IPS" >> "$ENV_FILE"
        echo "Private Instance IPs:" >> "$IP_FILE"
        echo "$PRIVATE_IP_ARRAY" | while read -r ip; do
            if [ -n "$ip" ]; then
                echo "  - $ip" >> "$IP_FILE"
            fi
        done
        echo "SUCCESS: Private IPs stored: $PRIVATE_IPS"
    else
        echo "WARNING: Private IPs not available yet"
        echo "PRIVATE_IPS=N/A" >> "$ENV_FILE"
    fi
else
    echo "WARNING: Private IPs not available yet"
    echo "PRIVATE_IPS=N/A" >> "$ENV_FILE"
fi

# Get VPC ID
VPC_ID=$(get_output "vpc_id")
if [ "$VPC_ID" != "N/A" ] && [ -n "$VPC_ID" ]; then
    echo "VPC_ID=$VPC_ID" >> "$ENV_FILE"
    echo "VPC ID: $VPC_ID" >> "$IP_FILE"
    echo "SUCCESS: VPC ID stored: $VPC_ID"
fi

# Get AMI ID
AMI_ID=$(get_output "sonarqube_ami_id")
if [ "$AMI_ID" != "N/A" ] && [ -n "$AMI_ID" ]; then
    echo "AMI_ID=$AMI_ID" >> "$ENV_FILE"
    echo "AMI ID: $AMI_ID" >> "$IP_FILE"
    echo "SUCCESS: AMI ID stored: $AMI_ID"
fi

# Get Launch Template ID
LAUNCH_TEMPLATE_ID=$(get_output "launch_template_id")
if [ "$LAUNCH_TEMPLATE_ID" != "N/A" ] && [ -n "$LAUNCH_TEMPLATE_ID" ]; then
    echo "LAUNCH_TEMPLATE_ID=$LAUNCH_TEMPLATE_ID" >> "$ENV_FILE"
    echo "Launch Template ID: $LAUNCH_TEMPLATE_ID" >> "$IP_FILE"
    echo "SUCCESS: Launch Template ID stored: $LAUNCH_TEMPLATE_ID"
fi

# Add timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "" >> "$IP_FILE"
echo "Stored at: $TIMESTAMP" >> "$IP_FILE"

echo ""
echo "=========================================="
echo "IP Storage Summary"
echo "=========================================="
echo "IPs stored in: $IP_FILE"
echo "Environment variables stored in: $ENV_FILE"
echo ""
echo "To use environment variables in later stages:"
echo "  source $ENV_FILE"
echo ""
echo "Contents of $IP_FILE:"
echo "----------------------------------------"
cat "$IP_FILE"
echo "----------------------------------------"
echo ""
echo "SUCCESS: IP addresses stored successfully!"
