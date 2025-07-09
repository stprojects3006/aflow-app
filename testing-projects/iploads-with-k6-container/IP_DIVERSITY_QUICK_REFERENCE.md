# 🚀 IP Diversity Quick Reference Guide

A comprehensive guide for implementing IP diversity in k6 load testing with AWS ECS, focusing on QueueIt integration testing.

## 🔄 Container IP Rotation vs Multiple Tasks: Key Differences

### **📊 Quick Comparison Table**

| Aspect | **Container IP Rotation** | **Multiple Tasks** |
|--------|---------------------------|-------------------|
| **Architecture** | Single container, multiple VUs | Multiple containers, fewer VUs each |
| **IP Assignment** | Dynamic per VU | Static per container |
| **Resource Model** | Shared CPU/Memory | Isolated CPU/Memory |
| **Network Model** | Single network namespace | Multiple network namespaces |
| **IP Diversity** | High (100+ unique IPs) | Medium (5-20 unique IPs) |
| **Cost** | High (+$50-200/month) | Low (no additional cost) |
| **Complexity** | High | Low |
| **Performance** | Medium (proxy latency) | High (direct connection) |
| **Reliability** | Medium (depends on proxy) | High (AWS managed) |
| **QueueIt Testing** | Complex session management | Simple, independent sessions |

---

## 🎯 When to Use Each Model

### **Use Container IP Rotation When:** [Shares the same cookie to bypass the waiting room after first request]
- ✅ **High IP diversity required** (100+ unique IPs)
- ✅ **Geographic distribution needed**
- ✅ **Advanced rate limiting scenarios**
- ✅ **Professional load testing services**
- ✅ **Security testing with IP rotation**
- ✅ **Budget allows for proxy services**

### **Use Multiple Tasks When:** [Helps to skip the cookies based checks for queueit]
- ✅ **Basic IP diversity sufficient** (5-20 unique IPs)
- ✅ **Cost-sensitive projects**
- ✅ **Quick implementation needed**
- ✅ **AWS-native solution preferred**
- ✅ **Simple rate limiting testing**
- ✅ **Minimal complexity desired**
- ✅ **QueueIt integration testing**
- ✅ **Independent session testing**

---

## 💰 Cost Comparison

| Model | **Setup Cost** | **Monthly Runtime** | **Total Annual Cost** |
|-------|----------------|---------------------|----------------------|
| **Multiple Tasks** | $0 | +$0 | $0 additional |
| **Container IP Rotation** | $0 | +$50-200 | $600-2,400 additional |
| **Proxy Services** | $0 | +$50-200 | $600-2,400 additional |
| **NAT Gateways** | $0 | +$50-100 | $600-1,200 additional |
| **Multi-Region** | $0 | +$20-50 | $240-600 additional |

---

## 🛠️ Implementation Complexity

### **Multiple Tasks (Easy) - Current Implementation**
```bash
# Simple script to create multiple tasks
./run-10-vu-tasks.sh

# Or manually
for i in {1..10}; do
    aws ecs run-task \
        --cluster k6-load-test-cluster \
        --task-definition k6-single-vu-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-097cbe067e542243a],securityGroups=[sg-0737d6eb4011e161c],assignPublicIp=ENABLED}" \
        --region us-east-1
done
```

**Time to Implement**: 1-2 hours
**Skills Required**: Basic AWS CLI knowledge

### **Container IP Rotation (Complex)**
```javascript
// Requires proxy service integration
export function setup() {
    const proxyConfig = {
        proxy: `${PROXY_SERVICE_URL}/vu/${__VU}`
    };
    return { proxyConfig };
}
```

**Time to Implement**: 1-2 weeks
**Skills Required**: Advanced networking, proxy services, k6 scripting

---

## 📈 Performance Characteristics

### **Multiple Tasks**
- **Latency**: Low (direct connection)
- **Throughput**: High (no proxy bottleneck)
- **Reliability**: High (AWS managed)
- **Scalability**: Limited by AWS task limits
- **QueueIt Testing**: Excellent (independent sessions)

### **Container IP Rotation**
- **Latency**: Medium (proxy hop)
- **Throughput**: Medium (proxy bottleneck)
- **Reliability**: Medium (depends on proxy service)
- **Scalability**: Limited by proxy service capacity
- **QueueIt Testing**: Complex (shared session management)

---

## 🎯 Decision Matrix

| Requirement | **Multiple Tasks** | **Container IP Rotation** |
|-------------|-------------------|---------------------------|
| **5-20 unique IPs** | ✅ **Perfect** | ⚠️ **Overkill** |
| **100+ unique IPs** | ❌ **Insufficient** | ✅ **Perfect** |
| **Geographic distribution** | ❌ **Not possible** | ✅ **Possible** |
| **Cost-sensitive** | ✅ **Best choice** | ❌ **Expensive** |
| **Quick implementation** | ✅ **Best choice** | ❌ **Complex** |
| **Professional testing** | ⚠️ **Basic** | ✅ **Advanced** |
| **QueueIt integration** | ✅ **Excellent** | ⚠️ **Complex** |

---

## 🚀 Current Implementation: Multiple Tasks

### **Project Structure**
```
iploads-with-k6-container/
├── run-10-vu-tasks.sh              # Simple IP diversity test
├── run-enhanced-queueit-test.sh    # Enhanced QueueIt test
├── task-def-single-vu-owners.json  # ECS task definition
├── config/test-config.json         # Test configuration
└── k6-scripts/queueit-test.js      # QueueIt test script
```

