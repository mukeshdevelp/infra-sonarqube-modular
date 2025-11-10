variable "vpc_id" {
    type = string
    description = "vpc id for security groups"
}

variable "allowed_host" {
  description = "allowed or whitelisted ips for ssh"
  type = list(string)
}
variable "everywhere_host" {
  description = "allow access to everyone"
  type = list(string)
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