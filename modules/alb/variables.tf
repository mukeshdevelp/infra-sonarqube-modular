# alb/variable.tf
variable "lb_name" {
  description = "Name of the ALB"
  type        = string
}

variable "internal" {
  description = "If the ALB is internal or not"
  type        = bool
  default     = false
}

variable "security_groups" {
  description = "List of security group IDs for the ALB"
  type        = list(string)
}

variable "subnets" {
  description = "List of subnet IDs for the ALB"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be deployed"
  type        = string
}

variable "target_group_name" {
  description = "Name of the ALB target group"
  type        = string
}

variable "target_group_port" {
  description = "Port of the ALB target group"
  type        = number
  
}

variable "target_group_protocol" {
  description = "Protocol used by the target group"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Path used for health checks on the target group"
  type        = string
  
}

variable "health_check_port" {
  description = "Port used for health checks on the target group"
  type        = number
 
}

variable "listener_port" {
  description = "Port of the listener"
  type        = number
  
}

variable "listener_protocol" {
  description = "Protocol of the listener"
  type        = string
  default     = "HTTP"
}
