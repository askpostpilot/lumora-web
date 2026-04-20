#!/usr/bin/env bash
set -euo pipefail

# =============================================
# Lumora IP-mode deployment script
# =============================================
# Deploy n8n on port 80 without domain/HTTPS
# Target: http://147.79.68.121/
# Idempotent, fail-fast, with retries and fallbacks

PROJECT_DIR="/root/lumora-web"
REPO_URL="https://github.com/askpostpilot/lumora-web.git"
VPS_IP="147.79.68.121"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Retry helper function (5 tries with exponential backoff)
retry() {
    local max_attempts=5
    local delay=1
    local attempt=1
    local command="$*"
    
    while [ $attempt -le $max_attempts ]; do
        log "Attempt $attempt/$max_attempts: $command"
        if eval "$command"; then
            log "Command succeeded on attempt $attempt"
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                error "Command failed after $max_attempts attempts: $command"
            fi
            warn "Attempt $attempt failed, retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
            attempt=$((attempt + 1))
        fi
    done
}

# Free ports 80/443
free_ports() {
    log "=== Freeing ports 80/443 ==="
    
    # Stop and disable common web servers
    for service in apache2 nginx; do
        if systemctl is-active --quiet $service 2>/dev/null; then
            log "Stopping $service..."
            systemctl stop $service || true
        fi
        if systemctl is-enabled --quiet $service 2>/dev/null; then
            log "Disabling $service..."
            systemctl disable $service || true
        fi
    done
    
    # Find and kill processes holding ports 80/443
    for port in 80 443; do
        local pids=$(ss -ltnp "( sport = :$port )" | awk '/LISTEN/ {print $7}' | cut -d',' -f2 | cut -d'=' -f2 | grep -E '^[0-9]+$' || true)
        if [ -n "$pids" ]; then
            warn "Found processes on port $port: $pids"
            for pid in $pids; do
                if [ "$pid" != "$$" ]; then  # Don't kill ourselves
                    log "Killing PID $pid on port $port"
                    kill -TERM $pid 2>/dev/null || true
                    sleep 2
                    kill -KILL $pid 2>/dev/null || true
                fi
            done
        fi
    done
    
    # Wait a moment for ports to be freed
    sleep 3
    
    # Verify ports are free
    for port in 80 443; do
        if ss -ltn "( sport = :$port )" | grep -q ":$port "; then
            warn "Port $port still appears to be in use, but continuing..."
        else
            log "Port $port is free"
        fi
    done
}

# Setup UFW firewall
setup_firewall() {
    log "=== Setting up UFW firewall ==="
    
    # Install UFW if missing
    if ! command -v ufw >/dev/null 2>&1; then
        log "Installing UFW..."
        retry "apt-get update && apt-get install -y ufw"
    fi
    
    # Configure UFW rules
    log "Configuring UFW rules..."
    ufw allow 22/tcp >/dev/null 2>&1 || true
    ufw allow 80/tcp >/dev/null 2>&1 || true
    
    # Enable UFW with auto-yes
    log "Enabling UFW..."
    yes | ufw enable >/dev/null 2>&1 || true
    
    # Show status
    ufw status verbose || true
}

# Sync code from GitHub
sync_code() {
    log "=== Syncing code from GitHub ==="
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log "Cloning repository to $PROJECT_DIR..."
        retry "git clone $REPO_URL $PROJECT_DIR"
    else
        log "Repository exists, updating..."
        cd "$PROJECT_DIR"
        retry "git fetch --all --prune"
        retry "git checkout main"
        retry "git reset --hard origin/main"
    fi
    
    cd "$PROJECT_DIR"
    log "Repository synced successfully"
}

# Ensure .env file for IP mode
ensure_env_file() {
    log "=== Ensuring .env file for IP mode ==="
    
    cd "$PROJECT_DIR"
    
    # Create .env if missing
    if [ ! -f ".env" ]; then
        log "Creating new .env file..."
        cat > .env << 'EOF'
N8N_PORT=5678
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64
DOMAIN=
LE_EMAIL=
EOF
    else
        log "Updating existing .env file..."
    fi
    
    # Function to update or add env variable
    update_env_var() {
        local key="$1"
        local value="$2"
        local env_file=".env"
        
        if grep -q "^${key}=" "$env_file"; then
            # Update existing key
            sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
            log "Updated ${key}=${value}"
        else
            # Add new key
            echo "${key}=${value}" >> "$env_file"
            log "Added ${key}=${value}"
        fi
    }
    
    # Set required variables for IP mode
    update_env_var "N8N_PORT" "5678"
    update_env_var "GENERIC_TIMEZONE" "Asia/Kolkata"
    update_env_var "TZ" "Asia/Kolkata"
    update_env_var "N8N_PAYLOAD_SIZE_MAX" "64"
    update_env_var "DOMAIN" ""
    update_env_var "LE_EMAIL" ""
    update_env_var "N8N_HOST" ""
    update_env_var "N8N_PROTOCOL" "http"
    update_env_var "WEBHOOK_URL" "http://${VPS_IP}"
    update_env_var "N8N_IP_PORT" "80"
    
    # Generate N8N_ENCRYPTION_KEY if missing or empty
    if ! grep -q "^N8N_ENCRYPTION_KEY=" .env || [ -z "$(grep "^N8N_ENCRYPTION_KEY=" .env | cut -d'=' -f2-)" ]; then
        log "Generating N8N_ENCRYPTION_KEY..."
        local encryption_key=$(openssl rand -base64 48 | tr -d '\n')
        update_env_var "N8N_ENCRYPTION_KEY" "$encryption_key"
    else
        log "N8N_ENCRYPTION_KEY already exists"
    fi
    
    # Set secure permissions
    chmod 600 .env
    log "Set .env permissions to 600"
}

