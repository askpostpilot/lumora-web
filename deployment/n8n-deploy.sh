#!/bin/bash

# n8n Deployment Script for Hostinger VPS (IP Mode)
# This script is idempotent and safe to re-run

set -euo pipefail

# Configuration
VPS_IP="147.79.68.121"
VPS_USER="root"
PROJECT_DIR="/opt/solyntra"
N8N_PORT="5678"

echo "=== n8n Deployment Script ==="
echo "VPS: ${VPS_IP}"
echo "Project Directory: ${PROJECT_DIR}"
echo "Port: ${N8N_PORT}"
echo "============================="

# SSH into VPS and execute deployment commands
ssh -o StrictHostKeyChecking=no ${VPS_USER}@${VPS_IP} << 'EOF'
set -euo pipefail

echo "Connected to VPS successfully"

# Step 2: Sanity check Docker versions
echo "=== Docker Version Check ==="
docker --version
docker compose version
echo "============================="

# Step 3: Ensure directory and files exist
echo "=== Setting up directories ==="
mkdir -p /opt/solyntra/files
cd /opt/solyntra

# Check if required files exist
if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: docker-compose.yml not found in /opt/solyntra"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "ERROR: .env file not found in /opt/solyntra"
    exit 1
fi

echo "Required files verified"

# Step 4: Fix/complete .env file
echo "=== Updating .env file ==="

# Function to add or update env variable
update_env_var() {
    local key="$1"
    local value="$2"
    local env_file=".env"
    
    if grep -q "^${key}=" "${env_file}"; then
        # Key exists, check if value is empty and update only if so
        current_value=$(grep "^${key}=" "${env_file}" | cut -d'=' -f2-)
        if [ -z "${current_value}" ]; then
            sed -i "s|^${key}=.*|${key}=${value}|" "${env_file}"
            echo "Updated ${key}=${value}"
        else
            echo "Kept existing ${key}=${current_value}"
        fi
    else
        # Key doesn't exist, add it
        echo "${key}=${value}" >> "${env_file}"
        echo "Added ${key}=${value}"
    fi
}

# Generate encryption key if needed
generate_encryption_key() {
    if ! grep -q "^N8N_ENCRYPTION_KEY=" .env || [ -z "$(grep "^N8N_ENCRYPTION_KEY=" .env | cut -d'=' -f2-)" ]; then
        # Generate a 48-character base64 key
        ENCRYPTION_KEY=$(openssl rand -base64 36 | tr -d '\n')
        update_env_var "N8N_ENCRYPTION_KEY" "${ENCRYPTION_KEY}"
    else
        echo "Kept existing N8N_ENCRYPTION_KEY"
    fi
}

# Update required environment variables
update_env_var "N8N_PORT" "5678"
update_env_var "GENERIC_TIMEZONE" "Asia/Kolkata"
update_env_var "TZ" "Asia/Kolkata"
update_env_var "N8N_PAYLOAD_SIZE_MAX" "64"
update_env_var "N8N_HOST" ""
update_env_var "LE_EMAIL" ""

# Generate encryption key
generate_encryption_key

echo "Environment file updated successfully"

# Step 5: Start/refresh n8n
echo "=== Starting n8n service ==="
docker compose pull
docker compose up -d

# Step 6: Create systemd service
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/n8n-compose.service << 'SYSTEMD_EOF'
[Unit]
Description=n8n Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/solyntra
RemainAfterExit=yes
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable n8n-compose.service
systemctl start n8n-compose.service

echo "Systemd service created and enabled"

# Wait a moment for containers to start
echo "Waiting for containers to start..."
sleep 10

# Step 7: Verify deployment
echo "=== Verification ==="

echo "Docker containers status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "Testing local connectivity:"

# Test HTTP response
HTTP_STATUS=$(curl -sI http://127.0.0.1:5678 | head -n1 || echo "Failed to connect")
echo "HTTP Status: ${HTTP_STATUS}"

# Test if n8n content is present
N8N_CONTENT=$(curl -s http://127.0.0.1:5678 | grep -i 'n8n' || echo "n8n content not found")
if [[ "${N8N_CONTENT}" != "n8n content not found" ]]; then
    echo "n8n content found: ✓"
else
    echo "n8n content check: ✗"
fi

echo ""
echo "=== Deployment Summary ==="
echo "Access URL: http://147.79.68.121:5678"
echo "Status: $(systemctl is-active n8n-compose.service)"
echo "Enabled: $(systemctl is-enabled n8n-compose.service)"

# Check for onboarding information
echo ""
echo "=== Onboarding Information ==="
ONBOARD_INFO=$(docker logs n8n --since 5m 2>/dev/null | grep -i 'User management' -n || echo "")
if [ -n "${ONBOARD_INFO}" ]; then
    echo "Onboarding info found:"
    echo "${ONBOARD_INFO}"
else
    echo "No recent onboarding info found. If needed, run:"
    echo "docker exec -it n8n n8n user-management:reset"
fi

echo ""
echo "=== Deployment Complete ==="
echo "n8n should be accessible at: http://147.79.68.121:5678"

EOF

echo "Deployment script execution completed!"