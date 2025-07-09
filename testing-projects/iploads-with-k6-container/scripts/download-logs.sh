#!/bin/bash

# Download latest k6 test logs from CloudWatch
REGION="us-east-1"
OUTPUT_FILE="k6-test-logs-$(date +%Y%m%d-%H%M%S).json"

# Try different possible log group names
LOG_GROUPS=(
    "/ecs/k6-load-test-k6"
    "/ecs/k6-single-vu-task"
    "/ecs/k6-10-vu-test"
    "/ecs/k6-load-test"
)

echo "Searching for k6 log groups..."

for LOG_GROUP in "${LOG_GROUPS[@]}"; do
    echo "Checking log group: $LOG_GROUP"
    
    # Check if log group exists
    if aws logs describe-log-streams --log-group-name "$LOG_GROUP" --region "$REGION" --max-items 1 >/dev/null 2>&1; then
        echo "Found log group: $LOG_GROUP"
        
        # Get the most recent log stream
        LATEST_STREAM=$(aws logs describe-log-streams \
            --log-group-name "$LOG_GROUP" \
            --region "$REGION" \
            --order-by LastEventTime \
            --descending \
            --max-items 1 \
            --query 'logStreams[0].logStreamName' \
            --output text 2>/dev/null)

        if [ "$LATEST_STREAM" != "None" ] && [ -n "$LATEST_STREAM" ]; then
            echo "Latest log stream: $LATEST_STREAM"
            echo "Downloading logs to $OUTPUT_FILE..."
            
            # Download all events from the latest stream
            if aws logs get-log-events \
                --log-group-name "$LOG_GROUP" \
                --log-stream-name "$LATEST_STREAM" \
                --region "$REGION" \
                --output json > "$OUTPUT_FILE" 2>/dev/null; then
                
                echo "Logs downloaded to $OUTPUT_FILE"
                echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
                echo "Number of log events: $(jq '.events | length' "$OUTPUT_FILE" 2>/dev/null || echo 'unknown')"
                exit 0
            else
                echo "Failed to download logs from stream: $LATEST_STREAM"
            fi
        else
            echo "No log streams found in $LOG_GROUP"
        fi
    else
        echo "Log group $LOG_GROUP does not exist"
    fi
done

echo "No valid log groups found. Please check the log group name in AWS Console."
exit 1 