resource "aws_s3_bucket" "terraform_state" {
  bucket = "itamarshaked-pets-app-state"

  tags = {
    Project = "Pets-App"
    Environment = "dev"
    ManagedBy = "Terraform"
  }
}