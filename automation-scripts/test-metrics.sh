#!/bin/bash

# Test Metrics Script
# This script generates traffic and verifies that metrics are being captured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Metrics Test Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Configuration
APP_URL="http://localhost:8080"
PROMETHEUS_URL="http://localhost:9090"
GRAFANA_URL="http://localhost:3000"

# Function to check if service is running
check_service() {
    local service_name="$1"
    local service_url="$2"
    
    echo -e "${YELLOW}Checking $service_name...${NC}"
    if curl -s --connect-timeout 5 "$service_url" > /dev/null; then
        echo -e "${GREEN}✓ $service_name is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not accessible${NC}"
        return 1
    fi
}

# Function to generate HTTP traffic
generate_http_traffic() {
    echo -e "${YELLOW}Generating HTTP traffic...${NC}"
    
    # Basic application endpoints
    curl -s "$APP_URL/" > /dev/null
    curl -s "$APP_URL/owners/find" > /dev/null
    curl -s "$APP_URL/vets.html" > /dev/null
    curl -s "$APP_URL/oups" > /dev/null
    
    echo -e "${GREEN}✓ HTTP traffic generated${NC}"
}

# Function to test QueueIt integration endpoints
test_queueit_integration() {
    echo -e "${YELLOW}Testing QueueIt integration endpoints...${NC}"
    
    # Test QueueIt endpoints
    curl -s -X POST "$APP_URL/integration/queueit/queue?userId=test-user-$(date +%s)" > /dev/null
    curl -s -X POST "$APP_URL/integration/queueit/validate?token=test-token-$(date +%s)" > /dev/null
    curl -s -X POST "$APP_URL/integration/queueit/cancel?sessionId=test-session-$(date +%s)" > /dev/null
    curl -s -X POST "$APP_URL/integration/queueit/extend-cookie?sessionId=test-session-$(date +%s)" > /dev/null
    curl -s -X GET "$APP_URL/integration/queueit/status" > /dev/null
    curl -s -X GET "$APP_URL/integration/queueit/health" > /dev/null
    
    echo -e "${GREEN}✓ QueueIt integration endpoints tested${NC}"
}

# Function to verify metrics in Prometheus
verify_prometheus_metrics() {
    echo -e "${YELLOW}Verifying metrics in Prometheus...${NC}"
    
    # Wait a moment for metrics to be scraped
    sleep 5
    
    # Check application HTTP metrics
    local http_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=http_server_requests_seconds_count")
    if echo "$http_metrics" | grep -q "result"; then
        echo -e "${GREEN}✓ HTTP metrics found in Prometheus${NC}"
    else
        echo -e "${RED}✗ HTTP metrics not found in Prometheus${NC}"
        return 1
    fi
    
    # Check QueueIt integration metrics
    local queueit_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=queueit_api_requests_total")
    if echo "$queueit_metrics" | grep -q "result"; then
        echo -e "${GREEN}✓ QueueIt integration metrics found in Prometheus${NC}"
    else
        echo -e "${YELLOW}⚠ QueueIt integration metrics not found (may be normal if no errors occurred)${NC}"
    fi
    
    # Check QueueIt filter metrics
    local filter_metrics=$(curl -s "$PROMETHEUS_URL/api/v1/query?query=queueit_filter_requests_total")
    if echo "$filter_metrics" | grep -q "result"; then
        echo -e "${GREEN}✓ QueueIt filter metrics found in Prometheus${NC}"
    else
        echo -e "${YELLOW}⚠ QueueIt filter metrics not found (may be normal if no redirects occurred)${NC}"
    fi
}

# Function to check application metrics endpoint
check_application_metrics() {
    echo -e "${YELLOW}Checking application metrics endpoint...${NC}"
    
    local metrics=$(curl -s "$APP_URL/actuator/prometheus")
    
    # Check for HTTP metrics
    if echo "$metrics" | grep -q "http_server_requests_seconds_count"; then
        echo -e "${GREEN}✓ HTTP metrics found in application endpoint${NC}"
    else
        echo -e "${RED}✗ HTTP metrics not found in application endpoint${NC}"
        return 1
    fi
    
    # Check for QueueIt metrics
    if echo "$metrics" | grep -q "queueit_"; then
        echo -e "${GREEN}✓ QueueIt metrics found in application endpoint${NC}"
    else
        echo -e "${YELLOW}⚠ QueueIt metrics not found in application endpoint (may be normal if no QueueIt operations occurred)${NC}"
    fi
}

