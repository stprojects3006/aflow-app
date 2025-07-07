#!/bin/bash

# AWS EC2 PetClinic Application Deployment Script
# This script builds, tests, and deploys the complete PetClinic application with monitoring stack for AWS EC2

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="petclinic"
DOCKER_IMAGE="petclinic-app:latest"
INFRA_COMPOSE_FILE="docker-compose.infra.aws.yml"
APP_COMPOSE_FILE="docker-compose.app.aws.yml"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Java is installed
    if ! command -v java &> /dev/null; then
        print_error "Java is not installed. Please install Java 17 or later."
        exit 1
    fi
    
    # Check Java version
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -lt 17 ]; then
        print_error "Java 17 or later is required. Current version: $JAVA_VERSION"
        exit 1
    fi
    
    # Check if Maven is installed
    if ! command -v mvn &> /dev/null; then
        print_error "Maven is not installed. Please install Maven first."
        exit 1
    fi
    
    print_success "All prerequisites are satisfied"
}

# Function to stop existing containers
stop_containers() {
    print_status "Stopping existing containers..."
    
    # Stop app containers
    if docker-compose -f $APP_COMPOSE_FILE down 2>/dev/null || docker compose -f $APP_COMPOSE_FILE down 2>/dev/null; then
        print_success "Application containers stopped"
    else
        print_warning "No application containers to stop"
    fi
    
    # Stop infra containers
    if docker-compose -f $INFRA_COMPOSE_FILE down 2>/dev/null || docker compose -f $INFRA_COMPOSE_FILE down 2>/dev/null; then
        print_success "Infrastructure containers stopped"
    else
        print_warning "No infrastructure containers to stop"
    fi
}

# Function to import Grafana dashboards
grafana_api_url="http://<your-ec2-public-dns>:3000/api/dashboards/db"
grafana_user="admin"
grafana_pass="admin"
grafana_dashboards_dir="../../grafana-dashboards"

