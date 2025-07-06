# Use the official k6 image as base
FROM grafana/k6:latest

# Switch to root for package installation
USER root

# Install additional tools for IP rotation
RUN apk add --no-cache \
    curl \
    jq \
    aws-cli \
    openvpn \
    tor \
    privoxy \
    && rm -rf /var/cache/apk/*

# Create directories for scripts and results
RUN mkdir -p /scripts /results /proxy-config

# Copy IP rotation scripts and configurations
COPY k6-scripts/ /scripts/
COPY proxy-config/ /proxy-config/
COPY rotate-ip.sh /scripts/
COPY setup-proxy.sh /scripts/

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Set environment variables for IP rotation
ENV IP_ROTATION_ENABLED=false
ENV PROXY_SERVICE_URL=""
ENV PROXY_TYPE="static"
ENV VU_IP_MAPPING_ENABLED=false
ENV MAX_PROXY_IPS=10

# Create results directory
RUN mkdir -p /results

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:6565/ || exit 1

# Default command
CMD ["/scripts/run-k6-with-upload.sh"] 