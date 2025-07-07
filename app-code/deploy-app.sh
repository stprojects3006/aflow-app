#!/bin/bash

# PetClinic Application-Only Deployment Script
# This script builds and deploys only the PetClinic application with databases

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
COMPOSE_FILE="docker-compose.app.yml"

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
    
    # Check if infrastructure is running
    check_infrastructure_prerequisites
    
    print_success "All prerequisites are satisfied"
}

# Function to check infrastructure prerequisites
check_infrastructure_prerequisites() {
    print_status "Checking infrastructure prerequisites..."
    
    # Check if databases are running
    if ! docker-compose -f docker-compose.infra.yml exec -T mysql mysqladmin ping -h localhost >/dev/null 2>&1; then
        print_warning "MySQL is not running. Please start infrastructure first: ./deploy-infra.sh"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "MySQL is running"
    fi
    
    if ! docker-compose -f docker-compose.infra.yml exec -T postgres pg_isready -U petclinic >/dev/null 2>&1; then
        print_warning "PostgreSQL is not running. Please start infrastructure first: ./deploy-infra.sh"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "PostgreSQL is running"
    fi
}

# Function to build the application
build_application() {
    print_status "Building PetClinic application..."
    
    # Clean previous builds
    if [ -d "target" ]; then
        print_status "Cleaning previous build..."
        mvn clean
    fi
    
    # Build the application
    print_status "Compiling and packaging application..."
    mvn package -DskipTests
    
    # Check if build was successful
    if [ ! -f "target/spring-petclinic-3.5.0-SNAPSHOT.jar" ]; then
        print_error "Build failed. JAR file not found."
        exit 1
    fi
    
    # Copy JAR to jars directory
    print_status "Copying JAR to jars directory..."
    mkdir -p jars
    cp target/spring-petclinic-3.5.0-SNAPSHOT.jar jars/pet-clinkc.jar
    
    print_success "Application built successfully"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    if mvn test; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
}

# Function to clean existing Docker images
clean_docker_images() {
    print_status "Cleaning existing Docker images..."
    
    # Remove existing image if it exists
    if docker rmi $DOCKER_IMAGE 2>/dev/null; then
        print_success "Existing Docker image removed"
    else
        print_warning "No existing Docker image to remove"
    fi
    
    # Clean up any dangling images
    if docker image prune -f 2>/dev/null; then
        print_success "Dangling images cleaned up"
    fi
}

# Function to build Docker image
build_docker_image() {
    print_status "Building Docker image..."
    
    if docker build -t $DOCKER_IMAGE .; then
        print_success "Docker image built successfully"
    else
        print_error "Docker build failed"
        exit 1
    fi
}

# Function to stop existing containers
stop_containers() {
    print_status "Stopping existing application containers..."
    
    if docker-compose -f $COMPOSE_FILE down 2>/dev/null || docker compose -f $COMPOSE_FILE down 2>/dev/null; then
        print_success "Existing containers stopped"
    else
        print_warning "No existing containers to stop"
    fi
}

# Function to start the application
start_application() {
    print_status "Starting PetClinic application..."
    
    # Start application services
    if docker-compose -f $COMPOSE_FILE up -d; then
        print_success "Application started successfully"
    else
        print_error "Failed to start application"
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
    
    # Check PetClinic application
    if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
        print_success "PetClinic application is healthy"
    else
        print_warning "PetClinic application health check failed"
    fi
}

# Function to display access information
display_access_info() {
    echo ""
    echo "=========================================="
    echo "🐾 PetClinic Application Deployed Successfully!"
    echo "=========================================="
    echo ""
    echo "📱 Application Access:"
    echo "   • PetClinic Application: http://localhost:8080/"
    echo ""
    echo "🔧 Management Commands:"
    echo "   • View logs: docker-compose -f $COMPOSE_FILE logs -f [service]"
    echo "   • Stop services: docker-compose -f $COMPOSE_FILE down"
    echo "   • Restart services: docker-compose -f $COMPOSE_FILE restart"
    echo "   • View status: docker-compose -f $COMPOSE_FILE ps"
    echo ""
    echo "📈 QueueIt Integration Testing:"
    echo "   • Integration Test Page: http://localhost:8080/integration/queueit"
    echo ""
    echo "💡 Note: This is application-only deployment."
    echo "   For databases and monitoring, run: ./deploy-infra.sh"
    echo ""
}

# Function to show logs
show_logs() {
    print_status "Showing application logs..."
    docker-compose -f $COMPOSE_FILE logs -f petclinic
}

# Function to cleanup
cleanup() {
    print_status "Cleaning up..."
    
    # Stop containers
    stop_containers
    
    # Remove Docker images
    if docker rmi $DOCKER_IMAGE 2>/dev/null; then
        print_success "Docker image removed"
    fi
    
    # Clean up dangling images
    if docker image prune -f 2>/dev/null; then
        print_success "Dangling images cleaned up"
    fi
    
    # Clean Maven build
    if mvn clean 2>/dev/null; then
        print_success "Maven build cleaned"
    fi
    
    print_success "Cleanup completed"
}

# Main deployment function
deploy() {
    echo "=========================================="
    echo "🐾 PetClinic Application Deployment"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    build_application
    run_tests
    clean_docker_images
    build_docker_image
    stop_containers
    start_application
    display_access_info
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  deploy     Deploy the PetClinic application (default)"
    echo "  build      Build the application only"
    echo "  test       Run tests only"
    echo "  start      Start the application"
    echo "  stop       Stop the application"
    echo "  restart    Restart the application"
    echo "  logs       Show application logs"
    echo "  status     Show service status"
    echo "  cleanup    Clean up all resources"
    echo "  help       Show this help message"
    echo ""
}

# Function to show status
show_status() {
    print_status "Service Status:"
    docker-compose -f $COMPOSE_FILE ps
}

# Function to restart services
restart_services() {
    print_status "Restarting services..."
    docker-compose -f $COMPOSE_FILE restart
    print_success "Services restarted"
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "build")
        check_prerequisites
        build_application
        clean_docker_images
        build_docker_image
        ;;
    "test")
        check_prerequisites
        run_tests
        ;;
    "start")
        start_application
        display_access_info
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
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac 