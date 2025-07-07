#!/bin/bash

# AWS EC2 PetClinic Infrastructure-Only Deployment Script
# This script deploys monitoring infrastructure (Prometheus, Grafana, nginx) for AWS EC2

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.infra.aws.yml"
INFRA_IMAGES=("mysql:8.0" "postgres:17" "prom/prometheus:v2.50.0" "grafana/grafana:12.0.2" "nginx:alpine")

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
    
    print_success "All prerequisites are satisfied"
}

# Function to clean existing Docker images
clean_docker_images() {
    print_status "Cleaning existing Docker images..."
    
    # Remove infrastructure images if they exist
    for image in "${INFRA_IMAGES[@]}"; do
        if docker rmi $image 2>/dev/null; then
            print_success "Removed image: $image"
        else
            print_warning "No existing image to remove: $image"
        fi
    done
    
    # Clean up any dangling images
    if docker image prune -f 2>/dev/null; then
        print_success "Dangling images cleaned up"
    fi
}

# Function to clean Docker volumes
clean_docker_volumes() {
    print_status "Cleaning Docker volumes..."
    
    # List of volumes to clean
    VOLUMES=("mysql_data" "postgres_data" "prometheus_data" "grafana_data")
    
    for volume in "${VOLUMES[@]}"; do
        if docker volume rm $volume 2>/dev/null; then
            print_success "Removed volume: $volume"
        else
            print_warning "No existing volume to remove: $volume"
        fi
    done
    
    # Clean up any dangling volumes
    if docker volume prune -f 2>/dev/null; then
        print_success "Dangling volumes cleaned up"
    fi
}

# Function to stop existing infrastructure containers
stop_containers() {
    print_status "Stopping existing infrastructure containers..."
    
    if docker-compose -f $COMPOSE_FILE down 2>/dev/null || docker compose -f $COMPOSE_FILE down 2>/dev/null; then
        print_success "Existing containers stopped"
    else
        print_warning "No existing containers to stop"
    fi
}

# Function to start the infrastructure
start_infrastructure() {
    print_status "Starting monitoring infrastructure..."
    
    # Start infrastructure services
    if docker-compose -f $COMPOSE_FILE up -d; then
        print_success "Infrastructure started successfully"
    else
        print_error "Failed to start infrastructure"
        exit 1
    fi
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    check_service_health
}

# Function to check service health
check_service_health() {
    print_status "Checking service health..."
    
    local all_healthy=true
    
    # Check MySQL
    if docker-compose -f $COMPOSE_FILE exec -T mysql mysqladmin ping -h localhost >/dev/null 2>&1; then
        print_success "MySQL is healthy"
    else
        print_warning "MySQL health check failed"
        all_healthy=false
    fi
    
    # Check PostgreSQL
    if docker-compose -f $COMPOSE_FILE exec -T postgres pg_isready -U petclinic >/dev/null 2>&1; then
        print_success "PostgreSQL is healthy"
    else
        print_warning "PostgreSQL health check failed"
        all_healthy=false
    fi
    
    # Check Prometheus
    if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        print_success "Prometheus is healthy"
    else
        print_warning "Prometheus health check failed"
        all_healthy=false
    fi
    
    # Check Grafana
    if curl -f http://localhost:3000/api/health >/dev/null 2>&1; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana health check failed"
        all_healthy=false
    fi
    
    # Check Nginx
    if curl -f http://localhost/ >/dev/null 2>&1; then
        print_success "Nginx is healthy"
    else
        print_warning "Nginx health check failed"
        all_healthy=false
    fi
    
    if [ "$all_healthy" = true ]; then
        print_success "All infrastructure services are healthy"
    else
        print_warning "Some services may not be fully ready yet"
    fi
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "[34mInfrastructure Deployed Successfully![0m"
    echo "=========================================="
    echo ""
    echo "[32mApplication Access:[0m"
    echo "   • Main Application: http://<your-ec2-public-dns>/"
    echo "   • Direct PetClinic: http://<your-ec2-public-dns>:8080/"
    echo ""
    echo "[33mDatabase Access:[0m"
    echo "   • MySQL: <your-ec2-public-dns>:3306 (petclinic/petclinic)"
    echo "   • PostgreSQL: <your-ec2-public-dns>:5432 (petclinic/petclinic)"
    echo ""
    echo "[34mMonitoring Access:[0m"
    echo "   • Grafana Dashboard: http://<your-ec2-public-dns>/grafana/"
    echo "   • Direct Grafana: http://<your-ec2-public-dns>:3000/ (admin/admin)"
    echo "   • Prometheus: http://<your-ec2-public-dns>/prometheus/"
    echo "   • Direct Prometheus: http://<your-ec2-public-dns>:9090/"
    echo ""
    echo "[36mManagement Commands:[0m"
    echo "   • Stop: ./deploy-infra.aws.sh stop"
    echo "   • Clean: ./deploy-infra.aws.sh clean"
    echo "   • Clean Volumes: ./deploy-infra.aws.sh clean-volumes"
    echo ""
}

# Main script
case "$1" in
    clean)
        clean_docker_images
        ;;
    clean-volumes)
        clean_docker_volumes
        ;;
    stop)
        stop_containers
        ;;
    start)
        start_infrastructure
        ;;
    deploy|"")
        check_prerequisites
        stop_containers
        start_infrastructure
        display_access_info
        ;;
    *)
        echo "Usage: $0 [clean|clean-volumes|stop|start|deploy]"
        exit 1
        ;;
esac 