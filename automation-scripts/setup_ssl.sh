#!/bin/bash
set -e

DOMAIN="affluenceit.com"
EMAIL="stprojects3006@gmail.com"
APP_PORT=8080
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

# Install Nginx and Certbot if not present
if ! command -v nginx >/dev/null; then
  echo "Installing Nginx..."
  sudo apt-get update && sudo apt-get install -y nginx
fi
if ! command -v certbot >/dev/null; then
  echo "Installing Certbot..."
  sudo apt-get update && sudo apt-get install -y certbot python3-certbot-nginx
fi

# Create Nginx config for reverse proxy
sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable the config
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "Obtaining Let's Encrypt certificate for $DOMAIN..."
sudo certbot --nginx --non-interactive --agree-tos --redirect -d $DOMAIN -m $EMAIL

echo "SSL setup complete! Your site should now be available at https://$DOMAIN/" 