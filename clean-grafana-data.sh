#!/bin/bash

# Grafana Data Cleanup Script
# This script cleans existing Grafana data to ensure fresh imports

set -e

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Grafana Data Cleanup Script ===${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo ""

# Check if Grafana is accessible
echo -e "${YELLOW}Checking Grafana connectivity...${NC}"
if ! curl -s "$GRAFANA_URL/api/health" | grep -q 'database'; then
    echo -e "${RED}Error: Cannot connect to Grafana at $GRAFANA_URL${NC}"
    echo "Please ensure Grafana is running and accessible."
    exit 1
fi
echo -e "${GREEN}✓ Grafana is accessible${NC}"
echo ""

# Get API key for authentication
echo -e "${YELLOW}Getting API key...${NC}"
API_KEY=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d '{"name":"cleanup-script","role":"Admin"}' \
    "$GRAFANA_URL/api/auth/keys" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
    echo -e "${RED}Failed to get API key. Using basic auth instead.${NC}"
    AUTH_HEADER="-u $GRAFANA_USER:$GRAFANA_PASS"
else
    echo -e "${GREEN}✓ Got API key${NC}"
    AUTH_HEADER="-H \"Authorization: Bearer $API_KEY\""
fi

# Function to delete dashboards
delete_dashboards() {
    echo -e "${YELLOW}Deleting existing dashboards...${NC}"
    
    # Get list of dashboards
    DASHBOARDS=$(curl -s -X GET \
        -H "Content-Type: application/json" \
        $AUTH_HEADER \
        "$GRAFANA_URL/api/search" | grep -o '"uid":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$DASHBOARDS" ]; then
        echo -e "${GREEN}No dashboards found to delete${NC}"
        return
    fi
    
    for uid in $DASHBOARDS; do
        echo "  Deleting dashboard: $uid"
        curl -s -X DELETE \
            -H "Content-Type: application/json" \
            $AUTH_HEADER \
            "$GRAFANA_URL/api/dashboards/uid/$uid" > /dev/null
    done
    echo -e "${GREEN}✓ Dashboards deleted${NC}"
}

# Function to delete datasources
delete_datasources() {
    echo -e "${YELLOW}Deleting existing datasources...${NC}"
    
    # Get list of datasources
    DATASOURCES=$(curl -s -X GET \
        -H "Content-Type: application/json" \
        $AUTH_HEADER \
        "$GRAFANA_URL/api/datasources" | grep -o '"id":[0-9]*' | cut -d':' -f2)
    
    if [ -z "$DATASOURCES" ]; then
        echo -e "${GREEN}No datasources found to delete${NC}"
        return
    fi
    
    for id in $DATASOURCES; do
        echo "  Deleting datasource ID: $id"
        curl -s -X DELETE \
            -H "Content-Type: application/json" \
            $AUTH_HEADER \
            "$GRAFANA_URL/api/datasources/$id" > /dev/null
    done
    echo -e "${GREEN}✓ Datasources deleted${NC}"
}

# Function to clear annotations
clear_annotations() {
    echo -e "${YELLOW}Clearing annotations...${NC}"
    
    # Get annotations and delete them
    curl -s -X DELETE \
        -H "Content-Type: application/json" \
        $AUTH_HEADER \
        "$GRAFANA_URL/api/annotations" > /dev/null
    
    echo -e "${GREEN}✓ Annotations cleared${NC}"
}

# Main cleanup process
echo -e "${BLUE}Starting cleanup process...${NC}"
echo ""

# Delete dashboards
delete_dashboards
echo ""

# Delete datasources (optional - uncomment if needed)
# delete_datasources
# echo ""

# Clear annotations
clear_annotations
echo ""

echo -e "${BLUE}=== Cleanup Summary ===${NC}"
echo -e "${GREEN}✓ Grafana data has been cleaned${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run the import script: ./import-grafana-dashboards.sh"
echo "2. Or manually import dashboards through the Grafana UI"
echo ""
echo -e "${BLUE}Cleanup process completed!${NC}"

# Clean up API key if it was created
if [ ! -z "$API_KEY" ]; then
    echo -e "${YELLOW}Cleaning up API key...${NC}"
    curl -s -X DELETE \
        -H "Content-Type: application/json" \
        -u "$GRAFANA_USER:$GRAFANA_PASS" \
        "$GRAFANA_URL/api/auth/keys/1" > /dev/null
fi 