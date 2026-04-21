#!/bin/bash
set -euo pipefail

# n8n Docker Compose Installation Script for Hostinger VPS
# This script sets up n8n with Docker Compose and systemd auto-start
# Designed to be idempotent - safe to re-run multiple times

echo "🚀 Starting n8n installation..."

# Configuration
N8N_PORT=5678
SERVER_IP="147.79.68.121"
INSTALL_DIR="/opt/solyntra"
ENV_FILE="$INSTALL_DIR/.env"
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
SYSTEMD_SERVICE="/etc/systemd/system/n8n-compose.service"

# Function to generate secure encryption key
generate_encryption_key() {
    openssl rand -base64 48 | tr -d '\n'
}

# Function to check if a variable exists and is not empty in .env file
get_env_var() {
    local var_name="$1"
    if [[ -f "$ENV_FILE" ]] && grep -q "^${var_name}=" "$ENV_FILE"; then
        grep "^${var_name}=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"'
    else
        echo ""
    fi
}

# Create directories
echo "📁 Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/files"

# Create or update .env file
echo "⚙️  Creating/updating .env configuration..."

# Get existing encryption key if it exists
existing_key=$(get_env_var "N8N_ENCRYPTION_KEY")
if [[ -z "$existing_key" ]]; then
    echo "🔐 Generating new encryption key..."
    encryption_key=$(generate_encryption_key)
else
    echo "🔐 Using existing encryption key..."
    encryption_key="$existing_key"
fi

# Write .env file
cat > "$ENV_FILE" << EOF
# n8n Configuration for Hostinger VPS
N8N_PORT=$N8N_PORT
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64

# Security - DO NOT CHANGE once set (will break existing data)
N8N_ENCRYPTION_KEY=$encryption_key

# IP mode (no domain yet)
N8N_HOST=
LE_EMAIL=
EOF

echo "✅ .env file created/updated"

# Create docker-compose.yml
echo "🐳 Creating Docker Compose configuration..."
cat > "$COMPOSE_FILE" << 'EOF'
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

volumes:
  n8n_data: {}
EOF

echo "✅ Docker Compose file created"

# Create systemd service
echo "🔧 Setting up systemd service..."
cat > "$SYSTEMD_SERVICE" << EOF
[Unit]
Description=n8n Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=$INSTALL_DIR
RemainAfterExit=yes
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Systemd service file created"

# Reload systemd and enable service
echo "⚡ Enabling and starting n8n service..."
systemctl daemon-reload
systemctl enable n8n-compose.service
systemctl start n8n-compose.service

echo "⏳ Waiting for container to start..."
sleep 10

# Verify container is running
echo "🔍 Verifying container status..."
if docker ps | grep -q "n8n"; then
    echo "✅ n8n container is running"
    docker ps --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ n8n container is not running"
    echo "Docker logs:"
    docker logs n8n 2>/dev/null || echo "No logs available"
    exit 1
fi

# Verify UI accessibility
echo "🌐 Checking UI accessibility..."
sleep 5
if curl -s --connect-timeout 10 "http://127.0.0.1:$N8N_PORT" | grep -qi "<title>"; then
    echo "✅ n8n UI is accessible"
else
    echo "⚠️  UI might not be ready yet, but container is running"
fi

# Extract onboarding URL from logs or provide fallback
echo "🎉 Installation complete!"
echo ""
echo "📋 n8n Setup Information:"
echo "├── Installation Directory: $INSTALL_DIR"
echo "├── Container Name: n8n"
echo "├── Port: $N8N_PORT"
echo "└── Service: n8n-compose.service"
echo ""

# Try to find onboarding information in logs
echo "🔗 Access URL:"
if docker logs n8n --since 5m 2>/dev/null | grep -i 'User management\|setup\|onboarding' | head -3; then
    echo ""
fi
echo "🌍 Open: http://$SERVER_IP:$N8N_PORT/"
echo ""
echo "📚 Next steps:"
echo "1. Visit the URL above in your browser"
echo "2. Complete n8n's first-time setup"
echo "3. Create your admin account"
echo ""
echo "🛠️  Management commands:"
echo "├── Check status: systemctl status n8n-compose.service"
echo "├── View logs: docker logs n8n -f"
echo "├── Restart: systemctl restart n8n-compose.service"
echo "└── Stop: systemctl stop n8n-compose.service"