#!/bin/bash

# Enhanced Test Execution Recording Script
# This script helps coordinate recording of K6 test execution with detailed drill-down analysis

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Enhanced Test Execution Recording Guide ===${NC}"
echo ""
echo -e "${YELLOW}This script will help you record your K6 test execution with detailed drill-down analysis.${NC}"
echo ""

# Check if K6 is installed
if ! command -v k6 &> /dev/null; then
    echo -e "${RED}K6 is not installed. Please install K6 first.${NC}"
    echo "Visit: https://k6.io/docs/getting-started/installation/"
    exit 1
fi

echo -e "${GREEN}✓ K6 is installed${NC}"
echo ""

# Enhanced recording setup instructions
echo -e "${BLUE}=== Recording Setup ===${NC}"
echo "1. Open your browser and navigate to: http://localhost:3000"
echo "2. Login to Grafana (admin/admin)"
echo "3. Open the 'Queue-it Load Testing' dashboard"
echo "4. Open Prometheus at: http://localhost:9090"
echo "5. Start your screen recording software"
echo ""

# Enhanced test configuration
echo -e "${BLUE}=== Test Configuration ===${NC}"
echo "Test Duration: 3 minutes (for detailed analysis)"
echo "Virtual Users: 50 (for clearer patterns)"
echo "Target Endpoints: /integration/queueit/queue, /integration/queueit/enqueue"
echo ""

# Enhanced recording timeline with drill-down sections
echo -e "${BLUE}=== Enhanced Recording Timeline (5 minutes) ===${NC}"
echo -e "${CYAN}Phase 1: Overview (00:00 - 01:00)${NC}"
echo "  • Show dashboard overview and K6 panels"
echo "  • Explain what you're looking for"
echo "  • Point out key metrics to watch"
echo ""
echo -e "${CYAN}Phase 2: Test Execution (01:00 - 02:00)${NC}"
echo "  • Start K6 test execution"
echo "  • Show real-time dashboard updates"
echo "  • Highlight Queue-it redirect spikes"
echo ""
echo -e "${CYAN}Phase 3: Queue-it Response Analysis (02:00 - 03:00)${NC}"
echo "  • Drill down into Queue-it redirect responses"
echo "  • Show actual redirect URLs and timing"
echo "  • Analyze response headers and status codes"
echo ""
echo -e "${CYAN}Phase 4: Latency & Timing Analysis (03:00 - 04:00)${NC}"
echo "  • Show response time distributions"
echo "  • Compare successful vs redirected request latencies"
echo "  • Analyze timing patterns"
echo ""
echo -e "${CYAN}Phase 5: Request Details & Prometheus Queries (04:00 - 05:00)${NC}"
echo "  • Show actual HTTP requests being made"
echo "  • Demonstrate Prometheus queries for detailed metrics"
echo "  • Analyze request patterns and volumes"
echo ""

# K6 test command with enhanced output
echo -e "${BLUE}=== Enhanced K6 Test Command ===${NC}"
echo "Run this command in a separate terminal:"
echo ""
echo -e "${YELLOW}cd testing-projects/k6-load-test && \\"
echo "k6 run --vus 50 --duration 3m --out json=test-results.json k6-load-test.js${NC}"
echo ""

# Detailed analysis sections
echo -e "${BLUE}=== Detailed Analysis Sections ===${NC}"
echo ""
echo -e "${PURPLE}1. Queue-it Response Analysis:${NC}"
echo "   • Navigate to Prometheus: http://localhost:9090"
echo "   • Query: rate(queueit_redirects[1m])"
echo "   • Query: rate(successful_responses[1m])"
echo "   • Show response time: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
echo ""
echo -e "${PURPLE}2. Request Timing Analysis:${NC}"
echo "   • Grafana panel: 'Test Response Times'"
echo "   • Show 95th percentile vs median"
echo "   • Compare successful vs redirected request times"
echo ""
echo -e "${PURPLE}3. Actual Request Inspection:${NC}"
echo "   • Use browser DevTools Network tab"
echo "   • Show actual HTTP requests to /queue and /enqueue"
echo "   • Point out redirect responses (302/303 status codes)"
echo "   • Show Location headers pointing to queue-it.net"
echo ""
echo -e "${PURPLE}4. Latency Distribution:${NC}"
echo "   • Prometheus query: histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))"
echo "   • Prometheus query: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))"
echo "   • Show how Queue-it redirects affect overall latency"
echo ""

# What to look for in detail
echo -e "${BLUE}=== Detailed What to Look For ===${NC}"
echo "✅ K6 Queue-it Redirects panel showing spikes"
echo "✅ Successful Responses panel showing activity"
echo "✅ Real-time updates in Grafana"
echo "✅ Redirect response times vs successful response times"
echo "✅ Actual HTTP 302/303 responses in browser DevTools"
echo "✅ Location headers containing 'queue-it.net'"
echo "❌ If redirects stay at zero, check trigger path configuration"
echo ""

# Enhanced recording tips
echo -e "${BLUE}=== Enhanced Recording Tips ===${NC}"
echo "• Use 3-minute test duration for detailed analysis"
echo "• Keep Grafana dashboard, Prometheus, and browser DevTools visible"
echo "• Point out specific metrics and their significance"
echo "• Show the correlation between K6 load and Queue-it responses"
echo "• Demonstrate how to read and interpret the detailed metrics"
echo "• Show actual HTTP request/response cycles"
echo ""

# Browser DevTools setup
echo -e "${BLUE}=== Browser DevTools Setup ===${NC}"
echo "1. Open browser DevTools (F12)"
echo "2. Go to Network tab"
echo "3. Filter by 'Fetch/XHR'"
echo "4. Clear network log"
echo "5. Start recording network activity"
echo ""

# Start recording prompt
echo -e "${YELLOW}Ready to start enhanced recording?${NC}"
echo "1. Set up your screen recording software"
echo "2. Open Grafana dashboard"
echo "3. Open Prometheus in another tab"
echo "4. Open browser DevTools Network tab"
echo "5. Position windows for optimal viewing"
echo "6. Press Enter when ready to continue..."
read -p ""

echo ""
echo -e "${GREEN}=== Enhanced Recording Started ===${NC}"
echo "Follow the detailed timeline above to create your comprehensive test execution video."
echo ""
echo -e "${BLUE}Good luck with your detailed recording!${NC}" 