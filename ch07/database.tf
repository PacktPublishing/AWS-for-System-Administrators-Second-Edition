provider "aws" {
  region = "eu-central-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "postgres-subnet-group"
  subnet_ids = aws_subnet.private[*].id

}

resource "aws_security_group" "postgres" {
  name        = "postgres-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_db_instance" "postgres_primary" {
  identifier           = "postgres-primary"
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.m6g.large"
  allocated_storage    = 20
  storage_type         = "gp3"
  multi_az             = true
  db_name              = "mydb"
  username             = "postgres"
  password             = "dfljsd03ld!"  # Replace with a secure password
  db_subnet_group_name = aws_db_subnet_group.postgres_subnet_group.name
  
  vpc_security_group_ids = [aws_security_group.postgres.id]

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:04:30"

  skip_final_snapshot    = true
  # final_snapshot_identifier = "tf-final-snapshot-2"
}

resource "aws_db_instance" "postgres_replica" {
  count                = 2
  identifier           = "postgres-replica-${count.index + 1}"
  instance_class       = "db.m6g.large"
  replicate_source_db  = aws_db_instance.postgres_primary.identifier
  
  vpc_security_group_ids = [aws_security_group.postgres.id]

  backup_retention_period = 0
  skip_final_snapshot     = true

}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "primary_endpoint" {
  value = aws_db_instance.postgres_primary.endpoint
}

output "replica_endpoints" {
  value = aws_db_instance.postgres_replica[*].endpoint
}