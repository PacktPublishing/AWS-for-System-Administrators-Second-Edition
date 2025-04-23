# AWS IAM Identity Center (SSO) Configuration with Internal Directory
# This configuration assumes you have an existing AWS Organizations setup

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
  region = "eu-central-1"  # Change to your preferred region
}

# Enable AWS IAM Identity Center
data "aws_ssoadmin_instances" "identity_center" {}

# Configure Identity Center to use the built-in identity store (internal directory)
resource "aws_identitystore_user" "example_user" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
  
  display_name = "Marcel Neidinger"
  user_name    = "mn-dev@nlogn.org"
  
  name {
    given_name  = "Marcel"
    family_name = "Neidinger"
  }
  
  emails {
    value   = "mn-dev@nlogn.org"
    primary = true
  }
}

# Create a permission set (defines a set of permissions that can be assigned to users)
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  description      = "Administrator access permission set"
  instance_arn     = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  session_duration = "PT12H"  # 12-hour session
}

# Attach AWS managed policy to the permission set
resource "aws_ssoadmin_managed_policy_attachment" "admin_policy" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

# Create a group in the internal directory
resource "aws_identitystore_group" "admin_group" {
  display_name      = "Administrators"
  description       = "Group for administrators"
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
}

# Add the user to the group
resource "aws_identitystore_group_membership" "admin_membership" {
  identity_store_id = tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0]
  group_id          = aws_identitystore_group.admin_group.group_id
  member_id         = aws_identitystore_user.example_user.user_id
}

data "aws_organizations_organization" "current" {}

resource "aws_organizations_organizational_unit" "environments" {
  name      = "Environments"
  parent_id = data.aws_organizations_organization.current.roots[0].id  # Use data resource instead of variable
}

resource "aws_organizations_account" "deploy" {
  name              = "Deploy"
  email             = "mn-click_button-deploy@nlogn.org"  # This will be provided as a variable
  role_name         = "OrganizationAccountAccessRole"  # Default role for cross-account access
  parent_id         = aws_organizations_organizational_unit.environments.id
  
  # Prevent account from being destroyed when using Terraform
  # Remove this for the initial creation, then uncomment for subsequent runs
  
}

# Staging account
resource "aws_organizations_account" "staging" {
  name              = "Staging"
  email             = "mn-click_button-staging@nlogn.org"  # This will be provided as a variable
  role_name         = "OrganizationAccountAccessRole"
  parent_id         = aws_organizations_organizational_unit.environments.id
  
}

# Production account
resource "aws_organizations_account" "production" {
  name              = "Production"
  email             = "mn-click_button-prod@nlogn.org"  # This will be provided as a variable
  role_name         = "OrganizationAccountAccessRole"
  parent_id         = aws_organizations_organizational_unit.environments.id
}

# Grant the group access to an AWS account with the specified permission set
resource "aws_ssoadmin_account_assignment" "deploy_account_assignment" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  
  principal_id   = aws_identitystore_group.admin_group.group_id
  principal_type = "GROUP"
  
  target_id   =  aws_organizations_account.deploy.id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "staging_account_assignment" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  
  principal_id   = aws_identitystore_group.admin_group.group_id
  principal_type = "GROUP"
  
  target_id   =  aws_organizations_account.staging.id
  target_type = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "prod_account_assignment" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.identity_center.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  
  principal_id   = aws_identitystore_group.admin_group.group_id
  principal_type = "GROUP"
  
  target_id   =  aws_organizations_account.production.id
  target_type = "AWS_ACCOUNT"
}

output "staging_account_id" {
    value = aws_organizations_account.staging.id
    description = "Account ID of the staging account"
}

output "identity_center_user_portal" {
  value       = "https://d-${substr(tolist(data.aws_ssoadmin_instances.identity_center.identity_store_ids)[0], 0, 10)}.awsapps.com/start"
  description = "The URL of the AWS IAM Identity Center user portal"
}

