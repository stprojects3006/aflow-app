# Quick Start Guide

Get your k6 load testing environment with IP diversity and QueueIt integration up and running in 10 minutes!

## Prerequisites Checklist

- [ ] AWS account with billing enabled
- [ ] AWS CLI v2 installed and configured
- [ ] Docker Desktop installed and running
- [ ] Terraform CLI installed (v1.0+)
- [ ] Target application running on https://affluenceit.com/
- [ ] QueueIt integration configured on target application

## 1. Setup (2 minutes)

```bash
# Configure AWS credentials
aws configure

# Verify tools are installed
aws --version && docker --version && terraform --version

# Clone and navigate to project
cd iploads-with-k6-container
```

## 2. Deploy Infrastructure (5 minutes)

```bash
# Deploy AWS infrastructure
cd terraform
terraform init
terraform apply \
  -var="ip_rotation_enabled=true" \
  -var="proxy_type=static" \
  -var="max_proxy_ips=10"
```

This will create:
- ✅ ECS Cluster: `k6-load-test-cluster`
- ✅ VPC with public subnets
- ✅ Security groups
- ✅ IAM roles
- ✅ S3 bucket for results
- ✅ CloudWatch log groups

## 3. Run Tests (2 minutes)

### Simple IP Diversity Test
```bash
# Run 10 separate tasks with 1 VU each
./run-10-vu-tasks.sh
```

### Enhanced QueueIt Test
```bash
# Run comprehensive test with monitoring
./run-enhanced-queueit-test.sh
```

### Monitor Tests
```bash
# Download latest logs
./scripts/download-logs.sh

# View CloudWatch logs
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1
```

## 4. View Results

### CloudWatch Monitoring
- **Log Groups**: 
  - `/ecs/k6-single-vu-task` (simple test)
  - `/ecs/k6-single-vu-test` (enhanced test)
- **Real-time**: Live log streaming
- **Metrics**: CPU, Memory, Network, k6 metrics

### S3 Results
- **Bucket**: `k6-load-test-results-786407478307`
- **Path**: `s3://k6-load-test-results-786407478307/test-results/`
- **Contents**: JSON results, HTML reports, logs

### Local Results
- **Directory**: `results/<test-id>/`
- **Files**: 
  - `cloudwatch-events.json` (CloudWatch logs)
  - `test-run.log` (Test execution log)
  - `summary.md` (Test summary report)

## 5. Cleanup (1 minute)

```bash
# Stop running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1
aws ecs stop-task --cluster k6-load-test-cluster --task <task-arn> --region us-east-1

# Clean up infrastructure
cd terraform
terraform destroy
```

## Common Commands

```bash
# Check ECS cluster status
aws ecs describe-clusters --clusters k6-load-test-cluster --region us-east-1

# List running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1

# View task details
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1

# Download logs
./scripts/download-logs.sh

# View logs in real-time
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1
```

## Test Scenarios

### QueueIt Integration Testing
1. **Protected Route Testing**
   - Target: `/owners/new`
   - Expected: 302 redirect to QueueIt waiting room
   - Validation: Location header contains "queue-it"

2. **Health Check Testing**
   - Target: `/integration/queueit/health`
   - Expected: 200 status code
   - Validation: QueueIt service health

3. **Public Route Testing**
   - Target: `/`
   - Expected: 200 status code
   - Validation: Public access without QueueIt

### IP Diversity Testing
- **10 separate ECS tasks** with 1 VU each
- **Each task gets unique AWS public IP**
- **Natural IP diversity** without proxy configuration
- **Test duration**: ~80 seconds per task

## Troubleshooting

### Target Application Not Accessible
```bash
# Test connectivity
curl -I https://affluenceit.com/

# Test QueueIt protected endpoint
curl -I https://affluenceit.com/owners/new

# Test QueueIt health endpoint
curl https://affluenceit.com/integration/queueit/health
```

### AWS Permissions Error
```bash
# Verify credentials
aws sts get-caller-identity

# Check IAM permissions
aws iam get-user
```

### ECS Task Failures
```bash
# Check task status
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1

# View CloudWatch logs
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1

# Check S3 bucket permissions
aws s3 ls s3://k6-load-test-results-786407478307/
```

### QueueIt Integration Issues
```bash
# Test protected endpoint manually
curl -I https://affluenceit.com/owners/new

# Check for 302 redirect
curl -L -I https://affluenceit.com/owners/new

# Verify QueueIt configuration
curl https://affluenceit.com/integration/queueit/health
```

## Cost Estimation

**Per Test Run:**
- ECS Fargate (10 tasks): ~$1.00-3.00
- CloudWatch Logs: ~$0.10-0.50
- Data Transfer: ~$0.10-0.30
- S3 Storage: ~$0.01-0.05

**Total per test: $1.21-3.85**

## Configuration Files

### Test Configuration (`config/test-config.json`)
```json
{
  "aws": {
    "region": "us-east-1",
    "cluster": {
      "name": "k6-load-test-cluster"
    },
    "network": {
      "subnet_id": "subnet-097cbe067e542243a",
      "security_group_id": "sg-0737d6eb4011e161c"
    },
    "s3": {
      "bucket": "k6-load-test-results-786407478307"
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

## Next Steps

1. **Customize Tests**: Edit `k6-scripts/queueit-test.js`
2. **Modify Configuration**: Update `config/test-config.json`
3. **Scale Up**: Increase `num_tasks` in configuration
4. **Add Monitoring**: Set up CloudWatch alarms
5. **Integrate**: Add to your CI/CD pipeline

## Need Help?

- 📖 Read the full [README.md](README.md)
- 🚀 Check [Enhanced Features](README-ENHANCED.md)
- 🔧 Review [Troubleshooting](README.md#troubleshooting)
- 📊 Learn about [Monitoring](README.md#monitoring-and-results)
- 🏗️ Understand [Architecture](SOLUTION_ARCHITECTURE.md)

---

**Happy Load Testing with IP Diversity and QueueIt Integration! 🚀** 