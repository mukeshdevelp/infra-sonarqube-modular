#subnet/variables.tf
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
# main variables defined in root/main.tf
variable "availability_zones" {
  description = "availibility zones of the subents"
  type = list(string)
  # default = [ "us-east-1a", "us-east-1b" ]
  
}

variable "public_subnets_cidrs" {
  description = "List of CIDRs for public subnets"
  type        = list(string)
  # default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets_cidrs" {
  description = "List of CIDRs for private subnets"
  type        = list(string)
  # default     = ["10.0.3.0/24", "10.0.4.0/24"]
}
# used for tags
variable "subnet_name" {
  description = "name of each subnet"
  type = list(string)
  default = [ "public-subent-1a" , "public-subnet-1b" , "private-subnet-1a", "private-subnet-1b"]
}
# used for tags
variable "access" {
  description = "type of access for each subnet"
  type = list(string)
  default = [ "public-subent-1" , "public-subnet-2" , "private-subnet-1", "private-subnet-2"]
  
}

