#!/bin/bash
set -e

# AWS EC2 Deployment Script with Nginx Integration
# Instance: i-08d5f81f81a8eee09
# IP: 18.217.148.69
# Region: us-east-2 (Ohio)
# Domain: affluenceit.com

EC2_INSTANCE_ID="i-08d5f81f81a8eee09"
EC2_PUBLIC_IP="18.217.148.69"
AWS_REGION="us-east-2"
DOMAIN="affluenceit.com"
SSH_KEY_PATH="/Users/stmum0107/.ssh/projectq-key-pair.pem"

echo "🚀 Starting AWS EC2 deployment with Nginx integration..."
echo "Instance ID: $EC2_INSTANCE_ID"
echo "Public IP: $EC2_PUBLIC_IP"
echo "Domain: $DOMAIN"
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

# Create nginx configuration files
echo "📝 Creating nginx configuration..."
cat > nginx-petclinic.conf << 'EOF'
# PetClinic Application
server {
    listen 80;
    server_name app.affluenceit.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

cat > nginx-prometheus.conf << 'EOF'
# Prometheus Monitoring
server {
    listen 80;
    server_name metrics.affluenceit.com;
    
    location / {
        proxy_pass http://localhost:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

cat > nginx-grafana.conf << 'EOF'
# Grafana Dashboard
server {
    listen 80;
    server_name dashboard.affluenceit.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for Grafana
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Create deployment package
echo "📦 Creating deployment package..."
tar -czf deployment-package.tar.gz \
    docker-compose.yml \
    Dockerfile \
    jars/ \
    prometheus.yml \
    conf.d/ \
    testing-projects/grafana-dashboards/ \
    nginx-petclinic.conf \
    nginx-prometheus.conf \
    nginx-grafana.conf

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

echo "🌐 Setting up nginx reverse proxy..."
# Copy nginx configurations
sudo cp nginx-petclinic.conf /etc/nginx/sites-available/app.affluenceit.com
sudo cp nginx-prometheus.conf /etc/nginx/sites-available/metrics.affluenceit.com
sudo cp nginx-grafana.conf /etc/nginx/sites-available/dashboard.affluenceit.com

# Enable sites
sudo ln -sf /etc/nginx/sites-available/app.affluenceit.com /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/metrics.affluenceit.com /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/dashboard.affluenceit.com /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

echo "🔒 Setting up SSL certificates with Let's Encrypt..."
# Get SSL certificates for subdomains
sudo certbot --nginx -d app.affluenceit.com --non-interactive --agree-tos --email stcloudgate@gmail.com || echo "SSL setup failed - check your email configuration"
sudo certbot --nginx -d metrics.affluenceit.com --non-interactive --agree-tos --email stcloudgate@gmail.com || echo "SSL setup failed - check your email configuration"
sudo certbot --nginx -d dashboard.affluenceit.com --non-interactive --agree-tos --email stcloudgate@gmail.com || echo "SSL setup failed - check your email configuration"

echo "✅ Deployment completed!"
echo "🌐 Services available at:"
echo "- PetClinic:     https://app.affluenceit.com/"
echo "- Prometheus:    https://metrics.affluenceit.com/"
echo "- Grafana:       https://dashboard.affluenceit.com/ (admin/admin)"

EOF

# Clean up local files
rm -f deployment-package.tar.gz nginx-petclinic.conf nginx-prometheus.conf nginx-grafana.conf

echo "✅ AWS deployment with nginx integration completed!"
echo "🌐 Your application is now running at:"
echo "- PetClinic:     https://app.affluenceit.com/"
echo "- Prometheus:    https://metrics.affluenceit.com/"
echo "- Grafana:       https://dashboard.affluenceit.com/ (admin/admin)"
echo ""
echo "🔧 To check logs: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker logs aflow-app-petclinic-1'"
echo "🛑 To stop services: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker compose down'"
echo ""
echo "⚠️  IMPORTANT: Update the email address in the script before running for SSL certificate setup!"
EOF 