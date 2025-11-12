#!/usr/bin/env bash

# Replace with your ASG name
ASG_NAME="sonarqube-asg"

# Default SSH user for your AMI (adjust as needed)
SSH_USER="ubuntu"

# Get instance IDs in the ASG
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query 'AutoScalingGroups[0].Instances[].InstanceId' \
    --output text)

# Loop through instance IDs to get private IPs
> private_hosts.txt  # empty the file first
for id in $INSTANCE_IDS; do
    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids "$id" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)
    echo -e "$PRIVATE_IP\t$SSH_USER" >> private_hosts.txt
done

echo "Saved private IPs and usernames to private_hosts.txt"
cat private_hosts.txt
