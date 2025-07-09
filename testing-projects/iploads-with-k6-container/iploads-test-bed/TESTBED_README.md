# iploads-k6-container Test Bed Setup

This directory contains a comprehensive automation framework for setting up and managing load testing infrastructure using k6 and AWS ECS.

## 📁 File Structure

```
iploads-with-k6-container/
├── setup-testbed.sh          # Main automation script
├── manage-testbed.sh         # Management and monitoring script
├── testbed-config.json       # Configuration file
├── TESTBED_README.md         # This file
├── task-definitions/         # ECS task definition templates
├── k6-scripts/              # k6 load testing scripts
├── logs/                    # Generated logs (created automatically)
├── results/                 # Test results (created automatically)
└── metrics/                 # CloudWatch metrics (created automatically)
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** installed and configured
2. **jq** for JSON processing
3. **AWS permissions** for ECS, CloudWatch, and IAM
4. **k6 scripts** in the `k6-scripts/` directory

### Basic Usage

```bash
# Make scripts executable
chmod +x setup-testbed.sh manage-testbed.sh

# Run all tests
./setup-testbed.sh --all-tests

# Run specific test
./setup-testbed.sh --test basic --duration 10m --vus 100

# Check status
./manage-testbed.sh status

# Cleanup resources
./manage-testbed.sh cleanup
```

## 📋 Scripts Overview

### 1. `setup-testbed.sh` - Main Automation Script

**Purpose**: Complete test bed setup, execution, and result collection

**Key Features**:
- Creates ECS cluster if needed
- Registers task definitions
- Runs load tests with different configurations
- Captures logs and metrics
- Generates reports

**Usage Examples**:

```bash
# Run all predefined tests
./setup-testbed.sh --all-tests

# Run specific test with custom parameters
./setup-testbed.sh --test queueit --duration 15m --vus 50

# Create cluster only
./setup-testbed.sh --create-cluster

# Run basic test with custom URL
./setup-testbed.sh --test basic --url https://example.com --vus 25
```

**Available Tests**:
- `basic` - Basic load test (50 VUs, 5m duration)
- `spike` - Spike test (100 VUs, 10m duration)
- `stress` - Stress test (200 VUs, 15m duration)
- `queueit` - QueueIt integration test (30 VUs, 8m duration)
- `owners` - Owners page test (40 VUs, 6m duration)
- `ip_rotation` - IP rotation test (25 VUs, 10m duration)

### 2. `manage-testbed.sh` - Management Script

**Purpose**: Monitor, maintain, and cleanup test infrastructure

**Key Features**:
- Monitor running tasks
- Download logs and metrics
- Generate summary reports
- Cleanup resources
- Health checks

**Usage Examples**:

```bash
# Check overall status
./manage-testbed.sh status

# List running tasks
./manage-testbed.sh tasks

# Download logs for specific test
./manage-testbed.sh logs basic --days 7

# Get metrics for last 48 hours
./manage-testbed.sh metrics queueit --hours 48

# Generate summary report
./manage-testbed.sh report

# Complete cleanup
./manage-testbed.sh cleanup
```

## ⚙️ Configuration

### `testbed-config.json`

The configuration file contains all settings for the test bed:

```json
{
  "aws": {
    "region": "us-east-1",
    "cluster_name": "k6-load-test-cluster",
    "task_family_prefix": "k6-load-test"
  },
  "target": {
    "base_url": "https://affluenceit.com",
    "endpoints": {
      "queueit": "/integration/queueit/validate",
      "owners": "/owners"
    }
  },
  "tests": {
    "basic": {
      "script": "basic-load-test.js",
      "configuration": {
        "vus": 50,
        "duration": "5m",
        "cpu": "1024",
        "memory": "2048"
      }
    }
  }
}
```

### Environment Variables

You can override configuration using environment variables:

```bash
export AWS_REGION=us-west-2
export TARGET_URL=https://example.com
export DURATION=10m
export VUS=100
```

## 🔧 Test Configurations

### Basic Load Test
- **Purpose**: Standard load testing
- **Configuration**: 50 VUs, 5 minutes duration
- **Target**: General application endpoints

### Spike Test
- **Purpose**: Sudden traffic increase testing
- **Configuration**: 100 VUs, 10 minutes duration
- **Target**: System behavior under sudden load

### Stress Test
- **Purpose**: Find breaking point
- **Configuration**: 200 VUs, 15 minutes duration
- **Target**: Maximum capacity testing

### QueueIt Integration Test
- **Purpose**: QueueIt-specific functionality
- **Configuration**: 30 VUs, 8 minutes duration
- **Target**: QueueIt endpoints and redirects

### IP Rotation Test
- **Purpose**: IP diversity testing
- **Configuration**: 25 VUs, 10 minutes duration
- **Target**: IP-based rate limiting and geolocation

## 📊 Monitoring & Results

### Generated Files

After running tests, the following structure is created:

```
logs/
└── 20241201_143022/
    ├── task-definitions/     # Task definition files
    ├── ecs-logs/            # ECS task logs
    └── k6-results/          # k6 output files

