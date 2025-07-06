#!/bin/bash

# S3 Upload Script for K6 Results
# This script uploads test results to S3 bucket

set -e

# Configuration
S3_BUCKET=${S3_BUCKET:-"k6-load-test-results"}
S3_PREFIX=${S3_PREFIX:-"test-results"}
AWS_REGION=${AWS_REGION:-"us-east-1"}
TEST_TYPE=${TEST_TYPE:-"basic"}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to upload results
upload_results() {
    echo "Uploading test results to S3..."
    
    # Create S3 path with timestamp and test type
    S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${TEST_TYPE}/${TIMESTAMP}/"
    
    # Upload JSON results if they exist
    if [ -f "/results/results.json" ]; then
        echo "Uploading results.json..."
        aws s3 cp /results/results.json "${S3_PATH}results.json"
    fi
    
    # Upload any other result files
    if [ -d "/results" ]; then
        echo "Uploading all result files..."
        aws s3 cp /results/ "${S3_PATH}" --recursive --exclude "*.tmp"
    fi
    
    # Create a summary file
    cat > /tmp/test-summary.json << EOF
{
    "test_type": "${TEST_TYPE}",
    "timestamp": "${TIMESTAMP}",
    "target_url": "${TARGET_URL}",
    "aws_region": "${AWS_REGION}",
    "s3_location": "${S3_PATH}",
    "container_id": "$(hostname)",
    "test_duration": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    aws s3 cp /tmp/test-summary.json "${S3_PATH}test-summary.json"
    
    echo "Results uploaded to: ${S3_PATH}"
}

# Function to upload logs
upload_logs() {
    echo "Uploading logs to S3..."
    
    S3_PATH="s3://${S3_BUCKET}/${S3_PREFIX}/${TEST_TYPE}/${TIMESTAMP}/"
    
    # Capture current logs and upload
    if [ -f "/var/log/k6.log" ]; then
        aws s3 cp /var/log/k6.log "${S3_PATH}k6.log"
    fi
    
    echo "Logs uploaded to: ${S3_PATH}"
}

# Main execution
main() {
    echo "Starting S3 upload process..."
    echo "Bucket: ${S3_BUCKET}"
    echo "Prefix: ${S3_PREFIX}"
    echo "Test Type: ${TEST_TYPE}"
    echo "Timestamp: ${TIMESTAMP}"
    
    # Upload results
    upload_results
    
    # Upload logs
    upload_logs
    
    echo "S3 upload completed successfully!"
}

# Run main function
main 