#!/bin/bash
set -e

# AWS Security Group Setup Script
# This script sets up security group rules for the PetClinic application

EC2_INSTANCE_ID="i-08d5f81f81a8eee09"
AWS_REGION="us-east-2"

echo "🔒 Setting up AWS Security Group rules..."

# Get the security group ID for the EC2 instance
echo "📋 Getting security group information..."
SECURITY_GROUP_ID=$(aws ec2 describe-instances \
    --instance-ids $EC2_INSTANCE_ID \
    --region $AWS_REGION \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group ID: $SECURITY_GROUP_ID"

# Define the ports we need to open
PORTS=(
    "22:SSH"
    "80:HTTP"
    "443:HTTPS"
    "8080:PetClinic Application"
    "9090:Prometheus"
    "3000:Grafana"
)

# Add security group rules
for port_info in "${PORTS[@]}"; do
    IFS=':' read -r port description <<< "$port_info"
    
    echo "🔓 Adding rule for port $port ($description)..."
    
    # Check if rule already exists
    RULE_EXISTS=$(aws ec2 describe-security-groups \
        --group-ids $SECURITY_GROUP_ID \
        --region $AWS_REGION \
        --query "SecurityGroups[0].IpPermissions[?FromPort==$port].FromPort" \
        --output text)
    
    if [ "$RULE_EXISTS" = "$port" ]; then
        echo "✅ Rule for port $port already exists"
    else
        # Add the rule
        aws ec2 authorize-security-group-ingress \
            --group-id $SECURITY_GROUP_ID \
            --protocol tcp \
            --port $port \
            --cidr 0.0.0.0/0 \
            --region $AWS_REGION
        
        echo "✅ Added rule for port $port"
    fi
done

echo "✅ Security group setup completed!"
echo "🌐 Your application will be accessible at:"
echo "- PetClinic:     http://18.217.148.69:8080/"
echo "- Prometheus:    http://18.217.148.69:9090/"
echo "- Grafana:       http://18.217.148.69:3000/" 