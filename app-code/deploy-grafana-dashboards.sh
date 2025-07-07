#!/bin/bash

# Grafana Dashboard Import Script
# This script imports dashboards into Grafana without affecting existing deployments

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GRAFANA_API_URL="http://localhost:3000/api/dashboards/db"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DEFAULT_DASHBOARDS_DIR="grafana-dashboards"

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
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed. Please install curl first."
        exit 1
    fi
    
    # Check if Grafana is running
    if ! curl -sf http://localhost:3000/api/health >/dev/null; then
        print_error "Grafana is not running on localhost:3000"
        print_error "Please start Grafana first using: ./deploy-infra.sh"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to wait for Grafana to be ready
wait_for_grafana() {
    print_status "Waiting for Grafana to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:3000/api/health >/dev/null; then
            print_success "Grafana is ready"
            return 0
        fi
        print_status "Waiting for Grafana... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "Grafana is not ready after $max_attempts attempts"
    return 1
}

# Function to import a single dashboard
import_dashboard() {
    local dashboard_file="$1"
    local overwrite="${2:-true}"
    
    if [ ! -f "$dashboard_file" ]; then
        print_warning "Dashboard file not found: $dashboard_file"
        return 1
    fi
    
    print_status "Importing dashboard: $dashboard_file"
    
    # Prepare payload
    local payload
    if grep -q '"dashboard"' "$dashboard_file"; then
        # File already has the correct format
        payload=$(cat "$dashboard_file")
        # Update overwrite flag if present
        if [ "$overwrite" = "true" ]; then
            payload=$(echo "$payload" | sed 's/"overwrite": *false/"overwrite": true/g')
            if ! echo "$payload" | grep -q '"overwrite"'; then
                payload=$(echo "$payload" | sed 's/}$/, "overwrite": true}/')
            fi
        fi
    else
        # Wrap in required format
        payload="{\"dashboard\": $(cat "$dashboard_file"), \"overwrite\": $overwrite}"
    fi
    
    # Import dashboard
    local response
    response=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -H "Content-Type: application/json" \
        -X POST "$GRAFANA_API_URL" \
        -d "$payload")
    
    if echo "$response" | grep -q '"status":"success"'; then
        local dashboard_title
        dashboard_title=$(echo "$response" | grep -o '"title":"[^"]*"' | cut -d'"' -f4)
        print_success "Imported: $dashboard_title"
        return 0
    else
        local error_msg
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$error_msg" ]; then
            error_msg="Unknown error"
        fi
        print_warning "Failed to import $dashboard_file: $error_msg"
        return 1
    fi
}

# Function to import all dashboards from a directory
import_dashboards_from_dir() {
    local dashboards_dir="$1"
    local overwrite="${2:-true}"
    
    if [ ! -d "$dashboards_dir" ]; then
        print_warning "Dashboards directory not found: $dashboards_dir"
        return 1
    fi
    
    print_status "Importing dashboards from: $dashboards_dir"
    
    local success_count=0
    local total_count=0
    
    for dashboard in "$dashboards_dir"/*.json; do
        if [ -f "$dashboard" ]; then
            total_count=$((total_count + 1))
            if import_dashboard "$dashboard" "$overwrite"; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    print_success "Import completed: $success_count/$total_count dashboards imported successfully"
    return $((total_count - success_count))
}

# Function to list existing dashboards
list_dashboards() {
    print_status "Listing existing dashboards..."
    
    local response
    response=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -H "Content-Type: application/json" \
        -X GET "http://localhost:3000/api/search?type=dash-db")
    
    if echo "$response" | grep -q '"title"'; then
        echo "$response" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 | sort
    else
        print_warning "No dashboards found or unable to retrieve dashboard list"
    fi
}

# Function to delete a dashboard
delete_dashboard() {
    local dashboard_uid="$1"
    
    if [ -z "$dashboard_uid" ]; then
        print_error "Dashboard UID is required"
        return 1
    fi
    
    print_status "Deleting dashboard: $dashboard_uid"
    
    local response
    response=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -H "Content-Type: application/json" \
        -X DELETE "http://localhost:3000/api/dashboards/uid/$dashboard_uid")
    
    if echo "$response" | grep -q '"message":"Dashboard deleted"'; then
        print_success "Dashboard deleted: $dashboard_uid"
        return 0
    else
        print_warning "Failed to delete dashboard: $dashboard_uid"
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION] [ARGUMENTS]"
    echo ""
    echo "Options:"
    echo "  import [DIR]     Import all dashboards from directory (default: grafana-dashboards)"
    echo "  import-file FILE Import a single dashboard file"
    echo "  list             List all existing dashboards"
    echo "  delete UID       Delete a dashboard by UID"
    echo "  help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 import                           # Import from default directory"
    echo "  $0 import custom-dashboards         # Import from custom directory"
    echo "  $0 import-file my-dashboard.json    # Import single file"
    echo "  $0 list                             # List existing dashboards"
    echo "  $0 delete abc123                    # Delete dashboard with UID abc123"
    echo ""
    echo "Environment Variables:"
    echo "  GRAFANA_URL      Grafana URL (default: http://localhost:3000)"
    echo "  GRAFANA_USER     Grafana username (default: admin)"
    echo "  GRAFANA_PASS     Grafana password (default: admin)"
    echo ""
}

# Function to validate Grafana connection
validate_connection() {
    print_status "Validating Grafana connection..."
    
    local response
    response=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" \
        -H "Content-Type: application/json" \
        -X GET "http://localhost:3000/api/search")
    
    if echo "$response" | grep -q '\[\]' || echo "$response" | grep -q '"title"'; then
        print_success "Grafana connection validated"
        return 0
    else
        print_error "Failed to connect to Grafana. Check credentials and URL."
        return 1
    fi
}

# Main function
main() {
    echo "=========================================="
    echo "📊 Grafana Dashboard Import Tool"
    echo "=========================================="
    echo ""
    
    # Override defaults with environment variables
    if [ -n "$GRAFANA_URL" ]; then
        GRAFANA_API_URL="${GRAFANA_URL}/api/dashboards/db"
    fi
    if [ -n "$GRAFANA_USER" ]; then
        GRAFANA_USER="$GRAFANA_USER"
    fi
    if [ -n "$GRAFANA_PASS" ]; then
        GRAFANA_PASS="$GRAFANA_PASS"
    fi
    
    check_prerequisites
    validate_connection
    
    case "${1:-import}" in
        "import")
            local dashboards_dir="${2:-$DEFAULT_DASHBOARDS_DIR}"
            import_dashboards_from_dir "$dashboards_dir"
            ;;
        "import-file")
            if [ -z "$2" ]; then
                print_error "Dashboard file path is required"
                show_help
                exit 1
            fi
            import_dashboard "$2"
            ;;
        "list")
            list_dashboards
            ;;
        "delete")
            if [ -z "$2" ]; then
                print_error "Dashboard UID is required"
                show_help
                exit 1
            fi
            delete_dashboard "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 