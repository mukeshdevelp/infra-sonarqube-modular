# modules/compute/variables.tf

variable "key_name" {
  description = "Name of the EC2 key pair."
  type        = string
}

variable "private_key_file_path" {
  description = "Local file path to store the private key."
  type        = string
  #default     = ".ssh/sonarqube-key.pem"
}

variable "ami_name" {
  description = "The name pattern for the Ubuntu AMI."
  type        = string
  #default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "launch_template_name" {
  description = "The name of the EC2 launch template."
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance."
  type        = string
  default     = "t3.large"
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the EC2 instance."
  type        = list(string)
}

variable "instance_name" {
  description = "Name tag for the EC2 instance."
  type        = string
  default     = "sonarqube-instance"
}
