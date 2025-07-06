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
# Start all services (PetClinic, Prometheus, Grafana)
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 2. Import Dashboards

```bash
# Make the import script executable (if not already)
chmod +x import-grafana-dashboards.sh

# Import all five dashboards
./import-grafana-dashboards.sh
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
- **PetClinic Error Tracking**: Error rates and types

## 🔧 Configuration Details

### Application Configuration (`application.properties`)
```properties
# Enhanced Metrics Configuration
management.metrics.export.prometheus.descriptions=true
management.metrics.export.prometheus.step=15s
management.metrics.tags.application=petclinic
management.metrics.tags.environment=development

# Enhanced HTTP Metrics
management.metrics.web.server.request.autotime.enabled=true
management.metrics.web.server.request.autotime.percentiles=0.5,0.95,0.99
management.metrics.web.server.request.autotime.percentiles-histogram=true

# Queue-it integration metrics
queueit.metrics.enabled=true
queueit.metrics.ip-tracking.enabled=true
```

### Prometheus Configuration (`prometheus.yml`)
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'petclinic'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['petclinic:8080']
    scrape_interval: 15s
    honor_labels: true
    
  - job_name: 'k6'
    static_configs:
      - targets: ['host.docker.internal:6565']
    scrape_interval: 15s
    honor_labels: true
```

## 🧪 Testing the Setup

### 1. Generate Traffic

```bash
# Generate HTTP traffic to the application
curl -X GET http://localhost:8080/
curl -X GET http://localhost:8080/owners/find
curl -X GET http://localhost:8080/vets.html

# Test QueueIt integration endpoints (these will return 500 errors as expected)
curl -X POST "http://localhost:8080/integration/queueit/queue?userId=test-user"
curl -X POST "http://localhost:8080/integration/queueit/validate?token=test-token"
curl -X GET http://localhost:8080/integration/queueit/status
curl -X GET http://localhost:8080/integration/queueit/health
curl -X POST "http://localhost:8080/integration/queueit/cancel?sessionId=test-session"
curl -X POST "http://localhost:8080/integration/queueit/extend-cookie?sessionId=test-session"

# Generate bulk traffic for testing
for i in {1..50}; do 
  curl -s http://localhost:8080/owners/find > /dev/null
  curl -s http://localhost:8080/vets > /dev/null
  curl -s http://localhost:8080/owners/1 > /dev/null
  sleep 0.1
done
```

### 2. Load Testing with K6

```bash
# Install K6 (if not already installed)
# macOS: brew install k6
# Linux: https://k6.io/docs/getting-started/installation/

# Run load test
k6 run --out prometheus=localhost:6565 testing-projects/k6-load-test/k6-load-test.js
```

### 3. Test Metrics Script

```bash
# Run the comprehensive metrics test script
./test-metrics.sh
```

## 📊 Error Tracking Features

### Comprehensive HTTP Error Code Monitoring
The enhanced dashboards now track all major HTTP error codes:

- **400 Bad Request**: Client-side errors
- **401 Unauthorized**: Authentication failures
- **403 Forbidden**: Authorization failures
- **404 Not Found**: Resource not found
- **500 Internal Server Error**: Server-side errors
- **502 Bad Gateway**: Gateway errors
- **503 Service Unavailable**: Service unavailability

### Error Analysis Capabilities
- **Real-time Error Rates**: Monitor error rates per second
- **Error Percentage Tracking**: Percentage breakdown of each error type
- **Response Time Analysis**: How long each error type takes to respond
- **Exception Correlation**: Link exceptions to specific error status codes
- **Success Rate Calculation**: Success rate excluding all error responses
- **Visual Thresholds**: Color-coded indicators for different error levels

### Dashboard Refresh and Updates
- **5-second Refresh Rate**: Real-time monitoring
- **Auto-scaling Panels**: Responsive dashboard layouts
- **Color-coded Thresholds**: Visual indicators for performance levels
- **Comprehensive Legends**: Detailed metric descriptions

## 🎯 Key Benefits

1. **Complete Error Visibility**: Track all HTTP error codes, not just 500 errors
2. **Real-time Monitoring**: 5-second refresh rate for immediate issue detection
3. **Comprehensive Analysis**: Error rates, percentages, response times, and exceptions
4. **Multiple Dashboard Views**: Different perspectives for different use cases
5. **Easy Setup**: Automated import scripts and configuration
6. **Production Ready**: Robust metrics collection and visualization

## 🔍 Troubleshooting

### Common Issues

1. **"No Data" in Dashboards**
   - Ensure Prometheus is scraping the PetClinic application
   - Check that metrics are being generated: `curl http://localhost:8080/actuator/prometheus`
   - Verify Prometheus targets are healthy: http://localhost:9090/targets

2. **Dashboard Import Failures**
   - Ensure Grafana is running: `docker-compose ps`
   - Check dashboard JSON format compatibility
   - Verify datasource configuration in Grafana

