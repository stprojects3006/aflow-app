#!/bin/bash

# Automated Queue-it Max Capacity Finder
# This script ramps up K6 load and logs results to help determine the max queue size

set -e

# Configuration
K6_SCRIPT="testing-projects/k6-load-test/k6-load-test.js"
RESULTS_DIR="queueit-capacity-results"
VUS_LIST=(100 500 1000 2000 5000 10000 20000)
DURATION="1m"
SLEEP_BETWEEN=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$RESULTS_DIR"

SUMMARY_FILE="$RESULTS_DIR/summary_$(date +%Y%m%d_%H%M%S).csv"
echo "VUs,Redirects,Successes,Errors,Notes" > "$SUMMARY_FILE"

echo -e "${BLUE}=== Automated Queue-it Max Capacity Finder ===${NC}"
echo "K6 Script: $K6_SCRIPT"
echo "Results Directory: $RESULTS_DIR"
echo "Test Durations: $DURATION each"
echo "Sleeping $SLEEP_BETWEEN seconds between tests"
echo ""

for vus in "${VUS_LIST[@]}"; do
  echo -e "${YELLOW}Running test with $vus VUs...${NC}"
  LOG_FILE="$RESULTS_DIR/k6_result_${vus}.log"
  k6 run --vus $vus --duration $DURATION $K6_SCRIPT > "$LOG_FILE" 2>&1

  # Parse results
  redirects=$(grep -i 'redirected to Queue-it' "$LOG_FILE" | wc -l)
  successes=$(grep -i 'status is 200' "$LOG_FILE" | wc -l)
  errors=$(grep -i '✗' "$LOG_FILE" | wc -l)

  # Notes: If errors > 0, flag as possible queue full
  notes=""
  if [ "$errors" -gt 0 ]; then
    notes="Possible queue full or errors detected"
  fi

  echo "$vus,$redirects,$successes,$errors,$notes" >> "$SUMMARY_FILE"
  echo -e "  Redirects: $redirects | Successes: $successes | Errors: $errors"
  echo -e "  Results logged to $LOG_FILE"
  echo ""
  sleep $SLEEP_BETWEEN

done

echo -e "${GREEN}=== Test Complete ===${NC}"
echo "Summary CSV: $SUMMARY_FILE"
echo "Review the summary and logs to determine the max queue capacity." 