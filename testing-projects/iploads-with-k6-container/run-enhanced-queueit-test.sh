#!/bin/bash

# Enhanced QueueIt Load Test Runner
# Features: Real AWS config, result collection, monitoring, error handling

set -e

# Load configuration
CONFIG_FILE="config/test-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Parse configuration using jq
CLUSTER_NAME=$(jq -r '.aws.cluster.name' "$CONFIG_FILE")
SUBNET_ID=$(jq -r '.aws.network.subnet_id' "$CONFIG_FILE")
SECURITY_GROUP_ID=$(jq -r '.aws.network.security_group_id' "$CONFIG_FILE")
S3_BUCKET=$(jq -r '.aws.s3.bucket' "$CONFIG_FILE")
CLOUDWATCH_LOG_GROUP=$(jq -r '.aws.cloudwatch.log_group' "$CONFIG_FILE")
TASK_ROLE_ARN=$(jq -r '.aws.iam.task_role' "$CONFIG_FILE")
EXECUTION_ROLE_ARN=$(jq -r '.aws.iam.execution_role' "$CONFIG_FILE")
TARGET_URL=$(jq -r '.test.target.base_url' "$CONFIG_FILE")
NUM_TASKS=$(jq -r '.test.parameters.num_tasks' "$CONFIG_FILE")
DURATION=$(jq -r '.test.parameters.duration_seconds' "$CONFIG_FILE")

# Test configuration
TASK_DEFINITION_FILE="task-def-single-vu-owners.json"
TEST_ID=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="results/$TEST_ID"
LOCAL_LOGS_DIR="$RESULTS_DIR/logs"
S3_RESULTS_PATH="s3://$S3_BUCKET/test-results/$TEST_ID"

echo "🚀 Enhanced QueueIt Load Test"
echo "================================"
echo "📊 Configuration:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Subnet: $SUBNET_ID"
echo "   Security Group: $SECURITY_GROUP_ID"
echo "   Target URL: $TARGET_URL"
echo "   Number of Tasks: $NUM_TASKS"
echo "   Duration: ${DURATION}s per task"
echo "   Test ID: $TEST_ID"
echo "   Results: $S3_RESULTS_PATH"
echo ""

# Create local results directory
mkdir -p "$LOCAL_LOGS_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOCAL_LOGS_DIR/test-run.log"
}

# Function to handle errors
handle_error() {
    log "❌ Error occurred: $1"
    log "🔄 Cleaning up..."
    cleanup
    exit 1
}

# Function to cleanup resources
cleanup() {
    log "🧹 Cleaning up resources..."
    
    # Stop running tasks
    RUNNING_TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --family k6-single-vu-test --query 'taskArns' --output text 2>/dev/null || echo "")
    if [ -n "$RUNNING_TASKS" ]; then
        log "🛑 Stopping running tasks..."
        aws ecs stop-task --cluster "$CLUSTER_NAME" --task "$RUNNING_TASKS" >/dev/null 2>&1 || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Validate AWS configuration
log "🔍 Validating AWS configuration..."
if ! aws ecs describe-clusters --clusters "$CLUSTER_NAME" >/dev/null 2>&1; then
    handle_error "Cluster $CLUSTER_NAME not found"
fi

if ! aws ec2 describe-subnets --subnet-ids "$SUBNET_ID" >/dev/null 2>&1; then
    handle_error "Subnet $SUBNET_ID not found"
fi

if ! aws ec2 describe-security-groups --group-ids "$SECURITY_GROUP_ID" >/dev/null 2>&1; then
    handle_error "Security group $SECURITY_GROUP_ID not found"
fi

log "✅ AWS configuration validated"

# Register task definition
log "📝 Registering task definition..."
if ! aws ecs register-task-definition --cli-input-json file://"$TASK_DEFINITION_FILE" >/dev/null; then
    handle_error "Failed to register task definition"
fi

# Get the latest revision
TASK_DEFINITION_ARN=$(aws ecs describe-task-definition --task-definition k6-single-vu-test --query 'taskDefinition.taskDefinitionArn' --output text)
log "✅ Task definition registered: $TASK_DEFINITION_ARN"

# Start monitoring in background
log "📊 Starting CloudWatch monitoring..."
(
    aws logs tail "$CLOUDWATCH_LOG_GROUP" --follow --since 1m > "$LOCAL_LOGS_DIR/cloudwatch.log" 2>&1 &
    CLOUDWATCH_PID=$!
    echo $CLOUDWATCH_PID > "$LOCAL_LOGS_DIR/cloudwatch.pid"
) &

# Start multiple tasks
log "🚀 Starting $NUM_TASKS individual VU tasks..."
TASK_ARNS=()

