# Terraform Backend #done
#root/backend.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

  }

  backend "s3" {
    bucket = "sonarqube-terraform-state-1"
    key    = "terraform.tfstate"
    region = "eu-central-1"
    //dynamodb_table = "terraform-locks"
    use_lockfile = true
    encrypt      = true
  }
}