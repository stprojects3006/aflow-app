# Grafana Metrics Setup for QueueIt Integration

This document provides comprehensive setup instructions for the enhanced Grafana metrics system with **five beautiful dashboards** for monitoring QueueIt integration, application performance, and comprehensive error tracking.

## 🎯 Overview

The enhanced metrics system includes:

1. **QueueIt Integration Dashboard** - Monitors API calls, response times, success rates, and comprehensive error tracking
2. **QueueIt Error Tracking Dashboard** - Dedicated dashboard for detailed error analysis across all HTTP status codes
3. **QueueIt Request Volume Dashboard** - Tracks redirects, validations, and traffic patterns
4. **Application HTTP Traffic Dashboard** - Overall application performance and traffic analysis
5. **PetClinic HTTP Traffic Dashboard** - PetClinic-specific metrics and traffic patterns

## 📊 Enhanced Metrics

### Application Metrics (Spring Boot Actuator)
- **HTTP Request Metrics**: `http_server_requests_seconds_count`, `http_server_requests_seconds_bucket`
- **Response Time**: 50th, 95th, and 99th percentiles
- **Status Code Distribution**: 2xx, 3xx, 4xx, 5xx breakdown
- **Method Distribution**: GET, POST, PUT, DELETE, PATCH
- **Endpoint Traffic**: Top endpoints by request volume
- **Error Tracking**: Comprehensive tracking of all HTTP error codes (400, 401, 403, 404, 500, 502, 503)

### QueueIt Integration Metrics
- **API Operations**: `queueit_validate_total`, `queueit_queue_total`, `queueit_cancel_total`
- **Response Times**: `queueit_*_duration_seconds` for each operation
- **Success/Error Rates**: `queueit_api_success_total`, `queueit_api_errors_total`
- **Request Volume**: `queueit_api_requests_total` by operation
- **Error Status Tracking**: Detailed tracking of 4xx and 5xx errors by endpoint

### QueueIt Filter Metrics
- **Request Processing**: `queueit_filter_requests_total`, `queueit_filter_proceed_total`
- **Redirects**: `queueit_redirects_total`, `queueit_http_redirects_total`, `queueit_ajax_redirects_total`
- **Validations**: `queueit_validations_success_total`, `queueit_validation_errors_total`
- **Action Types**: Queue, Idle, Redirect actions

## 🚀 Quick Setup

### 1. Start the Application Stack

```bash
# Navigate to app-code directory
cd app-code

# Start all services (PetClinic, Prometheus, Grafana)
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 2. Import Dashboards

```bash
# Make the import script executable (if not already)
chmod +x deploy-grafana-dashboards.sh

# Import all five dashboards
./deploy-grafana-dashboards.sh
```

### 3. Access Dashboards

- **Grafana URL**: http://localhost:3000
- **Default Credentials**: admin/admin
- **Data Source**: Prometheus (auto-configured)

## 📈 Dashboard Details

### 1. QueueIt Integration Dashboard
**Purpose**: Monitor QueueIt API integration performance with comprehensive error tracking

**Key Panels**:
- **QueueIt Endpoint Requests (All)**: All requests to QueueIt endpoints
- **QueueIt Error Rate by Status Code**: Individual tracking of 400, 401, 403, 404, 500, 502, 503 errors
- **QueueIt Error Percentage by Status Code**: Percentage breakdown of each error type
- **QueueIt Response Time by Error Status**: Response times for different error types
- **Total Errors by Status Code**: Cumulative error counts (4xx/5xx, 500, 404)
- **Error Rate by Endpoint and Status**: Error rates for each QueueIt endpoint
- **Success Rate (Non-Error Responses)**: Percentage of successful 2xx/3xx responses
- **Exception Types by Error Status**: Exception breakdown for all error types
- **IP Address Analysis**:
  - Top source IP addresses by request volume
  - IP address distribution by geographic regions
  - Unique IP addresses count
  - Error rates by IP region and status code

**Metrics Used**:
```promql
# All QueueIt endpoint requests
rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*"}[5m])

# Error rate by status code
rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status="500"}[5m])

# Error percentage
(rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status="500"}[5m]) / rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*"}[5m])) * 100

