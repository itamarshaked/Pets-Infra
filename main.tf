resource "aws_s3_bucket" "terraform_demo" {
  bucket = "itamar-pets-app-demo-bucket"

  tags = {
    Project = "Pets-App"
    Owner   = "Itamar"
  }
}