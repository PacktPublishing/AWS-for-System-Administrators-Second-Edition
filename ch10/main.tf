# Configure AWS provider
provider "aws" {
  region = "eu-central-1"
}

resource "aws_backup_vault" "backup_vault" {
  name = "tf-backup-vault"
  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_backup_plan" "prod_ebs_backups" {
  name = "prod-ebs-backups"

  rule {
    rule_name         = "daily_ebs_backup_rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 3 ? * * *)"  

    lifecycle {
      delete_after = 7
    }
  }

  rule {
    rule_name         = "weekly_ebs_backup_rule"
    target_vault_name = aws_backup_vault.backup_vault.name
    schedule          = "cron(0 3 ? * 1 *)"  # Weekly backup on Sundays at 3 AM UTC

    lifecycle {
      delete_after = 30
    }
  }
}

# Create IAM role for AWS Backup
resource "aws_iam_role" "backup_role" {
  name = "aws-backup-service-role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS Backup service role policy
resource "aws_iam_role_policy_attachment" "backup_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

# Create selection for EBS volumes to backup
resource "aws_backup_selection" "ebs_backup_selection" {
  name         = "ebs-backup-selection"
  iam_role_arn = aws_iam_role.backup_role.arn
  plan_id      = aws_backup_plan.prod_ebs_backups.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "ProdBackup"
    value = "true"
  }
}

resource "aws_ebs_volume" "example_volume" {
  availability_zone = "eu-central-1a"
  size             = 50  # Size in GiB
  type             = "gp3"  # General Purpose SSD
  encrypted        = true

  tags = {
    Name   = "example-volume"
    ProdBackup = "true"
  }
}
