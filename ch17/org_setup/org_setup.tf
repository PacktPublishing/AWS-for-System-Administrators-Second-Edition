terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

# Get the Organization root ID
data "aws_organizations_organization" "org" {}

# Create parent OU
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads"
  parent_id = data.aws_organizations_organization.org.roots[0].id
}

# Create child OUs
resource "aws_organizations_organizational_unit" "prod" {
  name      = "prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "test" {
  name      = "test"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

data "aws_organizations_organizational_unit" "sandbox" {
  parent_id = data.aws_organizations_organization.org.roots[0].id
  name      = "Sandbox"
}

resource "aws_organizations_organizational_unit" "security" {
  name      = "security"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "infrastructure"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "exceptions" {
  name      = "exceptions"
  parent_id = aws_organizations_organizational_unit.workloads.id
}