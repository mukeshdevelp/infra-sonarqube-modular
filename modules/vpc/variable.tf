# vpc/variables.tf
# done
variable "cidr_block" {
  description = "cidr block of vpc"
  type = string
}
variable "vpc_name" {
  description = "name tag for vpc and related resources"
  type = string
}
variable "public_subnets" {
  description = "List of public subnet IDs (for NAT Gateway)"
  type = list(string)
}
