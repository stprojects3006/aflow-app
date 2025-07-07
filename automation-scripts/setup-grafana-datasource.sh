#!/bin/bash

# Setup Grafana Data Source Script
# This script configures the Prometheus data source in Grafana

set -e

# Configuration
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASSWORD="admin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Grafana Data Source Setup Script${NC}"
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

# Function to check if Prometheus data source exists
check_prometheus_datasource() {
    echo -e "${YELLOW}Checking Prometheus data source...${NC}"
    
    local response=$(curl -s -w "%{http_code}" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/datasources")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        if echo "$response_body" | grep -q "prometheus"; then
            echo -e "${GREEN}✓ Prometheus data source already exists${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Prometheus data source not found${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Could not check data sources (HTTP $http_code)${NC}"
        return 1
    fi
}

# Function to create Prometheus data source
create_prometheus_datasource() {
    echo -e "${YELLOW}Creating Prometheus data source...${NC}"
    
    # Create the data source configuration
    local datasource_config='{
        "name": "Prometheus",
        "type": "prometheus",
        "url": "http://prometheus:9090",
        "access": "proxy",
        "isDefault": true,
        "jsonData": {
            "timeInterval": "15s"
        }
    }'
    
    # Create the data source
    local response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        -d "$datasource_config" \
        "$GRAFANA_URL/api/datasources")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "409" ]; then
        echo -e "${GREEN}✓ Prometheus data source created successfully${NC}"
        if [ "$http_code" = "409" ]; then
            echo -e "${YELLOW}  Note: Data source already exists (HTTP 409)${NC}"
        fi
        return 0
    else
        echo -e "${RED}✗ Failed to create Prometheus data source (HTTP $http_code)${NC}"
        echo -e "${RED}Response: $response_body${NC}"
        
        # Try to get more detailed error information
        if command -v jq >/dev/null 2>&1; then
            echo -e "${YELLOW}Detailed error:${NC}"
            echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
        fi
        return 1
    fi
}

# Function to test Prometheus data source
test_prometheus_datasource() {
    echo -e "${YELLOW}Testing Prometheus data source...${NC}"
    
    # Test the data source by querying for a simple metric
    local response=$(curl -s -w "%{http_code}" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/datasources/proxy/1/api/v1/query?query=up")
    
    local http_code="${response: -3}"
    local response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Prometheus data source is working${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Prometheus data source test failed (HTTP $http_code)${NC}"
        echo -e "${YELLOW}This might be normal if Prometheus is not running yet${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Starting Grafana data source setup...${NC}"
    
    # Check if Grafana is running
    if ! check_grafana; then
        echo -e "${RED}Failed to connect to Grafana. Please ensure it's running.${NC}"
        exit 1
    fi
    
    # Check if Prometheus data source already exists
    if check_prometheus_datasource; then
        echo -e "${GREEN}✓ Prometheus data source is already configured${NC}"
    else
        # Create the Prometheus data source
        if create_prometheus_datasource; then
            echo -e "${GREEN}✓ Prometheus data source created successfully${NC}"
        else
            echo -e "${RED}✗ Failed to create Prometheus data source${NC}"
            echo -e "${YELLOW}You may need to configure it manually in Grafana${NC}"
            echo -e "${YELLOW}URL: http://prometheus:9090${NC}"
            exit 1
        fi
    fi
    
    # Test the data source
    test_prometheus_datasource
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Setup Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}✓ Grafana data source setup completed!${NC}"
    echo -e "${BLUE}You can now import dashboards using: ./import-all-dashboards.sh${NC}"
}

# Run main function
main "$@" 