#!/bin/bash

# K6 Load Test with IP Spoofing Script
# This script runs K6 load tests with IP spoofing to simulate traffic from different IP addresses

set -e

echo "=========================================="
echo "  K6 Load Test with IP Spoofing"
echo "=========================================="

# Configuration
BASE_URL=${BASE_URL:-"http://localhost:8080"}
VUS=${VUS:-50}
DURATION=${DURATION:-"2m"}
DEBUG=${DEBUG:-"false"}
API_KEY=${API_KEY:-"test-api-key"}
CUSTOMER_ID=${CUSTOMER_ID:-"test-customer-id"}
SECRET_KEY=${SECRET_KEY:-"test-secret-key"}

# Check if K6 is installed
if ! command -v k6 &> /dev/null; then
    echo "❌ K6 is not installed. Please install K6 first:"
    echo "   macOS: brew install k6"
    echo "   Linux: https://k6.io/docs/getting-started/installation/"
    exit 1
fi

# Check if application is running
echo "Checking application status..."
if ! curl -s "$BASE_URL/actuator/health" > /dev/null; then
    echo "❌ Application is not running at $BASE_URL"
    echo "   Please start the application first: docker-compose up -d"
    exit 1
fi
echo "✅ Application is running"

# Check if Prometheus is running for metrics
echo "Checking Prometheus status..."
if ! curl -s "http://localhost:9090/-/healthy" > /dev/null; then
    echo "⚠️  Prometheus is not running. Metrics will not be collected."
    echo "   Start Prometheus: docker-compose up prometheus -d"
fi

# Create results directory
RESULTS_DIR="testing-projects/k6-load-test/results"
mkdir -p "$RESULTS_DIR"

# Generate timestamp for this test run
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$RESULTS_DIR/ip-spoofing-test-$TIMESTAMP.json"

echo ""
echo "Test Configuration:"
echo "  Base URL: $BASE_URL"
echo "  Virtual Users: $VUS"
echo "  Duration: $DURATION"
echo "  Debug Mode: $DEBUG"
echo "  Results File: $RESULTS_FILE"
echo ""

# Run the IP spoofing load test
echo "🚀 Starting K6 Load Test with IP Spoofing..."
echo "   This will simulate traffic from different IP addresses"
echo ""

k6 run \
    --env BASE_URL="$BASE_URL" \
    --env VUS="$VUS" \
    --env DURATION="$DURATION" \
    --env DEBUG="$DEBUG" \
    --env API_KEY="$API_KEY" \
    --env CUSTOMER_ID="$CUSTOMER_ID" \
    --env SECRET_KEY="$SECRET_KEY" \
    --out json="$RESULTS_FILE" \
    testing-projects/k6-load-test/k6-load-test-with-ip-spoofing.js

echo ""
echo "✅ Load test completed!"
echo "📊 Results saved to: $RESULTS_FILE"

# Display summary if results file exists
if [ -f "$RESULTS_FILE" ]; then
    echo ""
    echo "📈 Test Summary:"
    echo "=================="
    
    # Extract key metrics from results
    TOTAL_REQUESTS=$(jq -r '.metrics.http_reqs.count // 0' "$RESULTS_FILE")
    SUCCESSFUL_RESPONSES=$(jq -r '.metrics.successful_responses.count // 0' "$RESULTS_FILE")
    ERROR_RESPONSES=$(jq -r '.metrics.error_responses.count // 0' "$RESULTS_FILE")
    QUEUEIT_REDIRECTS=$(jq -r '.metrics.queueit_redirects.count // 0' "$RESULTS_FILE")
    AVG_RESPONSE_TIME=$(jq -r '.metrics.response_time.avg // 0' "$RESULTS_FILE")
    P95_RESPONSE_TIME=$(jq -r '.metrics.response_time.p(95) // 0' "$RESULTS_FILE")
    ERROR_RATE=$(jq -r '.metrics.error_rate.rate // 0' "$RESULTS_FILE")
    
    echo "  Total Requests: $TOTAL_REQUESTS"
    echo "  Successful Responses: $SUCCESSFUL_RESPONSES"
    echo "  Error Responses: $ERROR_RESPONSES"
    echo "  QueueIt Redirects: $QUEUEIT_REDIRECTS"
    echo "  Average Response Time: ${AVG_RESPONSE_TIME}ms"
    echo "  95th Percentile Response Time: ${P95_RESPONSE_TIME}ms"
    echo "  Error Rate: $(echo "$ERROR_RATE * 100" | bc -l | cut -c1-5)%"
    
    # Calculate success rate
    if [ "$TOTAL_REQUESTS" -gt 0 ]; then
        SUCCESS_RATE=$(echo "scale=2; $SUCCESSFUL_RESPONSES * 100 / $TOTAL_REQUESTS" | bc -l)
        echo "  Success Rate: ${SUCCESS_RATE}%"
    fi
fi

echo ""
echo "🌐 Check your Grafana dashboards for real-time metrics:"
echo "   http://localhost:3000"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "📋 Available dashboards:"
echo "   - QueueIt Integration Dashboard"
echo "   - QueueIt Error Tracking Dashboard"
echo "   - Application HTTP Traffic Dashboard"
echo "   - PetClinic HTTP Traffic Dashboard"
echo ""

# Optional: Generate traffic to populate dashboards
echo "🔄 Generating additional traffic to populate dashboards..."
for i in {1..20}; do
    curl -s "$BASE_URL/integration/queueit/health" > /dev/null
    curl -s "$BASE_URL/owners/find" > /dev/null
    curl -s "$BASE_URL/vets" > /dev/null
    sleep 0.1
done
echo "✅ Additional traffic generated"

echo ""
echo "🎯 IP Spoofing Load Test completed successfully!"
echo "   The test simulated traffic from multiple IP addresses"
echo "   Check your application logs and Grafana dashboards for results" 