results/
└── 20241201_143022/
    ├── basic/               # Basic test results
    ├── spike/               # Spike test results
    ├── stress/              # Stress test results
    ├── queueit/             # QueueIt test results
    └── dashboards/          # Generated dashboards
```

### Metrics Collected

- **ECS Metrics**: CPU, Memory, Network utilization
- **k6 Metrics**: HTTP request duration, error rates, throughput
- **Custom Metrics**: QueueIt redirects, IP diversity scores
- **CloudWatch Logs**: Application and access logs

### Reports Generated

1. **HTML Reports**: Individual test reports with metrics
2. **Summary Report**: Overall test bed status
3. **JSON Metrics**: Raw CloudWatch metrics
4. **Log Files**: Complete execution logs

## 🛠️ Troubleshooting

### Common Issues

1. **Cluster Not Found**
   ```bash
   ./setup-testbed.sh --create-cluster
   ```

2. **Task Definition Registration Failed**
   - Check AWS permissions
   - Verify task definition JSON syntax
   - Ensure ECS execution role exists

3. **Tasks Not Starting**
   - Check security groups
   - Verify subnet configuration
   - Review CloudWatch logs

4. **High Error Rates**
   - Check target application health
   - Review k6 script configuration
   - Monitor resource utilization

### Debug Commands

```bash
# Check cluster status
./manage-testbed.sh status

# View running tasks
./manage-testbed.sh tasks

# Download recent logs
./manage-testbed.sh logs basic --days 1

# Get metrics
./manage-testbed.sh metrics queueit --hours 2

# Generate debug report
./manage-testbed.sh report
```

## 🔒 Security Considerations

### AWS Permissions Required

- **ECS**: Create/delete clusters, register/deregister task definitions, run/stop tasks
- **CloudWatch**: Create log groups, write logs, get metrics
- **IAM**: Pass roles to ECS tasks
- **EC2**: Describe VPCs, subnets, security groups

### Security Best Practices

1. **Use IAM Roles**: Don't hardcode credentials
2. **Network Security**: Use security groups to restrict access
3. **Log Monitoring**: Monitor for suspicious activity
4. **Resource Cleanup**: Always cleanup resources after testing
5. **Credential Rotation**: Regularly rotate API keys

## 📈 Performance Optimization

### Resource Allocation

- **CPU**: 1024-2048 CPU units per task
- **Memory**: 2048-4096 MB per task
- **Network**: Monitor bandwidth usage
- **Storage**: Use EFS for shared storage

### Scaling Strategies

1. **Horizontal Scaling**: Multiple ECS tasks
2. **Vertical Scaling**: Increase CPU/Memory
3. **Load Distribution**: Use multiple subnets
4. **IP Diversity**: Rotate source IPs

## 🔄 Continuous Integration

### GitHub Actions Example

```yaml
name: Load Testing
on: [push, pull_request]

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Run load tests
        run: |
          chmod +x setup-testbed.sh
          ./setup-testbed.sh --test basic --duration 5m
      - name: Download results
        run: |
          chmod +x manage-testbed.sh
          ./manage-testbed.sh logs basic --days 1
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: load-test-results
          path: results/
```

## 📚 Additional Resources

### Documentation
- [k6 Documentation](https://k6.io/docs/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)

### Examples
- [k6 Examples](https://github.com/grafana/k6-examples)
- [ECS Task Definitions](https://docs.aws.amazon.com/ecs/latest/developerguide/task_definitions.html)

### Support
- [k6 Community](https://community.k6.io/)
- [AWS Support](https://aws.amazon.com/support/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details. 