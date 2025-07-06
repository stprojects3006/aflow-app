#!/bin/bash

# Enhanced k6 Load Test Runner with IP Rotation Support
# This script runs k6 load tests with optional IP rotation

set -e

# Configuration
TARGET_URL=${TARGET_URL:-"https://affluenceit.com/"}
TEST_SCRIPT=${TEST_SCRIPT:-"/scripts/basic-load-test.js"}
IP_ROTATION_ENABLED=${IP_ROTATION_ENABLED:-"false"}
PROXY_TYPE=${PROXY_TYPE:-"static"}
PROXY_SERVICE_URL=${PROXY_SERVICE_URL:-"http://localhost:8080"}
VU_IP_MAPPING_ENABLED=${VU_IP_MAPPING_ENABLED:-"false"}
MAX_PROXY_IPS=${MAX_PROXY_IPS:-10}
TEST_PROXY=${TEST_PROXY:-"false"}

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to setup proxy services
setup_proxy_services() {
    if [ "$IP_ROTATION_ENABLED" = "true" ]; then
        log "Setting up proxy services for IP rotation"
        
        # Start proxy setup script
        /scripts/setup-proxy.sh &
        PROXY_PID=$!
        
        # Wait for proxy services to start
        sleep 10
        
        # Test proxy services
        if [ "$TEST_PROXY" = "true" ]; then
            log "Testing proxy services"
            curl -s http://localhost:8080/status > /dev/null && log "Proxy service is running" || log "Proxy service test failed"
        fi
    fi
}

# Function to run k6 with IP rotation
run_k6_with_ip_rotation() {
    local script_path=$1
    
    log "Running k6 with IP rotation enabled"
    log "Target URL: $TARGET_URL"
    log "Test Script: $script_path"
    log "Proxy Type: $PROXY_TYPE"
    log "Proxy Service URL: $PROXY_SERVICE_URL"
    
    # Set environment variables for k6
    export K6_OUT=json=/results/results.json
    export K6_OUT_JSON=true
    export K6_OUT_INFLUXDB=false
    
    # Run k6 with IP rotation environment variables
    k6 run \
        --env TARGET_URL="$TARGET_URL" \
        --env IP_ROTATION_ENABLED="$IP_ROTATION_ENABLED" \
        --env PROXY_TYPE="$PROXY_TYPE" \
        --env PROXY_SERVICE_URL="$PROXY_SERVICE_URL" \
        --env VU_IP_MAPPING_ENABLED="$VU_IP_MAPPING_ENABLED" \
        --env MAX_PROXY_IPS="$MAX_PROXY_IPS" \
        --env TEST_PROXY="$TEST_PROXY" \
        --out json=/results/ip-rotation-results.json \
        --out influxdb=http://localhost:8086/k6 \
        "$script_path"
}

# Function to run k6 without IP rotation
run_k6_standard() {
    local script_path=$1
    
    log "Running k6 without IP rotation"
    log "Target URL: $TARGET_URL"
    log "Test Script: $script_path"
    
    # Set environment variables for k6
    export K6_OUT=json=/results/results.json
    export K6_OUT_JSON=true
    export K6_OUT_INFLUXDB=false
    
    # Run k6 with standard configuration
    k6 run \
        --env TARGET_URL="$TARGET_URL" \
        --out json=/results/results.json \
        --out influxdb=http://localhost:8086/k6 \
        "$script_path"
}

# Function to upload results to S3
upload_results_to_s3() {
    log "Uploading results to S3"
    
    # Get AWS account ID and region
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=${AWS_REGION:-$(aws configure get region)}
    
    if [ -z "$AWS_ACCOUNT_ID" ] || [ -z "$AWS_REGION" ]; then
        log "Error: AWS credentials not configured"
        return 1
    fi
    
    # S3 bucket name
    S3_BUCKET="k6-load-test-results-${AWS_ACCOUNT_ID}"
    
    # Create timestamp for unique folder
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    FOLDER_NAME="ip-rotation-test-${TIMESTAMP}"
    
    # Upload results
    if [ "$IP_ROTATION_ENABLED" = "true" ]; then
        # Upload IP rotation specific results
        aws s3 cp /results/ip-rotation-results.json "s3://${S3_BUCKET}/ip-rotation-results/${FOLDER_NAME}/"
        aws s3 cp /results/ip-rotation-summary.json "s3://${S3_BUCKET}/ip-rotation-results/${FOLDER_NAME}/" 2>/dev/null || true
        aws s3 cp /results/basic-load-test-ip-rotation-summary.json "s3://${S3_BUCKET}/ip-rotation-results/${FOLDER_NAME}/" 2>/dev/null || true
    else
        # Upload standard results
        aws s3 cp /results/results.json "s3://${S3_BUCKET}/load-test-results/${FOLDER_NAME}/"
    fi
    
    log "Results uploaded to s3://${S3_BUCKET}/${FOLDER_NAME}/"
}

# Function to generate IP rotation report
generate_ip_rotation_report() {
    if [ "$IP_ROTATION_ENABLED" = "true" ]; then
        log "Generating IP rotation report"
        
        # Create report
        cat > /results/ip-rotation-report.md << EOF
# IP Rotation Load Test Report

## Test Configuration
- **Target URL**: $TARGET_URL
- **IP Rotation Enabled**: $IP_ROTATION_ENABLED
- **Proxy Type**: $PROXY_TYPE
- **Proxy Service URL**: $PROXY_SERVICE_URL
- **VU IP Mapping**: $VU_IP_MAPPING_ENABLED
- **Max Proxy IPs**: $MAX_PROXY_IPS

## Test Results
- **Test Script**: $TEST_SCRIPT
- **Timestamp**: $(date)
- **Container ID**: $(hostname)

## IP Rotation Details
- **Method**: Container-level IP rotation
- **Proxy Assignment**: Per VU basis
- **IP Diversity**: $MAX_PROXY_IPS unique IPs available

## Usage Instructions
1. Set IP_ROTATION_ENABLED=true to enable IP rotation
2. Choose PROXY_TYPE: static, rotating, tor, privoxy
3. Configure PROXY_SERVICE_URL for rotating proxies
4. Set VU_IP_MAPPING_ENABLED=true to track IP usage

## Files Generated
- ip-rotation-results.json: Detailed test results
- ip-rotation-summary.json: Summary with IP mapping
- basic-load-test-ip-rotation-summary.json: Basic test summary
EOF

        # Upload report
        aws s3 cp /results/ip-rotation-report.md "s3://${S3_BUCKET}/ip-rotation-results/${FOLDER_NAME}/" 2>/dev/null || true
    fi
}

# Main execution
log "Starting k6 load test with IP rotation support"

# Setup proxy services if IP rotation is enabled
setup_proxy_services

# Run k6 test
if [ "$IP_ROTATION_ENABLED" = "true" ]; then
    run_k6_with_ip_rotation "$TEST_SCRIPT"
else
    run_k6_standard "$TEST_SCRIPT"
fi

# Generate IP rotation report
generate_ip_rotation_report

# Upload results to S3
upload_results_to_s3

log "k6 load test completed successfully"

# Cleanup proxy services if running
if [ -n "$PROXY_PID" ]; then
    log "Cleaning up proxy services"
    kill $PROXY_PID 2>/dev/null || true
fi 