# Docker compose up with retry
compose_up() {
    log "=== Starting Docker services ==="
    
    cd "$PROJECT_DIR"
    
    # Create docker-compose.override.yml for IP mode
    log "Creating docker-compose.override.yml for IP mode..."
    cat > docker-compose.override.yml << 'EOF'
services:
  n8n:
    ports:
      - "80:5678"
EOF
    
    # Stop existing containers
    log "Stopping existing containers..."
    docker compose down --remove-orphans || true
    
    # Start services with retry (only n8n in IP mode)
    log "Starting n8n service in IP mode..."
    retry "docker compose up -d --remove-orphans"
    
    log "Docker services started successfully"
}

# Health checks with fallbacks
health_checks() {
    log "=== Performing health checks ==="
    
    local max_attempts=10
    local delay=5
    local attempt=1
    
    # Wait for n8n to be ready
    log "Waiting for n8n to start..."
    sleep 10
    
    # Check if n8n is responding on port 80
    while [ $attempt -le $max_attempts ]; do
        log "Health check attempt $attempt/$max_attempts"
        
        if curl -sSf "http://127.0.0.1:80/" >/dev/null 2>&1; then
            log "✅ n8n is responding on port 80"
            return 0
        elif curl -sSf "http://127.0.0.1:5678/" >/dev/null 2>&1; then
            warn "⚠️  n8n is responding on port 5678 but not 80"
            info "Attempting to fix port mapping..."
            
            # Try to fix port mapping
            cd "$PROJECT_DIR"
            docker compose down || true
            
            # Ensure port mapping is correct in env
            update_env_var "N8N_IP_PORT" "80"
            
            # Restart with correct mapping
            retry "docker compose up -d --remove-orphans"
            sleep 10
        else
            warn "n8n not responding on either port, waiting ${delay}s..."
            sleep $delay
        fi
        
        attempt=$((attempt + 1))
    done
    
    warn "⚠️  Health checks completed with warnings"
}

# Function to update env variable (reusable)
update_env_var() {
    local key="$1"
    local value="$2"
    local env_file=".env"
    
    if grep -q "^${key}=" "$env_file"; then
        # Update existing key
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        # Add new key
        echo "${key}=${value}" >> "$env_file"
    fi
}

# Final status report
final_report() {
    log "=== Final Status Report ==="
    
    cd "$PROJECT_DIR"
    
    # Container status
    log "Container status:"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
    
    # Who owns port 80
    log "Port 80 ownership:"
    ss -ltnp '( sport = :80 )' || true
    
    # Success message
    echo ""
    echo "========================================="
    echo "🎉 DEPLOYMENT COMPLETE"
    echo "========================================="
    echo ""
    echo "OPEN_URL=http://${VPS_IP}/"
    echo ""
    
    # Additional status
    local containers_ok=$(docker ps --format '{{.Names}}' | grep -c "n8n" || echo "0")
    echo "CONTAINERS_OK=$containers_ok"
    
    # Notes
    local notes=""
    if ! curl -sSf "http://127.0.0.1:80/" >/dev/null 2>&1; then
        notes="WARNING: n8n may not be responding on port 80. Check logs with: docker logs n8n"
    else
        notes="SUCCESS: n8n is accessible on port 80"
    fi
    echo "NOTES=$notes"
    echo ""
}

# Main execution
main() {
    log "=== Starting Lumora IP-mode deployment ==="
    log "Target: http://${VPS_IP}/ (port 80 → n8n:5678)"
    
    free_ports
    setup_firewall
    sync_code
    ensure_env_file
    compose_up
    health_checks
    final_report
    
    log "=== Deployment script completed ==="
}

# Run main function
main "$@"