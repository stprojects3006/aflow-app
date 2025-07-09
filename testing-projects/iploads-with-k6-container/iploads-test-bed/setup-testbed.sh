#!/bin/bash

# =============================================================================
# iploads-k6-container Test Bed Setup Script - FULLY AUTOMATED
# =============================================================================
# This script provides COMPLETE automation of the load testing environment:
# 1. Installs and configures all prerequisites (AWS CLI, jq, etc.)
# 2. Sets up AWS credentials and configuration
# 3. Creates ECS cluster and required AWS resources
# 4. Registers task definitions and runs load tests
# 5. Captures logs, metrics, and generates reports
# 6. Provides cleanup and management capabilities
# =============================================================================

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="iploads-k6-container"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="${SCRIPT_DIR}/logs/${TIMESTAMP}"
RESULTS_DIR="${SCRIPT_DIR}/results/${TIMESTAMP}"
TASK_DEFINITIONS_DIR="${SCRIPT_DIR}/../task-definitions"
K6_SCRIPTS_DIR="${SCRIPT_DIR}/../k6-scripts"

# AWS Configuration - Can be overridden via environment variables
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-k6-load-test-cluster}"
SERVICE_NAME="${SERVICE_NAME:-k6-load-test-service}"
TASK_FAMILY_PREFIX="${TASK_FAMILY_PREFIX:-k6-load-test}"

# Test Configuration
TARGET_URL="${TARGET_URL:-https://affluenceit.com}"
DURATION="${DURATION:-5m}"
VUS="${VUS:-50}"
RAMP_UP="${RAMP_UP:-2m}"
RAMP_DOWN="${RAMP_DOWN:-1m}"

# AWS Credentials (can be set via environment variables)
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to detect OS and install prerequisites
install_prerequisites() {
    log_step "Installing prerequisites..."
    
    local os_type=$(uname -s)
    local package_manager=""
    
    # Detect OS and package manager
    case "$os_type" in
        "Darwin")
            log_info "Detected macOS"
            if command -v brew &> /dev/null; then
                package_manager="brew"
            else
                log_error "Homebrew is required on macOS. Please install it first: https://brew.sh/"
                exit 1
            fi
            ;;
        "Linux")
            log_info "Detected Linux"
            if command -v apt-get &> /dev/null; then
                package_manager="apt"
            elif command -v yum &> /dev/null; then
                package_manager="yum"
            elif command -v dnf &> /dev/null; then
                package_manager="dnf"
            else
                log_error "Unsupported Linux distribution. Please install AWS CLI and jq manually."
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $os_type"
            exit 1
            ;;
    esac
    
    # Install AWS CLI
    if ! command -v aws &> /dev/null; then
        log_info "Installing AWS CLI..."
        case "$package_manager" in
            "brew")
                brew install awscli
                ;;
            "apt")
                sudo apt-get update
                sudo apt-get install -y awscli
                ;;
            "yum")
                sudo yum install -y awscli
                ;;
            "dnf")
                sudo dnf install -y awscli
                ;;
        esac
        log_success "AWS CLI installed successfully"
    else
        log_info "AWS CLI already installed"
    fi
    
    # Install jq
    if ! command -v jq &> /dev/null; then
        log_info "Installing jq..."
        case "$package_manager" in
            "brew")
                brew install jq
                ;;
            "apt")
                sudo apt-get install -y jq
                ;;
            "yum")
                sudo yum install -y jq
                ;;
            "dnf")
                sudo dnf install -y jq
                ;;
        esac
        log_success "jq installed successfully"
    else
        log_info "jq already installed"
    fi
    
    # Install curl if not present
    if ! command -v curl &> /dev/null; then
        log_info "Installing curl..."
        case "$package_manager" in
            "brew")
                brew install curl
                ;;
            "apt")
                sudo apt-get install -y curl
                ;;
            "yum")
                sudo yum install -y curl
                ;;
            "dnf")
                sudo dnf install -y curl
                ;;
        esac
    fi
    
    log_success "All prerequisites installed successfully"
}

