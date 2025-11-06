#routes/variables.tf
variable "public_subnets" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs"
  type        = list(string)
}



variable "vpc_id" {
   description = "vpc id of the network"
    type        = string
}

variable "igw_id" {
  description = "igw id of the network"
    type        = string
}

variable "nat_gateway_id" {
  description = "nat gateway of the network"
    type        = string
}