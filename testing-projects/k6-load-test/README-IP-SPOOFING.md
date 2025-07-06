# K6 Load Testing with IP Spoofing

This guide explains how to use K6 for load testing with IP spoofing capabilities to test the IP address tracking features in the Grafana dashboards.

## Overview

The K6 load testing setup includes IP spoofing functionality that generates traffic from various IP address ranges, allowing you to test and validate the IP address tracking capabilities in the Grafana dashboards.

## Features

### IP Spoofing Capabilities
- **Geographic Distribution**: Generate traffic from different geographic regions
- **Network Types**: Test various network types (private, public, mobile)
- **Load Patterns**: Simulate realistic traffic patterns from different sources
- **Dashboard Validation**: Test IP address tracking panels in Grafana

### IP Address Ranges Used
- **North America**: `192.168.x.x` (private networks)
- **Private Networks**: `10.x.x.x`, `172.16.x.x`
- **Europe**: `193.x.x.x`, `194.x.x.x`
- **Asia**: `202.x.x.x`, `203.x.x.x`
- **Mobile Networks**: `100.64.x.x`, `100.65.x.x`

## Prerequisites

- K6 installed on your system
- Spring PetClinic application running
- Grafana and Prometheus monitoring stack running
- IP spoofing capabilities (may require root/admin privileges)

## Installation

### Install K6
```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A364D8598C4F8C8190B836B9C
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Windows
choco install k6
```

## Usage

### Basic IP Spoofing Test
```bash
# Run the IP spoofing load test
./run-ip-spoofing-load-test.sh
```

### Manual K6 Execution
```bash
# Run with custom parameters
k6 run --out json=results/ip-spoofing-test-$(date +%Y%m%d_%H%M%S).json k6-load-test-with-ip-spoofing.js
```

### Custom Configuration
```bash
# Run with specific duration and VUs
k6 run --duration 5m --vus 10 k6-load-test-with-ip-spoofing.js

# Run with custom stages
k6 run --stage 2m:10 --stage 5m:20 --stage 2m:10 k6-load-test-with-ip-spoofing.js
```

## Test Configuration

### IP Address Generation
The test script generates random IP addresses from predefined ranges:

```javascript
// IP address ranges for different regions
const ipRanges = {
  northAmerica: ['192.168.1', '192.168.2', '192.168.3'],
  privateNetworks: ['10.0.1', '10.0.2', '172.16.1', '172.16.2'],
  europe: ['193.1.1', '193.1.2', '194.1.1', '194.1.2'],
  asia: ['202.1.1', '202.1.2', '203.1.1', '203.1.2'],
  mobileNetworks: ['100.64.1', '100.64.2', '100.65.1', '100.65.2']
};
```

### Request Headers
The test sets multiple IP-related headers to ensure proper IP tracking:

```javascript
headers: {
  'X-Forwarded-For': randomIP,
  'X-Real-IP': randomIP,
  'X-Client-IP': randomIP,
  'CF-Connecting-IP': randomIP,
  'True-Client-IP': randomIP
}
```

## Dashboard Integration

### IP Address Tracking Panels
The load test validates these dashboard panels:

1. **QueueIt Integration Dashboard**:
   - Top Source IP Addresses
   - IP Address Distribution by Region
   - Unique IP Addresses Count
   - IP Address Error Rate

2. **QueueIt Error Tracking Dashboard**:
   - Top Error Sources by IP
   - Error Rate by IP Region
   - Unique IPs with Errors
   - Error Rate by IP and Status Code

3. **QueueIt Request Volume Dashboard**:
   - QueueIt Requests by IP Address
   - Top Request Sources by IP
   - Unique IP Addresses Count

4. **Application HTTP Traffic Dashboard**:
   - HTTP Traffic by IP Address
   - Top Traffic Sources by IP
   - Unique IP Addresses
   - HTTP Error Rate by IP

### Validation Process
1. **Run Load Test**: Execute the IP spoofing test
2. **Monitor Dashboards**: Check IP tracking panels in Grafana
3. **Verify Data**: Ensure IP addresses appear in the correct regions
4. **Analyze Patterns**: Review traffic distribution and error rates

## Metrics and Monitoring

