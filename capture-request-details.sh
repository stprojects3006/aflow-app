#!/bin/bash

# Request Details Capture Script
# Captures detailed HTTP request/response information for Queue-it analysis

set -e

# Configuration
BASE_URL="${BASE_URL:-http://localhost:8080}"
OUTPUT_DIR="${OUTPUT_DIR:-request-analysis}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Request Details Capture Script ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo "Base URL: $BASE_URL"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to capture request details
capture_request() {
    local endpoint=$1
    local output_file="$OUTPUT_DIR/${endpoint}_${TIMESTAMP}.txt"
    
    echo -e "${YELLOW}Capturing request details for: $endpoint${NC}"
    
    # Use curl with detailed output
    curl -v -w "\n\n=== TIMING DETAILS ===\n" \
         -w "DNS Lookup: %{time_namelookup}s\n" \
         -w "TCP Connect: %{time_connect}s\n" \
         -w "TLS Handshake: %{time_appconnect}s\n" \
         -w "First Byte: %{time_starttransfer}s\n" \
         -w "Total Time: %{time_total}s\n" \
         -w "HTTP Status: %{http_code}\n" \
         -w "Redirect URL: %{redirect_url}\n" \
         -w "Size: %{size_download} bytes\n" \
         -w "Speed: %{speed_download} bytes/sec\n" \
         -H "Content-Type: application/json" \
         -d '{"userId":"test-user-123"}' \
         "$BASE_URL$endpoint" > "$output_file" 2>&1
    
    echo -e "${GREEN}✓ Captured to: $output_file${NC}"
    
    # Extract key information
    local status_code=$(grep "HTTP Status:" "$output_file" | cut -d' ' -f3)
    local redirect_url=$(grep "Redirect URL:" "$output_file" | cut -d' ' -f3)
    local total_time=$(grep "Total Time:" "$output_file" | cut -d' ' -f3)
    
    echo "  Status: $status_code"
    echo "  Time: ${total_time}s"
    if [ "$redirect_url" != "(null)" ]; then
        echo "  Redirect: $redirect_url"
    fi
    echo ""
}

# Capture requests for both endpoints
echo -e "${BLUE}=== Capturing Request Details ===${NC}"
capture_request "/integration/queueit/queue"
capture_request "/integration/queueit/enqueue"

# Create summary report
SUMMARY_FILE="$OUTPUT_DIR/summary_${TIMESTAMP}.md"
echo -e "${BLUE}=== Creating Summary Report ===${NC}"

cat > "$SUMMARY_FILE" << EOF
# Queue-it Request Analysis Summary
Generated: $(date)

## Test Configuration
- Base URL: $BASE_URL
- Timestamp: $TIMESTAMP

## Endpoints Tested
1. /integration/queueit/queue
2. /integration/queueit/enqueue

## Analysis Files
- Queue endpoint: \`${OUTPUT_DIR}/integration/queueit/queue_${TIMESTAMP}.txt\`
- Enqueue endpoint: \`${OUTPUT_DIR}/integration/queueit/enqueue_${TIMESTAMP}.txt\`

## Key Metrics to Check
1. **HTTP Status Codes**: Look for 302/303 redirects
2. **Location Headers**: Should contain 'queue-it.net' for redirects
3. **Response Times**: Compare successful vs redirected requests
4. **Request Headers**: Check for Queue-it specific headers

## Prometheus Queries for Analysis
\`\`\`
# Queue-it redirect rate
rate(queueit_redirects[1m])

# Successful response rate
rate(successful_responses[1m])

# Response time percentiles
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
\`\`\`

## Grafana Dashboard Panels
1. **K6 Queue-it Redirects**: Shows redirect rate over time
2. **K6 Successful Responses**: Shows successful request rate
3. **Test Response Times**: Shows latency distribution
4. **Test Success Rate**: Shows overall success percentage

## Browser DevTools Analysis
1. Open Network tab in browser DevTools
2. Filter by 'Fetch/XHR'
3. Look for requests to /integration/queueit/*
4. Check response status codes and headers
5. Look for Location headers in redirect responses
EOF

echo -e "${GREEN}✓ Summary report created: $SUMMARY_FILE${NC}"
echo ""

# Display quick analysis
echo -e "${BLUE}=== Quick Analysis ===${NC}"
echo "Check the following files for detailed analysis:"
echo "  • Request details: $OUTPUT_DIR/"
echo "  • Summary report: $SUMMARY_FILE"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the captured request files"
echo "2. Check for Queue-it redirects (302/303 status codes)"
echo "3. Analyze timing differences between successful and redirected requests"
echo "4. Use the summary report for your video recording"
echo ""
echo -e "${GREEN}Capture completed!${NC}" 