# Success rate (non-error responses)
(1 - (sum(rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status=~"4..|5.."}[5m])) / sum(rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*"}[5m])))) * 100
```

### 2. QueueIt Error Tracking Dashboard
**Purpose**: Dedicated dashboard for comprehensive error analysis and monitoring

**Key Panels**:
- **Error Rate by HTTP Status Code**: Individual tracking of each error type for /health endpoint
- **Total Errors by Status Code**: Cumulative error counts for all error types
- **Error Percentage by Status Code**: Percentage breakdown of each error type
- **Response Time by Error Status**: Response times for different error types
- **Exception Types by Error Status**: Exception breakdown for all error types
- **Overall Error Summary**: Total error rate, percentage, and count
- **IP Address Error Analysis**:
  - Top error sources by IP address
  - Error rate by IP region (North America, Europe, Asia, Private Networks)
  - Unique IPs experiencing errors
  - Detailed error breakdown by IP and status code

**Metrics Used**:
```promql
# Error rate by status code
rate(http_server_requests_seconds_count{uri="/integration/queueit/health",status="400"}[5m])

# Total errors by status code
sum(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status="500"})

# Error percentage
(rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status="500"}[5m]) / rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*"}[5m])) * 100

# Overall error summary
sum(rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status=~"4..|5.."}[5m]))
```

### 3. QueueIt Request Volume Dashboard
**Purpose**: Monitor QueueIt filter processing and redirects

**Key Panels**:
- **Total QueueIt Requests**: All requests processed by the filter
- **QueueIt Redirect Rate**: Redirects per second
- **QueueIt Request Volume Over Time**: Requests, proceeded, and blocked rates
- **QueueIt Redirect Types**: HTTP, AJAX, and token removal redirects
- **QueueIt Validation Success Rate**: Percentage of successful validations
- **QueueIt Validation Errors**: Error rate over time
- **QueueIt Action Types Distribution**: Queue, Idle, Redirect actions
- **IP Address Traffic Analysis**:
  - Request volume by IP address region
  - Top request sources by IP address
  - Unique IP addresses count
  - Geographic traffic distribution

**Metrics Used**:
```promql
# Total requests processed
sum(queueit_filter_requests_total)

# Redirect rate
rate(queueit_redirects_total[5m])

# Validation success rate
rate(queueit_validations_success_total[5m]) / rate(queueit_filter_requests_total[5m]) * 100
```

### 4. Application HTTP Traffic Dashboard
**Purpose**: Monitor overall application performance and traffic

**Key Panels**:
- **Total HTTP Requests**: All HTTP requests to the application
- **HTTP Request Rate**: Requests per second
- **HTTP Response Time**: 95th and 50th percentile response times
- **HTTP Status Codes Distribution**: 2xx, 3xx, 4xx, 5xx breakdown
- **Top HTTP Endpoints**: Table of top endpoints by request volume
- **HTTP Methods Distribution**: GET, POST, PUT, DELETE, PATCH breakdown
- **Error Rate**: Percentage of 4xx and 5xx responses
- **QueueIt Integration Endpoints Traffic**: Specific QueueIt endpoint traffic
- **IP Address Traffic Analysis**:
  - HTTP traffic by IP address region
  - Top traffic sources by IP address
  - Unique IP addresses count
  - HTTP error rates by IP region

**Metrics Used**:
```promql
# Total HTTP requests
sum(http_server_requests_seconds_count)

# Request rate
rate(http_server_requests_seconds_count[5m])

# Response time (95th percentile)
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# Error rate
rate(http_server_requests_seconds_count{status=~"4..|5.."}[5m]) / rate(http_server_requests_seconds_count[5m]) * 100
```

### 5. PetClinic HTTP Traffic Dashboard
**Purpose**: PetClinic-specific metrics and traffic patterns

**Key Panels**:
- **PetClinic Request Volume**: Total requests to PetClinic endpoints
- **PetClinic Response Time**: Average response times
- **PetClinic Status Code Distribution**: Success and error rate breakdown
- **Top PetClinic Endpoints**: Most accessed PetClinic pages
- **PetClinic Error Analysis**: Error patterns and trends
- **QueueIt Protected Routes**: Traffic to protected endpoints
- **IP Address PetClinic Analysis**:
  - PetClinic traffic by IP address
  - Geographic distribution of PetClinic users
  - Error rates by IP region for PetClinic endpoints

**Metrics Used**:
```promql
# PetClinic requests (excluding QueueIt endpoints)
rate(http_server_requests_seconds_count{uri!~"/integration/queueit/.*"}[5m])

# PetClinic response time
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket{uri!~"/integration/queueit/.*"}[5m]))

# PetClinic error rate
rate(http_server_requests_seconds_count{uri!~"/integration/queueit/.*",status=~"4..|5.."}[5m]) / rate(http_server_requests_seconds_count{uri!~"/integration/queueit/.*"}[5m]) * 100
```

## 🔧 Configuration Details

### Prometheus Configuration

The Prometheus configuration is located in `app-code/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'petclinic'
    static_configs:
      - targets: ['petclinic:8080']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 5s
```

### Grafana Configuration

Grafana configuration is in `app-code/grafana.ini`:

```ini
[server]
http_port = 3000

