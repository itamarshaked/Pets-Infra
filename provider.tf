terraform {
  required_version = ">= 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Pets-App"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "Itamar"
    }
  }
}