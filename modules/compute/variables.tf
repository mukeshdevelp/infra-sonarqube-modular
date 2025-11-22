variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_security_group" {
  description = "Public security group ID for bastion host"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "key_name" {
  description = "EC2 private key name"
  type        = string
}

variable "public_subnet_a_id" {
  description = "Public subnet A ID for bastion host"
  type        = string
}

variable "private_sg" {
  description = "Private security groups ID list"
  type        = list(string)
}


variable "small_instance_size" {
  description  = "instance size t2.micro or t3.large"
  type = string
  default = "t2.micro"
  
}
variable "sonarqube_instance_size" {
  description = "sonarqube instance t2 medium or t3 large"
  type = string
  default = "t3.medium"
 
}
variable "desired_number" {
  description = "desired number of instances for  asg"
  type = number
  
}
variable "max_number" {
  description = "max number of instances for  asg"
  type = number
  
}
variable "min_number" {
  description = "min number of instances for  asg"
  type = number
  
}

variable "alb_listener" {
  description = "ALB listener (for dependencies)"
  type        = any
  default     = []
}
 