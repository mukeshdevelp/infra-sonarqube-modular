#security_groups/variables.tf
variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
variable "subnet_id" {
  description = "list of subent where security group should be applied"
  type = list(string)
}

variable "allowed_ip" {
  description = "allowed ips for ssh connection"
  type = list(string)
}
variable "app_port" {
  description = "port for sonarqube app"
  type = number
  default = 9000

}