### **Key Features**
- **10 separate ECS tasks** with 1 VU each
- **Each task gets unique AWS public IP**
- **Natural IP diversity** without proxy configuration
- **Independent QueueIt sessions** per task
- **Simple deployment** and monitoring

### **Test Configuration**
```json
{
  "aws": {
    "cluster": {
      "name": "k6-load-test-cluster",
      "arn": "arn:aws:ecs:us-east-1:786407478307:cluster/k6-load-test-cluster"
    },
    "network": {
      "subnet_id": "subnet-097cbe067e542243a",
      "security_group_id": "sg-0737d6eb4011e161c"
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

---

## 🎯 Recommended Implementation Path

### **Phase 1: Start Simple (Current)**
```bash
# Implement multiple tasks first
./run-10-vu-tasks.sh
```

**Benefits:**
- Immediate IP diversity (10 unique IPs)
- Zero additional cost
- Simple implementation
- Perfect for QueueIt testing

### **Phase 2: Evaluate Needs**
- Monitor rate limiting issues
- Assess IP diversity requirements
- Measure test effectiveness
- Review QueueIt integration performance

### **Phase 3: Scale Up (If Needed)**
- Add proxy service integration
- Implement container IP rotation
- Consider multi-region deployment

---

## 🔍 Key Technical Differences

### **Network Architecture**

#### **Multiple Tasks (Current Implementation)**
```
Task 1 (ENI 1) → Public IP: 3.1.1.1 → VU 1
Task 2 (ENI 2) → Public IP: 3.1.1.2 → VU 1
Task 3 (ENI 3) → Public IP: 3.1.1.3 → VU 1
...
Task 10 (ENI 10) → Public IP: 3.1.1.10 → VU 1
```

#### **Container IP Rotation (Future Option)**
```
Single Container (ENI 1) → Public IP: 3.1.1.1
├── VU 1 → Proxy 1 → IP: 1.1.1.1
├── VU 2 → Proxy 2 → IP: 1.1.1.2
└── VU 3 → Proxy 3 → IP: 1.1.1.3
```

### **Resource Allocation**

#### **Multiple Tasks (Current)**
```
Task 1: 256 CPU, 512MB RAM → 1 VU
Task 2: 256 CPU, 512MB RAM → 1 VU
Task 3: 256 CPU, 512MB RAM → 1 VU
...
Task 10: 256 CPU, 512MB RAM → 1 VU
```

#### **Container IP Rotation (Future)**
```
Single Task: 1024 CPU, 2GB RAM → 10 VUs
├── VU 1-5: Shared CPU/Memory
└── VU 6-10: Shared CPU/Memory
```

---

## 📋 Checklist for Choosing

### **Choose Multiple Tasks If:**
- [ ] Budget is limited
- [ ] Quick implementation needed
- [ ] 5-20 unique IPs sufficient
- [ ] AWS-native solution preferred
- [ ] Minimal complexity desired
- [ ] QueueIt integration testing required
- [ ] Independent session testing needed

### **Choose Container IP Rotation If:**
- [ ] High IP diversity required (100+ IPs)
- [ ] Geographic distribution needed
- [ ] Advanced rate limiting scenarios
- [ ] Professional testing requirements
- [ ] Budget allows for proxy services
- [ ] Complex session management acceptable

---

## 🎯 QueueIt Integration Benefits

### **Multiple Tasks Advantages for QueueIt:**
- ✅ **Independent sessions** - Each task has unique cookies
- ✅ **Natural IP diversity** - Each task gets unique AWS IP
- ✅ **Simple testing** - No proxy configuration needed
- ✅ **Realistic simulation** - Each task represents unique user
- ✅ **Easy monitoring** - Clear task-to-IP mapping

### **Test Scenarios Supported:**
1. **Protected Route Testing** - `/owners/new` with 302 redirects
2. **Health Check Validation** - `/integration/queueit/health`
3. **Public Route Verification** - `/` without QueueIt
4. **IP Diversity Validation** - Multiple unique IP sources

---

## 🚀 Quick Start Commands

### **Run Simple IP Diversity Test**
```bash
# Run 10 separate tasks with 1 VU each
./run-10-vu-tasks.sh
```

### **Run Enhanced QueueIt Test**
```bash
# Run comprehensive test with monitoring
./run-enhanced-queueit-test.sh
```

### **Monitor Tests**
```bash
# Download latest logs
./scripts/download-logs.sh

# View CloudWatch logs
aws logs tail /ecs/k6-single-vu-task --follow --region us-east-1
```

### **Stop Tests**
```bash
# Stop all running tasks
aws ecs list-tasks --cluster k6-load-test-cluster --region us-east-1 | \
  jq -r '.taskArns[]' | \
  xargs -I {} aws ecs stop-task --cluster k6-load-test-cluster --task {} --region us-east-1
```

---

## 🎯 Final Recommendation

**For QueueIt integration testing:**
1. **Start with Multiple Tasks** - Simple, cost-effective, immediate results
2. **Monitor and evaluate** - Assess IP diversity needs
3. **Scale to Container IP Rotation** - Only if high IP diversity is required

**Current Implementation Benefits:**
- ✅ **10 unique IP addresses** at zero additional cost
- ✅ **Perfect for QueueIt testing** with independent sessions
- ✅ **Simple deployment** and monitoring
- ✅ **AWS-native solution** with high reliability
- ✅ **Immediate results** without complex configuration

**Remember**: Multiple Tasks can provide 5-20 unique IPs at zero additional cost, which is sufficient for most QueueIt integration testing scenarios! 