# Function to setup AWS credentials
setup_aws_credentials() {
    log_step "Setting up AWS credentials..."
    
    # Check if credentials are already configured
    if aws sts get-caller-identity &> /dev/null 2>&1; then
        local current_identity=$(aws sts get-caller-identity --query 'Arn' --output text)
        log_info "AWS credentials already configured for: $current_identity"
        return 0
    fi
    
    # Check if credentials are provided via environment variables
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
        log_info "Using AWS credentials from environment variables"
        export AWS_ACCESS_KEY_ID
        export AWS_SECRET_ACCESS_KEY
        export AWS_DEFAULT_REGION
        
        # Test the credentials
        if aws sts get-caller-identity &> /dev/null 2>&1; then
            local identity=$(aws sts get-caller-identity --query 'Arn' --output text)
            log_success "AWS credentials validated for: $identity"
            return 0
        else
            log_error "Invalid AWS credentials provided via environment variables"
            exit 1
        fi
    fi
    
    # Interactive credential setup
    log_info "Setting up AWS credentials interactively..."
    echo ""
    echo "Please provide your AWS credentials:"
    echo "You can get these from the AWS Console > IAM > Users > Security credentials"
    echo ""
    
    # Prompt for credentials
    read -p "AWS Access Key ID: " aws_access_key
    read -s -p "AWS Secret Access Key: " aws_secret_key
    echo ""
    read -p "AWS Region [us-east-1]: " aws_region
    aws_region=${aws_region:-us-east-1}
    
    # Configure AWS CLI
    aws configure set aws_access_key_id "$aws_access_key"
    aws configure set aws_secret_access_key "$aws_secret_key"
    aws configure set default.region "$aws_region"
    aws configure set default.output json
    
    # Test the configuration
    if aws sts get-caller-identity &> /dev/null 2>&1; then
        local identity=$(aws sts get-caller-identity --query 'Arn' --output text)
        log_success "AWS credentials configured successfully for: $identity"
        
        # Update script variables
        AWS_REGION="$aws_region"
        export AWS_REGION
    else
        log_error "Failed to configure AWS credentials. Please check your credentials and try again."
        exit 1
    fi
}

