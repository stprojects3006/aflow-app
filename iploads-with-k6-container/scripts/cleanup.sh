#!/bin/bash

# K6 Load Testing Cleanup Script
# This script removes all AWS resources created for the load testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured."
        exit 1
    fi
    
    print_status "All prerequisites are met."
}

# Function to stop all running tasks
stop_running_tasks() {
    print_status "Stopping all running ECS tasks..."
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        source "$PROJECT_ROOT/.env"
        
        # Get running tasks
        RUNNING_TASKS=$(aws ecs list-tasks \
            --cluster "$ECS_CLUSTER_NAME" \
            --desired-status RUNNING \
            --query 'taskArns' \
            --output text)
        
        if [ -n "$RUNNING_TASKS" ]; then
            for task in $RUNNING_TASKS; do
                print_status "Stopping task: $task"
                aws ecs stop-task \
                    --cluster "$ECS_CLUSTER_NAME" \
                    --task "$task" \
                    --reason "Cleanup initiated"
            done
        else
            print_status "No running tasks found."
        fi
    else
        print_warning "No .env file found. Skipping task cleanup."
    fi
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    fi
    
    # Plan destruction
    print_status "Planning destruction..."
    terraform plan -destroy -out=destroy_plan
    
    # Confirm destruction
    echo
    print_warning "This will destroy ALL resources created for the load testing project."
    print_warning "This action cannot be undone!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Destroying infrastructure..."
        terraform apply destroy_plan
        
        print_status "Infrastructure destroyed successfully!"
    else
        print_status "Destruction cancelled."
        exit 0
    fi
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove .env file
    if [ -f "$PROJECT_ROOT/.env" ]; then
        rm "$PROJECT_ROOT/.env"
        print_status "Removed .env file"
    fi
    
    # Remove Terraform files
    if [ -f "$TERRAFORM_DIR/tfplan" ]; then
        rm "$TERRAFORM_DIR/tfplan"
        print_status "Removed Terraform plan file"
    fi
    
    if [ -f "$TERRAFORM_DIR/destroy_plan" ]; then
        rm "$TERRAFORM_DIR/destroy_plan"
        print_status "Removed Terraform destroy plan file"
    fi
    
    # Remove .terraform directory
    if [ -d "$TERRAFORM_DIR/.terraform" ]; then
        rm -rf "$TERRAFORM_DIR/.terraform"
        print_status "Removed Terraform working directory"
    fi
    
    print_status "Local files cleaned up."
}

# Function to show cost estimation
show_cost_estimation() {
    print_status "Cost estimation for resources being destroyed:"
    echo
    echo "Resources that will be removed:"
    echo "  - ECS Cluster (Fargate tasks)"
    echo "  - ECR Repository"
    echo "  - VPC and Networking"
    echo "  - Security Groups"
    echo "  - CloudWatch Log Groups"
    echo "  - S3 Bucket"
    echo "  - IAM Roles"
    echo
    print_warning "Note: You may still be charged for:"
    echo "  - Data transfer (if any occurred)"
    echo "  - CloudWatch logs (retention period)"
    echo "  - S3 storage (if any data was stored)"
    echo
}

# Function to backup results
backup_results() {
    print_status "Checking for test results to backup..."
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        source "$PROJECT_ROOT/.env"
        
        # Create backup directory
        BACKUP_DIR="$PROJECT_ROOT/backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # Download CloudWatch logs if they exist
        LOG_GROUP=$(aws logs describe-log-groups \
            --log-group-name-prefix "/ecs/k6-load-test" \
            --query 'logGroups[0].logGroupName' \
            --output text)
        
        if [ "$LOG_GROUP" != "None" ]; then
            print_status "Backing up CloudWatch logs..."
            aws logs export-task \
                --log-group-name "$LOG_GROUP" \
                --from "$(date -d '1 hour ago' +%s)000" \
                --to "$(date +%s)000" \
                --destination "$BACKUP_DIR/logs" \
                --destination-prefix "k6-logs"
        fi
        
        # Download S3 results if they exist
        if [ -n "$S3_BUCKET_NAME" ]; then
            print_status "Backing up S3 results..."
            aws s3 sync "s3://$S3_BUCKET_NAME" "$BACKUP_DIR/s3-results"
        fi
        
        print_status "Backup completed: $BACKUP_DIR"
    fi
}

# Main cleanup function
main() {
    print_status "Starting K6 Load Testing cleanup..."
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Show cost estimation
    show_cost_estimation
    
    # Backup results
    backup_results
    
    # Stop running tasks
    stop_running_tasks
    
    # Destroy infrastructure
    destroy_infrastructure
    
    # Clean up local files
    cleanup_local_files
    
    print_status "Cleanup completed successfully!"
    print_status "All AWS resources have been removed."
    print_status "Local files have been cleaned up."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force    Skip confirmation prompts"
            echo "  --help     Show this help message"
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