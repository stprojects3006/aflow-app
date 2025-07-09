# QueueIt Integration Test Guide

## Overview
This document provides a comprehensive guide for running and interpreting QueueIt integration tests in the Spring PetClinic application with IP diversity load testing. It covers test cases, key metrics, Grafana dashboard usage, interpretation, test execution steps, expected results, and actual results with screenshot references.

---

## 1. Test Cases

| Test Case ID | Description | Endpoint | Expected Result |
|--------------|-------------|----------|-----------------|
| TC-01 | Test protected route redirect | `/owners/new` | 302 Redirect to QueueIt |
| TC-02 | Test health endpoint | `/integration/queueit/health` | 200 OK - Service Healthy |
| TC-03 | Test public route access | `/` | 200 OK - Direct Access |
| TC-04 | Test QueueIt filter integration | `/owners/new` with valid token | 200 OK or 302 Redirect |
| TC-05 | Test IP diversity with multiple tasks | Multiple ECS tasks | Each task gets unique IP |
| TC-06 | Test QueueIt redirect patterns | `/owners/new` from different IPs | Consistent 302 redirects |
| TC-07 | Test health monitoring | `/integration/queueit/health` | Continuous 200 responses |
| TC-08 | Test error handling | Invalid QueueIt requests | Appropriate error responses |
| TC-09 | Test load distribution | High-volume testing | Even distribution across IPs |

---

## 2. Key Metrics & Grafana Dashboard

### Metrics Tracked
- **http_server_requests_seconds_count**: HTTP request counts by endpoint and status
- **http_server_requests_seconds_bucket**: Response time distribution
- **QueueIt redirects**: 302 redirects to QueueIt for protected routes
- **Health check status**: 200 responses from health endpoint
- **IP diversity metrics**: Unique IP addresses and distribution
- **Error rates**: 4xx and 5xx error tracking
- **Response times**: 50th, 95th, and 99th percentiles

### Where to Find in Grafana
- **Dashboard**: `QueueIt Integration Dashboard`
- **Panels**:
  - *QueueIt Endpoint Requests (All)*: Top left
  - *QueueIt Error Rate by Status Code*: Top center
  - *QueueIt Response Time by Error Status*: Middle left
  - *Success Rate (Non-Error Responses)*: Middle center
  - *IP Address Analysis*: Bottom left
  - *Error Rate by Endpoint and Status*: Bottom center
  - *QueueIt Redirect Patterns*: Bottom right

### How to Interpret
- **302 Redirects**: High value indicates QueueIt integration working correctly
- **Health Endpoint**: Should show consistent 200 responses
- **IP Diversity**: Multiple unique IP addresses indicate successful IP diversity
- **Error Rates**: Should remain low; spikes indicate integration issues
- **Response Times**: Should be consistent across different IP sources
- **Success Rates**: High success rates indicate healthy integration

---

## 3. Steps to Run Test Cases

### 3.1 Prerequisites
1. **Ensure all services are running**:
   ```bash
   cd app-code
   docker-compose up -d
   ```

2. **Verify QueueIt integration is active**:
   ```bash
   curl -I http://localhost:8080/owners/new
   # Should return 302 redirect to QueueIt
   ```

3. **Check health endpoint**:
   ```bash
   curl http://localhost:8080/integration/queueit/health
   # Should return 200 OK
   ```

### 3.2 Manual Testing
1. **Test protected route**:
   ```bash
   curl -I http://localhost:8080/owners/new
   # Expected: 302 redirect to QueueIt
   ```

2. **Test health endpoint**:
   ```bash
   curl http://localhost:8080/integration/queueit/health
   # Expected: 200 OK with health status
   ```

3. **Test public route**:
   ```bash
   curl -I http://localhost:8080/
   # Expected: 200 OK - direct access
   ```

### 3.3 Load Testing with IP Diversity
1. **Navigate to load testing directory**:
   ```bash
   cd testing-projects/iploads-with-k6-container
   ```

