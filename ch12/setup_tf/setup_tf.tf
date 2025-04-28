#terraform {
#  backend "s3" {
#    bucket         = "mn-tf-state-bucket"
#    key            = "demo.tfstate"
#    region         = "eu-central-1"
#    encrypt        = true
#    dynamodb_table = "mn-tf-state-table"
#  }
#}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# S3 bucket for storing Terraform state
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "mn-tf-state-bucket"
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_state_lock_table" {
  name           = "mn-tf-state-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}