#!/bin/bash

# Generate load for PetClinic and QueueIt endpoints for dashboard testing
# This script is safe to delete after testing

APP_URL="http://localhost:8080"

# Number of requests per endpoint
COUNT=50

# Endpoints to hit
ENDPOINTS=(
  "/"
  "/owners"
  "/vets"
  "/pets"
  "/integration/queueit/queue"
)

# Generate GET requests
for endpoint in "${ENDPOINTS[@]}"; do
  echo "Generating GET load for $APP_URL$endpoint ..."
  for i in $(seq 1 $COUNT); do
    curl -s -o /dev/null "$APP_URL$endpoint" &
  done
done

# Generate POST requests to QueueIt endpoint
for i in $(seq 1 $COUNT); do
  curl -s -X POST -o /dev/null "$APP_URL/integration/queueit/queue" &
done

wait

echo "Load generation complete. Check your dashboards in Grafana!" 