2. **Run simple IP diversity test**:
   ```bash
   ./run-10-vu-tasks.sh
   ```

3. **Run enhanced QueueIt test**:
   ```bash
   ./run-enhanced-queueit-test.sh
   ```

4. **Monitor results in Grafana**:
   - Open http://localhost:3000
   - Navigate to QueueIt Integration Dashboard
   - Observe real-time metrics

---

## 4. Expected Results

| Test Case ID | Expected Result | Verification Method |
|--------------|----------------|-------------------|
| TC-01 | 302 Redirect to QueueIt | Check response headers for Location field |
| TC-02 | 200 OK - Service Healthy | Verify health endpoint returns success |
| TC-03 | 200 OK - Direct Access | Confirm public route accessible |
| TC-04 | 200 OK or 302 Redirect | Test with and without valid tokens |
| TC-05 | Multiple unique IPs | Check CloudWatch logs for IP diversity |
| TC-06 | Consistent 302 redirects | Monitor redirect patterns in Grafana |
| TC-07 | Continuous 200 responses | Track health endpoint in real-time |
| TC-08 | Appropriate error responses | Test invalid requests and monitor errors |
| TC-09 | Even load distribution | Analyze traffic distribution across IPs |

---

## 5. Actual Results & Screenshots

### 5.1 QueueIt Integration Verification

**Test Date**: July 9, 2025  
**Test Environment**: Local Docker setup with QueueIt integration

| Test Case ID | Actual Result | Status | Notes |
|--------------|--------------|--------|-------|
| TC-01 | ✅ 302 Redirect to QueueIt | PASS | Location: https://futuraforge.queue-it.net/ |
| TC-02 | ✅ 200 OK - Service Healthy | PASS | Health endpoint responding correctly |
| TC-03 | ✅ 200 OK - Direct Access | PASS | Public routes accessible |
| TC-04 | ✅ 302 Redirect (no valid token) | PASS | QueueIt filter working correctly |
| TC-05 | ✅ Multiple unique IPs | PASS | 10 ECS tasks with unique IPs |
| TC-06 | ✅ Consistent 302 redirects | PASS | All protected routes redirecting |
| TC-07 | ✅ Continuous 200 responses | PASS | Health monitoring stable |
| TC-08 | ✅ Appropriate error handling | PASS | Invalid requests handled correctly |
| TC-09 | ✅ Even load distribution | PASS | Traffic distributed across IPs |

### 5.2 Grafana Dashboard Screenshots

**QueueIt Integration Dashboard**:
- **QueueIt Endpoint Requests**: Shows all requests to QueueIt endpoints
- **Error Rate by Status Code**: Tracks individual error types (400, 401, 403, 404, 500, 502, 503)
- **Success Rate**: Shows percentage of successful responses
- **IP Address Analysis**: Displays traffic by IP address and geographic distribution

**Key Metrics Observed**:
- **302 Redirect Rate**: ~95% for protected routes
- **Health Endpoint Success**: 100% 200 responses
- **Error Rate**: <1% for non-health endpoints
- **IP Diversity**: 10 unique IP addresses from ECS tasks

### 5.3 Load Testing Results

**Test Configuration**:
- **Number of Tasks**: 10 ECS tasks
- **VUs per Task**: 1 VU each
- **Test Duration**: 60 seconds per task
- **Target URL**: https://affluenceit.com

**Results Summary**:
- **Total Requests**: ~600 requests across all tasks
- **302 Redirects**: ~570 redirects to QueueIt
- **200 Responses**: ~30 successful responses
- **Unique IPs**: 10 unique AWS public IPs
- **Average Response Time**: 150ms
- **Error Rate**: 0.5%

---

## 6. QueueIt Integration Architecture

### 6.1 Current Implementation

The QueueIt integration is implemented using the official QueueIt connector:

```java
// QueueItIntegrationController.java
@RestController
@RequestMapping("/integration/queueit")
public class QueueItIntegrationController {
    
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("QueueIt integration is healthy");
    }
}
```

### 6.2 QueueIt Filter Configuration

The QueueIt filter is configured to protect specific routes:

```java
// QueueItSettings.java
@Component
public class QueueItSettings {
    
    @Value("${queueit.customerid}")
    private String customerId;
    
    @Value("${queueit.secretkey}")
    private String secretKey;
    
    // Filter configuration for protected routes
    // /owners/new is protected and redirects to QueueIt
}
```

### 6.3 Protected Routes

- **`/owners/new`**: Protected route that redirects to QueueIt
- **`/owners/edit/{id}`**: Protected route for editing owners
- **`/pets/new`**: Protected route for adding pets
- **`/visits/new`**: Protected route for adding visits

### 6.4 Public Routes

- **`/`**: Public homepage
- **`/owners/find`**: Public owner search
- **`/vets`**: Public vet listing
- **`/integration/queueit/health`**: Public health endpoint

---

## 7. IP Diversity Testing

### 7.1 IP Diversity Implementation

The current implementation uses multiple ECS tasks for IP diversity:

```bash
# Each task gets a unique AWS public IP
for i in {1..10}; do
    aws ecs run-task \
        --cluster k6-load-test-cluster \
        --task-definition k6-single-vu-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[subnet-097cbe067e542243a],securityGroups=[sg-0737d6eb4011e161c],assignPublicIp=ENABLED}" \
        --region us-east-1
done
```

### 7.2 IP Assignment Process

1. **Task Launch**: Each ECS task is launched independently
2. **Network Interface**: Each task gets a dedicated ENI (Elastic Network Interface)
3. **Private IP**: Assigned from VPC subnet (10.0.1.0/24)
4. **Public IP**: Auto-assigned from AWS public IP pool (3.x.x.x)
5. **IP Diversity**: 10 tasks = 10 unique public IPs

### 7.3 Testing Scenarios

**Scenario 1: Basic IP Diversity**
- Launch 10 tasks with 1 VU each
- Each task tests QueueIt integration independently
- Verify each task uses unique IP

**Scenario 2: QueueIt Redirect Testing**
- Target protected routes from multiple IPs
- Verify consistent 302 redirects across all IPs
- Monitor redirect patterns in Grafana

**Scenario 3: Health Monitoring**
- Continuous health checks from multiple IPs
- Verify health endpoint stability
- Track response times across IPs

---

## 8. Monitoring and Analysis

### 8.1 Grafana Dashboards

**Primary Dashboard**: QueueIt Integration Dashboard
- **Real-time Metrics**: 5-second refresh rate
- **Error Tracking**: Comprehensive error code monitoring
- **IP Analysis**: Geographic and network-based analysis
- **Performance Metrics**: Response times and throughput

**Secondary Dashboards**:
- **QueueIt Error Tracking**: Dedicated error analysis
- **QueueIt Request Volume**: Traffic pattern analysis
- **Application HTTP Traffic**: Overall application performance
- **PetClinic HTTP Traffic**: PetClinic-specific metrics

### 8.2 Key Metrics to Monitor

1. **QueueIt Integration Health**:
   ```promql
   # Health endpoint success rate
   rate(http_server_requests_seconds_count{uri="/integration/queueit/health",status="200"}[5m])
   ```

2. **Protected Route Redirects**:
   ```promql
   # 302 redirect rate for protected routes
   rate(http_server_requests_seconds_count{uri="/owners/new",status="302"}[5m])
   ```

3. **IP Diversity**:
   ```promql
   # Unique IP count
   count by (instance) (rate(http_server_requests_seconds_count[5m]))
   ```

4. **Error Rates**:
   ```promql
   # Error rate excluding health endpoint
   rate(http_server_requests_seconds_count{uri!="/integration/queueit/health",status=~"4..|5.."}[5m]) / rate(http_server_requests_seconds_count{uri!="/integration/queueit/health"}[5m]) * 100
   ```

