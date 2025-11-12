variable "private_subnets" {

}
variable "public_security_group" {

}
variable "target_group_arn" {
  
}
variable "key_name" {
    description = "ec2 private key name"
    type = string
}
variable public_subnet_a_id{
    description = "private subnet a id"
    type = string
}
variable private_sg{
    description = "private security groups id"
    type = list(string)
}


variable "small_instance_size" {
  description  = "instance size t2.micro or t3.large"
  type = string
  default = "t2.micro"
  
}
variable "sonarqube_instance_size" {
  description = "sonarqube instance t2 medium or t3 large"
  type = string
  default = "t3.medium"
 
}
variable "desired_number" {
  description = "desired number of instances for  asg"
  type = number
  
}
variable "max_number" {
  description = "max number of instances for  asg"
  type = number
  
}
variable "min_number" {
  description = "min number of instances for  asg"
  type = number
  
}

variable "alb_listener" {
  description = "listenner for alb"
}