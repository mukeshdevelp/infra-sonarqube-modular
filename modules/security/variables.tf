variable "vpc_id" {
    type = string
    description = "vpc id for security groups"
}

variable "allowed_host" {
  description = "Allowed or whitelisted IPs for SSH"
  type        = list(string)
}

variable "everywhere_host" {
  description = "Allow access to everyone (CIDR blocks)"
  type        = list(string)
}

variable "pub_subnet_a_association" {
  description = "attatching nacl to public a subnet"
  type = string
}

variable "pub_subnet_b_association" {
  description = "attatching nacl to public b subnet"
  type = string
}

variable "pri_subnet_a_association" {
  description = "attatching nacl to private a subnet"
  type = string
}
variable "pri_subnet_b_association" {
  description = "attatching nacl to private b subnet"
  type = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block (e.g., 10.0.0.0/16)"
  type        = string
}

variable "public_subnet_a_cidr" {
  description = "Public subnet A CIDR block (e.g., 10.0.1.0/24)"
  type        = string
}

variable "public_subnet_b_cidr" {
  description = "Public subnet B CIDR block (e.g., 10.0.2.0/24)"
  type        = string
}

variable "peered_vpc_cidr" {
  description = "Peered VPC CIDR block (e.g., 173.0.0.0/16)"
  type        = string
}

variable "allowed_http_https_cidrs" {
  description = "Allowed CIDR blocks for HTTP/HTTPS access to ALB (defaults to allowed_host if not specified)"
  type        = list(string)
  default     = []
}