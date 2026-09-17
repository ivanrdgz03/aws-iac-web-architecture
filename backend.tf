terraform {
  backend "s3" {
    bucket         = "mi-bucket-terraform-estado-prod"
    key            = "aws-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}