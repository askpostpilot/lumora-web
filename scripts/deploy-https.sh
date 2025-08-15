#!/usr/bin/env bash
set -euo pipefail

# Deploy script for Lumora + n8n with HTTPS via Traefik
# This script implements the requirements from the problem statement

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/opt/solyntra"
LOG_FILE="/var/log/lumora-deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

# Load environment variables
if [[ ! -f "${PROJECT_DIR}/.env" ]]; then
    error "Environment file ${PROJECT_DIR}/.env not found. Please create it from .env.example"
fi

source "${PROJECT_DIR}/.env"

if [[ -z "${DOMAIN:-}" || "${DOMAIN}" == "<your-domain-here>" ]]; then
    error "Please set DOMAIN in ${PROJECT_DIR}/.env"
fi

if [[ -z "${LE_EMAIL:-}" || "${LE_EMAIL}" == "<your-email-for-LetsEncrypt>" ]]; then
    error "Please set LE_EMAIL in ${PROJECT_DIR}/.env"
fi

log "Starting HTTPS deployment for domain: ${DOMAIN}"

# Step 0: Prechecks
log "Step 0: Performing prechecks..."
RESOLVED_IP=$(dig +short A "$DOMAIN" | head -n1)
EXPECTED_IP="147.79.68.121"

if [[ "$RESOLVED_IP" != "$EXPECTED_IP" ]]; then
    error "Fix DNS A record for $DOMAIN first. Expected: $EXPECTED_IP, Got: $RESOLVED_IP"
fi

log "DNS check passed: $DOMAIN resolves to $EXPECTED_IP"

# Step 1: Update env file (already loaded)
log "Step 1: Environment configuration validated"

# Step 3: Create files/dirs as needed
log "Step 3: Creating required directories..."
mkdir -p "${PROJECT_DIR}/traefik"
if [[ ! -f "${PROJECT_DIR}/traefik/acme.json" ]]; then
    touch "${PROJECT_DIR}/traefik/acme.json"
    chmod 600 "${PROJECT_DIR}/traefik/acme.json"
    log "Created acme.json with correct permissions"
fi

# Step 4: Pull & up
log "Step 4: Starting services..."
cd "$PROJECT_DIR"
docker compose pull
docker compose up -d

# Wait for services to start
log "Waiting for services to start..."
sleep 30

# Step 5: Verify
log "Step 5: Verifying deployment..."
log "Container status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

log "Testing HTTP redirect..."
HTTP_RESPONSE=$(curl -s -I "http://$DOMAIN" | head -n1 || echo "Failed")
log "HTTP response: $HTTP_RESPONSE"

log "Testing HTTPS..."
HTTPS_RESPONSE=$(curl -s -I "https://$DOMAIN" | head -n1 || echo "Failed")
log "HTTPS response: $HTTPS_RESPONSE"

log "Deployment completed successfully!"
log "Access URLs:"
log "  Lumora Website: https://$DOMAIN"
log "  n8n Interface: https://n8n.$DOMAIN"
log "  Traefik Dashboard: https://traefik.$DOMAIN"