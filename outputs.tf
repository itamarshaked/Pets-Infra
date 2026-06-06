output "bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}
output "vpc_id" {
  value = aws_vpc.pets_vpc.id
}

output "subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "security_group_id" {
  value = aws_security_group.pets_sg.id
}

output "server_public_ip" {
  value = aws_instance.pets_server.public_ip
}

output "private_subnet_1_id" {
  value = aws_subnet.private_subnet_1.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_subnet_2.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.pets_db_subnet_group.name
}

output "rds_security_group_id" {
  value = aws_security_group.rds_sg.id
}

output "rds_endpoint" {
  value = aws_db_instance.pets_db.endpoint
}