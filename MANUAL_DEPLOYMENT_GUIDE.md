# Manual Deployment Guide for AWS EC2

Since SSH connection is not working, here's how to manually deploy your application on your EC2 instance.

## Prerequisites

1. **EC2 Instance**: `i-08d5f81f81a8eee09` (18.217.148.69)
2. **ECR Repository**: `786407478307.dkr.ecr.us-east-1.amazonaws.com/k6-load-test-k6-repo:latest`
3. **Domain**: `affluenceit.com`

## Step 1: Connect to Your EC2 Instance

Connect to your EC2 instance using your preferred method:
- AWS Systems Manager Session Manager
- AWS Console EC2 Connect
- Your working SSH method

## Step 2: Install Docker and Docker Compose

```bash
# Update system
sudo apt-get update

# Install Docker
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## Step 3: Authenticate to ECR

```bash
# Configure AWS CLI (if not already configured)
aws configure

# Authenticate to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 786407478307.dkr.ecr.us-east-1.amazonaws.com
```

## Step 4: Download Deployment Files

Create a directory and download the deployment files:

```bash
mkdir -p ~/petclinic-deployment
cd ~/petclinic-deployment
```

You'll need to upload these files to your EC2 instance:
- `docker-compose-aws.yml`
- `prometheus.yml`
- `conf.d/` directory
- `testing-projects/grafana-dashboards/` directory

## Step 5: Create Nginx Configuration

Create the nginx configuration files:

```bash
# PetClinic Application
sudo tee /etc/nginx/sites-available/app.affluenceit.com << 'EOF'
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

# Prometheus Monitoring
sudo tee /etc/nginx/sites-available/metrics.affluenceit.com << 'EOF'
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

# Grafana Dashboard
sudo tee /etc/nginx/sites-available/dashboard.affluenceit.com << 'EOF'
server {
    listen 80;
    server_name dashboard.affluenceit.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable sites
sudo ln -sf /etc/nginx/sites-available/app.affluenceit.com /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/metrics.affluenceit.com /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/dashboard.affluenceit.com /etc/nginx/sites-enabled/

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx
```

## Step 6: Deploy Containers

```bash
# Pull the latest image
docker pull 786407478307.dkr.ecr.us-east-1.amazonaws.com/k6-load-test-k6-repo:latest

# Start all containers
docker compose -f docker-compose-aws.yml up -d

# Check status
docker ps
```

## Step 7: Set Up SSL Certificates

```bash
# Install certbot if not already installed
sudo apt-get install -y certbot python3-certbot-nginx

# Get SSL certificates
sudo certbot --nginx -d app.affluenceit.com --non-interactive --agree-tos --email stcloudgate@gmail.com
sudo certbot --nginx -d metrics.affluenceit.com --non-interactive --agree-tos --email stcloudgate@gmail.com
sudo certbot --nginx -d dashboard.affluenceit.com --non-interactive --agree-tos --email stcloudgate@gmail.com
```

## Step 8: Import Grafana Dashboards

```bash
# Wait for Grafana to be ready
sleep 30

# Set up Prometheus datasource
curl -s -X POST -H "Content-Type: application/json" \
  -u admin:admin \
  -d '{"name":"Prometheus","type":"prometheus","access":"proxy","url":"http://prometheus:9090","isDefault":true}' \
  "http://localhost:3000/api/datasources"

# Import dashboards
for dashboard in testing-projects/grafana-dashboards/*.json; do
  if [ -f "$dashboard" ]; then
    echo "Importing: $(basename "$dashboard")"
    curl -s -X POST -H "Content-Type: application/json" \
      -u admin:admin \
      -d @"$dashboard" \
      "http://localhost:3000/api/dashboards/db"
  fi
done
```

## Step 9: Verify Deployment

Your application should now be available at:
- **PetClinic**: https://app.affluenceit.com/
- **Prometheus**: https://metrics.affluenceit.com/
- **Grafana**: https://dashboard.affluenceit.com/ (admin/admin)

## Troubleshooting

### Check Container Logs
```bash
docker logs petclinic-app
docker logs petclinic-grafana
docker logs petclinic-prometheus
```

### Check Nginx Status
```bash
sudo systemctl status nginx
sudo nginx -t
```

### Check SSL Certificates
```bash
sudo certbot certificates
```

### Restart Services
```bash
docker compose -f docker-compose-aws.yml restart
sudo systemctl restart nginx
```

## Update Application

To update the application in the future:
```bash
docker pull 786407478307.dkr.ecr.us-east-1.amazonaws.com/k6-load-test-k6-repo:latest
docker compose -f docker-compose-aws.yml up -d
``` 