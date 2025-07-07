#!/bin/bash

# Generate various HTTP status codes for /integration/queueit/queue using the 'status' query parameter
# This script is safe to delete after testing

APP_URL="http://localhost:8080/integration/queueit/queue"
COUNT=10
USER_ID="testuser"

# List of status codes to test
STATUS_CODES=(200 201 204 301 302 307 400 401 403 404 500)

for code in "${STATUS_CODES[@]}"; do
  echo "Generating $code responses..."
  for i in $(seq 1 $COUNT); do
    curl -s -o /dev/null -w "%{http_code}\n" -X POST "$APP_URL?userId=$USER_ID&status=$code" &
  done
done

wait
echo "QueueIt error/status code load generation complete. Check your dashboards!" 