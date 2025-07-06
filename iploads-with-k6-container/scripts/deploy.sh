#!/bin/bash

# K6 Load Testing Deployment Script
# This script deploys the complete infrastructure and builds/pushes the Docker image

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
DOCKER_DIR="$PROJECT_ROOT/docker"

# Default values
AWS_REGION=${AWS_REGION:-"us-east-1"}
TARGET_URL=${TARGET_URL:-"http://localhost:8080"}
TEST_TYPE=${TEST_TYPE:-"basic"}

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
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "All prerequisites are met."
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan \
        -var="aws_region=$AWS_REGION" \
        -var="target_url=$TARGET_URL" \
        -var="test_type=$TEST_TYPE" \
        -out=tfplan
    
    # Apply deployment
    print_status "Applying infrastructure changes..."
    terraform apply tfplan
    
    # Get outputs
    print_status "Getting deployment outputs..."
    ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
    ECS_CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)
    SUBNET_ID=$(terraform output -raw subnet_id)
    SECURITY_GROUP_ID=$(terraform output -raw security_group_id)
    
    # Export variables for other scripts
    echo "export ECR_REPO_URL=$ECR_REPO_URL" > "$PROJECT_ROOT/.env"
    echo "export ECS_CLUSTER_NAME=$ECS_CLUSTER_NAME" >> "$PROJECT_ROOT/.env"
    echo "export SUBNET_ID=$SUBNET_ID" >> "$PROJECT_ROOT/.env"
    echo "export SECURITY_GROUP_ID=$SECURITY_GROUP_ID" >> "$PROJECT_ROOT/.env"
    echo "export AWS_REGION=$AWS_REGION" >> "$PROJECT_ROOT/.env"
    
    print_status "Infrastructure deployed successfully!"
}

# Function to build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    # Source environment variables
    if [ -f "$PROJECT_ROOT/.env" ]; then
        source "$PROJECT_ROOT/.env"
    fi
    
    cd "$PROJECT_ROOT"
    
    # Build Docker image
    print_status "Building Docker image..."
    docker build -t k6-load-test:latest "$DOCKER_DIR"
    
    # Tag for ECR
    print_status "Tagging image for ECR..."
    docker tag k6-load-test:latest "$ECR_REPO_URL:latest"
    
    # Login to ECR
    print_status "Logging in to ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$ECR_REPO_URL"
    
    # Push to ECR
    print_status "Pushing image to ECR..."
    docker push "$ECR_REPO_URL:latest"
    
    print_status "Docker image built and pushed successfully!"
}

# Function to run initial test
run_initial_test() {
    print_status "Running initial load test..."
    
    # Source environment variables
    if [ -f "$PROJECT_ROOT/.env" ]; then
        source "$PROJECT_ROOT/.env"
    fi
    
    # Run ECS task
    print_status "Starting ECS task..."
    TASK_ARN=$(aws ecs run-task \
        --cluster "$ECS_CLUSTER_NAME" \
        --task-definition k6-load-test-k6-task \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --query 'tasks[0].taskArn' \
        --output text)
    
    print_status "Task started with ARN: $TASK_ARN"
    print_status "You can monitor the task in the AWS Console or use:"
    print_status "aws ecs describe-tasks --cluster $ECS_CLUSTER_NAME --tasks $TASK_ARN"
}

# Main deployment function
main() {
    print_status "Starting K6 Load Testing deployment..."
    print_status "Configuration:"
    print_status "  AWS Region: $AWS_REGION"
    print_status "  Target URL: $TARGET_URL"
    print_status "  Test Type: $TEST_TYPE"
    echo
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy infrastructure
    deploy_infrastructure
    
    # Build and push image
    build_and_push_image
    
    # Run initial test
    run_initial_test
    
    print_status "Deployment completed successfully!"
    print_status "Next steps:"
    print_status "1. Monitor the test in AWS Console"
    print_status "2. Check CloudWatch logs for results"
    print_status "3. Use './scripts/run-tests.sh' to run additional tests"
    print_status "4. Use './scripts/cleanup.sh' to clean up resources"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --target-url)
            TARGET_URL="$2"
            shift 2
            ;;
        --test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --region REGION     AWS region (default: us-east-1)"
            echo "  --target-url URL    Target URL for testing (default: http://localhost:8080)"
            echo "  --test-type TYPE    Test type: basic, stress, spike (default: basic)"
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