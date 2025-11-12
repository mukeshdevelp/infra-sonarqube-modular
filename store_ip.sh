#!/bin/bash
terraform output -json public_ip_of_bastion | jq -r '.' > private_ips.ini
terraform output -json aws_private_instance_ip | jq -r '.[]' >> private_ips.ini

# connect with private instaces
ssh -i ./.ssh/sonarqube-key.pem   
-o 'ProxyCommand=ssh -i ./.ssh/sonarqube-key.pem -W %h:%p ubuntu@3.215.184.43'   ubuntu
@10.0.4.159