output "bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}
output "vpc_id" {
  value = aws_vpc.pets_vpc.id
}

output "subnet_id" {
  value = aws_subnet.public_subnet.id
}