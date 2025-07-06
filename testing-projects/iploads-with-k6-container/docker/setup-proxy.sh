#!/bin/bash

# Proxy Setup Script for IP Rotation
# This script sets up proxy services for k6 load testing

set -e

# Configuration
PROXY_TYPE=${PROXY_TYPE:-"static"}
PROXY_SERVICE_URL=${PROXY_SERVICE_URL:-""}
MAX_PROXY_IPS=${MAX_PROXY_IPS:-10}

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to setup Privoxy
setup_privoxy() {
    log "Setting up Privoxy proxy"
    
    # Create Privoxy configuration
    cat > /etc/privoxy/config << EOF
# Privoxy configuration for IP rotation
user-manual /usr/share/doc/privoxy/user-manual
confdir /etc/privoxy
logdir /var/log/privoxy
actionsfile match-all.action
actionsfile default.action
actionsfile user.action
filterfile default.filter
filterfile user.filter
logfile logfile
listen-address 0.0.0.0:8118
toggle 1
enable-remote-toggle 1
enable-remote-http-toggle 0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
enable-proxy-authentication-forwarding 0
forwarded-connect-retries 0
accept-intercepted-requests 0
allow-cgi-request-crunching 0
split-large-forms 0
keep-alive-timeout 5
tolerate-pipelining 1
socket-timeout 300
EOF

    # Start Privoxy
    privoxy /etc/privoxy/config
    
    log "Privoxy started on port 8118"
}

# Function to setup Tor
setup_tor() {
    log "Setting up Tor proxy"
    
    # Create Tor configuration
    cat > /etc/tor/torrc << EOF
# Tor configuration for IP rotation
SocksPort 9050
SocksListenAddress 0.0.0.0
DataDirectory /var/lib/tor
PidFile /var/run/tor/tor.pid
Log notice file /var/log/tor/notices.log
RunAsDaemon 1
EOF

    # Create Tor data directory
    mkdir -p /var/lib/tor /var/log/tor /var/run/tor
    chown -R tor:tor /var/lib/tor /var/log/tor /var/run/tor
    
    # Start Tor
    tor -f /etc/tor/torrc
    
    log "Tor started on port 9050"
}

# Function to setup mock proxy service
setup_mock_proxy_service() {
    log "Setting up mock proxy service"
    
    # Create a simple proxy service for testing
    cat > /tmp/mock-proxy.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import random
import time

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/rotate'):
            # Return a random proxy IP
            proxy_ips = [
                "192.168.1.100:8080",
                "192.168.1.101:8080", 
                "192.168.1.102:8080",
                "192.168.1.103:8080",
                "192.168.1.104:8080",
                "192.168.1.105:8080",
                "192.168.1.106:8080",
                "192.168.1.107:8080",
                "192.168.1.108:8080",
                "192.168.1.109:8080"
            ]
            
            proxy_ip = random.choice(proxy_ips)
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "proxy_ip": proxy_ip,
                "vu_id": self.path.split('=')[1] if '=' in self.path else "unknown",
                "timestamp": time.time()
            }
            
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not found")

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), ProxyHandler) as httpd:
        print(f"Mock proxy service running on port {PORT}")
        httpd.serve_forever()
EOF

    # Make executable and start
    chmod +x /tmp/mock-proxy.py
    python3 /tmp/mock-proxy.py &
    
    log "Mock proxy service started on port 8080"
}

# Function to setup proxy rotation service
setup_proxy_rotation_service() {
    log "Setting up proxy rotation service"
    
    # Create proxy rotation service
    cat > /tmp/proxy-rotation.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import time
import threading

class ProxyRotationHandler(http.server.BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.proxy_pool = [
            "192.168.1.100:8080",
            "192.168.1.101:8080", 
            "192.168.1.102:8080",
            "192.168.1.103:8080",
            "192.168.1.104:8080",
            "192.168.1.105:8080",
            "192.168.1.106:8080",
            "192.168.1.107:8080",
            "192.168.1.108:8080",
            "192.168.1.109:8080"
        ]
        self.vu_assignments = {}
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        if self.path.startswith('/rotate'):
            # Extract VU ID from query parameter
            vu_id = "unknown"
            if '=' in self.path:
                vu_id = self.path.split('=')[1]
            
            # Assign proxy IP to VU
            if vu_id not in self.vu_assignments:
                # Round-robin assignment
                proxy_index = len(self.vu_assignments) % len(self.proxy_pool)
                self.vu_assignments[vu_id] = self.proxy_pool[proxy_index]
            
            proxy_ip = self.vu_assignments[vu_id]
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "proxy_ip": proxy_ip,
                "vu_id": vu_id,
                "assigned_proxies": len(self.vu_assignments),
                "timestamp": time.time()
            }
            
            self.wfile.write(json.dumps(response).encode())
        elif self.path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            
            response = {
                "total_proxies": len(self.proxy_pool),
                "assigned_vus": len(self.vu_assignments),
                "assignments": self.vu_assignments,
                "timestamp": time.time()
            }
            
            self.wfile.write(json.dumps(response, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not found")

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), ProxyRotationHandler) as httpd:
        print(f"Proxy rotation service running on port {PORT}")
        httpd.serve_forever()
EOF

    # Make executable and start
    chmod +x /tmp/proxy-rotation.py
    python3 /tmp/proxy-rotation.py &
    
    log "Proxy rotation service started on port 8080"
}

# Function to test proxy services
test_proxy_services() {
    log "Testing proxy services"
    
    # Test mock proxy service
    if curl -s http://localhost:8080/rotate?vu=1 > /dev/null; then
        log "Mock proxy service is working"
    else
        log "Mock proxy service test failed"
    fi
    
    # Test Privoxy
    if curl -s --proxy http://localhost:8118 http://httpbin.org/ip > /dev/null; then
        log "Privoxy is working"
    else
        log "Privoxy test failed"
    fi
    
    # Test Tor (if available)
    if command -v tor > /dev/null; then
        if curl -s --socks5 localhost:9050 http://httpbin.org/ip > /dev/null; then
            log "Tor is working"
        else
            log "Tor test failed"
        fi
    fi
}

# Main execution
log "Setting up proxy services for IP rotation"

case $PROXY_TYPE in
    "static")
        log "Using static proxy configuration"
        setup_mock_proxy_service
        ;;
    "rotating")
        log "Using rotating proxy configuration"
        setup_proxy_rotation_service
        ;;
    "privoxy")
        log "Using Privoxy proxy"
        setup_privoxy
        ;;
    "tor")
        log "Using Tor proxy"
        setup_tor
        ;;
    *)
        log "Unknown proxy type: $PROXY_TYPE, using static"
        setup_mock_proxy_service
        ;;
esac

# Wait for services to start
sleep 5

# Test services
test_proxy_services

log "Proxy setup complete" 