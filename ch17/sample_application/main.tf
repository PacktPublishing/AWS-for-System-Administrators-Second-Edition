terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "<state bucket>" # Change this to your state bucket
    key            = "prod/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "<name of your state table>" # Change this to your state table
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# KMS key for RDS Secret encryption
resource "aws_kms_key" "rds_secret_key" {
  description             = "KMS key for RDS secret encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = {
    Name = "rds-secret-key"
  }
}

resource "aws_kms_alias" "rds_secret_key_alias" {
  name          = "alias/rds-secret-key"
  target_key_id = aws_kms_key.rds_secret_key.key_id
}

# Variables
variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  default     = "dbadmin"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "main-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Route Table Association for Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Association for Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for EC2 Instances
resource "aws_security_group" "ec2" {
  name        = "ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  # IMPORTANT NOTE:
  # For a real application, you would need to allow inbound traffic by either:
  # 1. Using an Application Load Balancer (ALB) in front of these instances
  #    The ALB would have its own security group allowing HTTP/HTTPS from the internet,
  #    and this security group would only allow traffic from the ALB security group. 
  #    Please refer to the book chapter on ALB to see how you can do this. 
  # 2. Directly allowing specific traffic to these instances 
  #    (uncomment and modify the blocks below as needed) - which is not recommended
  
  # Example of allowing traffic from an ALB (preferred approach):
  # ingress {
  #   description     = "HTTP from ALB"
  #   from_port       = 80
  #   to_port         = 80
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb.id]  # This would reference your ALB security group
  # }
  
  # Example of allowing direct traffic (less secure):
  # ingress {
  #   description = "HTTP"
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
  # 
  # ingress {
  #   description = "HTTPS"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# Security Group for RDS Instances
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "main-db-subnet-group"
  }
}

# Aurora PostgreSQL Cluster with native Secrets Manager integration
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "aurora-cluster"
  engine                  = "aurora-postgresql"
  engine_version          = "15.4"
  database_name           = "mydb"
  master_username         = var.db_username
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot     = true
  
  # Enable the native Secrets Manager integration
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.rds_secret_key.id
  
  tags = {
    Name = "aurora-postgresql-cluster"
  }
}

# Aurora PostgreSQL Instances
resource "aws_rds_cluster_instance" "aurora_instances" {
  count               = 2
  identifier          = "aurora-instance-${count.index + 1}"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = "db.t3.medium"
  engine              = "aurora-postgresql"
  engine_version      = "15.4"
  publicly_accessible = false
  
  tags = {
    Name = "aurora-instance-${count.index + 1}"
  }
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "ec2-secrets-manager-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ec2-secrets-manager-role"
  }
}

# IAM Policy for EC2 to access Secrets Manager (read-only)
resource "aws_iam_policy" "secrets_access" {
  name        = "ec2-secrets-access-policy"
  description = "Allow EC2 instances to get (but not modify) secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.rds_secret_key.arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "secrets_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-secrets-manager-profile"
  role = aws_iam_role.ec2_role.name
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "ec2-launch-template"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Require IMDSv2 for enhanced security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  
  tag_specifications {
    resource_type = "instance"
    
    tags = {
      Name = "ec2-instance"
    }
  }
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Basic instance setup
    yum update -y
    yum install -y nginx jq
    systemctl start nginx
    systemctl enable nginx
    
    # Note: This EC2 instance has no inbound traffic allowed, 
    # so the nginx service won't be accessible from outside.
    # In a real-world scenario, you would either:
    # - Place these instances behind an ALB, or
    # - Allow specific inbound traffic to these instances
    
    # Example of retrieving RDS-managed secret (for reference only):
    # SECRET_ARN="${aws_rds_cluster.aurora.master_user_secret[0].secret_arn}"
    # SECRET=$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --region ${var.region} --query SecretString --output text)
    # USERNAME=$(echo $SECRET | jq -r '.username')
    # PASSWORD=$(echo $SECRET | jq -r '.password')
    # HOST=$(echo $SECRET | jq -r '.host')
    EOF
  )
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "main-asg"
  desired_capacity    = 3
  min_size            = 3
  max_size            = 6
  vpc_zone_identifier = aws_subnet.public.*.id
  
  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "asg-instance"
    propagate_at_launch = true
  }
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public.*.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private.*.id
}

output "aurora_cluster_endpoint" {
  description = "Endpoint of the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.aurora.endpoint
}

output "aurora_reader_endpoint" {
  description = "Reader endpoint of the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.aurora.reader_endpoint
}

output "aurora_instance_endpoints" {
  description = "Endpoints of the Aurora PostgreSQL instances"
  value       = aws_rds_cluster_instance.aurora_instances.*.endpoint
}

output "aurora_master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret created by RDS"
  value       = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
}
