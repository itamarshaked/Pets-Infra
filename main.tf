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

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "pets_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.pets_sg.id]

  associate_public_ip_address = true
user_data = <<-EOF
#!/bin/bash
dnf update -y
dnf install -y docker curl nano

systemctl enable docker
systemctl start docker

usermod -aG docker ec2-user

mkdir -p /usr/libexec/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-x86_64 \
  -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

mkdir -p /opt/pets-app

cat > /opt/pets-app/docker-compose.yml <<'COMPOSE'
services:
  postgres:
    image: postgres:16
    container_name: pets-postgres
    restart: unless-stopped

    volumes:
      - postgres_data:/var/lib/postgresql/data

    environment:
      POSTGRES_USER: petuser
      POSTGRES_PASSWORD: petpass
      POSTGRES_DB: petsdb

  pet-app:
    image: ghcr.io/itamarshaked/pet-app:latest
    container_name: pet-app
    restart: unless-stopped
    depends_on:
      - postgres
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://petuser:petpass@postgres:5432/petsdb
      JWT_SECRET_KEY: dev-secret-key-change-me

volumes:
  postgres_data:

COMPOSE

cd /opt/pets-app
docker compose up -d
EOF

  tags = {
    Name = "pets-server"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.pets_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "pets-private-subnet-1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.pets_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "pets-private-subnet-2"
  }
}

resource "aws_db_subnet_group" "pets_db_subnet_group" {
  name = "pets-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_subnet_1.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "pets-db-subnet-group"
  }
}

