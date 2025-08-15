#!/usr/bin/env bash
set -euo pipefail

# Master installation script for Lumora + n8n deployment
# Combines HTTPS setup and hardening into a single idempotent script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/opt/solyntra"
LOG_FILE="/var/log/lumora-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "=== Lumora + n8n Master Installation Script ==="
log "This script will:"
log "1. Deploy HTTPS-enabled services via Traefik"
log "2. Apply security hardening measures"
log "3. Configure automated backups and monitoring"

# Check if we're in the right directory or if we need to set up the project
if [[ "$PWD" != "$PROJECT_DIR" ]]; then
    if [[ ! -d "$PROJECT_DIR" ]]; then
        warn "Project directory $PROJECT_DIR doesn't exist"
        info "Please manually copy the deployment files to $PROJECT_DIR first"
        info "Example: scp -r /path/to/lumora-web root@vps:/opt/solyntra"
        exit 1
    fi
    cd "$PROJECT_DIR"
fi

# Load and validate environment
if [[ ! -f ".env" ]]; then
    if [[ -f ".env.example" ]]; then
        warn "No .env file found, but .env.example exists"
        info "Please copy .env.example to .env and configure your settings:"
        info "  cp .env.example .env"
        info "  nano .env"
        exit 1
    else
        error "Neither .env nor .env.example found"
    fi
fi

source .env

# Validate required variables
REQUIRED_VARS=("DOMAIN" "LE_EMAIL" "N8N_ENCRYPTION_KEY")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" || "${!var}" == *"<"*">"* ]]; then
        error "Please set $var in .env file (currently: ${!var:-not set})"
    fi
done

log "Configuration validated for domain: $DOMAIN"

# Execute HTTPS deployment
log "=== Phase 1: HTTPS Deployment ==="
if [[ -f "scripts/deploy-https.sh" ]]; then
    ./scripts/deploy-https.sh
else
    error "deploy-https.sh script not found"
fi

# Execute hardening
log "=== Phase 2: Security Hardening ==="
if [[ -f "scripts/hardening.sh" ]]; then
    ./scripts/hardening.sh
else
    error "hardening.sh script not found"
fi

# Setup systemd service
log "=== Phase 3: Systemd Integration ==="
if [[ -f "systemd/n8n-compose.service" ]]; then
    cp systemd/n8n-compose.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable n8n-compose.service
    log "Systemd service enabled"
else
    warn "Systemd service file not found, skipping"
fi

# Final status report
log "=== Installation Complete ==="
log ""
log "🚀 Services Available:"
log "   • Lumora Website: https://$DOMAIN"
log "   • n8n Interface: https://n8n.$DOMAIN"
log "   • Traefik Dashboard: https://traefik.$DOMAIN"
log ""
log "🛡️  Security Features Enabled:"
log "   • Daily backups (02:10) → $PROJECT_DIR/backups"
log "   • 5-minute health checks"
log "   • Automatic container updates (03:00)"
log "   • Basic firewall (UFW)"
log ""
log "📋 Management Commands:"
log "   • View status: systemctl status n8n-compose.service"
log "   • View logs: docker compose logs -f"
log "   • Manual backup: $PROJECT_DIR/backup_n8n.sh"
log "   • Health check: $PROJECT_DIR/healthcheck.sh"
log ""
log "Installation completed successfully!"