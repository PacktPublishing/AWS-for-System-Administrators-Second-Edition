provider "aws" {
  region = "eu-central-1"
}

# VPC
resource "aws_vpc" "asg" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "asg-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "asg" {
  vpc_id = aws_vpc.asg.id

  tags = {
    Name = "asg-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.asg.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "asg-public-subnet-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.asg.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.asg.id
  }

  tags = {
    Name = "asg-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group for EC2 instances
resource "aws_security_group" "allow_http_ssh" {
  name        = "asg-allow-http-ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = aws_vpc.asg.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "asg-allow-http-ssh"
  }
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Launch Template
resource "aws_launch_template" "asg" {
  name_prefix   = "asg-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.allow_http_ssh.id]
  }

  user_data = base64encode(file("install.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "asg-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  name                = "asg-group"
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.asg.arn]
  health_check_type   = "ELB"

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_min_size

  launch_template {
    id      = aws_launch_template.asg.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ASG-Instance"
    propagate_at_launch = true
  }
}

# Schedule-based Scaling Policy - Scale Up
resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up"
  min_size               = var.asg_min_size * 10
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_min_size * 10
  recurrence             = "0 8 * * MON-FRI"
  time_zone              = "Europe/Berlin"
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Schedule-based Scaling Policy - Scale Down
resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down"
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_min_size
  recurrence             = "0 20 * * MON-FRI"
  time_zone              = "Europe/Berlin"
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Application Load Balancer
resource "aws_lb" "asg" {
  name               = "asg-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_ssh.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "asg-alb"
  }
}

# ALB Listener
resource "aws_lb_listener" "asg" {
  load_balancer_arn = aws_lb.asg.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}

# ALB Target Group
resource "aws_lb_target_group" "asg" {
  name     = "asg-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.asg.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

output "alb_dns" {
    value = aws_lb.asg.dns_name
}