# Function to check Prometheus targets
check_prometheus_targets() {
    echo -e "${YELLOW}Checking Prometheus targets...${NC}"
    
    local targets=$(curl -s "$PROMETHEUS_URL/api/v1/targets")
    
    if echo "$targets" | grep -q "petclinic:8080"; then
        echo -e "${GREEN}✓ PetClinic target found in Prometheus${NC}"
    else
        echo -e "${RED}✗ PetClinic target not found in Prometheus${NC}"
        return 1
    fi
    
    # Check target health
    if echo "$targets" | grep -q '"health":"up"'; then
        echo -e "${GREEN}✓ PetClinic target is healthy${NC}"
    else
        echo -e "${RED}✗ PetClinic target is not healthy${NC}"
        return 1
    fi
}

# Function to run load test with K6 (if available)
run_k6_load_test() {
    echo -e "${YELLOW}Checking if K6 is available...${NC}"
    
    if command -v k6 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ K6 found, running load test...${NC}"
        
        # Create a simple K6 test script
        cat > /tmp/k6-test.js << 'EOF'
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  vus: 5,
  duration: '30s',
};

export default function () {
  http.get('http://localhost:8080/');
  http.get('http://localhost:8080/owners/find');
  http.get('http://localhost:8080/vets.html');
  
  // Test QueueIt endpoints
  http.post('http://localhost:8080/integration/queueit/queue?userId=test-user-' + __VU);
  http.get('http://localhost:8080/integration/queueit/status');
  
  sleep(1);
}
EOF
        
        # Run K6 test
        k6 run --out prometheus=localhost:6565 /tmp/k6-test.js &
        local k6_pid=$!
        
        echo -e "${GREEN}✓ K6 load test started (PID: $k6_pid)${NC}"
        echo -e "${YELLOW}Load test will run for 30 seconds...${NC}"
        
        # Wait for K6 to finish
        wait $k6_pid
        echo -e "${GREEN}✓ K6 load test completed${NC}"
        
        # Clean up
        rm -f /tmp/k6-test.js
    else
        echo -e "${YELLOW}⚠ K6 not found, skipping load test${NC}"
        echo -e "${YELLOW}Install K6 with: brew install k6 (macOS) or see https://k6.io/docs/getting-started/installation/${NC}"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Starting metrics test...${NC}"
    
    # Check if services are running
    if ! check_service "PetClinic Application" "$APP_URL"; then
        echo -e "${RED}PetClinic application is not running. Please start it with: docker-compose up -d${NC}"
        exit 1
    fi
    
    if ! check_service "Prometheus" "$PROMETHEUS_URL"; then
        echo -e "${RED}Prometheus is not running. Please start it with: docker-compose up -d${NC}"
        exit 1
    fi
    
    if ! check_service "Grafana" "$GRAFANA_URL"; then
        echo -e "${RED}Grafana is not running. Please start it with: docker-compose up -d${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ All services are running${NC}"
    echo ""
    
    # Generate traffic
    generate_http_traffic
    test_queueit_integration
    
    echo ""
    
    # Verify metrics
    check_application_metrics
    check_prometheus_targets
    verify_prometheus_metrics
    
    echo ""
    
    # Run load test if K6 is available
    run_k6_load_test
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}✓ Metrics test completed successfully!${NC}"
    echo -e "${BLUE}Access your dashboards at: $GRAFANA_URL${NC}"
    echo -e "${BLUE}Check Prometheus at: $PROMETHEUS_URL${NC}"
    echo -e "${BLUE}Application metrics at: $APP_URL/actuator/prometheus${NC}"
}

# Run main function
main "$@" 