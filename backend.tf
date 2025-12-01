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
    bucket = "sonarqube-terraform-state-123"

    key     = "terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true



    use_lockfile = true
  }


}
