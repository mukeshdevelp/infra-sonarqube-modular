#!/bin/bash
terraform output -json public_ip_of_bastion  > private_ips.txt
terraform output -json aws_private_instance_ip | jq -r '.[]' >> private_ips.txt
