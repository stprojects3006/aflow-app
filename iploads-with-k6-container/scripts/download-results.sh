#!/bin/bash

# Download K6 Test Results from S3
# This script downloads test results from your S3 bucket

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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

# Function to get S3 bucket info
get_s3_info() {
    if [ -f "$PROJECT_ROOT/.env" ]; then
        source "$PROJECT_ROOT/.env"
        S3_BUCKET=$(aws s3 ls | grep k6-load-test-results | head -1 | awk '{print $3}')
        if [ -z "$S3_BUCKET" ]; then
            print_error "No k6 results bucket found. Please deploy the infrastructure first."
            exit 1
        fi
    else
        print_error "No .env file found. Please run './scripts/deploy.sh' first."
        exit 1
    fi
}

# Function to list available test results
list_results() {
    print_status "Available test results in S3:"
    aws s3 ls "s3://$S3_BUCKET/test-results/" --recursive | head -20
}

# Function to download specific test results
download_results() {
    local test_type=$1
    local timestamp=$2
    local local_dir=$3
    
    if [ -z "$test_type" ]; then
        print_error "Please specify test type (basic, stress, spike)"
        exit 1
    fi
    
    if [ -z "$timestamp" ]; then
        # Get latest timestamp
        timestamp=$(aws s3 ls "s3://$S3_BUCKET/test-results/$test_type/" | tail -1 | awk '{print $2}' | sed 's/\///')
    fi
    
    if [ -z "$local_dir" ]; then
        local_dir="./results/$test_type-$timestamp"
    fi
    
    print_status "Downloading results for $test_type test from $timestamp..."
    
    # Create local directory
    mkdir -p "$local_dir"
    
    # Download results
    aws s3 cp "s3://$S3_BUCKET/test-results/$test_type/$timestamp/" "$local_dir/" --recursive
    
    print_status "Results downloaded to: $local_dir"
    
    # Show downloaded files
    ls -la "$local_dir/"
}

# Function to download latest results
download_latest() {
    local test_type=$1
    
    if [ -z "$test_type" ]; then
        print_error "Please specify test type (basic, stress, spike)"
        exit 1
    fi
    
    # Get latest timestamp
    local latest_timestamp=$(aws s3 ls "s3://$S3_BUCKET/test-results/$test_type/" | tail -1 | awk '{print $2}' | sed 's/\///')
    
    if [ -z "$latest_timestamp" ]; then
        print_error "No results found for $test_type test"
        exit 1
    fi
    
    download_results "$test_type" "$latest_timestamp"
}

# Function to show S3 bucket info
show_bucket_info() {
    print_status "S3 Bucket Information:"
    echo "Bucket Name: $S3_BUCKET"
    echo "Bucket URL: https://s3.${AWS_REGION:-us-east-1}.amazonaws.com/$S3_BUCKET"
    echo "Results Path: s3://$S3_BUCKET/test-results/"
    echo ""
    
    print_status "Recent test results:"
    aws s3 ls "s3://$S3_BUCKET/test-results/" --recursive | tail -10
}

# Main function
main() {
    case ${1:-help} in
        "list")
            get_s3_info
            list_results
            ;;
        "download")
            get_s3_info
            download_results "$2" "$3" "$4"
            ;;
        "latest")
            get_s3_info
            download_latest "$2"
            ;;
        "info")
            get_s3_info
            show_bucket_info
            ;;
        "help"|*)
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  list                    List available test results"
            echo "  download TYPE [TIMESTAMP] [LOCAL_DIR]  Download specific test results"
            echo "  latest TYPE             Download latest results for test type"
            echo "  info                    Show S3 bucket information"
            echo "  help                    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 list"
            echo "  $0 download basic 20240706-143022"
            echo "  $0 latest stress"
            echo "  $0 info"
            ;;
    esac
}

# Run main function
main "$@" 