#!/bin/bash

# IP Rotation Script for k6 Load Testing
# This script provides different methods for IP rotation per VU

set -e

# Configuration
VU_ID=${1:-1}
PROXY_TYPE=${PROXY_TYPE:-"static"}
PROXY_SERVICE_URL=${PROXY_SERVICE_URL:-""}
MAX_PROXY_IPS=${MAX_PROXY_IPS:-10}

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [VU-$VU_ID] $1"
}

# Function to get static proxy IP
get_static_proxy_ip() {
    local vu_id=$1
    local proxy_index=$((vu_id % MAX_PROXY_IPS))
    
    # Static proxy IPs (example - replace with actual proxy IPs)
    local proxy_ips=(
        "192.168.1.100:8080"
        "192.168.1.101:8080"
        "192.168.1.102:8080"
        "192.168.1.103:8080"
        "192.168.1.104:8080"
        "192.168.1.105:8080"
        "192.168.1.106:8080"
        "192.168.1.107:8080"
        "192.168.1.108:8080"
        "192.168.1.109:8080"
    )
    
    echo "${proxy_ips[$proxy_index]}"
}

# Function to get rotating proxy IP
get_rotating_proxy_ip() {
    local vu_id=$1
    
    if [ -n "$PROXY_SERVICE_URL" ]; then
        # Get IP from proxy service
        local proxy_ip=$(curl -s "$PROXY_SERVICE_URL/rotate?vu=$vu_id" 2>/dev/null || echo "")
        if [ -n "$proxy_ip" ]; then
            echo "$proxy_ip"
            return 0
        fi
    fi
    
    # Fallback to static proxy
    get_static_proxy_ip "$vu_id"
}

# Function to setup Tor proxy
setup_tor_proxy() {
    log "Setting up Tor proxy for VU $VU_ID"
    
    # Start Tor service
    if ! pgrep tor > /dev/null; then
        tor --RunAsDaemon 1 --SocksPort 9050
        sleep 5
    fi
    
    echo "127.0.0.1:9050"
}

# Function to setup OpenVPN
setup_openvpn() {
    local vu_id=$1
    log "Setting up OpenVPN for VU $vu_id"
    
    # This would require OpenVPN configuration files
    # For demo purposes, we'll use a mock setup
    echo "10.8.0.$((vu_id + 1)):1194"
}

# Main IP rotation function
rotate_ip() {
    local vu_id=$1
    local proxy_type=${2:-$PROXY_TYPE}
    
    log "Setting up IP rotation for VU $vu_id using $proxy_type method"
    
    case $proxy_type in
        "static")
            local proxy_ip=$(get_static_proxy_ip "$vu_id")
            log "Using static proxy: $proxy_ip"
            echo "$proxy_ip"
            ;;
        "rotating")
            local proxy_ip=$(get_rotating_proxy_ip "$vu_id")
            log "Using rotating proxy: $proxy_ip"
            echo "$proxy_ip"
            ;;
        "tor")
            local proxy_ip=$(setup_tor_proxy)
            log "Using Tor proxy: $proxy_ip"
            echo "$proxy_ip"
            ;;
        "openvpn")
            local proxy_ip=$(setup_openvpn "$vu_id")
            log "Using OpenVPN: $proxy_ip"
            echo "$proxy_ip"
            ;;
        *)
            log "Unknown proxy type: $proxy_type, using static"
            get_static_proxy_ip "$vu_id"
            ;;
    esac
}

# Function to configure proxy environment variables
configure_proxy_env() {
    local proxy_ip=$1
    local proxy_host=$(echo "$proxy_ip" | cut -d: -f1)
    local proxy_port=$(echo "$proxy_ip" | cut -d: -f2)
    
    export HTTP_PROXY="http://$proxy_ip"
    export HTTPS_PROXY="http://$proxy_ip"
    export http_proxy="http://$proxy_ip"
    export https_proxy="http://$proxy_ip"
    
    log "Configured proxy environment: $proxy_ip"
}

# Function to test proxy connectivity
test_proxy() {
    local proxy_ip=$1
    local test_url="https://httpbin.org/ip"
    
    log "Testing proxy connectivity: $proxy_ip"
    
    local response=$(curl -s --proxy "http://$proxy_ip" --connect-timeout 10 "$test_url" 2>/dev/null || echo "")
    
    if [ -n "$response" ]; then
        log "Proxy test successful: $response"
        return 0
    else
        log "Proxy test failed for: $proxy_ip"
        return 1
    fi
}

# Main execution
if [ "$IP_ROTATION_ENABLED" = "true" ]; then
    log "IP rotation enabled for VU $VU_ID"
    
    # Get proxy IP
    proxy_ip=$(rotate_ip "$VU_ID" "$PROXY_TYPE")
    
    # Configure environment
    configure_proxy_env "$proxy_ip"
    
    # Test proxy (optional)
    if [ "$TEST_PROXY" = "true" ]; then
        test_proxy "$proxy_ip"
    fi
    
    log "IP rotation setup complete for VU $VU_ID"
else
    log "IP rotation disabled for VU $VU_ID"
fi

# Export functions for k6 to use
export -f rotate_ip
export -f configure_proxy_env
export -f test_proxy 