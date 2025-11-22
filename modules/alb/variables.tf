variable "vpc_id" {
  description = "VPC ID for ALB"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "public_sg_id" {
  description = "Public security group ID for ALB"
  type        = string
}

