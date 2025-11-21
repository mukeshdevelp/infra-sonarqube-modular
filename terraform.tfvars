# default region for resources
region = "us-east-1"
# cidr block for vpc
vpc_cidr_block = "10.0.0.0/16"
# public subnet 1 cidr block
public_subnet_a_cidr_block = "10.0.1.0/24"
# public subnet 2 cidr block
public_subnet_b_cidr_block = "10.0.2.0/24"
# private subnet 1 cidr block
private_subnet_a_cidr_block = "10.0.3.0/24"
# private subnet 1 cidr block
private_subnet_b_cidr_block = "10.0.4.0/24"
# az of public subnet 1
public_subnet_a_az = "us-east-1a"
# az of public subnet 2
public_subnet_b_az = "us-east-1b"
# az of private subnet 1
private_subnet_a_az = "us-east-1a"
# az of private subnet 2
private_subnet_b_az = "us-east-1b"
# ips that are authenticate to use the ssh in bastion host
whitelisted_ip = ["103.87.45.36/32", "0.0.0.0/0"]

key_pair_name = "sonarqube-key"

ec2_key_location = ".ssh/sonarqube-key.pem"
all_hosts        = ["0.0.0.0/0"]
# ec2 compute different owners and ami s
#owners_of_image = ["099720109477"]
instance_size_small             = "t2.micro"
instance_size_big_for_sonarqube = "t3.medium"

private_sec_group = []

# for auto scaling group
desired_number = 0
max_number     = 0
min_number     = 0

alb_listener = []

existing_vpc_id = "vpc-00f02dc789ed26995"
new_vpc_id = ""