#  Region for deploying resources (default to AWS region)
variable "region" {
  description = "AWS region for deploying resources"
  type        = string

}
variable "vpc_cidr_block" {
  description = "cidr block for vpc"
  type        = string

}
# private and public subnet lists


variable "public_subnet_a_cidr_block" {
  description = "public subnet cidr block in az 1a"
  type        = string

}

variable "public_subnet_b_cidr_block" {
  description = "public subnet cidr block in az 1b"
  type        = string

}
variable "private_subnet_a_cidr_block" {
  description = "public subnet cidr block in az 1a"
  type        = string

}
variable "private_subnet_b_cidr_block" {
  description = "public subnet cidr block in az 1b"
  type        = string

}

variable "public_subnet_a_az" {
  description = "public subnet region in az 1a"
  type        = string

}
variable "public_subnet_b_az" {
  description = "public subnet region in az 1b"
  type        = string

}
variable "private_subnet_a_az" {
  description = "private subnet region in az 1a"
  type        = string

}
variable "private_subnet_b_az" {
  description = "private subnet region in az 1b"
  type        = string

}
# enter your ip in tfvars
variable "whitelisted_ip" {
  description = "ips that are allowed ssh in bastion host"
  type        = list(string)
}
# 0.0.0.0/0
variable "all_hosts" {
  description = "all hosts string"
  type        = list(string)
}

variable "key_pair_name" {
  description = "key pair name of ec2"
  type        = string
}

variable "ec2_key_location" {
  description = "key pair location in the file system"
  type        = string
}

# compute module starts here


variable "instance_size_small" {
  description = "t2 micro variable"
  type        = string
  default     = "t2.micro"
}

variable "instance_size_big_for_sonarqube" {
  description = "sonarqube instance size"
  type        = string
  default     = "t3.medium"
}

variable "private_sec_group" {
  type        = list(string)
  description = "consits db postgres and private security group"
  default     = []
}
variable "desired_number" {
  description = "desired number of instances for  asg"
  type        = number

}
variable "max_number" {
  description = "max number of instances for  asg"
  type        = number

}
variable "min_number" {
  description = "min number of instances for  asg"
  type        = number

}
variable "alb_listener" {
  description = "listener on which asg is going to depend"
  type        = list(string)
}


variable "existing_vpc_id" {
  type        = string
  description = "Existing VPC ID for 173.0.0.0/16"

}

variable "new_vpc_id" {
  type        = string
  description = "New VPC ID for 10.0.0.0/16"
}

variable "existing_route_table_ids" {
  type        = list(string)
  description = "Route tables of existing VPC (173/16)"
  default     = []
}

variable "new_route_table_ids" {
  type        = list(string)
  description = "Private route tables of new VPC (10/16)"
  default     = []
}

#------------------
# gonna see after


