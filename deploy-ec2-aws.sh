#!/bin/bash
set -e

# AWS EC2 Deployment Script for ECR-based deployment
# Instance: i-08d5f81f81a8eee09
# IP: 18.217.148.69
# Region: us-east-2 (Ohio)
# ECR: us-east-1
# Domain: affluenceit.com

EC2_INSTANCE_ID="i-08d5f81f81a8eee09"
EC2_PUBLIC_IP="18.217.148.69"
AWS_REGION="us-east-2"
ECR_REGION="us-east-1"
DOMAIN="affluenceit.com"
ECR_REPO="786407478307.dkr.ecr.us-east-1.amazonaws.com/k6-load-test-k6-repo:latest"
SSH_KEY_PATH="/Users/stmum0107/.ssh/projectq-key-pair.pem"

echo "🚀 Starting AWS EC2 deployment with ECR integration..."
echo "Instance ID: $EC2_INSTANCE_ID"
echo "Public IP: $EC2_PUBLIC_IP"
echo "Domain: $DOMAIN"
echo "ECR Repository: $ECR_REPO"
echo "EC2 Region: $AWS_REGION"
echo "ECR Region: $ECR_REGION"

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "❌ SSH key not found at $SSH_KEY_PATH"
  exit 1
fi

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
    docker-compose-aws.yml \
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

echo "🔐 Authenticating to ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 786407478307.dkr.ecr.us-east-1.amazonaws.com

echo "🛑 Stopping any existing containers..."
docker compose -f docker-compose-aws.yml down || true

echo "🐳 Pulling latest image from ECR..."
docker pull 786407478307.dkr.ecr.us-east-1.amazonaws.com/k6-load-test-k6-repo:latest

echo "🐳 Starting containers with health checks..."
docker compose -f docker-compose-aws.yml up -d

echo "⏳ Waiting for services to be ready..."
sleep 60

echo "📊 Checking service status..."
docker ps

echo "🔍 Checking PetClinic logs..."
docker logs petclinic-app --tail 20

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

echo "📊 Setting up Grafana dashboards and datasources..."
# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:3000/api/health | grep -q 'database'; then
    echo "✅ Grafana is ready!"
    break
  fi
  sleep 2
  echo -n "."
done

# Create Grafana datasource configuration
echo "🔧 Setting up Prometheus datasource..."
cat > grafana-datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Add datasource
curl -s -X POST -H "Content-Type: application/json" \
  -u admin:admin \
  -d @grafana-datasource.yml \
  "http://localhost:3000/api/datasources" && \
  echo "✅ Prometheus datasource configured" || \
  echo "⚠️  Datasource configuration failed (might already exist)"

# Import dashboards with better error handling
echo "📊 Importing enhanced Grafana dashboards..."
DASHBOARD_COUNT=0
SUCCESS_COUNT=0

for dashboard in testing-projects/grafana-dashboards/*.json; do
  if [ -f "$dashboard" ]; then
    DASHBOARD_COUNT=$((DASHBOARD_COUNT + 1))
    echo "📋 Importing dashboard: $(basename "$dashboard")"
    
    # Import dashboard
    RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
      -u admin:admin \
      -d @"$dashboard" \
      "http://localhost:3000/api/dashboards/db")
    
    if echo "$RESPONSE" | grep -q '"status":"success"'; then
      echo "✅ Successfully imported $(basename "$dashboard")"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo "❌ Failed to import $(basename "$dashboard")"
      echo "Response: $RESPONSE"
    fi
  fi
done

echo "📊 Dashboard import summary: $SUCCESS_COUNT/$DASHBOARD_COUNT dashboards imported successfully"

# Create a summary of available dashboards
echo "🔍 Available dashboards:"
curl -s -u admin:admin "http://localhost:3000/api/search" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 | while read title; do
  echo "  - $title"
done

echo "✅ Deployment completed!"
echo "🌐 Services available at:"
echo "- PetClinic:     https://app.affluenceit.com/"
echo "- Prometheus:    https://metrics.affluenceit.com/"
echo "- Grafana:       https://dashboard.affluenceit.com/ (admin/admin)"

EOF

# Clean up local files
rm -f deployment-package.tar.gz nginx-petclinic.conf nginx-prometheus.conf nginx-grafana.conf grafana-datasource.yml

echo "✅ AWS EC2 deployment with ECR integration completed!"
echo "🌐 Your application is now running at:"
echo "- PetClinic:     https://app.affluenceit.com/"
echo "- Prometheus:    https://metrics.affluenceit.com/"
echo "- Grafana:       https://dashboard.affluenceit.com/ (admin/admin)"
echo ""
echo "🔧 To check logs: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker logs petclinic-app'"
echo "🛑 To stop services: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker compose -f docker-compose-aws.yml down'"
echo "🔄 To update: ssh -i $SSH_KEY_PATH ubuntu@$EC2_PUBLIC_IP 'docker pull $ECR_REPO && docker compose -f docker-compose-aws.yml up -d'" 