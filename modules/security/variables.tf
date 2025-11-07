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