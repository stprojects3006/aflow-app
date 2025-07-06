#!/bin/bash
set -e

# AWS EC2 Deployment Script
# Instance: i-08d5f81f81a8eee09
# IP: 18.217.148.69
# Region: us-east-2 (Ohio)

EC2_INSTANCE_ID="i-08d5f81f81a8eee09"
EC2_PUBLIC_IP="18.217.148.69"
AWS_REGION="us-east-2"
SSH_KEY_PATH="~/.ssh/your-key.pem"  # Update this path to your SSH key

echo "🚀 Starting AWS EC2 deployment..."
echo "Instance ID: $EC2_INSTANCE_ID"
echo "Public IP: $EC2_PUBLIC_IP"
echo "Region: $AWS_REGION"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI is not installed. Please install AWS CLI and configure it."
  exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "❌ SSH key not found at $SSH_KEY_PATH"
  echo "Please update the SSH_KEY_PATH variable in this script with your actual key path."
  exit 1
fi

# Build the application locally
echo "📦 Building application locally..."
mvn clean package -DskipTests -Dcheckstyle.skip=true

# Prepare the jars directory
mkdir -p jars
mv -f target/spring-petclinic-3.5.0-SNAPSHOT.jar jars/pet-clinkc.jar

# Create deployment package
echo "📦 Creating deployment package..."
tar -czf deployment-package.tar.gz \
    docker-compose.yml \
    Dockerfile \
    jars/ \
    prometheus.yml \
    conf.d/ \
    testing-projects/grafana-dashboards/ \
    --exclude='testing-projects/grafana-dashboards/*.md'

# Upload files to EC2
echo "📤 Uploading files to EC2 instance..."
scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no deployment-package.tar.gz ubuntu@$EC2_PUBLIC_IP:~/

# Execute deployment commands on EC2
echo "🔧 Executing deployment on EC2..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$EC2_PUBLIC_IP << 'EOF'
set -e

echo "📦 Extracting deployment package..."
tar -xzf deployment-package.tar.gz
rm deployment-package.tar.gz

echo "🐳 Installing Docker if not present..."
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    newgrp docker
fi

echo "🐳 Installing Docker Compose if not present..."
if ! command -v docker compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    sudo ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose
fi

echo "🛑 Stopping any existing containers..."
docker compose down || true

echo "🐳 Building and starting containers..."
docker compose up --build -d

echo "⏳ Waiting for services to be ready..."
sleep 30

echo "📊 Checking service status..."
docker ps

echo "🔍 Checking PetClinic logs..."
docker logs aflow-app-petclinic-1 --tail 20

echo "✅ Deployment completed!"
echo "🌐 Services available at:"
echo "- PetClinic:     http://$EC2_PUBLIC_IP:8080/"
echo "- Prometheus:    http://$EC2_PUBLIC_IP:9090/"
echo "- Grafana:       http://$EC2_PUBLIC_IP:3000/ (admin/admin)"

EOF

# Clean up local deployment package
rm -f deployment-package.tar.gz

echo "✅ AWS deployment completed!"
echo "🌐 Your application is now running at:"
echo "- PetClinic:     http://$EC2_PUBLIC_IP:8080/"
echo "- Prometheus:    http://$EC2_PUBLIC_IP:9090/"
echo "- Grafana:       http://$EC2_PUBLIC_IP:3000/ (admin/admin)"
echo ""
echo "🔧 To check logs: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker logs aflow-app-petclinic-1'"
echo "🛑 To stop services: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker compose down'" 