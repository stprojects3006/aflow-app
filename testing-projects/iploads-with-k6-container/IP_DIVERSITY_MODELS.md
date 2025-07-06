# 🌐 IP Diversity Models for Load Testing

## 📋 Table of Contents

1. [Overview](#overview)
2. [Current Architecture](#current-architecture)
3. [Model 1: Multiple ECS Tasks](#model-1-multiple-ecs-tasks)
4. [Model 2: Container IP Rotation](#model-2-container-ip-rotation)
5. [Model 3: Proxy/VPN Integration](#model-3-proxyvpn-integration)
6. [Model 4: AWS NAT Gateway with Multiple IPs](#model-4-aws-nat-gateway-with-multiple-ips)
7. [Model 5: Multi-Region Deployment](#model-5-multi-region-deployment)
8. [Detailed Comparison: Container IP Rotation vs Multiple Tasks](#detailed-comparison)
9. [Implementation Guidelines](#implementation-guidelines)
10. [Cost Analysis](#cost-analysis)
11. [Recommendations](#recommendations)

---

## 🎯 Overview

This document outlines various approaches to achieve IP diversity in k6 load testing scenarios. IP diversity is crucial for:
- **Rate Limiting Bypass**: Target applications may limit requests per IP
- **Geographic Distribution**: Simulate users from different locations
- **Load Balancer Testing**: Test how load balancers handle diverse IPs
- **Security Testing**: Test IP-based security rules
- **Realistic Analytics**: More authentic traffic patterns

---

## 🔍 Current Architecture

### **Single Task Model (Current Implementation)**
```
ECS Task (Container)
├── Public IP: 3.x.x.x (assigned by AWS)
├── VU 1 → Uses container's IP
├── VU 2 → Uses container's IP  
├── VU 3 → Uses container's IP
└── VU N → Uses container's IP
```

**Characteristics:**
- ❌ All VUs share the same public IP
- ❌ Limited IP diversity
- ❌ Potential rate limiting issues
- ✅ Simple implementation
- ✅ Cost-effective for basic testing

---

## 🚀 Model 1: Multiple ECS Tasks

### **Architecture**
```
Task 1: 10 VUs → Public IP: 3.1.1.1
Task 2: 10 VUs → Public IP: 3.1.1.2  
Task 3: 10 VUs → Public IP: 3.1.1.3
...
Task N: 10 VUs → Public IP: 3.1.1.N
```

### **Implementation**
```bash
# Deploy multiple tasks instead of one
for i in {1..10}; do
  aws ecs run-task \
    --cluster k6-cluster \
    --task-definition k6-task \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[subnet-123],securityGroups=[sg-123],assignPublicIp=ENABLED}"
done
```

### **Benefits**
- ✅ **Natural IP diversity** (AWS assigns different IPs)
- ✅ **Easy to implement** (modify task count)
- ✅ **Cost effective** (same total resources)
- ✅ **Scalable** (add more tasks)
- ✅ **No external dependencies**

### **Limitations**
- ❌ **Limited IP pool** (AWS public IPs in subnet)
- ❌ **No geographic diversity**
- ❌ **IPs may be sequential**

### **Use Cases**
- Basic IP diversity requirements
- Cost-sensitive projects
- Quick implementation needs
- Testing rate limiting scenarios

---

## 🔄 Model 2: Container IP Rotation

### **Architecture**
```
Single Container with IP Rotation
├── VU 1 → IP: 1.1.1.1 (via proxy rotation)
├── VU 2 → IP: 1.1.1.2 (via proxy rotation)
├── VU 3 → IP: 1.1.1.3 (via proxy rotation)
└── VU N → IP: 1.1.1.N (via proxy rotation)
```

### **Implementation**

#### **Enhanced Dockerfile**
```dockerfile
FROM grafana/k6:latest

# Install proxy tools
RUN apk add --no-cache curl jq aws-cli

# IP rotation script
COPY rotate-ip.sh /scripts/
RUN chmod +x /scripts/rotate-ip.sh

# Enhanced k6 script
COPY k6-scripts/ip-rotation-test.js /scripts/
```

#### **IP Rotation Script**
```bash
#!/bin/bash
# rotate-ip.sh

# Function to rotate IP for each VU
rotate_ip() {
    local vu_id=$1
    
    # Get proxy IP from rotation service
    PROXY_IP=$(curl -s "https://proxy-service.com/rotate?vu=$vu_id")
    
    # Configure proxy for this VU
    export HTTP_PROXY="http://$PROXY_IP:8080"
    export HTTPS_PROXY="http://$PROXY_IP:8080"
    
    echo "VU $vu_id using IP: $PROXY_IP"
}

# Export function for k6 to use
export -f rotate_ip
```

#### **Enhanced k6 Script**
```javascript
// ip-rotation-test.js
import http from 'k6/http';
import { check } from 'k6';

// IP rotation configuration
const IP_ROTATION_ENABLED = __ENV.IP_ROTATION_ENABLED === 'true';
const PROXY_SERVICE_URL = __ENV.PROXY_SERVICE_URL || 'http://proxy-service:8080';

// Setup function for IP rotation
export function setup() {
    if (IP_ROTATION_ENABLED) {
        console.log(`Setting up IP rotation for VU ${__VU}`);
        // Configure proxy for this VU
        const proxyConfig = {
            proxy: `${PROXY_SERVICE_URL}/vu/${__VU}`
        };
        return { proxyConfig };
    }
    return {};
}

// Main test function
export default function (data) {
    const options = {};
    
    if (IP_ROTATION_ENABLED && data.proxyConfig) {
        options.proxy = data.proxyConfig.proxy;
    }
    
    const response = http.get('https://affluenceit.com/', options);
    
    check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 2000ms': (r) => r.timings.duration < 2000,
    });
}

// Teardown function
export function teardown(data) {
    if (IP_ROTATION_ENABLED) {
        console.log(`Cleaning up IP rotation for VU ${__VU}`);
    }
}
```

### **Benefits**
- ✅ **True IP diversity** (each VU gets unique IP)
- ✅ **Single container** (easier management)
- ✅ **Dynamic IP rotation** (can change during test)
- ✅ **Geographic distribution** (if proxy service supports)
- ✅ **Bypass rate limits** effectively

### **Limitations**
- ❌ **Complex implementation**
- ❌ **External dependency** (proxy service)
- ❌ **Additional latency** (proxy hop)
- ❌ **Cost of proxy service**

### **Use Cases**
- High IP diversity requirements
- Geographic distribution needs
- Advanced rate limiting scenarios
- Security testing with IP rotation

---

## 🌍 Model 3: Proxy/VPN Integration

### **Architecture**
```
k6 Container
├── VU 1 → Proxy 1 → IP: 1.1.1.1
├── VU 2 → Proxy 2 → IP: 1.1.1.2
├── VU 3 → Proxy 3 → IP: 1.1.1.3
└── VU N → Proxy N → IP: 1.1.1.N
```

### **Implementation Options**

#### **Option A: Rotating Proxy Services**
```javascript
// k6 script with proxy rotation
import http from 'k6/http';

const PROXY_LIST = [
    'http://proxy1.service:8080',
    'http://proxy2.service:8080',
    'http://proxy3.service:8080',
    // ... more proxies
];

export default function () {
    // Rotate proxy for each request
    const proxyIndex = __VU % PROXY_LIST.length;
    const proxyUrl = PROXY_LIST[proxyIndex];
    
    const response = http.get('https://affluenceit.com/', {
        proxy: proxyUrl
    });
}
```

#### **Option B: VPN Integration**
```dockerfile
# Dockerfile with VPN support
FROM grafana/k6:latest

# Install VPN client
RUN apk add --no-cache openvpn

# VPN configuration
COPY vpn-config/ /etc/openvpn/
COPY vpn-connect.sh /scripts/
RUN chmod +x /scripts/vpn-connect.sh

# Start VPN before k6
CMD ["/scripts/vpn-connect.sh"]
```

### **Benefits**
- ✅ **True IP diversity**
- ✅ **Geographic distribution**
- ✅ **Bypass rate limits**
- ✅ **Professional proxy services**

### **Limitations**
- ❌ **Additional costs** ($50-200/month)
- ❌ **Complexity in setup**
- ❌ **Potential reliability issues**
- ❌ **Legal considerations**

---

## 🏗️ Model 4: AWS NAT Gateway with Multiple IPs

### **Architecture**
```
Multiple NAT Gateways
├── NAT Gateway 1 → EIP: 1.1.1.1
├── NAT Gateway 2 → EIP: 1.1.1.2
├── NAT Gateway 3 → EIP: 1.1.1.3
└── NAT Gateway N → EIP: 1.1.1.N

ECS Tasks route through different NATs
```

### **Implementation**
```terraform
# Multiple NAT Gateways
resource "aws_eip" "nat_1" {
  domain = "vpc"
  tags = {
    Name = "nat-eip-1"
  }
}

resource "aws_eip" "nat_2" {
  domain = "vpc"
  tags = {
    Name = "nat-eip-2"
  }
}

resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_subnet.id
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_subnet.id
}

# Route tables for different tasks
resource "aws_route_table" "task_route_1" {
  vpc_id = aws_vpc.k6_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }
}

resource "aws_route_table" "task_route_2" {
  vpc_id = aws_vpc.k6_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }
}
```

### **Benefits**
- ✅ **AWS-native solution**
- ✅ **Predictable IP ranges**
- ✅ **No external dependencies**
- ✅ **High reliability**

### **Limitations**
- ❌ **NAT Gateway costs** ($0.045/hour per gateway)
- ❌ **EIP costs** ($0.005/hour per IP)
- ❌ **Complex routing setup**
- ❌ **Limited scalability**

---

## 🌎 Model 5: Multi-Region Deployment

### **Architecture**
```
Region: us-east-1 → IPs: 3.x.x.x range
Region: us-west-2 → IPs: 4.x.x.x range  
Region: eu-west-1 → IPs: 5.x.x.x range
Region: ap-southeast-1 → IPs: 6.x.x.x range
```

### **Implementation**
```bash
# Deploy to multiple regions
aws ecs run-task --cluster k6-cluster-us-east-1
aws ecs run-task --cluster k6-cluster-us-west-2
aws ecs run-task --cluster k6-cluster-eu-west-1
aws ecs run-task --cluster k6-cluster-ap-southeast-1
```

### **Benefits**
- ✅ **Geographic diversity**
- ✅ **Natural IP diversity**
- ✅ **Latency testing**
- ✅ **Global load testing**

### **Limitations**
- ❌ **Higher costs** (multiple regions)
- ❌ **Complex management**
- ❌ **Data transfer costs**
- ❌ **Compliance considerations**

---

## 🔄 Detailed Comparison: Container IP Rotation vs Multiple Tasks

### **Architecture Differences**

| Aspect | **Container IP Rotation** | **Multiple Tasks** |
|--------|---------------------------|-------------------|
| **Container Count** | 1 container | N containers |
| **IP Assignment** | Dynamic per VU | Static per container |
| **Resource Sharing** | Shared resources | Isolated resources |
| **Network Model** | Single network namespace | Multiple network namespaces |

### **Technical Implementation**

#### **Container IP Rotation**
```javascript
// Single container with IP rotation
export default function () {
    // Each VU gets different IP via proxy
    const proxyUrl = `http://proxy-${__VU}.service:8080`;
    
    const response = http.get('https://affluenceit.com/', {
        proxy: proxyUrl
    });
}
```

#### **Multiple Tasks**
```bash
# Multiple containers, each with unique IP
for i in {1..10}; do
    aws ecs run-task \
        --cluster k6-cluster \
        --task-definition k6-task \
        --launch-type FARGATE
done
```

### **Resource Utilization**

#### **Container IP Rotation**
```
Single Container (2 vCPU, 4GB RAM)
├── VU 1-10 → Shared CPU/Memory
├── VU 11-20 → Shared CPU/Memory
└── VU 21-30 → Shared CPU/Memory
```

#### **Multiple Tasks**
```
Task 1 (1 vCPU, 2GB RAM) → VUs 1-10
Task 2 (1 vCPU, 2GB RAM) → VUs 11-20
Task 3 (1 vCPU, 2GB RAM) → VUs 21-30
```

### **IP Diversity Patterns**

#### **Container IP Rotation**
- **Dynamic IPs**: Can change during test execution
- **Geographic Distribution**: Possible with proxy services
- **High Diversity**: Each VU can have unique IP
- **Flexible Rotation**: Can rotate IPs based on conditions

#### **Multiple Tasks**
- **Static IPs**: Fixed for duration of task
- **AWS IP Pool**: Limited to available public IPs
- **Sequential IPs**: May be in same subnet range
- **Predictable**: IPs assigned by AWS

### **Performance Characteristics**

| Metric | **Container IP Rotation** | **Multiple Tasks** |
|--------|---------------------------|-------------------|
| **Latency** | Higher (proxy hop) | Lower (direct) |
| **Throughput** | Lower (proxy bottleneck) | Higher (direct) |
| **Reliability** | Depends on proxy service | High (AWS managed) |
| **Scalability** | Limited by proxy capacity | Limited by AWS limits |

### **Cost Analysis**

#### **Container IP Rotation**
```
Base Cost: ECS Task (same as current)
+ Proxy Service: $50-200/month
+ Additional Complexity: Development time
= Higher total cost
```

#### **Multiple Tasks**
```
Base Cost: Multiple ECS Tasks
+ No additional services
+ Minimal complexity
= Lower total cost
```

### **Use Case Scenarios**

#### **Container IP Rotation Best For:**
- ✅ **High IP diversity requirements** (100+ unique IPs)
- ✅ **Geographic distribution needs**
- ✅ **Advanced rate limiting scenarios**
- ✅ **Security testing with IP rotation**
- ✅ **Professional load testing services**

#### **Multiple Tasks Best For:**
- ✅ **Basic IP diversity** (5-20 unique IPs)
- ✅ **Cost-sensitive projects**
- ✅ **Quick implementation**
- ✅ **AWS-native solutions**
- ✅ **Simple rate limiting testing**

---

## 🛠️ Implementation Guidelines

### **Phase 1: Start with Multiple Tasks**
```bash
# Quick implementation
for i in {1..5}; do
    aws ecs run-task \
        --cluster k6-cluster \
        --task-definition k6-task \
        --launch-type FARGATE
done
```

### **Phase 2: Evaluate IP Rotation Needs**
```javascript
// Test IP rotation with proxy service
export const options = {
    scenarios: {
        ip_rotation_test: {
            executor: 'per-vu-iterations',
            vus: 10,
            iterations: 100,
            exec: 'ipRotationTest'
        }
    }
};
```

### **Phase 3: Advanced Solutions**
- **Geographic distribution**: Multi-region deployment
- **High IP diversity**: Proxy/VPN integration
- **Enterprise needs**: NAT Gateway with multiple IPs

---

## 💰 Cost Analysis

| Model | **Setup Cost** | **Runtime Cost** | **Complexity** | **IP Diversity** |
|-------|----------------|------------------|----------------|------------------|
| **Multiple Tasks** | $0 | +$0 | Low | Medium (5-20 IPs) |
| **Container IP Rotation** | $0 | +$50-200/month | High | High (100+ IPs) |
| **Proxy Services** | $0 | +$50-200/month | Medium | High (100+ IPs) |
| **NAT Gateways** | $0 | +$50-100/month | Medium | Medium (10-50 IPs) |
| **Multi-Region** | $0 | +$20-50/month | High | High (20-100 IPs) |

---

## 🎯 Recommendations

### **For Basic Load Testing**
**Recommendation**: Start with **Multiple ECS Tasks**
- ✅ **Zero additional cost**
- ✅ **Immediate implementation**
- ✅ **5-10 unique IPs**
- ✅ **Easy to scale**

### **For Advanced Load Testing**
**Recommendation**: **Container IP Rotation** with proxy service
- ✅ **High IP diversity**
- ✅ **Geographic distribution**
- ✅ **Professional-grade testing**
- ⚠️ **Higher cost and complexity**

### **For Enterprise Load Testing**
**Recommendation**: **Multi-Region** + **NAT Gateways**
- ✅ **Maximum IP diversity**
- ✅ **Geographic distribution**
- ✅ **AWS-native solution**
- ⚠️ **Higher cost and complexity**

### **Implementation Priority**
1. **Start Simple**: Multiple ECS Tasks
2. **Evaluate Needs**: Monitor rate limiting and IP diversity requirements
3. **Scale Up**: Add proxy services or multi-region deployment
4. **Optimize**: Fine-tune based on specific requirements

---

## 📊 Summary

The choice between **Container IP Rotation** and **Multiple Tasks** depends on:

| Factor | **Multiple Tasks** | **Container IP Rotation** |
|--------|-------------------|---------------------------|
| **IP Diversity** | Medium (5-20 IPs) | High (100+ IPs) |
| **Cost** | Low | High |
| **Complexity** | Low | High |
| **Performance** | High | Medium |
| **Reliability** | High | Medium |
| **Geographic Distribution** | No | Yes |

**For most load testing scenarios, start with Multiple Tasks and scale to Container IP Rotation only when high IP diversity is required.**

---

*This document provides a comprehensive guide for implementing IP diversity in load testing scenarios. Choose the model that best fits your specific requirements, budget, and technical capabilities.* 