# Function to check AWS permissions
check_aws_permissions() {
    log_step "Checking AWS permissions..."
    
    local required_services=("ecs" "ec2" "cloudwatch" "iam" "logs")
    local missing_permissions=()
    
    for service in "${required_services[@]}"; do
        case "$service" in
            "ecs")
                if ! aws ecs list-clusters &> /dev/null 2>&1; then
                    missing_permissions+=("ECS")
                fi
                ;;
            "ec2")
                if ! aws ec2 describe-vpcs --max-items 1 &> /dev/null 2>&1; then
                    missing_permissions+=("EC2")
                fi
                ;;
            "cloudwatch")
                if ! aws cloudwatch list-metrics --namespace AWS/ECS --max-items 1 &> /dev/null 2>&1; then
                    missing_permissions+=("CloudWatch")
                fi
                ;;
            "iam")
                if ! aws iam get-user &> /dev/null 2>&1; then
                    missing_permissions+=("IAM")
                fi
                ;;
            "logs")
                if ! aws logs describe-log-groups --max-items 1 &> /dev/null 2>&1; then
                    missing_permissions+=("CloudWatch Logs")
                fi
                ;;
        esac
    done
    
    if [ ${#missing_permissions[@]} -gt 0 ]; then
        log_warning "Missing permissions for: ${missing_permissions[*]}"
        log_info "You may need to request these permissions from your AWS administrator:"
        echo ""
        echo "Required IAM permissions:"
        echo "- ECS: CreateCluster, DeleteCluster, ListClusters, RegisterTaskDefinition, DeregisterTaskDefinition, RunTask, StopTask, DescribeTasks, ListTasks"
        echo "- EC2: DescribeVpcs, DescribeSubnets, DescribeSecurityGroups"
        echo "- CloudWatch: GetMetricStatistics, PutMetricData"
        echo "- CloudWatch Logs: CreateLogGroup, DeleteLogGroup, DescribeLogGroups, GetLogEvents, PutLogEvents"
        echo "- IAM: GetUser, PassRole"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        log_success "All required AWS permissions verified"
    fi
}

# Function to create required AWS resources
create_aws_resources() {
    log_step "Creating required AWS resources..."
    
    # Create ECS execution role if it doesn't exist
    if ! aws iam get-role --role-name ecsTaskExecutionRole &> /dev/null 2>&1; then
        log_info "Creating ECS task execution role..."
        
        # Create trust policy
        cat > /tmp/ecs-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
        
        # Create the role
        aws iam create-role \
            --role-name ecsTaskExecutionRole \
            --assume-role-policy-document file:///tmp/ecs-trust-policy.json
        
        # Attach the required policy
        aws iam attach-role-policy \
            --role-name ecsTaskExecutionRole \
            --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
        
        log_success "ECS task execution role created"
        rm -f /tmp/ecs-trust-policy.json
    else
        log_info "ECS task execution role already exists"
    fi
    
    # Create security group for ECS tasks if it doesn't exist
    local vpc_id=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    local sg_name="k6-load-test-sg"
    
    if ! aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=$sg_name" --query 'SecurityGroups[0].GroupId' --output text | grep -q "sg-"; then
        log_info "Creating security group for ECS tasks..."
        
        local sg_id=$(aws ec2 create-security-group \
            --group-name "$sg_name" \
            --description "Security group for k6 load testing" \
            --vpc-id "$vpc_id" \
            --region "$AWS_REGION" \
            --query 'GroupId' \
            --output text)
        
        # Add outbound rule
        aws ec2 authorize-security-group-egress \
            --group-id "$sg_id" \
            --protocol -1 \
            --port -1 \
            --cidr 0.0.0.0/0 \
            --region "$AWS_REGION"
        
        log_success "Security group created: $sg_id"
    else
        log_info "Security group already exists"
    fi
}

# Function to check prerequisites (enhanced)
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Installing now..."
        install_prerequisites
    fi
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are not configured. Setting up now..."
        setup_aws_credentials
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Installing now..."
        install_prerequisites
    fi
    
    # Check AWS permissions
    check_aws_permissions
    
    # Create required AWS resources
    create_aws_resources
    
    # Check if required directories exist
    if [ ! -d "$TASK_DEFINITIONS_DIR" ]; then
        log_warning "Task definitions directory not found: $TASK_DEFINITIONS_DIR"
        log_info "Creating task definitions directory..."
        mkdir -p "$TASK_DEFINITIONS_DIR"
    fi
    
    if [ ! -d "$K6_SCRIPTS_DIR" ]; then
        log_warning "k6 scripts directory not found: $K6_SCRIPTS_DIR"
        log_info "Creating k6 scripts directory..."
        mkdir -p "$K6_SCRIPTS_DIR"
        
        # Create sample k6 script if directory is empty
        if [ ! "$(ls -A $K6_SCRIPTS_DIR)" ]; then
            log_info "Creating sample k6 script..."
            cat > "${K6_SCRIPTS_DIR}/basic-load-test.js" << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
    stages: [
        { duration: '2m', target: 50 },  // Ramp up
        { duration: '5m', target: 50 },  // Stay at 50 users
        { duration: '2m', target: 0 },   // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<2000'],
        http_req_failed: ['rate<0.1'],
    },
};

export default function() {
    const response = http.get(__ENV.TARGET_URL || 'https://affluenceit.com');
    
    check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 2000ms': (r) => r.timings.duration < 2000,
    });
    
    sleep(1);
}
EOF
        fi
    fi
    
    log_success "All prerequisites are met"
}

# Function to create directories
create_directories() {
    log_step "Creating directories..."
    
    mkdir -p "$LOG_DIR"
    mkdir -p "$RESULTS_DIR"
    mkdir -p "${LOG_DIR}/task-definitions"
    mkdir -p "${LOG_DIR}/ecs-logs"
    mkdir -p "${LOG_DIR}/k6-results"
    mkdir -p "${RESULTS_DIR}/dashboards"
    mkdir -p "${RESULTS_DIR}/metrics"
    
    log_success "Directories created successfully"
}

