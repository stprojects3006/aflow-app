#!/bin/bash

# Grafana Dashboard Import Script
# This script imports all JSON dashboard files from the testing-projects/grafana-dashboards/ directory

set -e

# Configuration
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"
DASHBOARD_DIR="${DASHBOARD_DIR:-testing-projects/grafana-dashboards}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Grafana Dashboard Import Script ===${NC}"
echo "Grafana URL: $GRAFANA_URL"
echo "Dashboard Directory: $DASHBOARD_DIR"
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

# Check if dashboard directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
    echo -e "${RED}Error: Dashboard directory '$DASHBOARD_DIR' does not exist${NC}"
    exit 1
fi

# Count JSON files
JSON_COUNT=$(find "$DASHBOARD_DIR" -name "*.json" | wc -l)
if [ "$JSON_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No JSON dashboard files found in $DASHBOARD_DIR${NC}"
    exit 0
fi

echo -e "${BLUE}Found $JSON_COUNT dashboard(s) to import${NC}"
echo ""

# Import each dashboard
SUCCESS_COUNT=0
FAILED_COUNT=0

for dashboard in "$DASHBOARD_DIR"/*.json; do
    if [ -f "$dashboard" ]; then
        DASHBOARD_NAME=$(basename "$dashboard")
        echo -e "${YELLOW}Importing: $DASHBOARD_NAME${NC}"
        
        # Import the dashboard
        RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -u "$GRAFANA_USER:$GRAFANA_PASS" \
            -d @"$dashboard" \
            "$GRAFANA_URL/api/dashboards/db" 2>/dev/null)
        
        # Check if import was successful
        if echo "$RESPONSE" | grep -q '"status":"success"'; then
            echo -e "  ${GREEN}✓ Successfully imported${NC}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo -e "  ${RED}✗ Failed to import${NC}"
            echo "  Response: $RESPONSE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
        echo ""
    fi
done

# Summary
echo -e "${BLUE}=== Import Summary ===${NC}"
echo -e "${GREEN}Successfully imported: $SUCCESS_COUNT${NC}"
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo -e "${RED}Failed to import: $FAILED_COUNT${NC}"
fi

if [ "$SUCCESS_COUNT" -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Dashboard(s) are now available at:${NC}"
    echo "  $GRAFANA_URL"
    echo "  Username: $GRAFANA_USER"
    echo "  Password: $GRAFANA_PASS"
fi

echo ""
echo -e "${BLUE}Import process completed!${NC}" 