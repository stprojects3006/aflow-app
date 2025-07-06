# Configure the AWS Provider
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
resource "aws_vpc" "k6_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "k6_public_subnet" {
  vpc_id                  = aws_vpc.k6_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "k6_igw" {
  vpc_id = aws_vpc.k6_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "k6_public_rt" {
  vpc_id = aws_vpc.k6_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k6_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "k6_public_rta" {
  subnet_id      = aws_subnet.k6_public_subnet.id
  route_table_id = aws_route_table.k6_public_rt.id
}

# Security Groups
resource "aws_security_group" "k6_sg" {
  name_prefix = "${var.project_name}-sg"
  vpc_id      = aws_vpc.k6_vpc.id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic for proxy services
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Proxy service port"
  }

  # Allow inbound traffic for Tor
  ingress {
    from_port   = 9050
    to_port     = 9050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tor SOCKS port"
  }

  # Allow inbound traffic for Privoxy
  ingress {
    from_port   = 8118
    to_port     = 8118
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Privoxy port"
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# ECR Repository
resource "aws_ecr_repository" "k6_repo" {
  name                 = "${var.project_name}-k6-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-k6-repo"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "k6_cluster" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "k6_logs" {
  name              = "/ecs/${var.project_name}-k6"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-k6-logs"
  }
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# S3 Bucket for Test Results
resource "aws_s3_bucket" "k6_results" {
  bucket = "k6-load-test-results-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-results-bucket"
  }
}

resource "aws_s3_bucket_versioning" "k6_results" {
  bucket = aws_s3_bucket.k6_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Policy for ECS Task Access
resource "aws_s3_bucket_policy" "k6_results_policy" {
  bucket = aws_s3_bucket.k6_results.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.k6_results.arn,
          "${aws_s3_bucket.k6_results.arn}/*"
        ]
      }
    ]
  })
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name = "${var.project_name}-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.k6_results.arn,
          "${aws_s3_bucket.k6_results.arn}/*"
        ]
      }
    ]
  })
}

# Attach S3 policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_s3_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# ECS Task Definition
resource "aws_ecs_task_definition" "k6_task" {
  family                   = "${var.project_name}-k6-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "k6-load-test"
      image = "${aws_ecr_repository.k6_repo.repository_url}:latest"
      
      environment = [
        {
          name  = "TARGET_URL"
          value = var.target_url
        },
        {
          name  = "TEST_SCRIPT"
          value = var.test_script
        },
        {
          name  = "IP_ROTATION_ENABLED"
          value = var.ip_rotation_enabled
        },
        {
          name  = "PROXY_TYPE"
          value = var.proxy_type
        },
        {
          name  = "PROXY_SERVICE_URL"
          value = var.proxy_service_url
        },
        {
          name  = "VU_IP_MAPPING_ENABLED"
          value = var.vu_ip_mapping_enabled
        },
        {
          name  = "MAX_PROXY_IPS"
          value = var.max_proxy_ips
        },
        {
          name  = "TEST_PROXY"
          value = var.test_proxy
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.k6_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "k6"
        }
      }
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        },
        {
          containerPort = 9050
          protocol      = "tcp"
        },
        {
          containerPort = 8118
          protocol      = "tcp"
        }
      ]
      
      essential = true
    }
  ])

  tags = {
    Name = "${var.project_name}-k6-task"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "k6_dashboard" {
  dashboard_name = "${var.project_name}-k6-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-k6", "ClusterName", "${var.project_name}-cluster"]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "${var.project_name}-k6", "ClusterName", "${var.project_name}-cluster"]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Memory Utilization"
        }
      }
    ]
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {} 