region                      = "us-east-1"
vpc_cidr_block              = "10.0.0.0/16"
public_subnet_a_cidr_block  = "10.0.1.0/24"
public_subnet_b_cidr_block  = "10.0.2.0/24"
private_subnet_a_cidr_block = "10.0.3.0/24"
private_subnet_b_cidr_block = "10.0.4.0/24"
public_subnet_a_az          = "us-east-1a"
public_subnet_b_az          = "us-east-1b"
private_subnet_a_az         = "us-east-1a"
private_subnet_b_az         = "us-east-1b"
whitelisted_ip              = ["0.0.0.0/0", "103.87.45.36/32", "173.0.0.0/16"]
peered_vpc_cidr             = "173.0.0.0/16"
key_pair_name               = "sonarqube-key"
# ec2_key_location is set via TF_VAR_ec2_key_location environment variable in Jenkins pipeline
# In Jenkins: TF_VAR_ec2_key_location="${WORKSPACE}/.ssh/sonarqube-key.pem"
# For local use, use relative path:
ec2_key_location                = ".ssh/sonarqube-key.pem"
all_hosts                       = ["0.0.0.0/0"]
instance_size_small             = "t2.micro"
instance_size_big_for_sonarqube = "t3.large"
private_sec_group               = []
desired_number                  = 0
max_number                      = 0
min_number                      = 0
alb_listener                    = []
existing_vpc_id                 = "vpc-0b87c4f710a5bf9fe"
new_vpc_id                      = ""
