#!/bin/bash

# =============================================================================
# Test Bed Management Script - FULLY AUTOMATED
# =============================================================================
# This script provides COMPLETE automation for managing the iploads-k6-container test bed:
# - Automatically installs and configures all prerequisites
# - Sets up AWS credentials and configuration
# - Monitors running tasks and resources
# - Downloads logs and metrics
# - Generates reports and cleanup
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/testbed-config.json"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-k6-load-test-cluster}"
TASK_FAMILY_PREFIX="${TASK_FAMILY_PREFIX:-k6-load-test}"

# AWS Credentials (can be set via environment variables)
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

# Function to check cluster status
check_cluster_status() {
    log_step "Checking ECS cluster status..."
    
    local cluster_status=$(aws ecs describe-clusters \
        --clusters "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query 'clusters[0].status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$cluster_status" = "ACTIVE" ]; then
        log_success "Cluster $CLUSTER_NAME is ACTIVE"
        return 0
    elif [ "$cluster_status" = "NOT_FOUND" ]; then
        log_error "Cluster $CLUSTER_NAME not found"
        return 1
    else
        log_warning "Cluster $CLUSTER_NAME status: $cluster_status"
        return 1
    fi
}

# Function to list running tasks
list_running_tasks() {
    log_step "Listing running tasks..."
    
    local running_tasks=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --desired-status RUNNING \
        --query 'taskArns' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$running_tasks" ]; then
        log_info "Running tasks:"
        for task in $running_tasks; do
            local task_details=$(aws ecs describe-tasks \
                --cluster "$CLUSTER_NAME" \
                --tasks "$task" \
                --region "$AWS_REGION" \
                --query 'tasks[0].[taskDefinitionArn,lastStatus,createdAt]' \
                --output text)
            
            local task_def=$(echo "$task_details" | cut -f1)
            local status=$(echo "$task_details" | cut -f2)
            local created=$(echo "$task_details" | cut -f3)
            
            echo "  - Task: $(basename "$task")"
            echo "    Definition: $(basename "$task_def")"
            echo "    Status: $status"
            echo "    Created: $created"
            echo ""
        done
    else
        log_info "No running tasks found"
    fi
}

# Function to stop all running tasks
stop_all_tasks() {
    log_step "Stopping all running tasks..."
    
    local running_tasks=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --desired-status RUNNING \
        --query 'taskArns' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$running_tasks" ]; then
        for task in $running_tasks; do
            log_info "Stopping task: $(basename "$task")"
            aws ecs stop-task \
                --cluster "$CLUSTER_NAME" \
                --task "$task" \
                --region "$AWS_REGION" \
                --reason "Manual stop via management script"
        done
        log_success "All tasks stopped"
    else
        log_info "No running tasks to stop"
    fi
}

