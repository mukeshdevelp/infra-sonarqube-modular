#nacl/variables.tf
variable "vpc_id" {
  description = "The VPC ID where the NACLs will be created."
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnet IDs to associate with the public NACL."
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of private subnet IDs to associate with the private NACL."
  type        = list(string)
}

variable "private_cidr_block" {
  description = "CIDR block to allow traffic for private subnets."
  type        = string
  # default     = "10.0.0.0/16"
}
