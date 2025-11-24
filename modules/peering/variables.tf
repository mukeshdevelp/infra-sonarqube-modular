variable "name" {
  type        = string
  description = "Name for VPC Peering"
}

variable "requester_vpc_id" {
  type        = string
  description = "Requester VPC ID"
}

variable "accepter_vpc_id" {
  type        = string
  description = "Accepter VPC ID"
}

variable "requester_vpc_cidr" {
  type        = string
}

variable "accepter_vpc_cidr" {
  type        = string
}


variable "auto_accept" {
  type    = bool
  default = false
}

variable "requester_route_tables" {
  type = list(string)
}

variable "accepter_route_tables" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

