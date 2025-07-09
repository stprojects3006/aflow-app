#!/bin/bash

# QueueIt Load Test Result Collection Script
# Collects and aggregates results from S3, CloudWatch, and local logs

set -e

# Load configuration
CONFIG_FILE="../config/test-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Parse configuration
S3_BUCKET=$(jq -r '.aws.s3.bucket' "$CONFIG_FILE")
CLOUDWATCH_LOG_GROUP=$(jq -r '.aws.cloudwatch.log_group' "$CONFIG_FILE")
TARGET_URL=$(jq -r '.test.target.base_url' "$CONFIG_FILE")

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --test-id TEST_ID    Specific test ID to collect results for"
    echo "  -a, --all                Collect results for all tests"
    echo "  -d, --days DAYS          Collect results from last N days (default: 1)"
    echo "  -o, --output DIR         Output directory for collected results"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -t 20241201-143022    Collect results for specific test"
    echo "  $0 -a -d 7               Collect all results from last 7 days"
    echo "  $0 -o ./my-results       Collect to specific output directory"
}

# Parse command line arguments
TEST_ID=""
COLLECT_ALL=false
DAYS=1
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--test-id)
            TEST_ID="$2"
            shift 2
            ;;
        -a|--all)
            COLLECT_ALL=true
            shift
            ;;
        -d|--days)
            DAYS="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set default output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="../results/collected-$(date +%Y%m%d-%H%M%S)"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

log "🚀 Starting QueueIt Load Test Result Collection"
log "📊 Configuration:"
log "   S3 Bucket: $S3_BUCKET"
log "   CloudWatch Log Group: $CLOUDWATCH_LOG_GROUP"
log "   Target URL: $TARGET_URL"
log "   Output Directory: $OUTPUT_DIR"

# Function to collect results for a specific test
collect_test_results() {
    local test_id="$1"
    local test_dir="$OUTPUT_DIR/$test_id"
    
    log "📥 Collecting results for test: $test_id"
    mkdir -p "$test_dir"
    
    # Download from S3
    log "   📤 Downloading from S3..."
    if aws s3 ls "s3://$S3_BUCKET/test-results/$test_id/" >/dev/null 2>&1; then
        aws s3 cp "s3://$S3_BUCKET/test-results/$test_id/" "$test_dir/s3/" --recursive >/dev/null 2>&1 || log "   ⚠️  Warning: Failed to download from S3"
    else
        log "   ℹ️  No S3 results found for test $test_id"
    fi
    
    # Download CloudWatch logs
    log "   📊 Downloading CloudWatch logs..."
    aws logs filter-log-events \
        --log-group-name "$CLOUDWATCH_LOG_GROUP" \
        --start-time $(date -d "$DAYS days ago" +%s)000 \
        --filter-pattern "$test_id" \
        --query 'events[*].{timestamp:timestamp,message:message}' \
        --output json > "$test_dir/cloudwatch-logs.json" 2>/dev/null || log "   ⚠️  Warning: Failed to download CloudWatch logs"
    
    # Generate test summary
    log "   📋 Generating test summary..."
    cat > "$test_dir/test-summary.md" << EOF
# QueueIt Load Test Results - $test_id

**Collection Date:** $(date)  
**Target URL:** $TARGET_URL  

## Files Collected
- **S3 Results:** $test_dir/s3/ (if available)
- **CloudWatch Logs:** $test_dir/cloudwatch-logs.json
- **Test Summary:** $test_dir/test-summary.md

## Analysis
Review the collected files to analyze:
1. QueueIt redirect patterns
2. Response times and success rates
3. Error patterns and failures
4. IP diversity and session handling

## Next Steps
1. Review CloudWatch logs for detailed execution
2. Check S3 results for k6 output files
3. Analyze QueueIt integration behavior
EOF
}

# Function to collect all recent tests
collect_all_results() {
    log "📥 Collecting all test results from last $DAYS days..."
    
    # List recent test directories from S3
    RECENT_TESTS=$(aws s3 ls "s3://$S3_BUCKET/test-results/" | grep -E "^PRE [0-9]{8}-[0-9]{6}/" | awk '{print $2}' | sed 's/\///' | tail -20)
    
    if [ -z "$RECENT_TESTS" ]; then
        log "ℹ️  No recent test results found in S3"
        return
    fi
    
    for test_id in $RECENT_TESTS; do
        collect_test_results "$test_id"
    done
}

# Function to generate aggregated report
generate_aggregated_report() {
    log "📊 Generating aggregated report..."
    
    cat > "$OUTPUT_DIR/aggregated-report.md" << EOF
# QueueIt Load Test - Aggregated Results Report

**Generated:** $(date)  
**Target URL:** $TARGET_URL  
**Collection Period:** Last $DAYS days  

## Test Summary
$(find "$OUTPUT_DIR" -name "test-summary.md" -exec basename -s .md {} \; | wc -l) tests collected

## Test Results
$(for test_dir in "$OUTPUT_DIR"/*/; do
    if [ -d "$test_dir" ]; then
        test_id=$(basename "$test_dir")
        echo "- **$test_id:** [View Results]($test_id/)"
    fi
done)

## Key Metrics
- **Total Tests:** $(find "$OUTPUT_DIR" -name "test-summary.md" | wc -l)
- **S3 Results Available:** $(find "$OUTPUT_DIR" -name "s3" -type d | wc -l)
- **CloudWatch Logs Available:** $(find "$OUTPUT_DIR" -name "cloudwatch-logs.json" | wc -l)

## Analysis Recommendations
1. **QueueIt Integration:** Check redirect patterns and success rates
2. **Performance:** Analyze response times and throughput
3. **Errors:** Review error patterns and failure modes
4. **IP Diversity:** Verify unique IP usage across tests

## Files Structure
\`\`\`
$OUTPUT_DIR/
├── aggregated-report.md
├── test-id-1/
│   ├── s3/                    # S3 downloaded results
│   ├── cloudwatch-logs.json   # CloudWatch logs
│   └── test-summary.md        # Test summary
└── test-id-2/
    └── ...
\`\`\`
EOF
}

# Main execution
if [ -n "$TEST_ID" ]; then
    # Collect specific test
    collect_test_results "$TEST_ID"
elif [ "$COLLECT_ALL" = true ]; then
    # Collect all tests
    collect_all_results
    generate_aggregated_report
else
    echo "❌ Please specify either --test-id or --all"
    show_usage
    exit 1
fi

# Final summary
log "🎉 Result collection completed!"
log "📁 Results saved to: $OUTPUT_DIR"
log "📊 Files collected:"
log "   - Test results: $(find "$OUTPUT_DIR" -name "test-summary.md" | wc -l)"
log "   - S3 downloads: $(find "$OUTPUT_DIR" -name "s3" -type d | wc -l)"
log "   - CloudWatch logs: $(find "$OUTPUT_DIR" -name "cloudwatch-logs.json" | wc -l)"

echo ""
echo "🏁 Result collection completed successfully!"
echo "📁 Check results in: $OUTPUT_DIR" 