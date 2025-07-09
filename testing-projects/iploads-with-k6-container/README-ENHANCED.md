# Enhanced QueueIt Load Testing Suite

A comprehensive load testing solution for QueueIt integration with AWS ECS, featuring individual VU tasks, result collection, monitoring, and IP diversity testing.

## 🚀 Features

### ✅ **Core Features:**
- **Real AWS Configuration** - Uses actual subnet, security group, and cluster IDs
- **Separate Test Scripts** - Modular k6 test scripts for easy maintenance
- **Individual VU Tasks** - Each VU runs in its own container with unique IP
- **Comprehensive Result Collection** - S3, CloudWatch, and local result storage
- **Error Handling & Monitoring** - Robust error handling and real-time monitoring
- **IP Rotation Ready** - Configuration for Tor-based IP rotation
- **Test Configuration** - Centralized configuration management

### 🎯 **QueueIt Integration Testing:**
- **Protected Endpoint Testing** - Tests `/owners/new` with QueueIt redirects
- **Health Check Validation** - Monitors QueueIt health endpoint
- **Public Endpoint Verification** - Ensures public routes remain accessible
- **Redirect Pattern Analysis** - Tracks QueueIt redirect behavior
- **IP Diversity Testing** - Tests with multiple unique IP addresses

### 🔄 **IP Diversity Features:**
- **Container-Level IP Diversity** - Each ECS task gets unique AWS public IP
- **Natural IP Rotation** - No proxy configuration required
- **VU-IP Mapping** - Track which VU uses which IP address
- **Load Distribution** - Distribute load across multiple IP sources

## 📁 Project Structure

```
iploads-with-k6-container/
├── 📄 README.md                           # Main documentation
├── 📄 README-ENHANCED.md                  # Enhanced features guide (this file)
├── 📄 QUICK_START.md                      # Quick start guide
├── 📄 DEPLOYMENT_GUIDE.md                 # Deployment instructions
├── 📄 SOLUTION_ARCHITECTURE.md            # Architecture documentation
├── 📄 IP_ROTATION_IMPLEMENTATION_GUIDE.md # IP rotation implementation
├── 📄 IP_ROTATION_DETAILED_GUIDE.md      # Detailed IP rotation guide
├── 📄 IP_DIVERSITY_QUICK_REFERENCE.md    # IP diversity quick reference
├── 📄 IP_DIVERSITY_MODELS.md             # IP diversity models
├── 📄 FLOWCHARTS.md                       # Flow diagrams
├── 📄 FLOWCHARTS.html                     # Interactive flow diagrams
├── 📄 SOLUTION_ARCHITECTURE.html          # Interactive architecture
├── 📄 IP_ROTATION_VISUAL_GUIDE.html      # Visual IP rotation guide
├── 
├── 🚀 run-10-vu-tasks.sh                  # Simple IP diversity test
├── 🚀 run-enhanced-queueit-test.sh        # Enhanced QueueIt test
├── 
├── 📋 task-def-single-vu-owners.json     # ECS task definition
├── 
├── 📁 config/
│   └── 📄 test-config.json               # Test configuration
├── 
├── 📁 k6-scripts/
│   ├── 📄 queueit-test.js                # QueueIt test script
│   └── 📁 test-logs/                     # Test logs directory
│       └── 📄 k6-latest-logs.json        # Latest test logs
├── 
├── 📁 scripts/
│   ├── 📄 download-logs.sh               # Log download utility
│   ├── 📄 collect-results.sh             # Result collection
│   ├── 📄 cleanup.sh                     # Resource cleanup
│   ├── 📄 deploy.sh                      # Deployment script
│   ├── 📄 task-def.json                  # Basic task definition
│   └── 📄 task-def-with-ip-rotation.json # IP rotation task definition
├── 
├── 📁 terraform/                          # Infrastructure as Code
├── 
└── 📁 docker/                             # Docker configurations
```

## 🛠️ Configuration

