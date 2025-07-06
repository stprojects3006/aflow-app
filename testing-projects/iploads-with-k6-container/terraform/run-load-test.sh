#!/bin/bash

# Run k6 Load Test with IP Rotation
set -e

echo "Starting k6 load test with IP rotation..."

# Get values from Terraform outputs
SUBNET_ID=$(terraform output -raw subnet_id)
SECURITY_GROUP_ID=$(terraform output -raw security_group_id)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
TASK_DEFINITION=$(terraform output -raw task_definition_arn)

echo "Subnet ID: $SUBNET_ID"
echo "Security Group ID: $SECURITY_GROUP_ID"
echo "Cluster Name: $CLUSTER_NAME"
echo "Task Definition: $TASK_DEFINITION"

# Run the ECS task
aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_DEFINITION" \
  --launch-type FARGATE \
  --network-configuration file://network-config.json \
  --output json

echo "Task submitted successfully!"
echo "Check CloudWatch logs for progress: /ecs/k6-load-test-k6" 