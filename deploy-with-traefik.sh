#!/usr/bin/env bash
set -euo pipefail

# Deploy script for Lumora + n8n with HTTPS via Traefik + Let's Encrypt
# This script implements the requirements for production deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
LOG_FILE="./lumora-deploy.log"

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

# Function to create traefik/acme.json with correct permissions
setup_traefik_files() {
    log "Setting up Traefik configuration files..."
    
    # Create traefik directory if it doesn't exist
    mkdir -p "$PROJECT_DIR/traefik"
    
    # Create acme.json if it doesn't exist and set permissions
    if [ ! -f "$PROJECT_DIR/traefik/acme.json" ]; then
        log "Creating traefik/acme.json..."
        touch "$PROJECT_DIR/traefik/acme.json"
    fi
    
    # Set correct permissions (600 for acme.json)
    chmod 600 "$PROJECT_DIR/traefik/acme.json"
    log "Set permissions 600 on traefik/acme.json"
    
    # Verify traefik.yml exists
    if [ ! -f "$PROJECT_DIR/traefik/traefik.yml" ]; then
        error "traefik/traefik.yml not found. Please ensure it exists in the traefik directory."
    fi
    
    log "Traefik files setup completed"
}

# Function to ensure .env file exists and generate encryption key if needed
setup_env_file() {
    log "Setting up environment file..."
    
    # Check if .env exists
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        log ".env file not found, creating from .env.example..."
        if [ ! -f "$PROJECT_DIR/.env.example" ]; then
            error ".env.example not found. Cannot create .env file."
        fi
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
        log "Created .env from .env.example"
    else
        log ".env file already exists, preserving existing configuration"
    fi
    
    # Generate N8N_ENCRYPTION_KEY if it's blank or placeholder
    if grep -q "N8N_ENCRYPTION_KEY=<48-char base64>" "$PROJECT_DIR/.env" || \
       grep -q "N8N_ENCRYPTION_KEY=$" "$PROJECT_DIR/.env" || \
       ! grep -q "N8N_ENCRYPTION_KEY=" "$PROJECT_DIR/.env"; then
        log "Generating N8N_ENCRYPTION_KEY..."
        ENCRYPTION_KEY=$(openssl rand -base64 36 | tr -d '\n')
        sed -i "s|N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}|" "$PROJECT_DIR/.env"
        log "Generated new N8N_ENCRYPTION_KEY"
    else
        log "N8N_ENCRYPTION_KEY already configured"
    fi
    
    # Verify required variables are set
    if ! grep -q "DOMAIN=<your-domain>" "$PROJECT_DIR/.env"; then
        warn "DOMAIN variable appears to be configured"
    else
        warn "DOMAIN is still set to placeholder. Please update it with your actual domain."
    fi
    
    if ! grep -q "LE_EMAIL=<your-email>" "$PROJECT_DIR/.env"; then
        warn "LE_EMAIL variable appears to be configured"
    else
        warn "LE_EMAIL is still set to placeholder. Please update it with your actual email."
    fi
    
    log "Environment file setup completed"
}

# Function to deploy containers
deploy_containers() {
    log "Deploying containers..."
    
    cd "$PROJECT_DIR"
    
    # Stop existing containers
    log "Stopping existing containers..."
    docker compose down || true
    
    # Pull latest images
    log "Pulling latest images..."
    docker compose pull
    
    # Start containers
    log "Starting containers..."
    docker compose up -d
    
    log "Containers deployed successfully"
}

# Function to wait for Traefik to get certificates and perform health checks
health_checks() {
    log "Performing health checks..."
    
    # Source .env to get DOMAIN
    if [ -f "$PROJECT_DIR/.env" ]; then
        set -a
        source "$PROJECT_DIR/.env"
        set +a
    else
        error ".env file not found for health checks"
    fi
    
    if [ -z "${DOMAIN:-}" ] || [ "$DOMAIN" = "<your-domain>" ]; then
        warn "DOMAIN not properly configured in .env file. Skipping health checks."
        return 0
    fi
    
    log "Waiting for services to start..."
    sleep 30
    
    log "Checking container status..."
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    
    # Wait a bit longer for Traefik to get certificates
    log "Waiting for Traefik to obtain SSL certificates..."
    sleep 60
    
    # Test HTTP redirect
    log "Testing HTTP redirect for $DOMAIN..."
    HTTP_RESPONSE=$(curl -s -I "http://$DOMAIN" 2>/dev/null | head -n1 || echo "Failed to connect")
    log "HTTP response: $HTTP_RESPONSE"
    
    if echo "$HTTP_RESPONSE" | grep -E "(301|308)" > /dev/null; then
        log "✅ HTTP redirect working correctly"
    else
        warn "⚠️  HTTP redirect may not be working as expected"
    fi
    
    # Test HTTPS
    log "Testing HTTPS for $DOMAIN..."
    HTTPS_RESPONSE=$(curl -s -I "https://$DOMAIN" 2>/dev/null | head -n1 || echo "Failed to connect")
    log "HTTPS response: $HTTPS_RESPONSE"
    
    if echo "$HTTPS_RESPONSE" | grep "200" > /dev/null; then
        log "✅ HTTPS working correctly"
    else
        warn "⚠️  HTTPS may not be working as expected. SSL certificate might still be provisioning."
    fi
    
    log "Health checks completed"
}

# Main deployment function
main() {
    log "Starting Lumora deployment with Traefik + Let's Encrypt..."
    
    # Check if running as root (recommended for production)
    if [ "$EUID" -ne 0 ]; then
        warn "Not running as root. Some operations might require sudo privileges."
    fi
    
    # Step 1: Setup Traefik files
    setup_traefik_files
    
    # Step 2: Setup environment file
    setup_env_file
    
    # Step 3: Deploy containers
    deploy_containers
    
    # Step 4: Health checks
    health_checks
    
    log "Deployment completed successfully!"
    log ""
    log "Access your n8n instance at: https://\$DOMAIN"
    log "Traefik dashboard (if enabled): https://traefik.\$DOMAIN"
    log ""
    log "Next steps:"
    log "1. Ensure your domain DNS points to this server"
    log "2. Update .env file with your actual DOMAIN and LE_EMAIL values"
    log "3. Run this script again after updating .env"
    log "4. Monitor logs: docker compose logs -f"
}

# Run main function
main "$@"