# Function to list task definitions
list_task_definitions() {
    log_step "Listing task definitions..."
    
    local task_defs=$(aws ecs list-task-definitions \
        --family-prefix "$TASK_FAMILY_PREFIX" \
        --region "$AWS_REGION" \
        --status ACTIVE \
        --query 'taskDefinitionArns' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$task_defs" ]; then
        log_info "Active task definitions:"
        for def in $task_defs; do
            local revision=$(echo "$def" | rev | cut -d: -f1 | rev)
            local family=$(echo "$def" | rev | cut -d: -f2 | rev | rev | cut -d/ -f1 | rev)
            echo "  - $family (revision: $revision)"
        done
    else
        log_info "No active task definitions found"
    fi
}

# Function to deregister task definitions
deregister_task_definitions() {
    log_step "Deregistering task definitions..."
    
    local task_defs=$(aws ecs list-task-definitions \
        --family-prefix "$TASK_FAMILY_PREFIX" \
        --region "$AWS_REGION" \
        --status ACTIVE \
        --query 'taskDefinitionArns' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$task_defs" ]; then
        for def in $task_defs; do
            log_info "Deregistering: $(basename "$def")"
            aws ecs deregister-task-definition \
                --task-definition "$def" \
                --region "$AWS_REGION"
        done
        log_success "All task definitions deregistered"
    else
        log_info "No task definitions to deregister"
    fi
}

# Function to download CloudWatch logs
download_logs() {
    local test_name="$1"
    local days_back="${2:-1}"
    
    log_step "Downloading CloudWatch logs for: $test_name"
    
    local log_group="/ecs/${TASK_FAMILY_PREFIX}-${test_name}"
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local start_time=$(date -u -d "$days_back days ago" +"%Y-%m-%dT%H:%M:%SZ")
    
    # List log streams
    local log_streams=$(aws logs describe-log-streams \
        --log-group-name "$log_group" \
        --region "$AWS_REGION" \
        --order-by LastEventTime \
        --descending \
        --query 'logStreams[*].logStreamName' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$log_streams" ] && [ "$log_streams" != "null" ]; then
        local log_dir="${SCRIPT_DIR}/logs/${test_name}"
        mkdir -p "$log_dir"
        
        for stream in $log_streams; do
            if [ "$stream" != "null" ]; then
                log_info "Downloading stream: $stream"
                aws logs get-log-events \
                    --log-group-name "$log_group" \
                    --log-stream-name "$stream" \
                    --region "$AWS_REGION" \
                    --start-time "$start_time" \
                    --end-time "$end_time" \
                    --query 'events[*].message' \
                    --output text > "${log_dir}/${stream}.log"
            fi
        done
        log_success "Logs downloaded to: $log_dir"
    else
        log_warning "No log streams found for: $log_group"
    fi
}

# Function to get CloudWatch metrics
get_metrics() {
    local test_name="$1"
    local hours_back="${2:-24}"
    
    log_step "Getting CloudWatch metrics for: $test_name"
    
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local start_time=$(date -u -d "$hours_back hours ago" +"%Y-%m-%dT%H:%M:%SZ")
    local metrics_dir="${SCRIPT_DIR}/metrics/${test_name}"
    mkdir -p "$metrics_dir"
    
    # CPU Utilization
    aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name CPUUtilization \
        --dimensions Name=ClusterName,Value="$CLUSTER_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Average Maximum Minimum \
        --region "$AWS_REGION" > "${metrics_dir}/cpu-utilization.json"
    
    # Memory Utilization
    aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name MemoryUtilization \
        --dimensions Name=ClusterName,Value="$CLUSTER_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Average Maximum Minimum \
        --region "$AWS_REGION" > "${metrics_dir}/memory-utilization.json"
    
    # Network metrics
    aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name NetworkRxBytes \
        --dimensions Name=ClusterName,Value="$CLUSTER_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Sum \
        --region "$AWS_REGION" > "${metrics_dir}/network-rx.json"
    
    aws cloudwatch get-metric-statistics \
        --namespace AWS/ECS \
        --metric-name NetworkTxBytes \
        --dimensions Name=ClusterName,Value="$CLUSTER_NAME" \
        --start-time "$start_time" \
        --end-time "$end_time" \
        --period 300 \
        --statistics Sum \
        --region "$AWS_REGION" > "${metrics_dir}/network-tx.json"
    
    log_success "Metrics downloaded to: $metrics_dir"
}

# Function to generate summary report
generate_summary_report() {
    log_step "Generating summary report..."
    
    local report_file="${SCRIPT_DIR}/testbed-summary-$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Bed Summary Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f9f9f9; border-radius: 3px; }
        .status-active { color: green; font-weight: bold; }
        .status-stopped { color: red; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Test Bed Summary Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Cluster:</strong> $CLUSTER_NAME</p>
        <p><strong>Region:</strong> $AWS_REGION</p>
        <p><strong>Account:</strong> $(aws sts get-caller-identity --query 'Account' --output text)</p>
    </div>
    
    <div class="section">
        <h2>Cluster Status</h2>
        <div class="metric">
            <strong>Status:</strong> 
            <span class="status-active">$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" --query 'clusters[0].status' --output text 2>/dev/null || echo "UNKNOWN")</span>
        </div>
    </div>
    
    <div class="section">
        <h2>Running Tasks</h2>
        <table>
            <tr>
                <th>Task ID</th>
                <th>Definition</th>
                <th>Status</th>
                <th>Created</th>
            </tr>
EOF
    
    # Add running tasks to report
    local running_tasks=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --desired-status RUNNING --query 'taskArns' --output text 2>/dev/null || echo "")
    if [ -n "$running_tasks" ]; then
        for task in $running_tasks; do
            local task_details=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$task" --region "$AWS_REGION" --query 'tasks[0].[taskDefinitionArn,lastStatus,createdAt]' --output text)
            local task_def=$(echo "$task_details" | cut -f1)
            local status=$(echo "$task_details" | cut -f2)
            local created=$(echo "$task_details" | cut -f3)
            
            cat >> "$report_file" << EOF
            <tr>
                <td>$(basename "$task")</td>
                <td>$(basename "$task_def")</td>
                <td class="status-active">$status</td>
                <td>$created</td>
            </tr>
EOF
        done
    else
        cat >> "$report_file" << EOF
            <tr>
                <td colspan="4">No running tasks</td>
            </tr>
EOF
    fi
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Task Definitions</h2>
        <table>
            <tr>
                <th>Family</th>
                <th>Revision</th>
                <th>Status</th>
            </tr>
EOF
    
    # Add task definitions to report
    local task_defs=$(aws ecs list-task-definitions --family-prefix "$TASK_FAMILY_PREFIX" --region "$AWS_REGION" --status ACTIVE --query 'taskDefinitionArns' --output text 2>/dev/null || echo "")
    if [ -n "$task_defs" ]; then
        for def in $task_defs; do
            local revision=$(echo "$def" | rev | cut -d: -f1 | rev)
            local family=$(echo "$def" | rev | cut -d: -f2 | rev | rev | cut -d/ -f1 | rev)
            cat >> "$report_file" << EOF
            <tr>
                <td>$family</td>
                <td>$revision</td>
                <td class="status-active">ACTIVE</td>
            </tr>
EOF
        done
    else
        cat >> "$report_file" << EOF
            <tr>
                <td colspan="3">No active task definitions</td>
            </tr>
EOF
    fi
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Resource Usage</h2>
        <p>Check the metrics directory for detailed CloudWatch metrics.</p>
    </div>
</body>
</html>
EOF
    
    log_success "Summary report generated: $report_file"
}

# Function to cleanup everything
cleanup_all() {
    log_step "Performing complete cleanup..."
    
    # Stop all running tasks
    stop_all_tasks
    
    # Wait for tasks to stop
    sleep 10
    
    # Deregister task definitions
    deregister_task_definitions
    
    # Delete log groups (optional)
    read -p "Do you want to delete CloudWatch log groups? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local log_groups=$(aws logs describe-log-groups --log-group-name-prefix "/ecs/$TASK_FAMILY_PREFIX" --region "$AWS_REGION" --query 'logGroups[*].logGroupName' --output text 2>/dev/null || echo "")
        if [ -n "$log_groups" ]; then
            for group in $log_groups; do
                if [ "$group" != "null" ]; then
                    log_info "Deleting log group: $group"
                    aws logs delete-log-group --log-group-name "$group" --region "$AWS_REGION"
                fi
            done
        fi
    fi
    
    log_success "Complete cleanup finished"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status              Check cluster and task status"
    echo "  tasks               List running tasks"
    echo "  definitions         List task definitions"
    echo "  stop-tasks          Stop all running tasks"
    echo "  cleanup             Cleanup all resources"
    echo "  logs <test_name>    Download logs for specific test"
    echo "  metrics <test_name> Get CloudWatch metrics"
    echo "  report              Generate summary report"
    echo "  health              Perform health check"
    echo "  setup               Auto-setup prerequisites and AWS"
    echo ""
    echo "Options:"
    echo "  --days <number>     Number of days back for logs (default: 1)"
    echo "  --hours <number>    Number of hours back for metrics (default: 24)"
    echo "  --auto-setup        Automatically install prerequisites and setup AWS"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_ACCESS_KEY_ID       AWS Access Key ID"
    echo "  AWS_SECRET_ACCESS_KEY   AWS Secret Access Key"
    echo "  AWS_REGION              AWS Region (default: us-east-1)"
    echo "  CLUSTER_NAME            ECS Cluster name"
    echo "  TASK_FAMILY_PREFIX      Task family prefix"
    echo ""
    echo "Examples:"
    echo "  $0 setup                    # Auto-setup everything"
    echo "  $0 status                   # Check overall status"
    echo "  $0 tasks                    # List running tasks"
    echo "  $0 logs basic --days 7      # Download 7 days of logs for basic test"
    echo "  $0 metrics queueit --hours 48 # Get 48 hours of metrics for queueit test"
    echo "  $0 cleanup                  # Cleanup all resources"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    # Check if auto-setup is requested
    if [ "$command" = "setup" ] || [[ "$*" == *"--auto-setup"* ]]; then
        log_step "Performing automatic setup..."
        install_prerequisites
        setup_aws_credentials
        check_aws_permissions
    else
        # Check prerequisites
        if ! command -v aws &> /dev/null; then
            log_error "AWS CLI not found. Run '$0 setup' to install prerequisites."
            exit 1
        fi
        
        if ! aws sts get-caller-identity &> /dev/null 2>&1; then
            log_error "AWS credentials not configured. Run '$0 setup' to configure."
            exit 1
        fi
    fi
    
    case "$command" in
        "status")
            check_cluster_status
            list_running_tasks
            list_task_definitions
            ;;
        "tasks")
            list_running_tasks
            ;;
        "definitions")
            list_task_definitions
            ;;
        "stop-tasks")
            stop_all_tasks
            ;;
        "cleanup")
            cleanup_all
            ;;
        "logs")
            if [ -z "$1" ]; then
                log_error "Test name required for logs command"
                exit 1
            fi
            local days_back="1"
            if [ "$2" = "--days" ] && [ -n "$3" ]; then
                days_back="$3"
            fi
            download_logs "$1" "$days_back"
            ;;
        "metrics")
            if [ -z "$1" ]; then
                log_error "Test name required for metrics command"
                exit 1
            fi
            local hours_back="24"
            if [ "$2" = "--hours" ] && [ -n "$3" ]; then
                hours_back="$3"
            fi
            get_metrics "$1" "$hours_back"
            ;;
        "report")
            generate_summary_report
            ;;
        "health")
            check_cluster_status
            if [ $? -eq 0 ]; then
                log_success "Health check passed"
            else
                log_error "Health check failed"
                exit 1
            fi
            ;;
        "setup")
            log_success "Setup completed successfully"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 