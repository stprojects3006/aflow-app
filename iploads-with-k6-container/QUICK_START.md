# Quick Start Guide

Get your k6 load testing environment up and running in 10 minutes!

## Prerequisites Checklist

- [ ] AWS account with billing enabled
- [ ] AWS CLI v2 installed and configured
- [ ] Docker Desktop installed and running
- [ ] Terraform CLI installed (v1.0+)
- [ ] Target application running on https://affluenceit.com/

## 1. Setup (2 minutes)

```bash
# Configure AWS credentials
aws configure

# Verify tools are installed
aws --version && docker --version && terraform --version
```

## 2. Deploy (5 minutes)

```bash
# Deploy everything with one command
./scripts/deploy.sh --region us-east-1 --target-url https://affluenceit.com/ --test-type basic
```

This will:
- ✅ Create AWS infrastructure (VPC, ECS, ECR, etc.)
- ✅ Build and push Docker image
- ✅ Run initial test
- ✅ Set up monitoring

## 3. Run Tests (2 minutes)

```bash
# Run different test types
./scripts/run-tests.sh --test-type basic    # 10 users, 9 minutes
./scripts/run-tests.sh --test-type stress   # Up to 200 users, 22 minutes
./scripts/run-tests.sh --test-type spike    # Sudden spikes, 8 minutes

# Monitor in real-time
./scripts/run-tests.sh --test-type logs
```

## 4. View Results

- **CloudWatch Dashboard**: Monitor metrics in AWS Console
- **CloudWatch Logs**: View detailed test logs
- **S3 Bucket**: Download test results

## 5. Cleanup (1 minute)

```bash
# Stop all tests
./scripts/run-tests.sh --test-type stop

# Remove all AWS resources
./scripts/cleanup.sh
```

## Common Commands

```bash
# Check deployment status
aws ecs list-clusters
aws ecr describe-repositories

# View logs
./scripts/run-tests.sh --test-type logs

# List running tasks
./scripts/run-tests.sh --test-type list

# Stop all tasks
./scripts/run-tests.sh --test-type stop
```

## Troubleshooting

### Target Application Not Accessible
```bash
# Test connectivity
curl -I https://affluenceit.com/

# Check if your app is accessible
curl -s https://affluenceit.com/ | head -5
```

### AWS Permissions Error
```bash
# Verify credentials
aws sts get-caller-identity

# Check IAM permissions
aws iam get-user
```

### Container Fails to Start
```bash
# Check task status
aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn>

# View logs
aws logs tail /ecs/k6-load-test-k6 --follow
```

## Cost Estimation

**Per Test Run:**
- ECS Fargate: ~$0.50-2.00
- CloudWatch: ~$0.10-0.50
- Data Transfer: ~$0.10-0.30

**Total per test: $0.70-2.80**

## Next Steps

1. **Customize Tests**: Edit `docker/k6-scripts/` files
2. **Scale Up**: Modify `terraform/variables.tf`
3. **Add Monitoring**: Set up CloudWatch alarms
4. **Integrate**: Add to your CI/CD pipeline

## Need Help?

- 📖 Read the full [Deployment Guide](DEPLOYMENT_GUIDE.md)
- 🔧 Check [Troubleshooting](DEPLOYMENT_GUIDE.md#troubleshooting)
- 📊 Review [Monitoring](DEPLOYMENT_GUIDE.md#monitoring-and-results)

---

**Happy Load Testing! 🚀** 