for i in $(seq 1 $NUM_TASKS); do
    log "Starting task $i of $NUM_TASKS..."
    
    # Run task and capture ARN
    TASK_ARN=$(aws ecs run-task \
        --cluster "$CLUSTER_NAME" \
        --task-definition "$TASK_DEFINITION_ARN" \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --overrides "containerOverrides=[{name=k6-single-vu,environment=[{name=TASK_ID,value=task-$i}]}]" \
        --query 'tasks[0].taskArn' \
        --output text)
    
    if [ "$TASK_ARN" = "None" ] || [ -z "$TASK_ARN" ]; then
        handle_error "Failed to start task $i"
    fi
    
    TASK_ARNS+=("$TASK_ARN")
    log "✅ Task $i started: $TASK_ARN"
    
    # Small delay between task starts
    sleep 2
done

log "✅ All $NUM_TASKS tasks started successfully"

# Monitor task progress
log "📈 Monitoring task progress..."
COMPLETED_TASKS=0
FAILED_TASKS=0

while [ $COMPLETED_TASKS -lt $NUM_TASKS ] && [ $FAILED_TASKS -lt $NUM_TASKS ]; do
    for TASK_ARN in "${TASK_ARNS[@]}"; do
        if [ -n "$TASK_ARN" ]; then
            TASK_STATUS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query 'tasks[0].lastStatus' --output text 2>/dev/null || echo "UNKNOWN")
            
            case $TASK_STATUS in
                "STOPPED")
                    EXIT_CODE=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --query 'tasks[0].containers[0].exitCode' --output text 2>/dev/null || echo "UNKNOWN")
                    if [ "$EXIT_CODE" = "0" ]; then
                        log "✅ Task completed successfully: $TASK_ARN"
                        COMPLETED_TASKS=$((COMPLETED_TASKS + 1))
                    else
                        log "❌ Task failed with exit code $EXIT_CODE: $TASK_ARN"
                        FAILED_TASKS=$((FAILED_TASKS + 1))
                    fi
                    # Remove from monitoring list
                    TASK_ARNS=("${TASK_ARNS[@]/$TASK_ARN}")
                    ;;
                "RUNNING")
                    log "🔄 Task still running: $TASK_ARN"
                    ;;
                "PENDING")
                    log "⏳ Task pending: $TASK_ARN"
                    ;;
                *)
                    log "❓ Task status unknown: $TASK_ARN (Status: $TASK_STATUS)"
                    ;;
            esac
        fi
    done
    
    if [ $COMPLETED_TASKS -lt $NUM_TASKS ] && [ $FAILED_TASKS -lt $NUM_TASKS ]; then
        sleep 10
    fi
done

# Stop CloudWatch monitoring
if [ -f "$LOCAL_LOGS_DIR/cloudwatch.pid" ]; then
    CLOUDWATCH_PID=$(cat "$LOCAL_LOGS_DIR/cloudwatch.pid")
    kill $CLOUDWATCH_PID 2>/dev/null || true
    rm -f "$LOCAL_LOGS_DIR/cloudwatch.pid"
fi

# Collect results
log "📊 Collecting test results..."

# Download CloudWatch logs
log "📥 Downloading CloudWatch logs..."
aws logs filter-log-events \
    --log-group-name "$CLOUDWATCH_LOG_GROUP" \
    --start-time $(date -d '1 hour ago' +%s)000 \
    --query 'events[*].{timestamp:timestamp,message:message}' \
    --output json > "$LOCAL_LOGS_DIR/cloudwatch-events.json" 2>/dev/null || true

# Generate summary report
log "📋 Generating summary report..."
cat > "$RESULTS_DIR/summary.md" << EOF
# QueueIt Load Test Summary

**Test ID:** $TEST_ID  
**Date:** $(date)  
**Target URL:** $TARGET_URL  
**Number of Tasks:** $NUM_TASKS  
**Duration per Task:** ${DURATION}s  

## Results
- **Completed Tasks:** $COMPLETED_TASKS
- **Failed Tasks:** $FAILED_TASKS
- **Success Rate:** $(( (COMPLETED_TASKS * 100) / NUM_TASKS ))%

## Files
- **CloudWatch Logs:** $LOCAL_LOGS_DIR/cloudwatch-events.json
- **Test Run Log:** $LOCAL_LOGS_DIR/test-run.log
- **S3 Results:** $S3_RESULTS_PATH

## Next Steps
1. Review CloudWatch logs for detailed results
2. Check S3 bucket for uploaded results
3. Analyze QueueIt redirect patterns
EOF

# Upload results to S3
log "📤 Uploading results to S3..."
aws s3 cp "$RESULTS_DIR" "$S3_RESULTS_PATH" --recursive >/dev/null 2>&1 || log "⚠️  Warning: Failed to upload to S3"

# Final summary
log "🎉 Test completed!"
log "📊 Results Summary:"
log "   ✅ Completed: $COMPLETED_TASKS tasks"
log "   ❌ Failed: $FAILED_TASKS tasks"
log "   📁 Local results: $RESULTS_DIR"
log "   ☁️  S3 results: $S3_RESULTS_PATH"
log "   📊 CloudWatch logs: $CLOUDWATCH_LOG_GROUP"

# Remove trap
trap - EXIT

echo ""
echo "🏁 Test run completed successfully!"
echo "📁 Check results in: $RESULTS_DIR"
echo "☁️  S3 location: $S3_RESULTS_PATH" 