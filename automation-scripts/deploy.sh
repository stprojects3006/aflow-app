#!/bin/bash
set -e

echo "🚀 Starting PetClinic deployment..."

# Check for docker compose with better path detection
echo "🔍 Checking Docker installation..."
if ! /usr/bin/docker --version &> /dev/null; then
  echo "❌ Docker is not installed. Please install Docker and try again."
  exit 1
fi
echo "✅ Docker found: $(/usr/bin/docker --version)"

echo "🔍 Checking Docker Compose..."
if /usr/local/bin/docker-compose --version &> /dev/null; then
  echo "✅ Docker Compose found: $(/usr/local/bin/docker-compose --version)"
  DOCKER_COMPOSE_CMD="/usr/local/bin/docker-compose"
elif /usr/bin/docker compose version &> /dev/null; then
  echo "✅ Docker Compose v2 found: $(/usr/bin/docker compose version)"
  DOCKER_COMPOSE_CMD="/usr/bin/docker compose"
else
  echo "❌ Docker Compose is not available. Please install Docker Compose v2 and try again."
  exit 1
fi

# Check for Maven
echo "🔍 Checking Maven installation..."
if ! mvn --version &> /dev/null; then
  echo "❌ Maven is not installed. Please install Maven and try again."
  exit 1
fi
echo "✅ Maven found: $(mvn --version | head -1)"

# Build the application JAR
echo "📦 Building application with Maven..."
mvn clean package -DskipTests -Dcheckstyle.skip=true

# Prepare the jars directory
echo "📁 Preparing JAR file..."
mkdir -p jars
mv -f target/spring-petclinic-3.5.0-SNAPSHOT.jar jars/pet-clinkc.jar
echo "✅ JAR file prepared: jars/pet-clinkc.jar"

# Stop any existing containers
echo "🛑 Stopping existing containers..."
$DOCKER_COMPOSE_CMD down || true

# Build and start all containers
echo "🐳 Building and starting containers..."
$DOCKER_COMPOSE_CMD up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check container status
echo "📊 Checking container status..."
$DOCKER_COMPOSE_CMD ps

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:3000/api/health | grep 'database' &> /dev/null; then
    echo "✅ Grafana is up!"
    break
  fi
  sleep 2
  echo -n "."
done

echo ""
echo "✅ Deployment complete!"
echo "🌐 Services available at:"
echo "- PetClinic:     http://localhost:8080/"
echo "- Prometheus:    http://localhost:9090/"
echo "- Grafana:       http://localhost:3000/ (admin/admin)"
echo ""
echo "📊 Grafana is ready for dashboard imports!"
echo "🔧 To check logs: $DOCKER_COMPOSE_CMD logs"
echo "🛑 To stop services: $DOCKER_COMPOSE_CMD down" 