/*
# vpc modules
variable "vpc_name" {
  description = "name of the vpc"
  type        = string
  default     = "sonarqube-vpc"
}
# vpc module
variable "cidr_block" {
  description = "cidr block for vpc"
  type        = string
  default     = "10.0.0.0/16"
}
# subnet module
variable "availability_zones" {
  description = "subnets availibility zones for public subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

}
# subents modules
variable "public_subnets_cidrs" {
  description = "subnets availibility zones for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

}
# subents modules
variable "private_subnets_cidrs" {
  description = "cidrs of private subents"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# security_groups
variable "whitelisted_ip" {
  description = "allowed ips for security groups"
  type        = list(string)
  default     = ["0.0.0.0/32"]

}
# used as variable in root.tf and going in alb modules' variable
variable "alb_name" {
  description = "load balancer name applied on the sonarqube subnets"
  type        = string
  default     = "sonarqube-alb"
}
# used in root.tf
# target group name
variable "target_group_name" {
  description = "target groups for alb"
  type        = string
  default     = "sonarqube-tg"
}

# Health check path for ALB
variable "alb_health_check_path" {
  description = "health check path of sonarqube app"
  type        = string
  default     = "/"
}
variable "target_group_port" {
  description = "Port of the ALB target group"
  type        = number
  default     = 9000
}
variable "health_check_port" {
  description = "Port used for health checks on the target group"
  type        = number
  default     = 9000
}
variable "listener_port" {
  description = "Port of the listener"
  type        = number
  default     = 80
}

# compute module variables
variable "key_name" {
  description = "Name of the EC2 key pair."
  type        = string
  default     = "sonarqube-key"
}

variable "private_key_file_path" {
  description = "Local file path to store the private key."
  type        = string
  default     = ".ssh/sonarqube-key.pem"
}

variable "ami_name" {
  description = "The name pattern for the Ubuntu AMI."
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}
variable "ubuntu_ami_id" {
  description = "fetching dynamically"
  type        = string
}

variable "launch_template_name" {
  description = "The name of the EC2 launch template."
  type        = string
  default     = "sonarqube-lt"

}

variable "instance_type" {
  description = "Instance type for the EC2 instance."
  type        = string
  default     = "t3.large"
}
# remove this
variable "security_group_ids" {
  description = "List of security group IDs to associate with the EC2 instance."
  type        = list(string)
  default     = []

}

variable "instance_name" {
  description = "Name tag for the EC2 instance."
  type        = string
  default     = "sonarqube-instance"
}

# asg module variables
variable "asg_name" {
  description = "The name of the Auto Scaling Group"
  type        = string
  default     = "sonarqube-asg"
}

variable "desired_capacity" {
  description = "The desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "The maximum size of the Auto Scaling Group"
  type        = number
  default     = 3
}


variable "min_size" {
  description = "The minimum size of the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "private_subnets" {
  description = "The subnets for the Auto Scaling Group"
  type        = list(string)
  default     = []
}

variable "target_group_arn" {
  description = "The ARN of the ALB target group"
  type        = string
}

variable "launch_template_id" {
  description = "The ID of the Launch Template for instances"
  type        = string
}

variable "lb_listener_arn" {
  description = "The ARN of the ALB listener"
  type        = string
}
variable "app_port" {
  description = "app port for sonarqube"
  type        = number
  default     = 9000
}

# will see after--------------
/*
# root/variables.tf
# VPC ID for the SonarQube environment
variable "vpc_id" {
  description = "VPC ID where SonarQube infrastructure will be deployed"
  type        = string
  
  
}



variable "public_subnets" {
  description = "List of public subnet IDs (for NAT Gateway)"
  type = list(string)
}
# Subnets for Public Subnet


# Subnets for Private Subnet
variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

# Security Group ID for public access (ALB)
variable "public_sg_id" {
  description = "Security Group ID for the public access (ALB)"
  type        = string
}

# Security Group ID for private access (EC2 instances)
variable "private_sg_id" {
  description = "Security Group ID for the private access (EC2 instances)"
  type        = string
}

# Desired capacity for the Auto Scaling Group
variable "asg_desired_capacity" {
  description = "Desired capacity (number of instances) for Auto Scaling Group"
  type        = number
  default     = 2
}

# Maximum size for the Auto Scaling Group
variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 3
}

# Minimum size for the Auto Scaling Group
variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

# Launch Template ID (optional, if you're using an existing one)
variable "launch_template_id" {
  description = "ID of an existing Launch Template"
  type        = string
  default     = ""
}

# Key pair name for EC2 instances (for SSH access)
variable "key_pair_name" {
  description = "The name of the EC2 Key Pair"
  type        = string
}

#

# SonarQube Docker version to use
variable "sonarqube_docker_version" {
  description = "Version of SonarQube Docker image to be used"
  type        = string
  default     = "lts"
}

# ALB listener port (default HTTP 80)
variable "alb_listener_port" {
  description = "Port on which ALB listener will be configured"
  type        = number
  default     = 80
}




# AMI ID for EC2 instances (this can be overridden)
variable "ami_id" {
  description = "AMI ID to be used for the EC2 instances"
  type        = string
}

# Docker container name for SonarQube
variable "sonarqube_container_name" {
  description = "Name of the SonarQube Docker container"
  type        = string
  default     = "sonarqube"
}
*/