3. **Missing Error Metrics**
   - Generate traffic to QueueIt endpoints to create error metrics
   - Check application logs for any configuration issues
   - Verify QueueIt integration controller is properly configured

### Useful Commands

```bash
# Check application metrics
curl -s http://localhost:8080/actuator/prometheus | grep -E "(queueit|http_requests)" | head -10

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check Grafana datasources
curl -s -u admin:admin http://localhost:3000/api/datasources

# Generate test traffic
for i in {1..20}; do curl -s http://localhost:8080/integration/queueit/health > /dev/null; sleep 0.1; done
```

## 📈 Next Steps

1. **Customize Dashboards**: Modify panels and queries for your specific needs
2. **Add Alerts**: Configure Grafana alerts for error thresholds
3. **Scale Monitoring**: Add more applications and services to the monitoring stack
4. **Performance Tuning**: Optimize metrics collection intervals and retention
5. **Integration**: Connect with external monitoring systems and notification services

---

**Last Updated**: December 2024  
**Version**: 2.0 - Enhanced Error Tracking  
**Compatibility**: Grafana 12.0.2+, Prometheus 2.x, Spring Boot 3.x

## 📋 Metrics Reference

### QueueIt Integration Metrics
| Metric | Description | Type |
|--------|-------------|------|
| `queueit_api_requests_total` | Total API requests by operation | Counter |
| `queueit_api_success_total` | Successful API requests by operation | Counter |
| `queueit_api_errors_total` | Failed API requests by operation | Counter |
| `queueit_*_duration_seconds` | Response time for each operation | Histogram |
| `queueit_validate_total` | Total validate operations | Counter |
| `queueit_queue_total` | Total queue operations | Counter |
| `queueit_cancel_total` | Total cancel operations | Counter |

### QueueIt Filter Metrics
| Metric | Description | Type |
|--------|-------------|------|
| `queueit_filter_requests_total` | Total requests processed by filter | Counter |
| `queueit_filter_proceed_total` | Requests that proceeded to application | Counter |
| `queueit_filter_blocked_total` | Requests blocked by filter | Counter |
| `queueit_redirects_total` | Total redirects by action type | Counter |
| `queueit_http_redirects_total` | HTTP redirects | Counter |
| `queueit_ajax_redirects_total` | AJAX redirects | Counter |
| `queueit_validations_success_total` | Successful validations by action type | Counter |
| `queueit_validation_errors_total` | Validation errors by error type | Counter |

### Application HTTP Metrics
| Metric | Description | Type |
|--------|-------------|------|
| `http_server_requests_seconds_count` | Total HTTP requests by status/method/uri | Counter |
| `http_server_requests_seconds_bucket` | HTTP request duration histogram | Histogram |
| `http_server_requests_seconds_sum` | Total HTTP request duration | Counter |

## 🎨 Dashboard Features

### Visual Design
- **Dark Theme**: Modern dark theme for better readability
- **Color Coding**: Green for success, yellow for warning, red for errors
- **Human-Friendly Legends**: Clear, descriptive panel titles and legends
- **Responsive Layout**: Panels automatically adjust to screen size

### Interactive Features
- **Time Range Selection**: Flexible time range controls
- **Auto-refresh**: Dashboards refresh every 5 seconds
- **Drill-down Capability**: Click on panels for detailed views
- **Export Options**: PNG, PDF, and JSON export capabilities

### Alerting Ready
- **Thresholds**: Pre-configured thresholds for critical metrics
- **Alert Rules**: Ready-to-use Prometheus alert rules
- **Notification Channels**: Easy integration with Slack, email, etc.

## 📚 Additional Resources

