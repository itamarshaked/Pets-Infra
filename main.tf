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
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
  description = "Allow HTTPS"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

  egress {
    description = "Allow all outbound traffic"
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
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data_replace_on_change = true

  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.pets_sg.id]

  associate_public_ip_address = true
  user_data = <<-USERDATA
#!/bin/bash
dnf update -y
dnf install -y docker jq awscli

systemctl enable docker
systemctl start docker

mkdir -p /etc/ssl/cloudflare

cat > /etc/ssl/cloudflare/origin.crt <<'EOF'
${var.cloudflare_origin_cert}
EOF

cat > /etc/ssl/cloudflare/origin.key <<'EOF'
${var.cloudflare_origin_key}
EOF

chmod 644 /etc/ssl/cloudflare/origin.crt
chmod 600 /etc/ssl/cloudflare/origin.key

usermod -aG docker ec2-user

mkdir -p /usr/libexec/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.27.1/docker-compose-linux-x86_64 \
  -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

mkdir -p /opt/pets-app

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id pets-db-credentials \
  --region eu-west-1 \
  --query SecretString \
  --output text)

DB_USER=$(echo $${SECRET_JSON} | jq -r .username)
DB_PASS=$(echo $${SECRET_JSON} | jq -r .password)
DB_HOST=$(echo $${SECRET_JSON} | jq -r .host)
DB_NAME=$(echo $${SECRET_JSON} | jq -r .database)
DB_PORT=$(echo $${SECRET_JSON} | jq -r .port)

cat > /opt/pets-app/.env <<ENVFILE
DATABASE_URL=postgresql://$${DB_USER}:$${DB_PASS}@$${DB_HOST}:$${DB_PORT}/$${DB_NAME}
JWT_SECRET_KEY=dev-secret-key-change-me
ENVFILE

rm -rf /opt/pets-app/nginx.conf

cat > /opt/pets-app/nginx.conf <<'NGINX'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name pets.shaked.in;

    ssl_certificate     /etc/ssl/cloudflare/origin.crt;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;

    location / {
        proxy_pass http://pet-app:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

cat > /opt/pets-app/docker-compose.yml <<'COMPOSE'
services:
  nginx:
    image: nginx:alpine
    container_name: pets-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/ssl/cloudflare:/etc/ssl/cloudflare:ro
    depends_on:
      - pet-app

  pet-app:
    image: ghcr.io/itamarshaked/pet-app:latest
    container_name: pet-app
    restart: unless-stopped
    env_file:
      - .env
COMPOSE

cd /opt/pets-app
docker compose up -d
USERDATA

metadata_options {
  http_tokens = "required"
}

root_block_device {
  encrypted = true
}

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

resource "aws_security_group" "rds_sg" {
  name        = "pets-rds-sg"
  description = "Allow PostgreSQL from EC2"
  vpc_id      = aws_vpc.pets_vpc.id

  ingress {
    description = "Allow 5432"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.pets_sg.id]
  }

  tags = {
    Name = "pets-rds-sg"
  }
}

resource "aws_db_instance" "pets_db" {
  identifier = "pets-db"

  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = "petsdb"
  username = "petuser"
  password = var.db_password

  storage_encrypted = true
  auto_minor_version_upgrade = true

  db_subnet_group_name   = aws_db_subnet_group.pets_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "pets-rds-postgres"
  }
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "pets-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_secret_value" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    username = "petuser"
    password = var.db_password
    host     = aws_db_instance.pets_db.address
    database = "petsdb"
    port     = 5432
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "pets-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "pets-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "pets-secrets-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = aws_secretsmanager_secret.db_secret.arn
      }
    ]
  })
}