terraform {
  backend "s3" {
    bucket         = "mn-tf-state-bucket"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "mn-tf-state-table"
  }
}


