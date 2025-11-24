#!/bin/bash
# Check EC2 instances and tags using Terraform state

echo "=== Checking EC2 Instances via Terraform State ==="
echo ""

# Check if Terraform is initialized
if [ ! -f "terraform.tfstate" ] && [ ! -d ".terraform" ]; then
    echo "ERROR: Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

echo "1. Getting instance IDs and IPs from Terraform state..."
echo "--------------------------------------------------------"
INSTANCE_A_ID=$(terraform state show module.compute.aws_instance.private_server_a 2>/dev/null | grep "^\s*id\s*=" | awk '{print $3}' | tr -d '"')
INSTANCE_A_IP=$(terraform state show module.compute.aws_instance.private_server_a 2>/dev/null | grep "^\s*private_ip\s*=" | awk '{print $3}' | tr -d '"')

INSTANCE_B_ID=$(terraform state show module.compute.aws_instance.private_server_b 2>/dev/null | grep "^\s*id\s*=" | awk '{print $3}' | tr -d '"')
INSTANCE_B_IP=$(terraform state show module.compute.aws_instance.private_server_b 2>/dev/null | grep "^\s*private_ip\s*=" | awk '{print $3}' | tr -d '"')

echo "Private Server A:"
echo "  Instance ID: ${INSTANCE_A_ID:-N/A}"
echo "  Private IP: ${INSTANCE_A_IP:-N/A}"

echo ""
echo "Private Server B:"
echo "  Instance ID: ${INSTANCE_B_ID:-N/A}"
echo "  Private IP: ${INSTANCE_B_IP:-N/A}"

echo ""
echo "2. Extracting tags from Terraform state..."
echo "------------------------------------------"
echo "Private Server A tags:"
terraform state show module.compute.aws_instance.private_server_a 2>/dev/null | grep -A 20 "^\s*tags\s*=" | grep -E '"(Name|env|az|role|subnet)"' | head -10

echo ""
echo "Private Server B tags:"
terraform state show module.compute.aws_instance.private_server_b 2>/dev/null | grep -A 20 "^\s*tags\s*=" | grep -E '"(Name|env|az|role|subnet)"' | head -10

echo ""
echo "3. Verifying tags match inventory requirements..."
echo "------------------------------------------------"
echo "Required: tag:env=sonarqube"
echo ""
if terraform state show module.compute.aws_instance.private_server_a 2>/dev/null | grep -A 20 "^\s*tags\s*=" | grep -q '"env".*=.*"sonarqube"'; then
    echo "  ✓ private_server_a has env=sonarqube tag"
else
    echo "  ✗ private_server_a MISSING env=sonarqube tag"
fi

if terraform state show module.compute.aws_instance.private_server_b 2>/dev/null | grep -A 20 "^\s*tags\s*=" | grep -q '"env".*=.*"sonarqube"'; then
    echo "  ✓ private_server_b has env=sonarqube tag"
else
    echo "  ✗ private_server_b MISSING env=sonarqube tag"
fi

echo ""
echo "4. Testing dynamic inventory locally..."
echo "--------------------------------------"
if [ -n "$INSTANCE_A_IP" ] && [ -n "$INSTANCE_B_IP" ]; then
    echo "Expected IPs in inventory: $INSTANCE_A_IP, $INSTANCE_B_IP"
    echo ""
    if [ -f "../ansible-assignment-5-v2/aws_ec2.yml" ]; then
        cd ../ansible-assignment-5-v2
        echo "Running: ansible-inventory -i aws_ec2.yml --list"
        if ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -q "_sonarqube"; then
            echo ""
            echo "✓ SUCCESS: _sonarqube group found in inventory"
            ansible-inventory -i aws_ec2.yml --list 2>/dev/null | grep -A 5 "_sonarqube"
        else
            echo ""
            echo "✗ ERROR: _sonarqube group NOT found in inventory"
            echo "This means dynamic inventory is not working even though tags are correct"
        fi
    else
        echo "  ansible-assignment-5-v2/aws_ec2.yml not found"
        echo "  Cannot test dynamic inventory"
    fi
else
    echo "  Could not get instance IPs from Terraform state"
    echo "  Make sure Terraform state is available and instances exist"
fi
