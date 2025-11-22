#!/bin/bash
# Store bastion IP
terraform output -json public_ip_of_bastion | jq -r '.' > private_ips.ini

# Store private instance IPs
terraform output -json aws_private_instance_ip | jq -r '.[]' >> private_ips.ini

# Store ALB DNS
echo "" >> private_ips.ini
echo "# ALB DNS for SonarQube access" >> private_ips.ini
terraform output -json alb_dns_name | jq -r '.' >> private_ips.ini

echo "IPs and ALB DNS stored in private_ips.ini"

