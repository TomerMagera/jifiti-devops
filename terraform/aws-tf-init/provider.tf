terraform {
  required_version = ">= 1.6.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.58.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region
  
  default_tags {
    tags = {
      Department   = "DevOps"
      Project      = "EKS application"
      Environment  = var.env
      TF_Workspace = terraform.workspace
    }
  }
}