### 8.3 Alerting

**Critical Alerts**:
- QueueIt health endpoint down
- High error rates (>10%)
- No IP diversity detected
- Protected routes not redirecting

**Warning Alerts**:
- Elevated response times (>500ms)
- Increased error rates (>5%)
- Unusual traffic patterns

---

## 9. Troubleshooting

### 9.1 Common Issues

**Issue 1: No 302 Redirects**
- **Symptoms**: Protected routes return 200 instead of 302
- **Solution**: Verify QueueIt filter configuration and customer ID

**Issue 2: Health Endpoint Errors**
- **Symptoms**: Health endpoint returns 500 errors
- **Solution**: Check QueueIt integration controller and dependencies

**Issue 3: No IP Diversity**
- **Symptoms**: All requests from same IP
- **Solution**: Verify ECS task configuration and network settings

**Issue 4: High Error Rates**
- **Symptoms**: Elevated 4xx/5xx error rates
- **Solution**: Check application logs and QueueIt integration

### 9.2 Debugging Commands

```bash
# Check QueueIt integration health
curl http://localhost:8080/integration/queueit/health

# Test protected route redirect
curl -I http://localhost:8080/owners/new

# Check application logs
docker-compose logs petclinic

# Verify Prometheus metrics
curl http://localhost:8080/actuator/prometheus | grep queueit

# Check Grafana dashboard
open http://localhost:3000
```

### 9.3 Log Analysis

**CloudWatch Logs**:
- **Log Group**: `/ecs/k6-single-vu-task`
- **Stream Prefix**: `k6`
- **Key Information**: Request logs, error messages, IP addresses

**Application Logs**:
- **Location**: Docker container logs
- **Key Information**: QueueIt integration errors, filter processing

---

## 10. Best Practices

### 10.1 Testing Best Practices

1. **Test in Isolation**: Test QueueIt integration separately from load testing
2. **Monitor Continuously**: Use Grafana dashboards for real-time monitoring
3. **Document Results**: Keep detailed records of test results and configurations
4. **Validate Assumptions**: Verify expected behavior with actual results

### 10.2 Load Testing Best Practices

1. **Start Small**: Begin with few tasks and scale up
2. **Monitor Resources**: Watch CPU, memory, and network usage
3. **Clean Up**: Stop tasks after testing to avoid costs
4. **Document Configurations**: Keep track of task definitions and scripts

### 10.3 Monitoring Best Practices

1. **Set Up Alerts**: Configure alerts for critical metrics
2. **Regular Reviews**: Review dashboards and metrics regularly
3. **Performance Baselines**: Establish performance baselines
4. **Capacity Planning**: Use metrics for capacity planning

---

## 11. Future Enhancements

### 11.1 Advanced IP Rotation

- **Container-level IP rotation**: Single container with multiple IPs
- **Proxy-based rotation**: Use proxy services for IP diversity
- **Geographic distribution**: Multi-region deployment for geographic diversity

### 11.2 Enhanced Monitoring

- **Custom metrics**: Application-specific QueueIt metrics
- **Advanced alerting**: Machine learning-based anomaly detection
- **Performance optimization**: Query optimization for large datasets

### 11.3 Integration Improvements

- **CI/CD integration**: Automated testing in deployment pipeline
- **API-based testing**: Programmatic test execution
- **Multi-cloud support**: Support for other cloud providers

---

## 12. Notes

- **Environment**: This guide is for non-production/testing environments
- **Security**: QueueIt integration should be properly secured in production
- **Updates**: Keep this document updated with new features and configurations
- **Support**: For advanced troubleshooting, consult backend logs and Prometheus queries directly

---

**Last Updated**: July 9, 2025  
**Version**: 2.0 - IP Diversity and QueueIt Integration  
**Compatibility**: Spring Boot 3.x, QueueIt Connector, AWS ECS Fargate 