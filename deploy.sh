#!/bin/bash
set -e

# Check for docker compose
if ! command -v docker &> /dev/null; then
  echo "Docker is not installed. Please install Docker and try again."
  exit 1
fi
if ! docker compose version &> /dev/null; then
  echo "Docker Compose is not available. Please install Docker Compose v2 and try again."
  exit 1
fi

# Build the application JAR
mvn clean package -DskipTests -Dcheckstyle.skip=true

# Prepare the jars directory
mkdir -p jars

# Move the JAR to the jars directory with the correct name
mv -f target/spring-petclinic-3.5.0-SNAPSHOT.jar jars/pet-clinkc.jar

# Build and start all containers
docker compose up --build -d

# Wait for Grafana to be ready
printf "Waiting for Grafana to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:3000/api/health | grep 'database' &> /dev/null; then
    echo " Grafana is up!"
    break
  fi
  sleep 2
  printf "."
done

# Import the dashboard
curl -s -X POST -H "Content-Type: application/json" \
  -d @grafana_dashboard.json \
  -u admin:admin \
  http://localhost:3000/api/dashboards/import > /dev/null && \
  echo "Grafana dashboard imported!" || \
  echo "Failed to import Grafana dashboard."

# Import all Grafana dashboards from testing-projects/grafana-dashboards/
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
DASHBOARD_DIR="testing-projects/grafana-dashboards"

for dashboard in "$DASHBOARD_DIR"/*.json; do
  if [ -f "$dashboard" ]; then
    echo "Importing dashboard: $dashboard"
    curl -s -X POST -H "Content-Type: application/json" \
      -u $GRAFANA_USER:$GRAFANA_PASS \
      -d @"$dashboard" \
      "$GRAFANA_URL/api/dashboards/db" | grep -q '"status":"success"' && \
      echo "Successfully imported $dashboard" || \
      echo "Failed to import $dashboard"
  fi
done

echo "\nDeployment complete!"
echo "- PetClinic:     http://localhost:8080/"
echo "- Prometheus:    http://localhost:9090/"
echo "- Grafana:       http://localhost:3000/ (admin/admin)" 