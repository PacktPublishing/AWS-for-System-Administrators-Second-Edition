provider "aws" {
  region = "eu-central-1" 
}

variable "secret_value" {}

# Create the secret in Secrets Manager
resource "aws_secretsmanager_secret" "tf_secret" {
  name        = "tf_secret2"
  description = "Secret created from terraform"
}

resource "aws_secretsmanager_secret_version" "tf_secret_version" {
  secret_id     = aws_secretsmanager_secret.tf_secret.id
  secret_string = jsonencode({
    Username = "admin"
    Password = var.secret_value
  })
}