[security]
admin_user = admin
admin_password = admin

[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Viewer
```

### Dashboard Import Process

The `deploy-grafana-dashboards.sh` script:

1. **Waits for Grafana to be ready**
2. **Creates data source** (Prometheus)
3. **Imports all dashboards** from `grafana-dashboards/` directory
4. **Verifies import success**

```bash
#!/bin/bash
# deploy-grafana-dashboards.sh

echo "Waiting for Grafana to be ready..."
until curl -s http://localhost:3000/api/health; do
    sleep 2
done

echo "Creating Prometheus data source..."
curl -X POST http://admin:admin@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy"
  }'

echo "Importing dashboards..."
for dashboard in grafana-dashboards/*.json; do
    echo "Importing $dashboard..."
    curl -X POST http://admin:admin@localhost:3000/api/dashboards/import \
      -H "Content-Type: application/json" \
      -d @$dashboard
done

echo "Dashboard deployment complete!"
```

## 📊 QueueIt Integration Testing

### Load Testing with IP Diversity

When running load tests with IP diversity (multiple ECS tasks), the dashboards will show:

1. **Multiple IP Sources**: Each task contributes unique IP addresses
2. **QueueIt Redirect Patterns**: 302 redirects to QueueIt for protected routes
3. **Health Check Monitoring**: Continuous monitoring of QueueIt health endpoint
4. **Error Distribution**: Errors distributed across multiple IP sources

### Expected Metrics During Load Testing

```promql
# QueueIt redirects during load testing
rate(http_server_requests_seconds_count{uri="/owners/new",status="302"}[5m])

# Health endpoint monitoring
rate(http_server_requests_seconds_count{uri="/integration/queueit/health",status="200"}[5m])

# IP diversity analysis
count by (instance) (rate(http_server_requests_seconds_count[5m]))

# Error rate excluding health endpoint
rate(http_server_requests_seconds_count{uri!="/integration/queueit/health",status=~"4..|5.."}[5m]) / rate(http_server_requests_seconds_count{uri!="/integration/queueit/health"}[5m]) * 100
```

## 🔍 Troubleshooting

### Common Issues

1. **Dashboards Not Loading**
   ```bash
   # Check if Prometheus is accessible
   curl http://localhost:9090/api/v1/status/targets
   
   # Check if PetClinic metrics are available
   curl http://localhost:8080/actuator/prometheus
   ```

2. **No QueueIt Metrics**
   ```bash
   # Verify QueueIt integration is working
   curl http://localhost:8080/integration/queueit/health
   
   # Check for 302 redirects
   curl -I http://localhost:8080/owners/new
   ```

3. **Grafana Connection Issues**
   ```bash
   # Restart Grafana
   docker-compose restart grafana
   
   # Check logs
   docker-compose logs grafana
   ```

### Performance Optimization

1. **Reduce Scrape Interval** for high-frequency testing
2. **Increase Retention** for longer-term analysis
3. **Use Recording Rules** for complex queries
4. **Optimize Dashboard Refresh** rates

## 📈 Advanced Monitoring

### Custom Alerts

Create alerts for critical QueueIt integration issues:

```yaml
# prometheus/alerts.yml
groups:
  - name: queueit_alerts
    rules:
      - alert: QueueItHealthDown
        expr: up{job="petclinic"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "QueueIt health endpoint is down"
          
      - alert: HighQueueItErrorRate
        expr: rate(http_server_requests_seconds_count{uri=~"/integration/queueit/.*",status=~"4..|5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High QueueIt error rate detected"
```

### Custom Metrics

Add custom metrics for QueueIt integration:

```java
// QueueItIntegrationController.java
@RestController
@RequestMapping("/integration/queueit")
public class QueueItIntegrationController {
    
    private final Counter queueitRequestsTotal = Counter.build()
        .name("queueit_requests_total")
        .help("Total QueueIt requests")
        .labelNames("endpoint", "status")
        .register();
    
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        queueitRequestsTotal.labels("health", "200").inc();
        return ResponseEntity.ok("QueueIt integration is healthy");
    }
}
```

## 🎯 Summary

This enhanced Grafana metrics setup provides:

1. **Comprehensive QueueIt Monitoring**: Real-time tracking of QueueIt integration performance
2. **IP Diversity Analysis**: Monitor load testing with multiple IP sources
3. **Error Tracking**: Detailed error analysis and alerting
4. **Performance Insights**: Response times, throughput, and resource utilization
5. **Geographic Analysis**: IP-based traffic distribution and error patterns

The dashboards are designed to work seamlessly with the IP diversity load testing setup, providing insights into both the technical performance and business impact of QueueIt integration! 🚀 