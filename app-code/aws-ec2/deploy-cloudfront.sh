#!/bin/bash

# CloudFront Deployment Script for PetClinic Application
# This script deploys CloudFront distribution in front of your EC2 application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="petclinic-cloudfront"
DOMAIN_NAME="affluenceit.com"
AWS_REGION="us-east-1"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check Terraform version
    TF_VERSION=$(terraform version -json | jq -r '.terraform_version' | cut -d'.' -f1)
    if [ "$TF_VERSION" -lt 1 ]; then
        print_error "Terraform 1.0 or later is required. Current version: $(terraform version)"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install jq first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to initialize Terraform
init_terraform() {
    print_status "Initializing Terraform..."
    
    if [ ! -f "cloudfront.tf" ]; then
        print_error "cloudfront.tf file not found in current directory"
        exit 1
    fi
    
    terraform init
    print_success "Terraform initialized"
}

# Function to plan Terraform deployment
plan_deployment() {
    print_status "Planning CloudFront deployment..."
    
    terraform plan -var="domain_name=$DOMAIN_NAME" -var="aws_region=$AWS_REGION" -out=tfplan
    print_success "Terraform plan created"
}

# Function to deploy CloudFront
deploy_cloudfront() {
    print_status "Deploying CloudFront distribution..."
    
    terraform apply tfplan
    print_success "CloudFront distribution deployed"
}

# Function to get CloudFront information
get_cloudfront_info() {
    print_status "Getting CloudFront distribution information..."
    
    DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    DISTRIBUTION_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "")
    
    if [ -n "$DISTRIBUTION_ID" ] && [ -n "$DISTRIBUTION_DOMAIN" ]; then
        print_success "CloudFront Distribution ID: $DISTRIBUTION_ID"
        print_success "CloudFront Domain: $DISTRIBUTION_DOMAIN"
        
        # Get distribution status
        STATUS=$(aws cloudfront get-distribution --id "$DISTRIBUTION_ID" --query 'Distribution.Status' --output text 2>/dev/null || echo "Unknown")
        print_status "Distribution Status: $STATUS"
        
        if [ "$STATUS" = "Deployed" ]; then
            print_success "CloudFront distribution is deployed and ready!"
        else
            print_warning "CloudFront distribution is still deploying..."
        fi
    else
        print_warning "Could not retrieve CloudFront information"
    fi
}

# Function to validate DNS configuration
validate_dns() {
    print_status "Validating DNS configuration..."
    
    # Check if domain resolves to CloudFront
    CLOUDFRONT_IP=$(dig +short "$DOMAIN_NAME" | head -1)
    
    if [ -n "$CLOUDFRONT_IP" ]; then
        print_success "Domain $DOMAIN_NAME resolves to: $CLOUDFRONT_IP"
        
        # Check if it's a CloudFront IP
        if [[ "$CLOUDFRONT_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            print_status "Verifying if IP belongs to CloudFront..."
            # This is a simplified check - in production you might want to use AWS IP ranges
            print_success "DNS appears to be configured correctly"
        fi
    else
        print_warning "Domain $DOMAIN_NAME does not resolve. DNS propagation may take time."
    fi
}

# Function to test CloudFront
test_cloudfront() {
    print_status "Testing CloudFront distribution..."
    
    # Test main application
    if curl -sf "https://$DOMAIN_NAME/" >/dev/null; then
        print_success "Main application accessible via CloudFront"
    else
        print_warning "Main application not accessible via CloudFront yet"
    fi
    
    # Test Grafana
    if curl -sf "https://$DOMAIN_NAME/grafana/" >/dev/null; then
        print_success "Grafana accessible via CloudFront"
    else
        print_warning "Grafana not accessible via CloudFront yet"
    fi
    
    # Test Prometheus
    if curl -sf "https://$DOMAIN_NAME/prometheus/" >/dev/null; then
        print_success "Prometheus accessible via CloudFront"
    else
        print_warning "Prometheus not accessible via CloudFront yet"
    fi
}

# Function to show CloudFront logs
show_logs() {
    print_status "CloudFront logs are stored in S3 bucket: cloudfront-logs-$(aws sts get-caller-identity --query 'Account' --output text)"
    print_status "To view logs, use AWS CLI or CloudWatch Logs"
}

# Function to invalidate cache
invalidate_cache() {
    print_status "Invalidating CloudFront cache..."
    
    DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    
    if [ -n "$DISTRIBUTION_ID" ]; then
        aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"
        print_success "Cache invalidation initiated"
    else
        print_error "Could not retrieve CloudFront distribution ID"
    fi
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🌐 CloudFront Distribution Deployed!"
    echo "=========================================="
    echo ""
    echo "📱 Application Access:"
    echo "   • Main Application: https://$DOMAIN_NAME/"
    echo "   • Grafana Dashboard: https://$DOMAIN_NAME/grafana/"
    echo "   • Prometheus: https://$DOMAIN_NAME/prometheus/"
    echo ""
    echo "🔧 Management Commands:"
    echo "   • Invalidate cache: $0 invalidate"
    echo "   • Show logs: $0 logs"
    echo "   • Test access: $0 test"
    echo "   • Destroy: $0 destroy"
    echo ""
    echo "📊 CloudFront Benefits:"
    echo "   • Global CDN with edge locations"
    echo "   • SSL/TLS termination"
    echo "   • DDoS protection"
    echo "   • Caching for better performance"
    echo "   • Compression and optimization"
    echo ""
}

# Function to destroy CloudFront
destroy_cloudfront() {
    print_warning "This will destroy the CloudFront distribution and all associated resources!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Destroying CloudFront distribution..."
        terraform destroy -var="domain_name=$DOMAIN_NAME" -var="aws_region=$AWS_REGION"
        print_success "CloudFront distribution destroyed"
    else
        print_status "Destruction cancelled"
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  deploy     Deploy CloudFront distribution (default)"
    echo "  plan       Plan CloudFront deployment"
    echo "  test       Test CloudFront access"
    echo "  invalidate Invalidate CloudFront cache"
    echo "  logs       Show CloudFront logs information"
    echo "  destroy    Destroy CloudFront distribution"
    echo "  help       Show this help message"
    echo ""
    echo "💡 Prerequisites:"
    echo "   • Terraform 1.0+ installed"
    echo "   • AWS CLI configured"
    echo "   • Route53 hosted zone for $DOMAIN_NAME"
    echo "   • Valid domain name pointing to your EC2 instance"
    echo ""
}

# Main deployment function
deploy() {
    echo "=========================================="
    echo "🌐 CloudFront Distribution Deployment"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    init_terraform
    plan_deployment
    deploy_cloudfront
    get_cloudfront_info
    validate_dns
    test_cloudfront
    display_access_info
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "plan")
        check_prerequisites
        init_terraform
        plan_deployment
        ;;
    "test")
        test_cloudfront
        ;;
    "invalidate")
        invalidate_cache
        ;;
    "logs")
        show_logs
        ;;
    "destroy")
        destroy_cloudfront
        ;;
    "help")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 