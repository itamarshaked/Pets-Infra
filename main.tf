resource "aws_s3_bucket" "terraform_state" {
  bucket = "itamarshaked-pets-app-state"

  tags = {
    Project = "Pets-App"
    Environment = "dev"
    ManagedBy = "Terraform"
  }
}

resource "aws_vpc" "pets_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "pets-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.pets_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "pets-public-subnet"
  }
}