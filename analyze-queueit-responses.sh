#!/bin/bash

# Queue-it Response Analysis Script
# Analyzes Queue-it responses and provides detailed metrics for recording

set -e

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
ANALYSIS_DURATION="${ANALYSIS_DURATION:-5m}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}=== Queue-it Response Analysis Script ===${NC}"
echo "Analysis Duration: $ANALYSIS_DURATION"
echo ""

# Function to query Prometheus
query_prometheus() {
    local query="$1"
    local description="$2"
    
    echo -e "${YELLOW}$description${NC}"
    echo "Query: $query"
    
    local result=$(curl -s -G --data-urlencode "query=$query" "$PROMETHEUS_URL/api/v1/query")
    echo "Result: $result"
    echo ""
}

# Function to get Grafana dashboard info
get_dashboard_info() {
    echo -e "${PURPLE}=== Grafana Dashboard Analysis ===${NC}"
    echo "Dashboard URL: $GRAFANA_URL"
    echo "Dashboard: Queue-it Load Testing"
    echo ""
    echo "Key Panels to Monitor:"
    echo "1. K6 Queue-it Redirects (bottom of dashboard)"
    echo "2. K6 Successful Responses (bottom of dashboard)"
    echo "3. Test Response Times (middle section)"
    echo "4. Test Success Rate (top section)"
    echo ""
}

# Main analysis
echo -e "${BLUE}=== Prometheus Metrics Analysis ===${NC}"
echo ""

# Queue-it specific metrics
query_prometheus "rate(queueit_redirects[1m])" "Queue-it Redirect Rate (per second)"
query_prometheus "rate(successful_responses[1m])" "Successful Response Rate (per second)"
query_prometheus "queueit_redirects" "Total Queue-it Redirects"
query_prometheus "successful_responses" "Total Successful Responses"

# Response time analysis
query_prometheus "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))" "Median Response Time"
query_prometheus "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))" "95th Percentile Response Time"
query_prometheus "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))" "99th Percentile Response Time"

# Success rate analysis
query_prometheus "rate(successful_responses[5m]) / (rate(successful_responses[5m]) + rate(queueit_redirects[5m])) * 100" "Success Rate Percentage"

# Get dashboard info
get_dashboard_info

# Recording guidance
echo -e "${PURPLE}=== Recording Guidance ===${NC}"
echo ""
echo "For your video recording, focus on these key points:"
echo ""
echo "1. **Queue-it Redirect Detection**:"
echo "   • Show spikes in 'K6 Queue-it Redirects' panel"
echo "   • Explain that spikes indicate Queue-it waiting room activation"
echo "   • Point out the correlation with load increases"
echo ""
echo "2. **Response Time Analysis**:"
echo "   • Compare successful vs redirected request times"
echo "   • Show how Queue-it redirects affect overall latency"
echo "   • Demonstrate 95th percentile vs median differences"
echo ""
echo "3. **Request Flow Visualization**:"
echo "   • Use browser DevTools to show actual HTTP requests"
echo "   • Point out 302/303 status codes for redirects"
echo "   • Show Location headers containing 'queue-it.net'"
echo ""
echo "4. **Success Rate Patterns**:"
echo "   • Show how success rate changes under load"
echo "   • Explain the balance between successful responses and redirects"
echo "   • Demonstrate Queue-it's protective behavior"
echo ""

echo -e "${GREEN}Analysis completed! Use these metrics for your detailed recording.${NC}" 