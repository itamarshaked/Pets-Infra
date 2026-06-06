variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}