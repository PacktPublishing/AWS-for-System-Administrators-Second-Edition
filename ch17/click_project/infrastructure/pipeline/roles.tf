# Provider for the deployment account using the OrganizationAccountAccessRole
provider "aws" {
  alias  = "deploy"
  region = "eu-central-1"
  
  assume_role {
    role_arn = "arn:aws:iam::${var.deploy_account_id}:role/OrganizationAccountAccessRole"
  }
}

# Provider for the staging account using the OrganizationAccountAccessRole
provider "aws" {
  alias  = "staging"
  region = "eu-central-1"
  
  assume_role {
    role_arn = "arn:aws:iam::${var.staging_account_id}:role/OrganizationAccountAccessRole"
  }
}

variable "deploy_account_id" {
    default = "855289842796"
}
variable "staging_account_id" {
    default = "518103494808"
}

data "aws_organizations_organization" "current" {}

# Create the deployment role in the staging account
resource "aws_iam_role" "terraform_deployment_role_staging" {
  provider = aws.staging
  name     = "TerraformDeploymentRole"
  description = "Role for CodePipeline to deploy Terraform resources from deploy account"

  # Trust policy that allows the deployment account to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.deploy_account_id}:role/*"
        }
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = data.aws_organizations_organization.current.id
          }
        }
      }
    ]
  })
}

# Create the permissions policy in the staging account
resource "aws_iam_policy" "terraform_deployment_policy_staging" {
  provider    = aws.staging
  name        = "TerraformDeploymentPolicy"
  description = "Policy for Terraform deployments in staging"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Customize these permissions based on what your Terraform deployments need
      {
        Action = [
          "ec2:*",
          "iam:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role in staging
resource "aws_iam_role_policy_attachment" "terraform_deployment_policy_attachment_staging" {
  provider   = aws.staging
  role       = aws_iam_role.terraform_deployment_role_staging.name
  policy_arn = aws_iam_policy.terraform_deployment_policy_staging.arn
}
