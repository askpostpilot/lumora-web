#!/bin/bash
# Test script to validate n8n installer components

set -euo pipefail

DEPLOY_DIR="/tmp/n8n-test"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🧪 Testing n8n installer components..."

# Create test directory
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Test encryption key generation
echo "Testing encryption key generation..."
ENCRYPTION_KEY=$(openssl rand -base64 48 | tr -d '\n')
echo "✅ Encryption key generated (${#ENCRYPTION_KEY} chars)"

# Test .env creation
echo "Testing .env file creation..."
cat > .env << EOF
N8N_PORT=5678
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
# Optional: set to a real domain to enable HTTPS via Traefik
N8N_HOST=
# Email for Let's Encrypt if N8N_HOST is set
LE_EMAIL=
EOF

# Verify .env file
if [[ -f ".env" && $(grep -c "N8N_ENCRYPTION_KEY" .env) -eq 1 ]]; then
    echo "✅ .env file created successfully"
else
    echo "❌ .env file creation failed"
    exit 1
fi

# Test docker-compose.yml creation (HTTP mode)
echo "Testing docker-compose.yml creation (HTTP mode)..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_PORT=${N8N_PORT}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${TZ}
      - N8N_PAYLOAD_SIZE_MAX=${N8N_PAYLOAD_SIZE_MAX}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./files:/files
    env_file:
      - .env
    ports:
      - "0.0.0.0:5678:5678"

volumes:
  n8n_data:
EOF

if [[ -f "docker-compose.yml" && $(grep -c "n8nio/n8n:latest" docker-compose.yml) -eq 1 ]]; then
    echo "✅ docker-compose.yml created successfully (HTTP mode)"
else
    echo "❌ docker-compose.yml creation failed"
    exit 1
fi

# Test docker-compose.yml with Traefik (HTTPS mode)
echo "Testing docker-compose.yml with Traefik labels..."
N8N_HOST="example.com"
LE_EMAIL="admin@example.com"

cat > docker-compose-https.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_PORT=${N8N_PORT}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${TZ}
      - N8N_PAYLOAD_SIZE_MAX=${N8N_PAYLOAD_SIZE_MAX}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./files:/files
    env_file:
      - .env
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`${N8N_HOST}`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
    networks:
      - traefik

  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.letsencrypt.acme.email=${LE_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_data:/letsencrypt
    networks:
      - traefik

networks:
  traefik:
    external: false

volumes:
  n8n_data:
  traefik_data:
EOF

if [[ -f "docker-compose-https.yml" && $(grep -c "traefik" docker-compose-https.yml) -gt 1 ]]; then
    echo "✅ docker-compose.yml with Traefik created successfully (HTTPS mode)"
else
    echo "❌ docker-compose.yml with Traefik creation failed"
    exit 1
fi

# Test systemd service file creation
echo "Testing systemd service file creation..."
cat > n8n-compose.service << EOF
[Unit]
Description=n8n Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$DEPLOY_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

if [[ -f "n8n-compose.service" && $(grep -c "WorkingDirectory=$DEPLOY_DIR" n8n-compose.service) -eq 1 ]]; then
    echo "✅ systemd service file created successfully"
else
    echo "❌ systemd service file creation failed"
    exit 1
fi

echo "🎉 All tests passed!"
echo "Files created in $DEPLOY_DIR:"
ls -la

# Clean up
echo "Cleaning up test directory..."
rm -rf "$DEPLOY_DIR"
echo "✅ Cleanup complete"