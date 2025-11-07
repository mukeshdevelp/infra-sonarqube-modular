#!/bin/bash

# Capture the Terraform output
terraform output public_ec2_ip > public_ips.txt
terraform output private_ec2_ip >> public_ips.txt
terraform output asg_instance_ips >> public_ips.txt

echo "Public and Private IPs have been saved to public_ips.txt"