import_grafana_dashboards() {
    print_status "Importing Grafana dashboards..."
    
    # Wait a bit for Grafana to be fully ready
    sleep 5
    
    if ! curl -sf http://<your-ec2-public-dns>:3000/api/health >/dev/null; then
        print_warning "Grafana is not healthy or not running. Skipping dashboard import."
        return
    fi
    
    if [ ! -d "$grafana_dashboards_dir" ]; then
        print_warning "Grafana dashboards directory not found: $grafana_dashboards_dir"
        return
    fi
    
    local imported_count=0
    local total_count=0
    
    for dashboard in "$grafana_dashboards_dir"/*.json; do
        if [ -f "$dashboard" ]; then
            total_count=$((total_count + 1))
            print_status "Importing dashboard: $(basename "$dashboard")"
            
            # Wrap dashboard JSON in required Grafana API format if not already
            if grep -q '"dashboard"' "$dashboard"; then
                payload=$(cat "$dashboard")
            else
                payload="{\"dashboard\": $(cat "$dashboard"), \"overwrite\": true}"
            fi
            
            response=$(curl -s -u "$grafana_user:$grafana_pass" -H "Content-Type: application/json" -X POST "$grafana_api_url" -d "$payload")
            
            if echo "$response" | grep -q '"status":"success"'; then
                print_success "Imported: $(basename "$dashboard")"
                imported_count=$((imported_count + 1))
            else
                print_warning "Failed to import $(basename "$dashboard"): $response"
            fi
        fi
    done
    
    if [ $total_count -gt 0 ]; then
        print_success "Dashboard import completed: $imported_count/$total_count dashboards imported"
    else
        print_warning "No dashboard files found in $grafana_dashboards_dir"
    fi
}

# Function to check service health
check_service_health() {
    print_status "Checking service health..."
    
    local all_healthy=true
    
    # Check PetClinic application
    if curl -f http://<your-ec2-public-dns>:8080/actuator/health >/dev/null 2>&1; then
        print_success "PetClinic application is healthy"
    else
        print_warning "PetClinic application health check failed"
        all_healthy=false
    fi
    
    # Check Prometheus
    if curl -f http://<your-ec2-public-dns>:9090/-/healthy >/dev/null 2>&1; then
        print_success "Prometheus is healthy"
    else
        print_warning "Prometheus health check failed"
        all_healthy=false
    fi
    
    # Check Grafana
    if curl -f http://<your-ec2-public-dns>:3000/api/health >/dev/null 2>&1; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana health check failed"
        all_healthy=false
    fi
    
    # Check Nginx
    if curl -f http://<your-ec2-public-dns>/ >/dev/null 2>&1; then
        print_success "Nginx is healthy"
    else
        print_warning "Nginx health check failed"
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        print_success "All services are healthy"
    else
        print_warning "Some services may not be fully ready yet"
    fi
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🚀 PetClinic Application Deployed Successfully!"
    echo "=========================================="
    echo ""
    echo "📱 Application Access:"
    echo "   • Main Application: http://<your-ec2-public-dns>/"
    echo "   • Direct PetClinic: http://<your-ec2-public-dns>:8080/"
    echo ""
    echo "📊 Monitoring Access:"
    echo "   • Grafana Dashboard: http://<your-ec2-public-dns>/grafana/"
    echo "   • Direct Grafana: http://<your-ec2-public-dns>:3000/ (admin/admin)"
    echo "   • Prometheus: http://<your-ec2-public-dns>/prometheus/"
    echo "   • Direct Prometheus: http://<your-ec2-public-dns>:9090/"
    echo ""
    echo "🗄️  Database Access:"
    echo "   • MySQL: <your-ec2-public-dns>:3306 (petclinic/petclinic)"
    echo "   • PostgreSQL: <your-ec2-public-dns>:5432 (petclinic/petclinic)"
    echo ""
    echo "🔧 Management Commands:"
    echo "   • View logs: docker-compose logs -f [service]"
    echo "   • Stop services: docker-compose down"
    echo "   • Restart services: docker-compose restart"
    echo "   • View status: docker-compose ps"
    echo ""
    echo "📈 QueueIt Integration Testing:"
    echo "   • Integration Test Page: http://<your-ec2-public-dns>:8080/integration/queueit"
    echo ""
}

# Function to show logs
show_logs() {
    print_status "Showing application logs..."
    ./deploy-app.aws.sh logs
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Stop containers
    stop_containers
    
    print_success "Cleanup completed"
}

# Main deployment function
deploy() {
    echo "=========================================="
    echo "🐾 PetClinic Complete Stack Deployment"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    
    # Step 1: Deploy infrastructure first
    print_status "Step 1: Deploying infrastructure (databases + monitoring)..."
    ./deploy-infra.aws.sh deploy
    
    # Step 2: Wait for infrastructure to be fully ready
    print_status "Step 2: Waiting for infrastructure to be fully ready..."
    wait_for_infrastructure
    
    # Step 3: Import Grafana dashboards (after infra is ready)
    print_status "Step 3: Importing Grafana dashboards..."
    import_grafana_dashboards
    
    # Step 4: Deploy application
    print_status "Step 4: Deploying application..."
    ./deploy-app.aws.sh deploy
    
    display_access_info
}

# Function to wait for infrastructure to be ready
wait_for_infrastructure() {
    print_status "Waiting for infrastructure services to be ready..."
    
    # Wait for databases
    local max_attempts=60
    local attempt=1
    
    # Wait for MySQL
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f $INFRA_COMPOSE_FILE exec -T mysql mysqladmin ping -h localhost >/dev/null 2>&1; then
            print_success "MySQL is ready"
            break
        fi
        print_status "Waiting for MySQL... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "MySQL failed to start within expected time"
        exit 1
    fi
    
    # Wait for PostgreSQL
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f $INFRA_COMPOSE_FILE exec -T postgres pg_isready -U petclinic >/dev/null 2>&1; then
            print_success "PostgreSQL is ready"
            break
        fi
        print_status "Waiting for PostgreSQL... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "PostgreSQL failed to start within expected time"
        exit 1
    fi
    
    # Wait for Prometheus
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://<your-ec2-public-dns>:9090/-/healthy >/dev/null 2>&1; then
            print_success "Prometheus is ready"
            break
        fi
        print_status "Waiting for Prometheus... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Prometheus failed to start within expected time"
        exit 1
    fi
    
    # Wait for Grafana
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://<your-ec2-public-dns>:3000/api/health >/dev/null 2>&1; then
            print_success "Grafana is ready"
            break
        fi
        print_status "Waiting for Grafana... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Grafana failed to start within expected time"
        exit 1
    fi
    
    print_success "All infrastructure services are ready!"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  deploy     Deploy the complete application stack (default)"
    echo "  app        Deploy only the PetClinic application"
    echo "  infra      Deploy only the monitoring infrastructure"
    echo "  start      Start the application stack"
    echo "  stop       Stop the application stack"
    echo "  restart    Restart the application stack"
    echo "  logs       Show application logs"
    echo "  status     Show service status"
    echo "  cleanup    Clean up all resources"
    echo "  dashboards Import Grafana dashboards"
    echo "  help       Show this help message"
    echo ""
    echo "💡 For separate deployments:"
    echo "   • Application only: ./deploy-app.aws.sh"
    echo "   • Infrastructure only: ./deploy-infra.aws.sh"
    echo "   • Dashboard import: ./deploy-grafana-dashboards.sh"
    echo ""
}

# Function to show status
show_status() {
    print_status "Infrastructure Service Status:"
    ./deploy-infra.aws.sh status
    
    echo ""
    print_status "Application Service Status:"
    ./deploy-app.aws.sh status
}

# Function to restart services
restart_services() {
    print_status "Restarting infrastructure services..."
    ./deploy-infra.aws.sh restart
    
    print_status "Restarting application services..."
    ./deploy-app.aws.sh restart
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "app")
        print_status "Deploying application only..."
        ./deploy-app.aws.sh deploy
        ;;
    "infra")
        print_status "Deploying infrastructure only..."
        ./deploy-infra.aws.sh deploy
        ;;
    "start")
        print_status "Starting application stack..."
        ./deploy-app.aws.sh start
        ;;
    "stop")
        stop_containers
        ;;
    "restart")
        restart_services
        ;;
    "logs")
        show_logs
        ;;
    "status")
        show_status
        ;;
    "cleanup")
        cleanup
        ;;
    "dashboards")
        print_status "Importing Grafana dashboards..."
        import_grafana_dashboards
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 