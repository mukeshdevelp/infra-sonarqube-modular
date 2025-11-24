#!/bin/bash

# Module Deployment Script
# Deploys Terraform modules one by one in the correct order

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Module Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to deploy a module
deploy_module() {
    local module_name=$1
    local description=$2
    
    echo -e "${YELLOW}Deploying: ${module_name}${NC}"
    echo -e "${YELLOW}Description: ${description}${NC}\n"
    
    if terraform apply -target="module.${module_name}" -auto-approve; then
        echo -e "${GREEN}SUCCESS: ${module_name} deployed successfully!${NC}\n"
        return 0
    else
        echo -e "${RED}ERROR: ${module_name} deployment failed!${NC}\n"
        return 1
    fi
}

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
    echo ""
fi

# Validate configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
if ! terraform validate; then
    echo -e "${RED}ERROR: Terraform validation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}SUCCESS: Configuration is valid${NC}\n"

# Deploy modules in order
echo -e "${BLUE}Starting module deployment...${NC}\n"

# Step 1: VPC
deploy_module "vpc" "VPC, Public Subnets, Private Subnets"

# Step 2: Keypair (can run in parallel, but we'll do it sequentially)
deploy_module "keypair" "EC2 Key Pair"

# Step 3: Network
deploy_module "network" "Internet Gateway, NAT Gateway, Route Tables"

# Wait for NAT Gateway (optional, but recommended)
echo -e "${YELLOW}Waiting 30 seconds for NAT Gateway to stabilize...${NC}"
sleep 30
echo ""

# Step 4: Security
deploy_module "security" "Security Groups, NACLs"

# Step 5: ALB
deploy_module "alb" "Application Load Balancer, Target Group, Listener"

# Step 6: Compute
deploy_module "compute" "Bastion Host, Image Builder EC2, Private Instances, Launch Template"

# Final summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}All modules deployed successfully!${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Getting outputs...${NC}"
terraform output

echo -e "\n${GREEN}Deployment complete!${NC}"

