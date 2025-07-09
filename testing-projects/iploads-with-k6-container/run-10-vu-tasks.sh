#!/bin/bash

# Script to run 10 separate ECS tasks, each with 1 VU
# This provides better IP diversity and isolation

set -e

# Configuration
CLUSTER_NAME="k6-load-test-cluster"
TASK_DEFINITION_FILE="task-def-single-vu-owners.json"
SUBNET_ID="subnet-097cbe067e542243a"
SECURITY_GROUP_ID="sg-0737d6eb4011e161c"
REGION="us-east-1"
NUM_TASKS=10

echo "🚀 Starting 10 VU Load Test (1 VU per task)"
echo "=========================================="

# Register the task definition
echo "📝 Registering task definition..."
aws ecs register-task-definition \
    --cli-input-json file://$TASK_DEFINITION_FILE \
    --region $REGION

echo "✅ Task definition registered successfully"

# Launch 10 separate tasks
echo "🚀 Launching $NUM_TASKS tasks (1 VU each)..."

for i in $(seq 1 $NUM_TASKS); do
    echo "Launching task $i of $NUM_TASKS..."
    
    # Set unique task ID for each task
    TASK_ID="vu-$i"
    
    # Launch the task
    aws ecs run-task \
        --cluster $CLUSTER_NAME \
        --task-definition k6-single-vu-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --region $REGION \
        --overrides "containerOverrides=[{name=k6-single-vu,environment=[{name=TASK_ID,value=$TASK_ID}]}]" &
    
    # Small delay between task launches
    sleep 2
done

echo "✅ All $NUM_TASKS tasks launched successfully!"
echo ""
echo "📊 Monitoring:"
echo "- Check ECS console for task status"
echo "- Monitor logs: aws logs tail /ecs/k6-single-vu-task --follow --region $REGION"
echo "- Each task will run for ~80 seconds (10s ramp + 60s steady + 10s ramp down)"
echo ""
echo "🎯 Expected Results:"
echo "- 10 separate tasks running concurrently"
echo "- Each task has 1 VU hitting /owners/new (should get 302 redirects)"
echo "- Each task has its own IP address for better diversity" 