# Function to create ECS cluster if it doesn't exist
create_ecs_cluster() {
    log_step "Creating ECS cluster..."
    
    # Check if cluster exists
    if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" | jq -e '.clusters[0].status' > /dev/null 2>&1; then
        log_info "Cluster $CLUSTER_NAME already exists"
    else
        log_info "Creating ECS cluster: $CLUSTER_NAME"
        aws ecs create-cluster \
            --cluster-name "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --capacity-providers FARGATE \
            --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
        
        log_success "ECS cluster created successfully"
    fi
}

# Function to create task definition
create_task_definition() {
    local test_name="$1"
    local script_file="$2"
    local vus="$3"
    local duration="$4"
    
    log_step "Creating task definition for: $test_name"
    
    local task_def_file="${TASK_DEFINITIONS_DIR}/task-def-${test_name}.json"
    local task_family="${TASK_FAMILY_PREFIX}-${test_name}"
    
    # Get security group ID
    local vpc_id=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    local sg_id=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=k6-load-test-sg" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Create task definition JSON
    cat > "$task_def_file" << EOF
{
    "family": "$task_family",
    "networkMode": "awsvpc",
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "1024",
    "memory": "2048",
    "executionRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/ecsTaskExecutionRole",
    "taskRoleArn": "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/ecsTaskExecutionRole",
    "containerDefinitions": [
        {
            "name": "k6-load-test",
            "image": "grafana/k6:latest",
            "command": [
                "run",
                "--out", "json=/tmp/results.json",
                "--env", "TARGET_URL=$TARGET_URL",
                "--env", "VUS=$vus",
                "--env", "DURATION=$duration",
                "/scripts/$script_file"
            ],
            "environment": [
                {
                    "name": "K6_OUT",
                    "value": "json=/tmp/results.json"
                }
            ],
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-group": "/ecs/$task_family",
                    "awslogs-region": "$AWS_REGION",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
}
EOF
    
    # Create CloudWatch log group if it doesn't exist
    if ! aws logs describe-log-groups --log-group-name-prefix "/ecs/$task_family" --region "$AWS_REGION" | jq -e '.logGroups | length > 0' > /dev/null 2>&1; then
        aws logs create-log-group --log-group-name "/ecs/$task_family" --region "$AWS_REGION"
        log_info "Created CloudWatch log group: /ecs/$task_family"
    fi
    
    # Register task definition
    log_info "Registering task definition: $task_family"
    local task_def_arn=$(aws ecs register-task-definition \
        --cli-input-json "file://$task_def_file" \
        --region "$AWS_REGION" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    log_success "Task definition registered: $task_def_arn"
    echo "$task_def_arn" > "${LOG_DIR}/task-definitions/${test_name}-task-def-arn.txt"
    
    # Copy task definition to logs
    cp "$task_def_file" "${LOG_DIR}/task-definitions/"
}

# Function to run ECS task
run_ecs_task() {
    local test_name="$1"
    local task_def_arn="$2"
    
    log_step "Running ECS task for: $test_name"
    
    # Get default VPC and subnets
    local vpc_id=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text)
    local subnet_ids=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',' | sed 's/,/","/g')
    subnet_ids="\"${subnet_ids}\""
    
    # Get security group
    local security_group_id=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=group-name,Values=k6-load-test-sg" --query 'SecurityGroups[0].GroupId' --output text)
    
    # Run task
    local task_arn=$(aws ecs run-task \
        --cluster "$CLUSTER_NAME" \
        --task-definition "$task_def_arn" \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$subnet_ids],securityGroups=[$security_group_id],assignPublicIp=ENABLED}" \
        --region "$AWS_REGION" \
        --query 'tasks[0].taskArn' \
        --output text)
    
    log_success "Task started: $task_arn"
    echo "$task_arn" > "${LOG_DIR}/ecs-logs/${test_name}-task-arn.txt"
    
    # Wait for task to complete
    log_info "Waiting for task to complete..."
    aws ecs wait tasks-stopped \
        --cluster "$CLUSTER_NAME" \
        --tasks "$task_arn" \
        --region "$AWS_REGION"
    
    log_success "Task completed: $task_arn"
    
    # Get task status
    local task_status=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$task_arn" \
        --region "$AWS_REGION" \
        --query 'tasks[0].lastStatus' \
        --output text)
    
    log_info "Task status: $task_status"
    
    return 0
}

