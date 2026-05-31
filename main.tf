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

resource "aws_internet_gateway" "pets_igw" {
  vpc_id = aws_vpc.pets_vpc.id

  tags = {
    Name = "pets-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.pets_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pets_igw.id
  }

  tags = {
    Name = "pets-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "pets_sg" {
  name        = "pets-sg"
  description = "Security group for Pets App"
  vpc_id      = aws_vpc.pets_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pets-sg"
  }
}
