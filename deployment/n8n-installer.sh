#!/bin/bash
set -euo pipefail

# n8n One-Shot Installer for Ubuntu 24.04 with Docker & Docker Compose
# Creates a production-ready n8n deployment with optional HTTPS via Traefik
# Working directory: /opt/solyntra

DEPLOY_DIR="/opt/solyntra"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Create working directory
log "Creating deployment directory: $DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Backup existing files if they exist
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        log "Backing up existing $file to ${file}.bak-${TIMESTAMP}"
        cp "$file" "${file}.bak-${TIMESTAMP}"
    fi
}

# Generate strong encryption key
generate_encryption_key() {
    openssl rand -base64 48 | tr -d '\n'
}

# Create or update .env file
log "Creating/updating .env file"
backup_file ".env"

# Read existing .env if it exists to preserve values
declare -A env_vars
if [[ -f ".env" ]]; then
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]] && continue
        env_vars["$key"]="$value"
    done < .env
fi

# Set default values, keeping existing ones
[[ -z "${env_vars[N8N_PORT]:-}" ]] && env_vars[N8N_PORT]="5678"
[[ -z "${env_vars[GENERIC_TIMEZONE]:-}" ]] && env_vars[GENERIC_TIMEZONE]="Asia/Kolkata"
[[ -z "${env_vars[TZ]:-}" ]] && env_vars[TZ]="Asia/Kolkata"
[[ -z "${env_vars[N8N_PAYLOAD_SIZE_MAX]:-}" ]] && env_vars[N8N_PAYLOAD_SIZE_MAX]="64"

# Generate encryption key if not set
if [[ -z "${env_vars[N8N_ENCRYPTION_KEY]:-}" ]]; then
    log "Generating new N8N encryption key"
    env_vars[N8N_ENCRYPTION_KEY]=$(generate_encryption_key)
else
    log "Using existing N8N encryption key"
fi

# Write .env file
cat > .env << EOF
N8N_PORT=${env_vars[N8N_PORT]}
GENERIC_TIMEZONE=${env_vars[GENERIC_TIMEZONE]}
TZ=${env_vars[TZ]}
N8N_PAYLOAD_SIZE_MAX=${env_vars[N8N_PAYLOAD_SIZE_MAX]}
N8N_ENCRYPTION_KEY=${env_vars[N8N_ENCRYPTION_KEY]}
# Optional: set to a real domain to enable HTTPS via Traefik
N8N_HOST=${env_vars[N8N_HOST]:-}
# Email for Let's Encrypt if N8N_HOST is set
LE_EMAIL=${env_vars[LE_EMAIL]:-}
EOF

log "Environment file created/updated"

# Load environment variables
source .env

# Check if Traefik is already running
TRAEFIK_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q traefik; then
    TRAEFIK_RUNNING=true
    log "Existing Traefik container found, will reuse it"
fi

# Create docker-compose.yml
log "Creating/updating docker-compose.yml"
backup_file "docker-compose.yml"

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
EOF

# Add port configuration or Traefik labels based on N8N_HOST
if [[ -z "$N8N_HOST" ]]; then
    log "No domain configured, exposing n8n on port 5678"
    cat >> docker-compose.yml << 'EOF'
    ports:
      - "0.0.0.0:5678:5678"
EOF
else
    log "Domain configured: $N8N_HOST, setting up Traefik labels"
    cat >> docker-compose.yml << 'EOF'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(`${N8N_HOST}`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
    networks:
      - traefik
EOF

    # Add Traefik service if not already running
    if [[ "$TRAEFIK_RUNNING" = false ]]; then
        log "Adding Traefik service to docker-compose.yml"
        cat >> docker-compose.yml << 'EOF'

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
EOF
    else
        cat >> docker-compose.yml << 'EOF'

networks:
  traefik:
    external: true
EOF
    fi
fi

# Add volumes section
cat >> docker-compose.yml << 'EOF'

volumes:
  n8n_data:
EOF

# Add traefik_data volume if Traefik is being created
if [[ -n "$N8N_HOST" && "$TRAEFIK_RUNNING" = false ]]; then
    cat >> docker-compose.yml << 'EOF'
  traefik_data:
EOF
fi

log "Docker Compose configuration created"

# Create systemd service
log "Creating systemd service: /etc/systemd/system/n8n-compose.service"
cat > /etc/systemd/system/n8n-compose.service << EOF
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

# Enable and reload systemd
log "Enabling n8n systemd service"
systemctl daemon-reload
systemctl enable n8n-compose.service

# Create files directory if it doesn't exist
mkdir -p files

# Start the services
log "Starting n8n services"
systemctl start n8n-compose.service

# Wait for services to start
log "Waiting for services to start..."
sleep 10

# Open firewall ports if UFW is active and domain is set
if [[ -n "$N8N_HOST" ]] && command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    log "UFW is active, opening ports 80 and 443"
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw reload
fi

# Get server IP for non-domain setup
if [[ -z "$N8N_HOST" ]]; then
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')
    PUBLIC_URL="http://$SERVER_IP:5678"
    log "n8n should be accessible at: $PUBLIC_URL"
    
    # Test connectivity
    log "Testing connectivity..."
    if curl -I "$PUBLIC_URL" >/dev/null 2>&1; then
        log "✅ n8n is accessible at $PUBLIC_URL"
    else
        warn "⚠️  Could not verify connectivity to $PUBLIC_URL"
    fi
else
    PUBLIC_URL="https://$N8N_HOST"
    log "n8n should be accessible at: $PUBLIC_URL"
    
    # Wait for Traefik to obtain certificates
    log "Waiting for Traefik to obtain SSL certificates (this may take a few minutes)..."
    for i in {1..60}; do
        if curl -Ik "$PUBLIC_URL" >/dev/null 2>&1; then
            log "✅ SSL certificate obtained and n8n is accessible at $PUBLIC_URL"
            break
        fi
        if [[ $i -eq 60 ]]; then
            warn "⚠️  SSL certificate not ready yet. Please wait a few more minutes and check $PUBLIC_URL"
        else
            sleep 10
        fi
    done
fi

# Display service status
log "Docker containers status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Show n8n logs for onboarding information
log "Checking n8n logs for onboarding information:"
N8N_CONTAINER=$(docker ps --format '{{.Names}}' | grep -m1 n8n || echo "n8n")
docker logs "$N8N_CONTAINER" --since 10m 2>/dev/null | grep -i 'User management' || log "No user management message found in recent logs"

# Final summary
echo
log "🎉 n8n deployment completed successfully!"
echo
log "📋 Summary:"
log "  • Working Directory: $DEPLOY_DIR"
log "  • Service: n8n-compose.service (enabled for auto-start)"
log "  • Access URL: $PUBLIC_URL"
echo
log "🚀 Next Steps:"
log "  1. Open $PUBLIC_URL in your browser"
log "  2. Complete the n8n onboarding process"
log "  3. Create your admin account"
echo
log "💡 Useful Commands:"
log "  • Check status: systemctl status n8n-compose.service"
log "  • View logs: docker logs n8n"
log "  • Stop services: systemctl stop n8n-compose.service"
log "  • Restart services: systemctl restart n8n-compose.service"
echo