### **AWS Configuration (`config/test-config.json`):**
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

## 🚀 Quick Start

### **1. Run Simple IP Diversity Test:**
```bash
# Run 10 separate tasks with 1 VU each
./run-10-vu-tasks.sh
```

### **2. Run Enhanced QueueIt Test:**
```bash
# Run comprehensive test with monitoring
./run-enhanced-queueit-test.sh
```

### **3. Collect Results:**
```bash
# Download latest logs
./scripts/download-logs.sh

# Collect specific test results
./scripts/collect-results.sh -t 20250709-114704

# Collect all recent tests
./scripts/collect-results.sh -a -d 7
```

## 📊 Test Results

### **Local Results:**
```
results/
└── 20250709-114704/
    ├── logs/
    │   ├── test-run.log
    │   ├── cloudwatch.log
    │   └── cloudwatch-events.json
    └── summary.md
```

### **S3 Results:**
```
s3://k6-load-test-results-786407478307/test-results/
└── 20250709-114704/
    ├── k6-results-task-1-*.json
    ├── k6-results-task-1-*.html
    └── k6-summary-task-1-*.txt
```

### **CloudWatch Monitoring:**
- **Log Groups**: 
  - `/ecs/k6-single-vu-task` (simple test)
  - `/ecs/k6-single-vu-test` (enhanced test)
- **Real-time monitoring** during test execution
- **Live log streaming** with `aws logs tail`

## 🎯 Test Scenarios

### **QueueIt Integration Testing:**
1. **Protected Route Access** - Tests `/owners/new` endpoint
2. **QueueIt Redirects** - Validates 302 redirects to waiting room
3. **Health Endpoint** - Monitors QueueIt health status
4. **Public Routes** - Ensures public endpoints remain accessible

### **IP Diversity Testing:**
1. **Natural IP Diversity** - Each ECS task gets unique AWS public IP
2. **Load Distribution** - Distribute load across multiple IP sources
3. **Session Independence** - No shared cookies between tasks
4. **Realistic Simulation** - Each task represents a unique user

### **Load Testing Features:**
- **Individual VU Tasks** - Each VU has unique IP and independent cookies
- **Ramp-up/Ramp-down** - Gradual load increase and decrease
- **Custom Metrics** - QueueIt-specific metrics tracking
- **Comprehensive Checks** - Response time, status codes, redirects

## 📈 Monitoring & Analytics

### **Real-time Monitoring:**
- **CloudWatch Logs** - Live log streaming during tests
- **Task Status Tracking** - Monitor individual task progress
- **Error Detection** - Automatic failure detection and reporting

### **Result Analysis:**
- **QueueIt Redirect Patterns** - Track redirect success rates
- **Response Time Analysis** - Performance metrics per endpoint
- **Error Pattern Analysis** - Identify failure modes
- **IP Diversity Verification** - Confirm unique IP usage

### **Sample Test Results:**
```json
{
  "test_id": "20250709-114704",
  "target_url": "https://affluenceit.com",
  "num_tasks": 10,
  "duration_per_task": 60,
  "results": {
    "completed_tasks": 10,
    "failed_tasks": 0,
    "success_rate": 100,
    "queueit_redirects": 45,
    "avg_response_time": 1500,
    "p95_response_time": 2500
  },
  "ip_diversity": {
    "unique_ips_used": 10,
    "ip_rotation_success_rate": 0.95
  }
}
```

## 🔧 Advanced Configuration

### **IP Rotation Setup:**
```json
{
  "ip_rotation": {
    "enabled": true,
    "method": "tor",
    "tor_config": {
      "socks_port": 9050,
      "control_port": 9051
    }
  }
}
```

### **Custom Test Parameters:**
```bash
# Override configuration
export TARGET_URL="https://your-domain.com"
export NUM_TASKS=10
export DURATION=120
```

