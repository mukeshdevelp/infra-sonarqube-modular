variable "vpc_id" {
    description = "vpc id for which networking has to be set fetched dynamicaaly"
    type = string
}
variable "public_subnets" {
    description = "public subnets fetched dynamically"
    type = list(string)
}
variable "private_subnets" {
    description = "private subnets fetched dynamically"
    type = list(string)
}