- [Prometheus Query Language (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/)
- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Spring Boot Actuator Metrics](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.metrics)
- [QueueIt Integration Guide](https://queue-it.com/docs/connectors/aspnet-core)

---

**Note**: This setup provides comprehensive monitoring for QueueIt integration and application performance. The dashboards are designed to be both informative for developers and actionable for operations teams. 

## IP Address Tracking Features

### Geographic Regions Monitored
- **North America**: `192.168.x.x` (private networks)
- **Private Networks**: `10.x.x.x` and `172.16.x.x`
- **Europe**: `193.x.x.x` and `194.x.x.x`
- **Asia**: `202.x.x.x` and `203.x.x.x`
- **Mobile Networks**: `100.64.x.x` and `100.65.x.x`

### IP Analysis Capabilities
1. **Geographic Distribution**: Track traffic patterns by region
2. **Performance Analysis**: Compare response times and error rates by region
3. **Security Monitoring**: Identify suspicious IP addresses or regions
4. **Load Distribution**: Understand traffic distribution across regions
5. **Capacity Planning**: Identify high-traffic regions for infrastructure planning

## Configuration

### Prerequisites
- Docker and Docker Compose installed
- Spring Boot application with Actuator enabled
- Prometheus configured for metrics collection

### Environment Setup
```bash
# Clone the repository
git clone <repository-url>
cd spring-petclinic-main

# Start the monitoring stack
docker-compose up -d prometheus grafana
```

### Application Configuration
Ensure your `application.properties` includes:
```properties
# Actuator configuration
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.metrics.export.prometheus.enabled=true
management.metrics.tags.application=petclinic

# Queue-it integration metrics
queueit.metrics.enabled=true
queueit.metrics.ip-tracking.enabled=true
```

## Dashboard Import

### Automatic Import
Use the provided import script:
```bash
./import-grafana-dashboards.sh
```

### Manual Import
1. Access Grafana at `http://localhost:3000`
2. Navigate to Dashboards → Import
3. Import each dashboard JSON file from `testing-projects/grafana-dashboards/`

## Testing and Validation

### Generate Test Traffic
```bash
# Basic traffic generation
./test-metrics.sh

# IP spoofing load test
./run-ip-spoofing-load-test.sh
```

### K6 Load Testing with IP Spoofing
```bash
# Run K6 load test with IP spoofing
cd testing-projects/k6-load-test/
./run-ip-spoofing-load-test.sh
```

The K6 script generates traffic from various IP ranges:
- North America: `192.168.x.x`
- Private Networks: `10.x.x.x`, `172.16.x.x`
- Europe: `193.x.x.x`, `194.x.x.x`
- Asia: `202.x.x.x`, `203.x.x.x`
- Mobile Networks: `100.64.x.x`, `100.65.x.x`

## Metrics Collection

### Prometheus Metrics
The application exposes these key metrics:
- `http_server_requests_seconds_count`: HTTP request counts
- `http_server_requests_seconds_sum`: HTTP request durations
- `queueit_filter_requests_total`: Queue-it filter requests
- `queueit_redirects_total`: Queue-it redirects
- `queueit_validations_success_total`: Successful validations

### IP Address Tracking
IP addresses are captured in the `client_ip` label for:
- HTTP request metrics
- Queue-it integration metrics
- Error tracking metrics

## Troubleshooting

### Common Issues

#### 1. "No Data" in Dashboards
**Symptoms**: Dashboards show "No data" despite application running
**Solutions**:
- Verify Prometheus is collecting metrics: `http://localhost:9090/targets`
- Check application metrics endpoint: `http://localhost:8080/actuator/prometheus`
- Ensure proper datasource configuration in Grafana

#### 2. IP Address Data Not Appearing
**Symptoms**: IP address panels show no data
**Solutions**:
- Verify IP spoofing is working in load tests
- Check that `client_ip` label is present in metrics
- Ensure load tests are generating traffic from different IP ranges

#### 3. Dashboard Import Failures
**Symptoms**: HTTP 400 errors during import
**Solutions**:
- Verify JSON format is correct
- Check Grafana version compatibility
- Ensure datasource is configured as "Prometheus"

### Verification Steps
1. **Check Prometheus Targets**: `http://localhost:9090/targets`
2. **Verify Metrics**: `http://localhost:9090/graph`
3. **Test Queries**: Use Prometheus UI to test metric queries
4. **Validate IP Data**: Run IP spoofing tests and verify data appears

## Performance Considerations

### Metric Cardinality
- IP address tracking increases metric cardinality
- Monitor Prometheus memory usage
- Consider metric retention policies

### Storage Requirements
- IP address data requires additional storage
- Plan for increased Prometheus storage needs
- Monitor disk usage regularly

## Security Considerations

### IP Address Privacy
- IP addresses are stored in Prometheus
- Consider data retention policies
- Implement access controls for sensitive data

### Network Security
- Ensure monitoring stack is properly secured
- Use HTTPS for Grafana access
- Implement authentication for dashboard access

## Next Steps

### Advanced Features
1. **Alerting**: Set up Grafana alerts for error thresholds
2. **Custom Metrics**: Add application-specific metrics
3. **Geographic Mapping**: Integrate with IP geolocation services
4. **Anomaly Detection**: Implement automated anomaly detection

### Scaling Considerations
1. **High Cardinality**: Monitor metric cardinality growth
2. **Storage Planning**: Plan for long-term metric storage
3. **Performance Optimization**: Optimize queries for large datasets
4. **Multi-Region**: Consider multi-region monitoring setup

## Support and Maintenance

### Regular Tasks
- Monitor dashboard performance
- Review and update alerting rules
- Clean up old metrics data
- Update dashboard configurations

### Documentation Updates
- Keep this guide updated with new features
- Document custom metrics and configurations
- Maintain troubleshooting procedures

## Conclusion

This monitoring setup provides comprehensive visibility into your Spring PetClinic application with Queue-it integration, including detailed IP address tracking for geographic and network-based analysis. The dashboards enable proactive monitoring, troubleshooting, and capacity planning based on real traffic patterns. 