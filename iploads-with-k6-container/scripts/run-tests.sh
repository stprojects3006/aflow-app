#!/bin/bash

# K6 Load Testing Runner Script
# This script runs different types of load tests on the deployed infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
TEST_TYPE=${TEST_TYPE:-"basic"}
DURATION=${DURATION:-"5m"}
USERS=${USERS:-"10"}

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if infrastructure is deployed
check_infrastructure() {
    print_status "Checking infrastructure deployment..."
    
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        print_error "Infrastructure not deployed. Please run './scripts/deploy.sh' first."
        exit 1
    fi
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    # Check if ECS cluster exists
    if ! aws ecs describe-clusters --clusters "$ECS_CLUSTER_NAME" --query 'clusters[0].status' --output text | grep -q ACTIVE; then
        print_error "ECS cluster is not active. Please check the deployment."
        exit 1
    fi
    
    print_status "Infrastructure is ready."
}

# Function to run basic load test
run_basic_test() {
    print_status "Running basic load test..."
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    # Run ECS task with basic test
    TASK_ARN=$(aws ecs run-task \
        --cluster "$ECS_CLUSTER_NAME" \
        --task-definition k6-load-test-k6-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --overrides "{\"containerOverrides\":[{\"name\":\"k6-load-test\",\"environment\":[{\"name\":\"TEST_TYPE\",\"value\":\"basic\"}]}]}" \
        --query 'tasks[0].taskArn' \
        --output text)
    
    print_status "Basic test started with ARN: $TASK_ARN"
    return $TASK_ARN
}

# Function to run stress test
run_stress_test() {
    print_status "Running stress test..."
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    # Run ECS task with stress test
    TASK_ARN=$(aws ecs run-task \
        --cluster "$ECS_CLUSTER_NAME" \
        --task-definition k6-load-test-k6-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --overrides "{\"containerOverrides\":[{\"name\":\"k6-load-test\",\"environment\":[{\"name\":\"TEST_TYPE\",\"value\":\"stress\"}]}]}" \
        --query 'tasks[0].taskArn' \
        --output text)
    
    print_status "Stress test started with ARN: $TASK_ARN"
    return $TASK_ARN
}

# Function to run spike test
run_spike_test() {
    print_status "Running spike test..."
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    # Run ECS task with spike test
    TASK_ARN=$(aws ecs run-task \
        --cluster "$ECS_CLUSTER_NAME" \
        --task-definition k6-load-test-k6-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --overrides "{\"containerOverrides\":[{\"name\":\"k6-load-test\",\"environment\":[{\"name\":\"TEST_TYPE\",\"value\":\"spike\"}]}]}" \
        --query 'tasks[0].taskArn' \
        --output text)
    
    print_status "Spike test started with ARN: $TASK_ARN"
    return $TASK_ARN
}

# Function to monitor test
monitor_test() {
    local task_arn=$1
    local test_type=$2
    
    print_status "Monitoring $test_type test..."
    print_status "Task ARN: $task_arn"
    
    # Wait for task to complete
    while true; do
        STATUS=$(aws ecs describe-tasks \
            --cluster "$ECS_CLUSTER_NAME" \
            --tasks "$task_arn" \
            --query 'tasks[0].lastStatus' \
            --output text)
        
        if [ "$STATUS" = "STOPPED" ]; then
            print_status "Test completed."
            break
        elif [ "$STATUS" = "STOPPING" ]; then
            print_status "Test is stopping..."
        else
            print_status "Test is running... (Status: $STATUS)"
        fi
        
        sleep 30
    done
    
    # Get task results
    EXIT_CODE=$(aws ecs describe-tasks \
        --cluster "$ECS_CLUSTER_NAME" \
        --tasks "$task_arn" \
        --query 'tasks[0].containers[0].exitCode' \
        --output text)
    
    if [ "$EXIT_CODE" = "0" ]; then
        print_status "Test completed successfully!"
    else
        print_warning "Test completed with exit code: $EXIT_CODE"
    fi
}

# Function to list running tasks
list_tasks() {
    print_status "Listing running tasks..."
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    aws ecs list-tasks \
        --cluster "$ECS_CLUSTER_NAME" \
        --desired-status RUNNING \
        --query 'taskArns' \
        --output table
}

# Function to stop all tasks
stop_all_tasks() {
    print_status "Stopping all running tasks..."
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    TASK_ARNS=$(aws ecs list-tasks \
        --cluster "$ECS_CLUSTER_NAME" \
        --desired-status RUNNING \
        --query 'taskArns' \
        --output text)
    
    if [ -n "$TASK_ARNS" ]; then
        aws ecs stop-task \
            --cluster "$ECS_CLUSTER_NAME" \
            --task "$TASK_ARNS"
        print_status "Tasks stopped."
    else
        print_status "No running tasks found."
    fi
}

# Function to show logs
show_logs() {
    print_status "Showing CloudWatch logs..."
    
    # Source environment variables
    source "$PROJECT_ROOT/.env"
    
    LOG_GROUP=$(aws logs describe-log-groups \
        --log-group-name-prefix "/ecs/k6-load-test" \
        --query 'logGroups[0].logGroupName' \
        --output text)
    
    if [ "$LOG_GROUP" != "None" ]; then
        aws logs tail "$LOG_GROUP" --follow
    else
        print_error "No log group found."
    fi
}

# Main function
main() {
    case $TEST_TYPE in
        "basic")
            check_infrastructure
            TASK_ARN=$(run_basic_test)
            monitor_test "$TASK_ARN" "basic"
            ;;
        "stress")
            check_infrastructure
            TASK_ARN=$(run_stress_test)
            monitor_test "$TASK_ARN" "stress"
            ;;
        "spike")
            check_infrastructure
            TASK_ARN=$(run_spike_test)
            monitor_test "$TASK_ARN" "spike"
            ;;
        "list")
            list_tasks
            ;;
        "stop")
            stop_all_tasks
            ;;
        "logs")
            show_logs
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            echo "Available options: basic, stress, spike, list, stop, logs"
            exit 1
            ;;
    esac
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --users)
            USERS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --test-type TYPE    Test type: basic, stress, spike, list, stop, logs"
            echo "  --duration TIME     Test duration (e.g., 5m, 10m)"
            echo "  --users COUNT       Number of virtual users"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main 