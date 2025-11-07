# no variables here yet
variable "vpc_cidr_block"{
    description = "AWS region for deploying resources"
    type        = string
}

variable "public_subnet_a_cidr_block" {
    description = "cidr block of subnet in az1 public"
    type = string
}
variable "public_subnet_a_az" {
  description = "az for public subnet 1"
  type = string
}
variable "public_subnet_b_cidr_block" {
  description = "cidr block of subnet in az2 public"
  type = string
}
variable "public_subnet_b_az" {
  description = "az for public subnet 2"
  type = string
}
variable "private_subnet_a_cidr_block" {
  description = "cidr block of subnet in az1 private"
  type = string
}
variable "private_subnet_a_az" {
  description = "az for private subnet 1"
  type = string
}
variable "private_subnet_b_cidr_block" {
  description = "cidr block of subnet in az2 private"
    type = string
}
variable "private_subnet_b_az" {
  description = "az for private subnet 2"
  type = string
}

