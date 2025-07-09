# 🔄 K6 Load Testing with IP Diversity and QueueIt Integration - Flowcharts

## 📋 Table of Contents

1. [Complete Request Flow](#complete-request-flow)
2. [IP Diversity Assignment Process](#ip-diversity-assignment-process)
3. [QueueIt Integration Flow](#queueit-integration-flow)
4. [Test Execution Lifecycle](#test-execution-lifecycle)
5. [Results Processing Pipeline](#results-processing-pipeline)
6. [Network Traffic Flow](#network-traffic-flow)
7. [Data Storage Flow](#data-storage-flow)
8. [Monitoring Flow](#monitoring-flow)

---

## 🔄 Complete Request Flow

### **End-to-End Request Flow with QueueIt Integration**

```mermaid
flowchart TD
    subgraph "Deployment Phase"
        A[User Runs Test Script] --> B[./run-10-vu-tasks.sh]
        B --> C[Register Task Definition]
        C --> D[Launch 10 ECS Tasks]
    end
    
    subgraph "Container Deployment"
        D --> E[Fargate Task Execution]
        E --> F[Each Task Gets Unique IP]
        F --> G[Task 1: IP 3.x.x.1]
        F --> H[Task 2: IP 3.x.x.2]
        F --> I[Task 10: IP 3.x.x.10]
    end
    
    subgraph "K6 Test Execution"
        G --> J[VU 1 Starts]
        H --> K[VU 1 Starts]
        I --> L[VU 1 Starts]
        
        J --> M[Request to /owners/new]
        K --> N[Request to /owners/new]
        L --> O[Request to /owners/new]
    end
    
    subgraph "QueueIt Integration"
        M --> P[QueueIt Filter Checks]
        N --> Q[QueueIt Filter Checks]
        O --> R[QueueIt Filter Checks]
        
        P --> S{User in Queue?}
        Q --> T{User in Queue?}
        R --> U{User in Queue?}
        
        S -->|No| V[302 Redirect to QueueIt]
        T -->|No| W[302 Redirect to QueueIt]
        U -->|No| X[302 Redirect to QueueIt]
        
        S -->|Yes| Y[Allow Access]
        T -->|Yes| Z[Allow Access]
        U -->|Yes| AA[Allow Access]
    end
    
    subgraph "Response Processing"
        V --> BB[K6 Processes 302]
        W --> CC[K6 Processes 302]
        X --> DD[K6 Processes 302]
        Y --> EE[K6 Processes 200]
        Z --> FF[K6 Processes 200]
        AA --> GG[K6 Processes 200]
    end
    
    subgraph "Results Collection"
        BB --> HH[Update Metrics]
        CC --> HH
        DD --> HH
        EE --> HH
        FF --> HH
        GG --> HH
        
        HH --> II[Log Results]
        II --> JJ[Test Completes]
        JJ --> KK[Upload to S3]
        KK --> LL[CloudWatch Logs]
    end
    
    style A fill:#e1f5fe
    style V fill:#fff3e0
    style LL fill:#c8e6c9
```

---

## 🌐 IP Diversity Assignment Process

### **Multiple Tasks IP Assignment Flow**

```mermaid
flowchart TD
    subgraph "Task Launch"
        A[./run-10-vu-tasks.sh] --> B[Loop: 1 to 10]
        B --> C[aws ecs run-task]
        C --> D[ECS Scheduler]
    end
    
    subgraph "Resource Allocation"
        D --> E[Fargate Platform]
        E --> F[Allocate CPU: 256 units]
        E --> G[Allocate Memory: 512 MiB]
        E --> H[Allocate Network: awsvpc mode]
    end
    
    subgraph "Network Interface Creation"
        H --> I[Create ENI in VPC]
        I --> J[Assign Private IP from Subnet]
        J --> K[10.0.1.x from subnet-097cbe067e542243a]
    end
    
    subgraph "Public IP Assignment"
        K --> L[Public Subnet Configuration]
        L --> M[map_public_ip_on_launch = true]
        M --> N[Auto-assign Public IP]
        N --> O[3.x.x.x from AWS IP Pool]
    end
    
    subgraph "IP Diversity Result"
        O --> P[Task 1: 3.x.x.1]
        O --> Q[Task 2: 3.x.x.2]
        O --> R[Task 3: 3.x.x.3]
        O --> S[...]
        O --> T[Task 10: 3.x.x.10]
    end
    
    subgraph "Task Ready"
        P --> U[Each Task Has Unique IP]
        Q --> U
        R --> U
        S --> U
        T --> U
        U --> V[Natural IP Diversity Achieved]
    end
    
    style A fill:#e1f5fe
    style V fill:#c8e6c9
```

### **IP Assignment Code Reference**

```bash
#!/bin/bash
# run-10-vu-tasks.sh - IP Diversity Implementation

# Register task definition
aws ecs register-task-definition \
    --cli-input-json file://task-def-single-vu-owners.json \
    --region us-east-1

# Launch 10 tasks for IP diversity
for i in {1..10}; do
    aws ecs run-task \
        --cluster k6-load-test-cluster \
        --task-definition k6-single-vu-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-097cbe067e542243a],securityGroups=[sg-0737d6eb4011e161c],assignPublicIp=ENABLED}" \
        --region us-east-1
done
```

```terraform
# VPC Configuration
resource "aws_vpc" "k6_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Public Subnet with Auto-assign Public IP
resource "aws_subnet" "k6_public_subnet" {
  vpc_id                  = aws_vpc.k6_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true  # ← Enables auto-assign
}

# ECS Task with awsvpc Network Mode
resource "aws_ecs_task_definition" "k6_task" {
  network_mode             = "awsvpc"  # ← Required for public IP
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
}
```

---

## 🎯 QueueIt Integration Flow

### **QueueIt Integration Testing Flow**

```mermaid
flowchart TD
    subgraph "Test Configuration"
        A[config/test-config.json] --> B[Target Configuration]
        B --> C[base_url: https://affluenceit.com]
        B --> D[endpoints.queueit_protected: /owners/new]
        B --> E[endpoints.queueit_health: /integration/queueit/health]
        B --> F[endpoints.public: /]
    end
    
    subgraph "K6 Test Script"
        G[k6-scripts/queueit-test.js] --> H[Load Test Configuration]
        H --> I[Test Multiple Endpoints]
        I --> J[Protected Route Test]
        I --> K[Health Check Test]
        I --> L[Public Route Test]
    end
    
    subgraph "Protected Route Testing"
        J --> M[Request to /owners/new]
        M --> N[QueueIt Filter Intercepts]
        N --> O{User Has Valid Token?}
        O -->|No| P[302 Redirect to QueueIt]
        O -->|Yes| Q[200 OK - Allow Access]
        
        P --> R[Location: https://futuraforge.queue-it.net/]
        Q --> S[Access Granted]
    end
    
    subgraph "Health Check Testing"
        K --> T[Request to /integration/queueit/health]
        T --> U[QueueIt Health Endpoint]
        U --> V[200 OK - Service Healthy]
    end
    
    subgraph "Public Route Testing"
        L --> W[Request to /]
        W --> X[No QueueIt Filter]
        X --> Y[200 OK - Public Access]
    end
    
    subgraph "Response Analysis"
        R --> Z[K6 Processes 302]
        S --> AA[K6 Processes 200]
        V --> BB[K6 Processes 200]
        Y --> CC[K6 Processes 200]
        
        Z --> DD[Update Redirect Metrics]
        AA --> EE[Update Success Metrics]
        BB --> FF[Update Health Metrics]
        CC --> GG[Update Public Metrics]
    end
    
    style A fill:#e1f5fe
    style P fill:#fff3e0
    style GG fill:#c8e6c9
```

### **QueueIt Test Script Flow**

```javascript
// k6-scripts/queueit-test.js - QueueIt Integration Testing
import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.TARGET_URL || 'https://affluenceit.com';

export default function () {
    // 1. Test Protected Route (QueueIt Integration)
    const protectedResponse = http.get(`${BASE_URL}/owners/new`, {
        redirects: 0  // Don't follow redirects
    });
    
    check(protectedResponse, {
        'protected route returns 302': (r) => r.status === 302,
        'redirects to queue-it': (r) => r.headers.Location && r.headers.Location.includes('queue-it'),
    });
    
    // 2. Test Health Endpoint
    const healthResponse = http.get(`${BASE_URL}/integration/queueit/health`);
    
    check(healthResponse, {
        'health endpoint returns 200': (r) => r.status === 200,
    });
    
    // 3. Test Public Route
    const publicResponse = http.get(`${BASE_URL}/`);
    
    check(publicResponse, {
        'public route returns 200': (r) => r.status === 200,
    });
}
```

---

## 🚀 Test Execution Lifecycle

### **Complete Test Execution Flow**

```mermaid
flowchart TD
    subgraph "Test Initiation"
        A[User Runs Test] --> B{Test Type?}
        B -->|Simple| C[./run-10-vu-tasks.sh]
        B -->|Enhanced| D[./run-enhanced-queueit-test.sh]
    end
    
    subgraph "Task Deployment"
        C --> E[Launch 10 Tasks]
        D --> F[Launch Configurable Tasks]
        
        E --> G[Each Task: 1 VU, 60s duration]
        F --> H[Each Task: 1 VU, configurable duration]
    end
    
    subgraph "Container Startup"
        G --> I[Fargate Starts Container]
        H --> I
        I --> J[Docker Image: grafana/k6:latest]
        J --> K[Container Entry Point]
        K --> L[k6 run queueit-test.js]
    end
    
    subgraph "Environment Setup"
        L --> M[Set Environment Variables]
        M --> N[TARGET_URL=https://affluenceit.com]
        M --> O[TEST_SCRIPT=queueit-test.js]
        M --> P[AWS_REGION=us-east-1]
    end
    
    subgraph "K6 Initialization"
        P --> Q[Load Test Script]
        Q --> R[Test Configuration Applied]
        R --> S[VU Initialized]
    end
    
    subgraph "Test Execution"
        S --> T[VU Generates Requests]
        T --> U[Request to Target Application]
        U --> V[QueueIt Integration Check]
        V --> W[Response Processing]
        W --> X[Update Metrics]
        X --> Y[Continue Test Loop]
    end
    
    subgraph "Test Completion"
        Y --> Z[Duration Reached]
        Z --> AA[Generate Results]
        AA --> BB[Upload to S3]
        BB --> CC[Container Stops]
    end
    
    style A fill:#e1f5fe
    style V fill:#fff3e0
    style CC fill:#c8e6c9
```

### **Task Definition Configuration**

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
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/k6-single-vu-task",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "k6"
        }
      }
    }
  ]
}
```

---

## 📊 Results Processing Pipeline

### **Complete Results Processing Flow**

```mermaid
flowchart TD
    subgraph "Test Completion"
        A[K6 Test Finishes] --> B[Generate Results Files]
        B --> C[Test Metrics]
        B --> D[QueueIt Redirect Data]
        B --> E[Performance Data]
    end
    
    subgraph "Local Processing"
        C --> F[Upload Script Triggers]
        D --> F
        E --> F
        F --> G[Enhanced Test: S3 Upload]
        F --> H[Simple Test: CloudWatch Only]
    end
    
    subgraph "S3 Upload Process"
        G --> I[Create S3 Path]
        I --> J[s3://k6-load-test-results-786407478307/test-results/20250709-114704/]
        J --> K[Upload results.json]
        J --> L[Upload test-summary.json]
        J --> M[Upload k6.log]
    end
    
    subgraph "CloudWatch Integration"
        A --> N[Real-time Log Stream]
        N --> O[CloudWatch Logs]
        O --> P[/ecs/k6-single-vu-task]
        
        A --> Q[Performance Metrics]
        Q --> R[ECS Service Metrics]
        R --> S[CPU Utilization]
        R --> T[Memory Utilization]
    end
    
    subgraph "Monitoring & Analysis"
        S --> U[CloudWatch Dashboard]
        T --> U
        P --> U
        
        K --> V[Download Script]
        L --> V
        M --> V
        V --> W[Local Analysis]
        W --> X[Performance Reports]
        W --> Y[QueueIt Integration Analysis]
    end
    
    style A fill:#e1f5fe
    style Y fill:#c8e6c9
```

### **Results Analysis Flow**

```bash
#!/bin/bash
# scripts/download-logs.sh - Results Processing

# Download latest logs
aws logs get-log-events \
    --log-group-name "/ecs/k6-single-vu-task" \
    --log-stream-name "k6/k6-single-vu/$(aws logs describe-log-streams --log-group-name "/ecs/k6-single-vu-task" --order-by LastEventTime --descending --max-items 1 --query 'logStreams[0].logStreamName' --output text)" \
    --region us-east-1 \
    --output json > k6-scripts/test-logs/k6-latest-logs.json

# Analyze QueueIt integration results
jq '.events[] | select(.message | contains("302"))' k6-scripts/test-logs/k6-latest-logs.json
jq '.events[] | select(.message | contains("queue-it"))' k6-scripts/test-logs/k6-latest-logs.json
```

---

## 🌐 Network Traffic Flow

### **Detailed Network Flow with IP Diversity**

```mermaid
flowchart TD
    subgraph "K6 Tasks"
        A[Task 1: VU 1] --> B[HTTP Request]
        C[Task 2: VU 1] --> D[HTTP Request]
        E[Task 3: VU 1] --> F[HTTP Request]
        G[...]
        H[Task 10: VU 1] --> I[HTTP Request]
    end
    
    subgraph "Container Networks"
        B --> J[Container 1 Network Interface]
        D --> K[Container 2 Network Interface]
        F --> L[Container 3 Network Interface]
        I --> M[Container 10 Network Interface]
    end
    
    subgraph "VPC Network"
        J --> N[Private IP: 10.0.1.1]
        K --> O[Private IP: 10.0.1.2]
        L --> P[Private IP: 10.0.1.3]
        M --> Q[Private IP: 10.0.1.10]
        
        N --> R[Public IP: 3.x.x.1]
        O --> S[Public IP: 3.x.x.2]
        P --> T[Public IP: 3.x.x.3]
        Q --> U[Public IP: 3.x.x.10]
    end
    
    subgraph "Internet"
        R --> V[Internet Gateway]
        S --> V
        T --> V
        U --> V
        V --> W[Internet]
        W --> X[Target Application: https://affluenceit.com]
    end
    
    subgraph "QueueIt Integration"
        X --> Y[QueueIt Filter]
        Y --> Z{Protected Route?}
        Z -->|Yes| AA[Check QueueIt Token]
        Z -->|No| BB[Direct Access]
        
        AA --> CC{Valid Token?}
        CC -->|No| DD[302 Redirect to QueueIt]
        CC -->|Yes| EE[200 OK - Allow Access]
        BB --> FF[200 OK - Public Access]
    end
    
    subgraph "Response Path"
        DD --> GG[Response to K6]
        EE --> GG
        FF --> GG
        
        GG --> HH[Internet]
        HH --> II[Internet Gateway]
        II --> JJ[Public IPs]
        JJ --> KK[Private IPs]
        KK --> LL[Container Networks]
        LL --> MM[K6 Processes Response]
    end
    
    style A fill:#e1f5fe
    style DD fill:#fff3e0
    style MM fill:#c8e6c9
```

### **Network Configuration Details**

```terraform
# Network Configuration Flow
resource "aws_vpc" "k6_vpc" {
  cidr_block = "10.0.0.0/16"  # ← VPC CIDR
}

resource "aws_subnet" "k6_public_subnet" {
  vpc_id                  = aws_vpc.k6_vpc.id
  cidr_block              = "10.0.1.0/24"  # ← Subnet CIDR
  map_public_ip_on_launch = true  # ← Auto-assign public IP
}

resource "aws_internet_gateway" "k6_igw" {
  vpc_id = aws_vpc.k6_vpc.id  # ← Internet connectivity
}

resource "aws_route_table" "k6_public_rt" {
  vpc_id = aws_vpc.k6_vpc.id
  route {
    cidr_block = "0.0.0.0/0"  # ← All traffic to internet
    gateway_id = aws_internet_gateway.k6_igw.id
  }
}

# ECS Task Network Configuration
resource "aws_ecs_task_definition" "k6_task" {
  network_mode = "awsvpc"  # ← Each task gets ENI
  # ... other configuration
}
```

---

## 💾 Data Storage Flow

### **Complete Data Storage Architecture**

```mermaid
flowchart TD
    subgraph "Data Generation"
        A[K6 Test Execution] --> B[Generate Metrics]
        A --> C[Generate Logs]
        A --> D[Generate Results]
        A --> E[QueueIt Integration Data]
    end
    
    subgraph "Local Storage"
        B --> F[/results/results.json]
        C --> G[/results/k6.log]
        D --> H[/results/test-summary.json]
        E --> I[/results/queueit-analysis.json]
    end
    
    subgraph "S3 Storage"
        F --> J[S3 Upload Script]
        G --> J
        H --> J
        I --> J
        J --> K[S3 Bucket]
        K --> L[Organized Structure]
        L --> M[s3://k6-load-test-results-786407478307/test-results/20250709-114704/]
    end
    
    subgraph "CloudWatch Storage"
        A --> N[Real-time Log Stream]
        N --> O[CloudWatch Logs]
        O --> P[/ecs/k6-single-vu-task]
        
        A --> Q[Performance Metrics]
        Q --> R[CloudWatch Metrics]
        R --> S[ECS Service Metrics]
    end
    
    subgraph "Data Access"
        M --> T[Download Script]
        T --> U[Local Analysis]
        U --> V[Performance Reports]
        U --> W[QueueIt Integration Reports]
        
        P --> X[CloudWatch Dashboard]
        S --> X
    end
    
    style A fill:#e1f5fe
    style W fill:#c8e6c9
    style X fill:#fff3e0
```

### **S3 Storage Structure**

```
s3://k6-load-test-results-786407478307/
├── test-results/
│   ├── 20250709-114704/
│   │   ├── results.json              # Detailed k6 metrics
│   │   ├── test-summary.json         # Test metadata
│   │   ├── k6.log                   # Application logs
│   │   └── queueit-analysis.json    # QueueIt integration data
│   └── 20250709-120000/
│       ├── results.json
│       ├── test-summary.json
│       ├── k6.log
│       └── queueit-analysis.json
```

---

## 📊 Monitoring Flow

### **Complete Monitoring Architecture**

```mermaid
flowchart TD
    subgraph "Data Sources"
        A[K6 Container] --> B[Application Logs]
        A --> C[Performance Metrics]
        A --> D[Test Results]
        A --> E[QueueIt Integration Data]
    end
    
    subgraph "CloudWatch Integration"
        B --> F[CloudWatch Logs]
        C --> G[CloudWatch Metrics]
        D --> H[S3 Storage]
        E --> I[QueueIt Metrics]
        
        F --> J[Real-time Log Stream]
        G --> K[ECS Service Metrics]
        H --> L[Persistent Storage]
        I --> M[QueueIt Dashboard]
    end
    
    subgraph "Monitoring Components"
        J --> N[CloudWatch Dashboard]
        K --> N
        L --> O[Download Script]
        M --> P[QueueIt Integration Dashboard]
        
        N --> Q[Real-time Monitoring]
        O --> R[Offline Analysis]
        P --> S[QueueIt Performance]
    end
    
    subgraph "Alerting & Analysis"
        Q --> T[Performance Alerts]
        R --> U[Performance Reports]
        S --> V[QueueIt Integration Reports]
        
        T --> W[Email Notifications]
        U --> X[Trend Analysis]
        V --> Y[QueueIt Health Monitoring]
    end
    
    style A fill:#e1f5fe
    style Q fill:#c8e6c9
    style Y fill:#fff3e0
```

### **Monitoring Configuration**

```terraform
# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "k6_logs" {
  name              = "/ecs/k6-single-vu-task"
  retention_in_days = 7
}

# ECS Task Log Configuration
container_definitions = [
  {
    name = "k6"
    image = "grafana/k6:latest"
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.k6_logs.name
        awslogs-region        = "us-east-1"
        awslogs-stream-prefix = "k6"
      }
    }
  }
]

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "k6_dashboard" {
  dashboard_name = "k6-load-test-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization"],
            ["AWS/ECS", "MemoryUtilization"]
          ]
        }
      },
      {
        type = "log"
        properties = {
          query = "SOURCE '/ecs/k6-single-vu-task' | fields @timestamp, @message | filter @message like /302/ or @message like /queue-it/"
        }
      }
    ]
  })
}
```

---

## 🎯 Summary

This flowchart document provides:

### **Key Flow Components**
1. **IP Diversity**: Multiple tasks with unique AWS public IPs
2. **QueueIt Integration**: Complete QueueIt testing flow
3. **Test Execution**: Lifecycle from task launch to completion
4. **Network Flow**: Detailed traffic routing with IP diversity
5. **Results Processing**: From local generation to S3 storage
6. **Monitoring**: Real-time metrics and log collection

### **Fargate Role in Each Flow**
- **Resource Allocation**: CPU, memory, and network resources
- **Network Integration**: awsvpc mode with public IP assignment
- **Task Management**: Start, stop, and monitor container execution
- **Logging**: Integration with CloudWatch for real-time monitoring

### **QueueIt Integration Benefits**
- ✅ **Protected Route Testing**: Tests `/owners/new` with QueueIt redirects
- ✅ **Health Check Validation**: Monitors QueueIt health endpoint
- ✅ **Public Route Verification**: Ensures public endpoints remain accessible
- ✅ **IP Diversity**: Each task tests with unique IP address
- ✅ **Realistic Simulation**: Each task represents unique user

### **Benefits of This Architecture**
- ✅ **Natural IP Diversity**: Each task gets unique AWS public IP
- ✅ **QueueIt Integration**: Comprehensive QueueIt testing capabilities
- ✅ **Scalable Design**: Easy to add more tasks or modify flows
- ✅ **Comprehensive Monitoring**: Multiple data collection points
- ✅ **Cost Optimization**: Pay only for actual execution time
- ✅ **Security**: Proper network isolation and access controls

The flowcharts demonstrate how AWS Fargate seamlessly integrates with QueueIt and other AWS services to provide a complete, serverless load testing solution with IP diversity. 