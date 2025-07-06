#!/bin/bash

# Import All Grafana Dashboards Script
# This script imports three comprehensive dashboards for QueueIt integration monitoring

set -e

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Dashboard files
DASHBOARDS=(
    "testing-projects/grafana-dashboards/queueit-integration-dashboard.json"
    "testing-projects/grafana-dashboards/queueit-request-volume-dashboard.json"
    "testing-projects/grafana-dashboards/application-http-traffic-dashboard.json"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Grafana Dashboard Import Script${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to check if Grafana is running
check_grafana() {
    echo -e "${YELLOW}Checking Grafana availability...${NC}"
    if curl -s --connect-timeout 5 "$GRAFANA_URL/api/health" > /dev/null; then
        echo -e "${GREEN}✓ Grafana is running at $GRAFANA_URL${NC}"
        return 0
    else
        echo -e "${RED}✗ Grafana is not accessible at $GRAFANA_URL${NC}"
        echo -e "${YELLOW}Please ensure Grafana is running and accessible${NC}"
        return 1
    fi
}

# Function to wait for Grafana to be ready
wait_for_grafana() {
    echo -e "${YELLOW}Waiting for Grafana to be ready...${NC}"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s --connect-timeout 5 "$GRAFANA_URL/api/health" > /dev/null; then
            echo -e "${GREEN}✓ Grafana is ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Attempt $attempt/$max_attempts: Grafana not ready yet...${NC}"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ Grafana did not become ready within $max_attempts attempts${NC}"
    return 1
}

# Function to import a dashboard
import_dashboard() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)
    
    echo -e "${YELLOW}Importing dashboard: $dashboard_name${NC}"
    
    if [ ! -f "$dashboard_file" ]; then
        echo -e "${RED}✗ Dashboard file not found: $dashboard_file${NC}"
        return 1
    fi
    
    # Import dashboard using Grafana API
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        -d @"$dashboard_file" \
        "$GRAFANA_URL/api/dashboards/db")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "412" ]; then
        echo -e "${GREEN}✓ Successfully imported: $dashboard_name${NC}"
        if [ "$http_code" = "412" ]; then
            echo -e "${YELLOW}  Note: Dashboard already exists (HTTP 412)${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Failed to import $dashboard_name (HTTP $http_code)${NC}"
        echo -e "${RED}Response: $response_body${NC}"
        
        # Try to get more detailed error information
        if command -v jq >/dev/null 2>&1; then
            echo -e "${YELLOW}Detailed error:${NC}"
            echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
        fi
        return 1
    fi
}

# Function to verify dashboard import
verify_dashboard() {
    local dashboard_name="$1"
    echo -e "${YELLOW}Verifying dashboard: $dashboard_name${NC}"
    
    # Wait a moment for the dashboard to be indexed
    sleep 2
    
    # Check if dashboard exists in Grafana
    local response=$(curl -s -w "%{http_code}" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/search?query=$dashboard_name")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        if echo "$response_body" | grep -q "$dashboard_name"; then
            echo -e "${GREEN}✓ Dashboard verified: $dashboard_name${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Dashboard not found in search results: $dashboard_name${NC}"
            echo -e "${YELLOW}This might be normal if the dashboard was just imported${NC}"
            return 0  # Don't fail the import for this
        fi
    else
        echo -e "${YELLOW}⚠ Failed to verify dashboard (HTTP $http_code)${NC}"
        return 0  # Don't fail the import for verification issues
    fi
}

# Function to check Prometheus data source
check_prometheus_datasource() {
    echo -e "${YELLOW}Checking Prometheus data source...${NC}"
    
    local response=$(curl -s -w "%{http_code}" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/datasources")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        if echo "$response_body" | grep -q "prometheus"; then
            echo -e "${GREEN}✓ Prometheus data source found${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Prometheus data source not found${NC}"
            echo -e "${YELLOW}You may need to configure the Prometheus data source manually${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Could not check data sources (HTTP $http_code)${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Starting dashboard import process...${NC}"
    
    # Check if Grafana is running
    if ! check_grafana; then
        echo -e "${YELLOW}Attempting to wait for Grafana...${NC}"
        if ! wait_for_grafana; then
            echo -e "${RED}Failed to connect to Grafana. Please ensure it's running.${NC}"
            exit 1
        fi
    fi
    
    # Check Prometheus data source
    check_prometheus_datasource
    
    echo -e "${BLUE}Importing dashboards...${NC}"
    local success_count=0
    local total_count=${#DASHBOARDS[@]}
    
    for dashboard_file in "${DASHBOARDS[@]}"; do
        if import_dashboard "$dashboard_file"; then
            success_count=$((success_count + 1))
            
            # Verify the import
            local dashboard_name=$(basename "$dashboard_file" .json)
            verify_dashboard "$dashboard_name"
        fi
        echo ""
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Import Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Successfully imported: $success_count/$total_count dashboards${NC}"
    
    if [ $success_count -eq $total_count ]; then
        echo -e "${GREEN}✓ All dashboards imported successfully!${NC}"
        echo -e "${BLUE}Access your dashboards at: $GRAFANA_URL${NC}"
        echo -e "${BLUE}Default credentials: admin/admin${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo -e "${YELLOW}1. Generate some traffic to see metrics: ./test-metrics.sh${NC}"
        echo -e "${YELLOW}2. Check the dashboards in Grafana${NC}"
        echo -e "${YELLOW}3. If no data appears, check the troubleshooting guide in GRAFANA_METRICS_SETUP.md${NC}"
    else
        echo -e "${RED}✗ Some dashboards failed to import${NC}"
        echo -e "${YELLOW}Check the error messages above for details${NC}"
        exit 1
    fi
}

# Run main function
main "$@" 