terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}
provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
  source   = "./modules/standard_vpc"
  project  = "test-project"
  region   = "eu-central-1"
  vpc_cidr = "10.10.0.0/16"
  public_subnet_cidrs = [
    "10.10.1.0/24",
    "10.10.2.0/24",
    "10.10.3.0/24"
  ]
  private_subnet_cidrs = [
    "10.10.11.0/24",
    "10.10.12.0/24",
    "10.10.13.0/24"
  ]
}
