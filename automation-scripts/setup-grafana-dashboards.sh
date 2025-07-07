#!/bin/bash

# Grafana Dashboard Setup Script
# This script combines cleanup and import steps for a fresh Grafana setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Grafana Dashboard Setup Script ===${NC}"
echo "This script will clean existing Grafana data and import fresh dashboards."
echo ""

# Check if individual scripts exist
if [ ! -f "./clean-grafana-data.sh" ]; then
    echo -e "${RED}Error: clean-grafana-data.sh not found${NC}"
    exit 1
fi

if [ ! -f "./import-grafana-dashboards.sh" ]; then
    echo -e "${RED}Error: import-grafana-dashboards.sh not found${NC}"
    exit 1
fi

# Make sure scripts are executable
chmod +x ./clean-grafana-data.sh
chmod +x ./import-grafana-dashboards.sh

echo -e "${YELLOW}Step 1: Cleaning existing Grafana data...${NC}"
echo "=================================================="
./clean-grafana-data.sh

echo ""
echo -e "${YELLOW}Step 2: Importing fresh dashboards...${NC}"
echo "================================================"
./import-grafana-dashboards.sh

echo ""
echo -e "${BLUE}=== Setup Complete ===${NC}"
echo -e "${GREEN}✓ Grafana has been cleaned and fresh dashboards imported${NC}"
echo ""
echo -e "${YELLOW}Access your dashboards at:${NC}"
echo "  http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${BLUE}Setup process completed successfully!${NC}" 