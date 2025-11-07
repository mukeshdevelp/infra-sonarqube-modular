#asg/variables.tf
variable "asg_name" {
  description = "The name of the Auto Scaling Group"
  type        = string
}

variable "desired_capacity" {
  description = "The desired number of instances in the Auto Scaling Group"
  type        = number
}

variable "max_size" {
  description = "The maximum size of the Auto Scaling Group"
  type        = number
}


variable "min_size" {
  description = "The minimum size of the Auto Scaling Group"
  type        = number
}

variable "private_subnets" {
  description = "The subnets for the Auto Scaling Group"
  type        = list(string)
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

variable "ami_name" {
  description = "ami of public subnet's ec2"
  type = string
}
variable "key_name" {
  description = "key name to be used with public subnet ec2"
  type = string
}
variable "public_subnet_a" {
  description = "public subnet in availibility zone 1a"
  type = string
}
variable "public_sg_id" {
  description = "public security group id for bastio host"
  type = string
}
