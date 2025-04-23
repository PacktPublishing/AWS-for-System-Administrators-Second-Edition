# Configure AWS Provider
provider "aws" {
  region = "eu-central-1"  # Choose your preferred region
}

# Create VPC (assuming you don't have one)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "rds-vpc"
  }
}

# Create two private subnets in different AZs
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-central-1b"

  tags = {
    Name = "private-subnet-2"
  }
}

# Create subnet group for RDS
resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "RDS subnet group"
  }
}

# Create security group for RDS
resource "aws_security_group" "rds" {
  name        = "rds-security-group"
  description = "Security group for RDS cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
}

# Create RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "cluster_pg" {
  family = "aurora-postgresql14"
  name   = "rds-cluster-pg"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries that take more than 1 second
  }
}

# Create RDS Cluster
resource "aws_rds_cluster" "postgresql" {
  cluster_identifier     = "aurora-cluster-demo"
  engine                = "aurora-postgresql"
  engine_version        = "14.6"  # Use latest stable version
  database_name         = "mydb"
  master_username       = "clusteradmin"
  master_password       = "CHANGE_ME_PLEASE"  # Use AWS Secrets Manager in production
  
  # Cost optimization settings
  backup_retention_period = 1  # Minimum required for multi-AZ
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot    = true  # Set to false in production
  
  # High availability settings
  availability_zones     = ["eu-central-1a", "eu-central-1b"]
  db_subnet_group_name  = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  # Performance settings
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.cluster_pg.name
  
  # Cost-optimized storage settings
  storage_encrypted     = true
  
  tags = {
    Environment = "testing"
    Project     = "chaos-testing"
  }
}

# Create RDS Cluster Instances
resource "aws_rds_cluster_instance" "cluster_instances" {
  count               = 2
  identifier          = "aurora-cluster-demo-${count.index}"
  cluster_identifier  = aws_rds_cluster.postgresql.id
  instance_class      = "db.t4g.medium"  # Cost-effective instance type
  engine              = "aurora-postgresql"
  engine_version      = "14.6"
  
  # Performance Insights for monitoring during chaos testing
  performance_insights_enabled = true
  performance_insights_retention_period = 7  # Free tier retention period
  
  tags = {
    Environment = "testing"
    Project     = "chaos-testing"
  }
}

resource "aws_cloudwatch_log_group" "chaos_experiments" {
  name              = "/chaos-experiments"
  retention_in_days = 30

  tags = {
    Environment = "testing"
    Project     = "chaos-testing"
    Purpose     = "chaos-experiment-logs"
  }
}

# Output the cluster endpoint
output "cluster_endpoint" {
  value = aws_rds_cluster.postgresql.endpoint
}

# Output the reader endpoint
output "reader_endpoint" {
  value = aws_rds_cluster.postgresql.reader_endpoint
}