### Key Metrics Tracked
- **Request Volume**: Traffic from different IP regions
- **Error Rates**: Errors by geographic location
- **Response Times**: Performance by IP region
- **Unique IPs**: Count of distinct IP addresses

### Dashboard Validation
After running the test, verify these dashboard panels show data:

1. **Geographic Distribution**: Check if traffic appears in expected regions
2. **Error Analysis**: Verify error rates by IP region
3. **Performance Metrics**: Review response times by geographic location
4. **Capacity Planning**: Analyze traffic patterns for infrastructure planning

## Configuration Options

### Test Parameters
```javascript
// Load test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up
    { duration: '5m', target: 20 },  // Sustained load
    { duration: '2m', target: 10 },  // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'], // 95% of requests under 2s
    http_req_failed: ['rate<0.1'],     // Error rate under 10%
  },
};
```

### IP Spoofing Settings
```javascript
// IP generation frequency
const ipChangeInterval = 1000; // Change IP every 1000 requests

// IP range distribution
const regionWeights = {
  northAmerica: 0.3,
  privateNetworks: 0.2,
  europe: 0.2,
  asia: 0.2,
  mobileNetworks: 0.1
};
```

## Troubleshooting

### Common Issues

#### 1. IP Spoofing Not Working
**Symptoms**: All requests show same IP address
**Solutions**:
- Ensure running with appropriate privileges
- Check network configuration
- Verify IP ranges are accessible

#### 2. Dashboard Not Showing IP Data
**Symptoms**: IP tracking panels show no data
**Solutions**:
- Verify `client_ip` label in Prometheus metrics
- Check application IP extraction logic
- Ensure load test is generating diverse IPs

#### 3. Performance Issues
**Symptoms**: High latency or timeouts
**Solutions**:
- Reduce concurrent users
- Increase timeouts
- Check application capacity

### Verification Steps
1. **Check IP Generation**: Verify logs show different IPs
2. **Monitor Prometheus**: Check metrics in Prometheus UI
3. **Validate Dashboards**: Ensure IP data appears in Grafana
4. **Review Logs**: Check application logs for IP tracking

## Advanced Usage

### Custom IP Ranges
Modify the IP ranges in the test script:

```javascript
const customIPRanges = {
  yourRegion: ['192.168.10', '192.168.11'],
  // Add more custom ranges
};
```

### Geographic Testing
Test specific geographic scenarios:

```javascript
// Test specific regions
const testRegions = ['northAmerica', 'europe'];
const regionIPs = testRegions.map(region => getRandomIP(region));
```

### Load Pattern Simulation
Simulate realistic traffic patterns:

```javascript
// Simulate peak hours
const peakHourPattern = [
  { duration: '1h', target: 50 },  // Peak traffic
  { duration: '2h', target: 20 },  // Normal traffic
  { duration: '1h', target: 10 },  // Low traffic
];
```

## Security Considerations

### IP Address Privacy
- IP addresses are logged and stored in metrics
- Consider data retention policies
- Implement access controls for sensitive data

### Network Security
- Ensure IP spoofing doesn't violate network policies
- Monitor for suspicious IP patterns
- Implement rate limiting if needed

## Performance Optimization

### Test Optimization
- Use appropriate VU count for your environment
- Monitor system resources during tests
- Adjust test duration based on needs

### Dashboard Performance
- IP tracking increases metric cardinality
- Monitor Prometheus memory usage
- Consider metric retention policies

## Integration with CI/CD

### Automated Testing
```bash
# Run in CI/CD pipeline
k6 run --out json=test-results.json k6-load-test-with-ip-spoofing.js

# Parse results
python parse-k6-results.py test-results.json
```

### Quality Gates
Set up quality gates based on IP tracking metrics:
- Geographic distribution thresholds
- Error rate limits by region
- Performance SLAs by location

## Conclusion

The K6 load testing with IP spoofing provides comprehensive testing of the IP address tracking features in the Grafana dashboards. This setup enables realistic load testing scenarios that validate geographic traffic patterns, error analysis, and performance monitoring across different network regions.

The integration with the monitoring stack ensures that IP address data is properly captured, stored, and visualized in the dashboards, providing valuable insights for capacity planning, security monitoring, and performance optimization.

---

**Last Updated**: December 2024  
**Version**: 1.0 - IP Spoofing Load Testing  
**Compatibility**: K6 0.45+, Node.js 18+ 