# Function to capture logs
capture_logs() {
    local test_name="$1"
    local task_arn="$2"
    
    log_step "Capturing logs for: $test_name"
    
    # Get CloudWatch log group and stream
    local log_group="/ecs/${TASK_FAMILY_PREFIX}-${test_name}"
    local log_stream=$(aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --region "$AWS_REGION" \
        --order-by LastEventTime \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$log_stream" ] && [ "$log_stream" != "null" ]; then
        # Download logs
        local log_file="${LOG_DIR}/ecs-logs/${test_name}-k6-logs.log"
        aws logs get-log-events \
            --log-group-name "$log_group" \
            --log-stream-name "$log_stream" \
            --region "$AWS_REGION" \
            --query 'events[*].message' \
            --output text > "$log_file"
        
        log_success "Logs captured: $log_file"
    else
        log_warning "No log streams found for: $log_group"
    fi
}

# Function to download results
download_results() {
    local test_name="$1"
    
    log_step "Downloading results for: $test_name"
    
    # Create results directory for this test
    local test_results_dir="${RESULTS_DIR}/${test_name}"
    mkdir -p "$test_results_dir"
    
    # Download CloudWatch metrics
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local start_time=$(date -u -d "1 hour ago" +"%Y-%m-%dT%H:%M:%SZ")
    
    # Get ECS metrics
    aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name CPUUtilization \
        --dimensions Name=ClusterName,Value="$CLUSTER_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Average Maximum \
        --region "$AWS_REGION" > "${test_results_dir}/cpu-utilization.json"
    
    aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name MemoryUtilization \
        --dimensions Name=ClusterName,Value="$CLUSTER_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Average Maximum \
        --region "$AWS_REGION" > "${test_results_dir}/memory-utilization.json"
    
    log_success "Results downloaded to: $test_results_dir"
}

# Function to generate test report
generate_report() {
    local test_name="$1"
    
    log_step "Generating report for: $test_name"
    
    local report_file="${RESULTS_DIR}/${test_name}-report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Load Test Report - $test_name</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f9f9f9; border-radius: 3px; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Load Test Report</h1>
        <p><strong>Test Name:</strong> $test_name</p>
        <p><strong>Timestamp:</strong> $TIMESTAMP</p>
        <p><strong>Target URL:</strong> $TARGET_URL</p>
        <p><strong>AWS Region:</strong> $AWS_REGION</p>
    </div>
    
    <div class="section">
        <h2>Test Configuration</h2>
        <div class="metric"><strong>Duration:</strong> $DURATION</div>
        <div class="metric"><strong>Virtual Users:</strong> $VUS</div>
        <div class="metric"><strong>Ramp Up:</strong> $RAMP_UP</div>
        <div class="metric"><strong>Ramp Down:</strong> $RAMP_DOWN</div>
    </div>
    
    <div class="section">
        <h2>Test Results</h2>
        <p>Results and metrics have been captured and stored in the results directory.</p>
        <p>Check the following files for detailed information:</p>
        <ul>
            <li>CPU Utilization: ${test_name}/cpu-utilization.json</li>
            <li>Memory Utilization: ${test_name}/memory-utilization.json</li>
            <li>K6 Logs: logs/ecs-logs/${test_name}-k6-logs.log</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>AWS Resources</h2>
        <p><strong>Cluster:</strong> $CLUSTER_NAME</p>
        <p><strong>Region:</strong> $AWS_REGION</p>
        <p><strong>Account:</strong> $(aws sts get-caller-identity --query 'Account' --output text)</p>
    </div>
</body>
</html>
EOF
    
    log_success "Report generated: $report_file"
}

# Function to run complete test suite
run_test_suite() {
    log_step "Starting complete test suite..."
    
    # Define test configurations
    declare -A tests=(
        ["basic"]="basic-load-test.js"
        ["spike"]="spike-test.js"
        ["stress"]="stress-test.js"
        ["queueit"]="queueit-test.js"
        ["owners"]="owners-test.js"
    )
    
    # Test configurations
    declare -A test_configs=(
        ["basic_vus"]="50"
        ["basic_duration"]="5m"
        ["spike_vus"]="100"
        ["spike_duration"]="10m"
        ["stress_vus"]="200"
        ["stress_duration"]="15m"
        ["queueit_vus"]="30"
        ["queueit_duration"]="8m"
        ["owners_vus"]="40"
        ["owners_duration"]="6m"
    )
    
    for test_name in "${!tests[@]}"; do
        log_step "Running test: $test_name"
        
        local script_file="${tests[$test_name]}"
        local vus="${test_configs[${test_name}_vus]}"
        local duration="${test_configs[${test_name}_duration]}"
        
        # Create task definition
        create_task_definition "$test_name" "$script_file" "$vus" "$duration"
        
        # Get task definition ARN
        local task_def_arn=$(cat "${LOG_DIR}/task-definitions/${test_name}-task-def-arn.txt")
        
        # Run task
        run_ecs_task "$test_name" "$task_def_arn"
        
        # Get task ARN
        local task_arn=$(cat "${LOG_DIR}/ecs-logs/${test_name}-task-arn.txt")
        
        # Capture logs
        capture_logs "$test_name" "$task_arn"
        
        # Download results
        download_results "$test_name"
        
        # Generate report
        generate_report "$test_name"
        
        log_success "Test $test_name completed successfully"
        
        # Wait between tests
        if [ "$test_name" != "${!tests[@]: -1}" ]; then
            log_info "Waiting 30 seconds before next test..."
            sleep 30
        fi
    done
}

# Function to cleanup resources
cleanup() {
    log_step "Cleaning up resources..."
    
    # Stop all running tasks
    local running_tasks=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --desired-status RUNNING \
        --query 'taskArns' \
        --output text)
    
    if [ -n "$running_tasks" ]; then
        log_info "Stopping running tasks..."
        aws ecs stop-task \
            --cluster "$CLUSTER_NAME" \
            --task "$running_tasks" \
            --region "$AWS_REGION" || true
    fi
    
    # Deregister task definitions
    for task_def_file in "${LOG_DIR}/task-definitions"/*-task-def-arn.txt; do
        if [ -f "$task_def_file" ]; then
            local task_def_arn=$(cat "$task_def_file")
            log_info "Deregistering task definition: $task_def_arn"
            aws ecs deregister-task-definition \
                --task-definition "$task_def_arn" \
                --region "$AWS_REGION" || true
        fi
    done
    
    log_success "Cleanup completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --create-cluster    Create ECS cluster"
    echo "  -t, --test <name>       Run specific test (basic, spike, stress, queueit, owners)"
    echo "  -a, --all-tests         Run all tests"
    echo "  -l, --logs              Download logs only"
    echo "  -r, --results           Download results only"
    echo "  -x, --cleanup           Cleanup resources"
    echo "  -d, --duration <time>   Set test duration (default: 5m)"
    echo "  -v, --vus <number>      Set virtual users (default: 50)"
    echo "  -u, --url <url>         Set target URL (default: https://affluenceit.com)"
    echo "  --auto-setup            Automatically install prerequisites and setup AWS"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_ACCESS_KEY_ID       AWS Access Key ID"
    echo "  AWS_SECRET_ACCESS_KEY   AWS Secret Access Key"
    echo "  AWS_REGION              AWS Region (default: us-east-1)"
    echo "  TARGET_URL              Target URL for load testing"
    echo "  DURATION                Test duration"
    echo "  VUS                     Number of virtual users"
    echo ""
    echo "Examples:"
    echo "  $0 --auto-setup --all-tests                    # Full automation"
    echo "  $0 --auto-setup --test basic --duration 10m    # Auto setup + basic test"
    echo "  $0 --test queueit --vus 100                    # Run queueit test with 100 VUs"
    echo "  $0 --cleanup                                   # Cleanup all resources"
}

# Main function
main() {
    log_info "Starting iploads-k6-container test bed setup - FULLY AUTOMATED"
    log_info "Timestamp: $TIMESTAMP"
    log_info "Project: $PROJECT_NAME"
    
    # Parse command line arguments
    local create_cluster=false
    local run_all_tests=false
    local specific_test=""
    local download_logs=false
    local download_results=false
    local cleanup_resources=false
    local auto_setup=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--create-cluster)
                create_cluster=true
                shift
                ;;
            -t|--test)
                specific_test="$2"
                shift 2
                ;;
            -a|--all-tests)
                run_all_tests=true
                shift
                ;;
            -l|--logs)
                download_logs=true
                shift
                ;;
            -r|--results)
                download_results=true
                shift
                ;;
            -x|--cleanup)
                cleanup_resources=true
                shift
                ;;
            -d|--duration)
                DURATION="$2"
                shift 2
                ;;
            -v|--vus)
                VUS="$2"
                shift 2
                ;;
            -u|--url)
                TARGET_URL="$2"
                shift 2
                ;;
            --auto-setup)
                auto_setup=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Auto setup if requested
    if [ "$auto_setup" = true ]; then
        log_step "Performing automatic setup..."
        install_prerequisites
        setup_aws_credentials
        check_aws_permissions
        create_aws_resources
    else
        # Check prerequisites
        check_prerequisites
    fi
    
    # Create directories
    create_directories
    
    # Handle cleanup
    if [ "$cleanup_resources" = true ]; then
        cleanup
        exit 0
    fi
    
    # Create cluster if requested
    if [ "$create_cluster" = true ]; then
        create_ecs_cluster
    fi
    
    # Run tests based on options
    if [ "$run_all_tests" = true ]; then
        run_test_suite
    elif [ -n "$specific_test" ]; then
        log_step "Running specific test: $specific_test"
        
        # Define test configuration for specific test
        case "$specific_test" in
            "basic")
                create_task_definition "basic" "basic-load-test.js" "$VUS" "$DURATION"
                ;;
            "spike")
                create_task_definition "spike" "spike-test.js" "100" "10m"
                ;;
            "stress")
                create_task_definition "stress" "stress-test.js" "200" "15m"
                ;;
            "queueit")
                create_task_definition "queueit" "queueit-test.js" "30" "8m"
                ;;
            "owners")
                create_task_definition "owners" "owners-test.js" "40" "6m"
                ;;
            *)
                log_error "Unknown test: $specific_test"
                exit 1
                ;;
        esac
        
        # Get task definition ARN and run
        local task_def_arn=$(cat "${LOG_DIR}/task-definitions/${specific_test}-task-def-arn.txt")
        run_ecs_task "$specific_test" "$task_def_arn"
        
        # Get task ARN and capture logs/results
        local task_arn=$(cat "${LOG_DIR}/ecs-logs/${specific_test}-task-arn.txt")
        capture_logs "$specific_test" "$task_arn"
        download_results "$specific_test"
        generate_report "$specific_test"
    fi
    
    # Download logs/results if requested
    if [ "$download_logs" = true ] || [ "$download_results" = true ]; then
        log_step "Downloading logs and results..."
        # This would need to be implemented based on existing task ARNs
        log_warning "Log/results download requires existing task ARNs"
    fi
    
    log_success "Test bed setup completed successfully!"
    log_info "Results available in: $RESULTS_DIR"
    log_info "Logs available in: $LOG_DIR"
    
    # Show summary
    echo ""
    echo "================================================================================"
    echo "TEST BED SETUP SUMMARY"
    echo "================================================================================"
    echo "Timestamp: $TIMESTAMP"
    echo "Project: $PROJECT_NAME"
    echo "Target URL: $TARGET_URL"
    echo "AWS Region: $AWS_REGION"
    echo "Results Directory: $RESULTS_DIR"
    echo "Logs Directory: $LOG_DIR"
    echo "================================================================================"
}

# Run main function with all arguments
main "$@" 