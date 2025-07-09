# K6 Load Testing with IP Diversity and QueueIt Integration - Deployment Guide

This guide provides step-by-step instructions for deploying and running the k6 load testing project with IP diversity and QueueIt integration on AWS ECS.

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

Ensure your target application (https://affluenceit.com/) is:
- Running and accessible
- Configured with QueueIt integration
- Ready for load testing with queue management

## Initial Setup

### 1. Clone and Configure

```bash
# Clone the repository (if using git)
git clone <repository-url>
cd iploads-with-k6-container

# Or if you have the files locally
cd /path/to/iploads-with-k6-container
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
# Navigate to terraform directory
cd terraform

# Initialize Terraform
terraform init

# Deploy infrastructure with IP rotation enabled
terraform apply \
  -var="ip_rotation_enabled=true" \
  -var="proxy_type=static" \
  -var="max_proxy_ips=10"
```

**What this creates:**
- VPC with public subnets
- ECS cluster (`k6-load-test-cluster`)
- Security groups and IAM roles
- S3 bucket for results (`k6-load-test-results-786407478307`)
- CloudWatch log groups
- ECR repository (if needed)

### Step 2: Verify Deployment

```bash
# Check if resources were created
aws ecs list-clusters --region us-east-1
aws logs describe-log-groups --log-group-name-prefix "/ecs/k6" --region us-east-1
aws s3 ls s3://k6-load-test-results-786407478307/ --region us-east-1
```

### Step 3: Configure Test Settings

Update the test configuration file:

```bash
# Edit the configuration file
nano config/test-config.json
```

**Current Configuration:**
```json
{
  "aws": {
    "region": "us-east-1",
    "cluster": {
      "name": "k6-load-test-cluster",
      "arn": "arn:aws:ecs:us-east-1:786407478307:cluster/k6-load-test-cluster"
    },
    "network": {
      "subnet_id": "subnet-097cbe067e542243a",
      "security_group_id": "sg-0737d6eb4011e161c"
    },
    "s3": {
      "bucket": "k6-load-test-results-786407478307"
    },
    "cloudwatch": {
      "log_group": "/ecs/k6-single-vu-test"
    }
  },
  "test": {
    "target": {
      "base_url": "https://affluenceit.com",
      "endpoints": {
        "queueit_protected": "/owners/new",
        "queueit_health": "/integration/queueit/health",
        "public": "/"
      }
    },
    "parameters": {
      "vus_per_task": 1,
      "duration_seconds": 60,
      "num_tasks": 5
    }
  }
}
```

## Running Tests

### 1. Simple IP Diversity Test

```bash
# Run 10 separate tasks with 1 VU each
./run-10-vu-tasks.sh
```

**Test Parameters:**
- **Tasks**: 10 separate ECS tasks
- **VUs per task**: 1
- **Duration**: ~80 seconds per task
- **Target**: `/owners/new` (QueueIt protected endpoint)
- **IP Diversity**: Each task gets unique AWS public IP

### 2. Enhanced QueueIt Test

```bash
# Run comprehensive test with monitoring
./run-enhanced-queueit-test.sh
```

**Test Parameters:**
- **Configuration**: Uses `config/test-config.json`
- **Features**: Real-time monitoring, result collection, error handling
- **Output**: S3 results, CloudWatch logs, local reports

### 3. Monitor Running Tests

```bash
# List running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1

# View task details
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1

# View logs in real-time
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1

# Download latest logs
./scripts/download-logs.sh
```

### 4. Stop Running Tests

```bash
# Stop specific task
aws ecs stop-task --cluster k6-load-test-cluster --task <task-arn> --region us-east-1

# Stop all tasks
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1 | \
  jq -r '.taskArns[]' | \
  xargs -I {} aws ecs stop-task --cluster k6-load-test-cluster --task {} --region us-east-1
```

## Monitoring and Results

### 1. CloudWatch Monitoring

**Log Groups:**
- `/ecs/k6-single-vu-task` (simple test)
- `/ecs/k6-single-vu-test` (enhanced test)

**Real-time Monitoring:**
```bash
# View logs in terminal
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1

# Filter for specific patterns
aws logs filter-log-events \
  --log-group-name /ecs/k6-single-vu-task \
  --filter-pattern "error" \
  --region us-east-1
```

### 2. S3 Results Storage

**Bucket**: `k6-load-test-results-786407478307`

**Path**: `s3://k6-load-test-results-786407478307/test-results/`

**Contents**:
- JSON format results
- HTML reports
- Performance metrics
- Test logs

### 3. Local Results

**Directory**: `results/<test-id>/`

**Files**:
- `cloudwatch-events.json` (CloudWatch logs)
- `test-run.log` (Test execution log)
- `summary.md` (Test summary report)

### 4. Key Metrics to Monitor

- **Response Time**: p50, p90, p95, p99 percentiles
- **Request Rate**: Requests per second (RPS)
- **Error Rate**: Percentage of failed requests
- **QueueIt Redirects**: 302 redirect success rate
- **IP Diversity**: Unique IP addresses used
- **Resource Utilization**: CPU, memory, network

## Troubleshooting

### Common Issues

#### 1. ECS Task Failures

**Symptoms**: Task shows STOPPED status with non-zero exit code

**Solutions**:
```bash
# Check task details
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1

# Check CloudWatch logs
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1

# Verify target URL is accessible
curl -I https://affluenceit.com/
```

#### 2. QueueIt Integration Issues

**Symptoms**: 500 errors or unexpected redirects

**Solutions**:
```bash
# Test protected endpoint manually
curl -I https://affluenceit.com/owners/new

# Check for 302 redirect
curl -L -I https://affluenceit.com/owners/new

# Test health endpoint
curl https://affluenceit.com/integration/queueit/health
```

#### 3. Network Connectivity Issues

**Symptoms**: Timeout errors or connection refused

**Solutions**:
- Verify target application is running
- Check security group rules
- Ensure public IP assignment is enabled
- Verify VPC and subnet configuration

#### 4. Permission Issues

**Symptoms**: Access denied errors

**Solutions**:
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM roles
aws iam get-role --role-name k6-load-test-ecs-task-role --region us-east-1
aws iam get-role --role-name k6-load-test-ecs-execution-role --region us-east-1

# Check S3 bucket permissions
aws s3 ls s3://k6-load-test-results-786407478307/ --region us-east-1
```

#### 5. IP Diversity Issues

**Symptoms**: All requests coming from same IP

**Solutions**:
```bash
# Verify multiple tasks are running
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1

# Check task network configuration
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1
```

### Debugging Commands

```bash
# Check ECS cluster status
aws ecs describe-clusters --clusters k6-load-test-cluster --region us-east-1

# List running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --desired-status RUNNING --region us-east-1

# Get task details
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=k6-load-test-cluster \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average \
  --region us-east-1

# Download and analyze logs
./scripts/download-logs.sh
jq '.events[] | select(.message | contains("error"))' k6-scripts/test-logs/k6-latest-logs.json
```

## Cleanup

### 1. Stop All Tests

```bash
# Stop all running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1 | \
  jq -r '.taskArns[]' | \
  xargs -I {} aws ecs stop-task --cluster k6-load-test-cluster --task {} --region us-east-1
```

### 2. Destroy Infrastructure

```bash
# Clean up all AWS resources
cd terraform
terraform destroy
```

**Warning**: This will permanently delete all resources created for this project.

### 3. Manual Cleanup (if scripts fail)

```bash
# Destroy Terraform resources
cd terraform
terraform destroy

# Delete CloudWatch log groups
aws logs delete-log-group --log-group-name /ecs/k6-single-vu-task --region us-east-1
aws logs delete-log-group --log-group-name /ecs/k6-single-vu-test --region us-east-1

# Delete S3 bucket (if empty)
aws s3 rb s3://k6-load-test-results-786407478307 --force --region us-east-1

# Clean up local files
rm -rf results/
rm -f k6-scripts/test-logs/*.json
```

## Cost Optimization

### 1. Resource Sizing

- Start with minimal resources (256 CPU, 512MB memory)
- Scale up based on test requirements
- Use Fargate for serverless scaling

### 2. Test Duration

- Keep tests short for development (~60 seconds)
- Run longer tests only when needed
- Monitor costs in AWS Cost Explorer

### 3. Cleanup

- Always run cleanup after testing
- Set up billing alerts
- Monitor resource usage

## Best Practices

### 1. Test Planning

- Start with small load tests (1-5 tasks)
- Gradually increase load
- Monitor target application health
- Set realistic thresholds for QueueIt integration

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

### 4. QueueIt Testing

- Test protected endpoints (`/owners/new`)
- Verify redirect behavior (302 status codes)
- Monitor health endpoints
- Validate public route accessibility

## Support

For additional support:

1. Check the troubleshooting section above
2. Review CloudWatch logs for detailed error messages
3. Verify AWS service limits and quotas
4. Consult AWS documentation for ECS and k6
5. Check QueueIt integration documentation

## Next Steps

After successful deployment:

1. **Customize Tests**: Modify `k6-scripts/queueit-test.js`
2. **Adjust Configuration**: Update `config/test-config.json`
3. **Add Monitoring**: Set up CloudWatch alarms
4. **Scale Up**: Increase `num_tasks` for more IP diversity
5. **Integrate**: Add to CI/CD pipeline
6. **Optimize**: Fine-tune based on results 