### **Task Definition Configuration:**
```json
{
  "family": "k6-single-vu-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::786407478307:role/k6-load-test-ecs-execution-role",
  "taskRoleArn": "arn:aws:iam::786407478307:role/k6-load-test-ecs-task-role",
  "containerDefinitions": [
    {
      "name": "k6",
      "image": "grafana/k6:latest",
      "environment": [
        {"name": "TARGET_URL", "value": "https://affluenceit.com"},
        {"name": "TEST_SCRIPT", "value": "queueit-test.js"}
      ]
    }
  ]
}
```

## 🚨 Troubleshooting

### **Common Issues:**

1. **Task Startup Failures:**
   ```bash
   # Check task status
   aws ecs describe-tasks --cluster k6-load-test-cluster --tasks <task-arn> --region us-east-1
   
   # View CloudWatch logs
   aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1
   ```

2. **Configuration Errors:**
   ```bash
   # Validate configuration
   jq '.' config/test-config.json
   ```

3. **Result Collection Issues:**
   ```bash
   # Check S3 permissions
   aws s3 ls s3://k6-load-test-results-786407478307/
   
   # Download logs manually
   ./scripts/download-logs.sh
   ```

4. **QueueIt Integration Issues:**
   ```bash
   # Test protected endpoint manually
   curl -I https://affluenceit.com/owners/new
   
   # Check for 302 redirect
   curl -L -I https://affluenceit.com/owners/new
   ```

### **Log Analysis:**
```bash
# View CloudWatch logs
aws logs tail /ecs/k6-single-vu-test --follow --region us-east-1

# Download specific test logs
./scripts/download-logs.sh

# Analyze log content
jq '.events[] | select(.message | contains("error"))' k6-scripts/test-logs/k6-latest-logs.json
```

## 📋 Prerequisites

- **AWS CLI** configured with appropriate permissions
- **jq** for JSON parsing
- **ECS cluster** with Fargate capacity (`k6-load-test-cluster`)
- **S3 bucket** for result storage (`k6-load-test-results-786407478307`)
- **CloudWatch log groups** for monitoring
- **Target application** with QueueIt integration

## 🎉 Benefits

### **For QueueIt Testing:**
- **Realistic Simulation** - Each VU represents a unique user
- **IP Diversity** - Unique IP addresses for each task
- **Session Independence** - No shared cookies between VUs
- **Comprehensive Coverage** - Tests all QueueIt integration points
- **Redirect Validation** - Verifies QueueIt redirect behavior

### **For Load Testing:**
- **Scalable Architecture** - Easy to increase/decrease load
- **Result Aggregation** - Centralized result collection
- **Error Handling** - Robust error detection and reporting
- **Monitoring** - Real-time visibility into test execution
- **IP Diversity** - Natural IP rotation without proxy configuration

### **For IP Diversity Testing:**
- **Natural IP Rotation** - Each ECS task gets unique AWS public IP
- **No Proxy Required** - Eliminates proxy configuration complexity
- **Realistic Load Distribution** - Distributes load across multiple IP sources
- **Easy Scaling** - Simply increase number of tasks for more IP diversity

## 🔄 Next Steps

1. **Run Initial Test** - Execute the enhanced test suite
2. **Analyze Results** - Review QueueIt redirect patterns
3. **Adjust Configuration** - Modify test parameters as needed
4. **Scale Testing** - Increase load or add more test scenarios
5. **Monitor Performance** - Track QueueIt integration performance
6. **Customize Scripts** - Modify k6 test scripts for specific needs

## 📚 Related Documentation

- **[README.md](README.md)** - Main project documentation
- **[QUICK_START.md](QUICK_START.md)** - Quick start guide
- **[SOLUTION_ARCHITECTURE.md](SOLUTION_ARCHITECTURE.md)** - Architecture details
- **[IP_DIVERSITY_QUICK_REFERENCE.md](IP_DIVERSITY_QUICK_REFERENCE.md)** - IP diversity guide
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Deployment instructions

---

**Ready to test your QueueIt integration with realistic load patterns and IP diversity! 🚀** 