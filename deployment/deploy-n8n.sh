#!/bin/bash

# n8n Deployment Script for Lumora
# Run this script as root on Ubuntu 24.04 VPS

set -euo pipefail

echo "=== n8n Deployment Script for Lumora ==="
echo "Starting deployment..."

# 0) Sanity checks
echo "Checking Docker installation..."
docker --version
docker compose version

# 1) Create necessary directories
echo "Creating directories..."
mkdir -p /opt/solyntra/files

# 2) Create .env file (KEEP existing if present)
if [ ! -f /opt/solyntra/.env ]; then
  echo "Creating new .env file..."
  KEY="$(openssl rand -base64 48 | tr -d '\n')"
  cat > /opt/solyntra/.env <<'EOF'
# --- n8n core ---
N8N_PORT=5678
GENERIC_TIMEZONE=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64
TZ=Asia/Kolkata
# Generate a long random value (keep secret)
N8N_ENCRYPTION_KEY=CHANGE_ME

# Optional future domain mode (leave empty for IP mode)
N8N_HOST=
WEBHOOK_URL=

# Allow external Node.js packages inside Function nodes (optional)
# NODE_FUNCTION_ALLOW_EXTERNAL=axios,moment,uuid
EOF
  sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${KEY}|" /opt/solyntra/.env
  echo "Created .env file with generated encryption key"
else
  echo "Using existing .env file"
fi

# 3) Create docker-compose.yml (overwrite safely with backup)
echo "Creating Docker Compose configuration..."
cp -f /opt/solyntra/docker-compose.yml "/opt/solyntra/docker-compose.yml.$(date +%Y%m%d%H%M%S).bak" 2>/dev/null || true
cat > /opt/solyntra/docker-compose.yml <<'YAML'
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    ports:
      - "5678:5678"
    env_file:
      - .env
    environment:
      - N8N_PORT=${N8N_PORT}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - N8N_PAYLOAD_SIZE_MAX=${N8N_PAYLOAD_SIZE_MAX}
      - TZ=${TZ}
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_DISABLE_PRODUCTION_MAIN_PROCESS=false
      - N8N_COMMUNITY_PACKAGES_ENABLED=true
    volumes:
      - n8n_data:/home/node/.n8n
      - ./files:/files
    restart: unless-stopped

  # watchtower (optional auto‑updates at 03:00 daily). Leave commented for now.
  # watchtower:
  #   image: containrrr/watchtower
  #   command: --cleanup --include-restarting --include-stopped --schedule "0 0 3 * * *" n8n
  #   volumes:
  #     - /var/run/docker.sock:/var/run/docker.sock
  #   restart: unless-stopped

volumes:
  n8n_data: {}
YAML

# 4) Create systemd unit to auto-start stack
echo "Creating systemd service..."
cat > /etc/systemd/system/n8n-compose.service <<'UNIT'
[Unit]
Description=n8n Docker Compose
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
UNIT

systemctl daemon-reload
systemctl enable --now n8n-compose.service

# 5) Bring up the stack (idempotent), verify, and show onboarding URL hint
echo "Starting n8n container..."
docker compose -f /opt/solyntra/docker-compose.yml up -d
sleep 2

echo "Container status:"
docker ps

sleep 5
echo "----- Last n8n logs (look for 'User management' onboarding URL) -----"
docker logs n8n --since 5m | grep -i 'User management' -n || true

IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=== Deployment Complete ==="
echo "n8n is now available at: http://${IP}:5678/"
echo ""
echo "If port 5678 is firewalled, open it in Hostinger panel:"
echo "VPS → Firewall → Add allow rule for TCP 5678"
echo ""
echo "To view recent logs: docker logs n8n --since 10m"
echo "To reset user management: docker exec -it n8n n8n user-management:reset"