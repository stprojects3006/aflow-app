# Terraform variables for k6 Load Testing Infrastructure with IP Rotation Support

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "k6-load-test"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for subnet"
  type        = string
  default     = "us-east-1a"
}

variable "target_url" {
  description = "Target URL for load testing"
  type        = string
  default     = "https://affluenceit.com/"
}

variable "test_script" {
  description = "k6 test script to run"
  type        = string
  default     = "/scripts/basic-load-test-with-ip-rotation.js"
}

# IP Rotation Configuration Variables
variable "ip_rotation_enabled" {
  description = "Enable IP rotation for load testing"
  type        = string
  default     = "false"
  validation {
    condition     = contains(["true", "false"], var.ip_rotation_enabled)
    error_message = "ip_rotation_enabled must be 'true' or 'false'."
  }
}

variable "proxy_type" {
  description = "Type of proxy to use for IP rotation"
  type        = string
  default     = "static"
  validation {
    condition     = contains(["static", "rotating", "tor", "privoxy"], var.proxy_type)
    error_message = "proxy_type must be one of: static, rotating, tor, privoxy."
  }
}

variable "proxy_service_url" {
  description = "URL for proxy rotation service"
  type        = string
  default     = "http://localhost:8080"
}

variable "vu_ip_mapping_enabled" {
  description = "Enable VU to IP mapping tracking"
  type        = string
  default     = "false"
  validation {
    condition     = contains(["true", "false"], var.vu_ip_mapping_enabled)
    error_message = "vu_ip_mapping_enabled must be 'true' or 'false'."
  }
}

variable "max_proxy_ips" {
  description = "Maximum number of proxy IPs available"
  type        = string
  default     = "10"
  validation {
    condition     = can(tonumber(var.max_proxy_ips)) && tonumber(var.max_proxy_ips) > 0 && tonumber(var.max_proxy_ips) <= 100
    error_message = "max_proxy_ips must be a number between 1 and 100."
  }
}

variable "test_proxy" {
  description = "Enable proxy connectivity testing"
  type        = string
  default     = "false"
  validation {
    condition     = contains(["true", "false"], var.test_proxy)
    error_message = "test_proxy must be 'true' or 'false'."
  }
}

variable "test_type" {
  description = "Type of test to run (basic, stress, spike)"
  type        = string
  default     = "basic"
  validation {
    condition     = contains(["basic", "stress", "spike"], var.test_type)
    error_message = "Test type must be one of: basic, stress, spike."
  }
}

variable "task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "task_cpu must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "task_memory" {
  description = "Memory for ECS task in MiB"
  type        = number
  default     = 2048
  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192], var.task_memory)
    error_message = "task_memory must be one of: 512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192."
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 10
    error_message = "Desired count must be between 1 and 10."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "test_duration" {
  description = "Duration of the load test in minutes"
  type        = number
  default     = 10
  validation {
    condition     = var.test_duration >= 1 && var.test_duration <= 120
    error_message = "test_duration must be between 1 and 120 minutes."
  }
}

variable "virtual_users" {
  description = "Number of virtual users for the load test"
  type        = number
  default     = 10
  validation {
    condition     = var.virtual_users >= 1 && var.virtual_users <= 1000
    error_message = "virtual_users must be between 1 and 1000."
  }
}

variable "ramp_up_time" {
  description = "Ramp up time in minutes"
  type        = number
  default     = 2
  validation {
    condition     = var.ramp_up_time >= 1 && var.ramp_up_time <= 30
    error_message = "ramp_up_time must be between 1 and 30 minutes."
  }
}

variable "ramp_down_time" {
  description = "Ramp down time in minutes"
  type        = number
  default     = 2
  validation {
    condition     = var.ramp_down_time >= 1 && var.ramp_down_time <= 30
    error_message = "ramp_down_time must be between 1 and 30 minutes."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "k6-load-test"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "k6-load-test"
    Environment = "production"
    ManagedBy   = "terraform"
  }
} 