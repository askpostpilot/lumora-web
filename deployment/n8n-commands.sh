set -euo pipefail

# n8n One-Shot Installer Commands - Paste directly into Ubuntu 24.04 VPS root shell
DEPLOY_DIR="/opt/solyntra"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create deployment directory
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Backup function
backup_file() { [[ -f "$1" ]] && cp "$1" "${1}.bak-${TIMESTAMP}"; }

# Backup existing files
backup_file ".env"
backup_file "docker-compose.yml"

# Read existing .env to preserve values
declare -A env_vars
if [[ -f ".env" ]]; then
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] || [[ -z $key ]] && continue
        env_vars["$key"]="$value"
    done < .env
fi

# Set defaults, preserve existing
[[ -z "${env_vars[N8N_PORT]:-}" ]] && env_vars[N8N_PORT]="5678"
[[ -z "${env_vars[GENERIC_TIMEZONE]:-}" ]] && env_vars[GENERIC_TIMEZONE]="Asia/Kolkata"
[[ -z "${env_vars[TZ]:-}" ]] && env_vars[TZ]="Asia/Kolkata"
[[ -z "${env_vars[N8N_PAYLOAD_SIZE_MAX]:-}" ]] && env_vars[N8N_PAYLOAD_SIZE_MAX]="64"

# Generate encryption key if needed
if [[ -z "${env_vars[N8N_ENCRYPTION_KEY]:-}" ]]; then
    env_vars[N8N_ENCRYPTION_KEY]=$(openssl rand -base64 48 | tr -d '\n')
fi

# Create .env file
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

# Load environment
source .env

# Check for existing Traefik
TRAEFIK_RUNNING=false
docker ps --format '{{.Names}}' | grep -q traefik && TRAEFIK_RUNNING=true

# Create docker-compose.yml base
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

# Add ports or Traefik labels based on N8N_HOST
if [[ -z "$N8N_HOST" ]]; then
    cat >> docker-compose.yml << 'EOF'
    ports:
      - "0.0.0.0:5678:5678"
EOF
else
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

    # Add Traefik service if not running
    if [[ "$TRAEFIK_RUNNING" = false ]]; then
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

# Add volumes
cat >> docker-compose.yml << 'EOF'

volumes:
  n8n_data:
EOF

# Add traefik_data volume if creating Traefik
[[ -n "$N8N_HOST" && "$TRAEFIK_RUNNING" = false ]] && cat >> docker-compose.yml << 'EOF'
  traefik_data:
EOF

# Create systemd service
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

# Enable service and create files directory
systemctl daemon-reload
systemctl enable n8n-compose.service
mkdir -p files

# Start services
systemctl start n8n-compose.service
sleep 10

# Open firewall if needed
if [[ -n "$N8N_HOST" ]] && command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw reload
fi

# Get access URL and test
if [[ -z "$N8N_HOST" ]]; then
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || hostname -I | awk '{print $1}')
    PUBLIC_URL="http://$SERVER_IP:5678"
    echo "n8n accessible at: $PUBLIC_URL"
    curl -I "$PUBLIC_URL" >/dev/null 2>&1 && echo "✅ Connectivity confirmed" || echo "⚠️ Check firewall/connectivity"
else
    PUBLIC_URL="https://$N8N_HOST"
    echo "n8n will be accessible at: $PUBLIC_URL"
    echo "Waiting for SSL certificate (may take a few minutes)..."
    for i in {1..60}; do
        curl -Ik "$PUBLIC_URL" >/dev/null 2>&1 && { echo "✅ SSL ready at $PUBLIC_URL"; break; } || sleep 10
        [[ $i -eq 60 ]] && echo "⚠️ SSL not ready yet, check $PUBLIC_URL in a few minutes"
    done
fi

# Display status
echo
echo "Docker containers:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo
echo "n8n onboarding info:"
docker logs $(docker ps --format '{{.Names}}' | grep -m1 n8n) --since 10m | grep -i 'User management' || echo "Check logs: docker logs n8n"
echo
echo "🎉 Deployment complete!"
echo "📍 Access: $PUBLIC_URL"
echo "💡 Manage: systemctl status n8n-compose.service"