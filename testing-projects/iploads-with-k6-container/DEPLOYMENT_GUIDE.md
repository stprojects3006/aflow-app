# K6 Load Testing Deployment Guide

This guide provides step-by-step instructions for deploying and running the k6 load testing project on AWS ECS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deployment Steps](#deployment-steps)
4. [Running Tests](#running-tests)
5. [Monitoring and Results](#monitoring-and-results)
6. [Troubleshooting](#troubleshooting)
7. [Cleanup](#cleanup)

## Prerequisites

### 1. AWS Account Setup

- **AWS Account**: Active AWS account with billing enabled
- **AWS CLI v2**: Install and configure AWS CLI
- **IAM Permissions**: Ensure your AWS user has the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:*",
                "ecr:*",
                "cloudwatch:*",
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PassRole",
                "logs:*",
                "ec2:*",
                "s3:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### 2. Local Development Environment

- **Docker**: Docker Desktop installed and running
- **Terraform**: Terraform CLI installed (v1.0+)
- **Git**: Git for version control
- **jq**: JSON processor (install via package manager)

### 3. Target Application

Ensure your target application (http://localhost:8080/) is:
- Running and accessible
- Configured to accept external connections
- Ready for load testing

## Initial Setup

### 1. Clone and Configure

```bash
# Clone the repository (if using git)
git clone <repository-url>
cd k6-load-testing

# Or if you have the files locally
cd /path/to/k6-load-testing
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

### 3. Verify Prerequisites

```bash
# Check if all tools are installed
aws --version
docker --version
terraform --version
jq --version
```

## Deployment Steps

### Step 1: Deploy Infrastructure

```bash
# Make scripts executable (if not already done)
chmod +x scripts/*.sh

# Deploy the complete infrastructure
./scripts/deploy.sh --region us-east-1 --target-url http://localhost:8080 --test-type basic
```

**What this does:**
- Creates VPC with public subnet
- Sets up ECS cluster with Fargate
- Creates ECR repository for Docker images
- Configures CloudWatch logs and dashboard
- Sets up S3 bucket for results
- Creates IAM roles and security groups

### Step 2: Verify Deployment

```bash
# Check if resources were created
aws ecs list-clusters
aws ecr describe-repositories
aws logs describe-log-groups --log-group-name-prefix "/ecs/k6-load-test"
```

### Step 3: Build and Push Docker Image

The deployment script automatically builds and pushes the Docker image, but you can also do it manually:

```bash
# Build the Docker image
docker build -t k6-load-test:latest ./docker

# Tag for ECR (replace with your ECR URL from deployment)
docker tag k6-load-test:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/k6-load-test:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/k6-load-test:latest
```

## Running Tests

### 1. Basic Load Test

```bash
# Run a basic load test
./scripts/run-tests.sh --test-type basic
```

**Test Parameters:**
- Duration: 9 minutes total
- Users: 10 concurrent users
- Stages: Ramp up → Steady load → Ramp down

### 2. Stress Test

```bash
# Run a stress test
./scripts/run-tests.sh --test-type stress
```

**Test Parameters:**
- Duration: 22 minutes total
- Users: Up to 200 concurrent users
- Purpose: Find the breaking point

### 3. Spike Test

```bash
# Run a spike test
./scripts/run-tests.sh --test-type spike
```

**Test Parameters:**
- Duration: 8 minutes total
- Users: Sudden spikes from 10 to 200 users
- Purpose: Test system resilience

### 4. Monitor Running Tests

```bash
# List running tasks
./scripts/run-tests.sh --test-type list

# View logs in real-time
./scripts/run-tests.sh --test-type logs

# Stop all running tests
./scripts/run-tests.sh --test-type stop
```

## Monitoring and Results

### 1. CloudWatch Dashboard

Access the CloudWatch dashboard to monitor:
- ECS service metrics
- CPU and memory utilization
- Network performance

**URL**: Available in the deployment output or AWS Console

### 2. CloudWatch Logs

View detailed test logs:

```bash
# View logs in terminal
aws logs tail /ecs/k6-load-test-k6 --follow

# Or use the script
./scripts/run-tests.sh --test-type logs
```

### 3. S3 Results

Test results are stored in S3:
- JSON format results
- CSV exports
- Performance metrics

### 4. Key Metrics to Monitor

- **Response Time**: p50, p90, p95, p99 percentiles
- **Request Rate**: Requests per second (RPS)
- **Error Rate**: Percentage of failed requests
- **Resource Utilization**: CPU, memory, network

## Troubleshooting

### Common Issues

#### 1. Container Fails to Start

**Symptoms**: Task shows STOPPED status with non-zero exit code

**Solutions**:
```bash
# Check task details
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn>

# Check CloudWatch logs
aws logs tail /ecs/k6-load-test-k6 --follow

# Verify target URL is accessible
curl -I http://localhost:8080/
```

#### 2. Network Connectivity Issues

**Symptoms**: Timeout errors or connection refused

**Solutions**:
- Verify target application is running
- Check security group rules
- Ensure public IP assignment is enabled
- Verify VPC and subnet configuration

#### 3. Permission Issues

**Symptoms**: Access denied errors

**Solutions**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM roles
aws iam get-role --role-name k6-load-test-ecs-task-role
aws iam get-role --role-name k6-load-test-ecs-execution-role
```

#### 4. Resource Limits

**Symptoms**: Tasks fail due to insufficient resources

**Solutions**:
- Increase CPU/memory allocation in Terraform variables
- Check AWS service limits
- Monitor resource usage in CloudWatch

### Debugging Commands

```bash
# Check ECS cluster status
aws ecs describe-clusters --clusters k6-load-test-cluster

# List running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --desired-status RUNNING

# Get task details
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn>

# Check ECR repository
aws ecr describe-repositories --repository-names k6-load-test-k6

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=k6-load-test-cluster \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average
```

## Cleanup

### 1. Stop All Tests

```bash
# Stop all running tasks
./scripts/run-tests.sh --test-type stop
```

### 2. Destroy Infrastructure

```bash
# Clean up all AWS resources
./scripts/cleanup.sh
```

**Warning**: This will permanently delete all resources created for this project.

### 3. Manual Cleanup (if scripts fail)

```bash
# Destroy Terraform resources
cd terraform
terraform destroy

# Delete ECR repository
aws ecr delete-repository --repository-name k6-load-test-k6 --force

# Delete CloudWatch log group
aws logs delete-log-group --log-group-name /ecs/k6-load-test-k6

# Delete S3 bucket (if empty)
aws s3 rb s3://k6-load-test-results-<suffix> --force
```

## Cost Optimization

### 1. Resource Sizing

- Start with minimal resources (256 CPU, 512MB memory)
- Scale up based on test requirements
- Use spot instances where possible

### 2. Test Duration

- Keep tests short for development
- Run longer tests only when needed
- Monitor costs in AWS Cost Explorer

### 3. Cleanup

- Always run cleanup after testing
- Set up billing alerts
- Monitor resource usage

## Best Practices

### 1. Test Planning

- Start with small load tests
- Gradually increase load
- Monitor target application health
- Set realistic thresholds

### 2. Security

- Use IAM roles with minimal permissions
- Enable VPC flow logs
- Regular security updates
- Monitor for unusual activity

### 3. Monitoring

- Set up CloudWatch alarms
- Monitor resource utilization
- Track cost metrics
- Review logs regularly

## Support

For additional support:

1. Check the troubleshooting section above
2. Review CloudWatch logs for detailed error messages
3. Verify AWS service limits and quotas
4. Consult AWS documentation for ECS and k6

## Next Steps

After successful deployment:

1. **Customize Tests**: Modify k6 scripts in `docker/k6-scripts/`
2. **Add Monitoring**: Set up CloudWatch alarms
3. **Scale Up**: Increase resources for larger tests
4. **Integrate**: Add to CI/CD pipeline
5. **Optimize**: Fine-tune based on results 