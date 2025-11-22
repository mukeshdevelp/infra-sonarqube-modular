#!/bin/bash

# Test connectivity script
BASTION_IP="13.221.184.187"
PRIVATE_SERVER_1="10.0.4.99"
PRIVATE_SERVER_2="10.0.3.130"
KEY_FILE="/tmp/test-key.pem"

echo "=========================================="
echo "CONNECTIVITY TEST"
echo "=========================================="
echo ""
echo "Bastion IP: $BASTION_IP"
echo "Private Server 1: $PRIVATE_SERVER_1"
echo "Private Server 2: $PRIVATE_SERVER_2"
echo ""

# Test 1: SSH from local to bastion
echo "1. Testing SSH to Bastion..."
if ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$BASTION_IP "echo 'Bastion connection successful'" 2>/dev/null; then
    echo "   ✓ Bastion SSH: SUCCESS"
else
    echo "   ✗ Bastion SSH: FAILED"
    exit 1
fi

# Test 2: SSH from bastion to private server 1
echo ""
echo "2. Testing SSH from Bastion to Private Server 1..."
if ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$BASTION_IP "ssh -i ~/sonarqube-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PRIVATE_SERVER_1 'echo \"Private Server 1 connection successful\"'" 2>/dev/null; then
    echo "   ✓ Private Server 1 SSH: SUCCESS"
else
    echo "   ✗ Private Server 1 SSH: FAILED"
    echo "   Note: Key might need to be copied to bastion first"
fi

# Test 3: SSH from bastion to private server 2
echo ""
echo "3. Testing SSH from Bastion to Private Server 2..."
if ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$BASTION_IP "ssh -i ~/sonarqube-key.pem -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PRIVATE_SERVER_2 'echo \"Private Server 2 connection successful\"'" 2>/dev/null; then
    echo "   ✓ Private Server 2 SSH: SUCCESS"
else
    echo "   ✗ Private Server 2 SSH: FAILED"
    echo "   Note: Key might need to be copied to bastion first"
fi

# Test 4: Internet connectivity from private server 1 (apt update test)
echo ""
echo "4. Testing Internet Connectivity from Private Server 1 (apt update)..."
if ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@$BASTION_IP "ssh -i ~/sonarqube-key.pem -o StrictHostKeyChecking=no ubuntu@$PRIVATE_SERVER_1 'ping -c 3 8.8.8.8 > /dev/null 2>&1 && echo \"Internet connectivity: SUCCESS\" || echo \"Internet connectivity: FAILED\"'" 2>/dev/null; then
    echo "   ✓ Internet connectivity test completed"
else
    echo "   ⚠ Could not test internet connectivity (SSH might not be set up)"
fi

# Test 5: Test apt update on private server 1
echo ""
echo "5. Testing apt update on Private Server 1..."
if ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ubuntu@$BASTION_IP "ssh -i ~/sonarqube-key.pem -o StrictHostKeyChecking=no ubuntu@$PRIVATE_SERVER_1 'sudo apt-get update -qq 2>&1 | head -5'" 2>/dev/null; then
    echo "   ✓ apt update test completed"
else
    echo "   ⚠ Could not test apt update (SSH might not be set up)"
fi

echo ""
echo "=========================================="
echo "TEST COMPLETE"
echo "=========================================="

