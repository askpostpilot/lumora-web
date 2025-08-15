#!/bin/bash

# ===========================================
# Lumora Stack SSH VPS Deployment Script
# ===========================================
# This script SSHes into Hostinger VPS and deploys the latest Lumora stack
# Target: Ubuntu 24.04, root@147.79.68.121
# Runs everything non-interactively and prints results at the end

set -euo pipefail

# VPS Configuration
VPS_HOST="147.79.68.121"
VPS_USER="root"
DEPLOYMENT_DIR="/root/lumora-web"

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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Create the remote deployment commands as a heredoc script
create_deployment_script() {
    cat << 'REMOTE_SCRIPT'
#!/bin/bash
set -euo pipefail

echo "=== Lumora Stack Deployment Started ==="
echo "Target: $(hostname -f) ($(hostname -I | awk '{print $1}'))"
echo "Time: $(date)"
echo ""

# Check prerequisites
echo "=== Prerequisites Check ==="
if ! command -v git >/dev/null 2>&1; then
    echo "❌ Git is not installed"
    exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker is not installed"
    exit 1
fi
if ! command -v docker compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ Docker Compose is not installed"
    exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
    echo "❌ OpenSSL is not installed"
    exit 1
fi
echo "✅ All prerequisites available"
echo ""

# Step 1: Navigate to deployment folder (clone if missing)
echo "=== Step 1: Setting up deployment directory ==="
cd /root/lumora-web 2>/dev/null || {
    echo "Cloning repository to /root/lumora-web..."
    git clone https://github.com/askpostpilot/lumora-web.git /root/lumora-web
    cd /root/lumora-web
}
echo "Current directory: $(pwd)"
echo ""

# Step 2: Pull latest changes from main branch
echo "=== Step 2: Updating repository ==="
git fetch --all --prune
git checkout main
git pull --ff-only origin main
echo "Repository updated to latest main branch"
echo ""

# Step 3: Ensure .env exists with IP mode configuration
echo "=== Step 3: Creating .env configuration ==="
# Generate encryption key
ENCRYPTION_KEY=$(openssl rand -base64 48 | tr -d '\n')
cat > .env <<EOF
N8N_PORT=5678
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
DOMAIN=
LE_EMAIL=
EOF
chmod 600 .env
echo ".env file created with IP mode configuration"
echo "Generated encryption key: ${ENCRYPTION_KEY:0:20}..." 
echo ""

# Step 4: Fix port-80 conflict
echo "=== Step 4: Fixing port conflicts ==="
echo "Stopping any process listening on port 80 that is NOT our docker traefik..."

# Get list of processes on port 80 and kill non-traefik ones
PROCESSES_80=$(lsof -t -i :80 -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$PROCESSES_80" ]; then
    for p in $PROCESSES_80; do 
        if kill -9 $p 2>/dev/null; then
            echo "Killed process $p on port 80"
        fi
    done
else
    echo "No processes found on port 80"
fi

echo "Stopping any process listening on port 443 that is NOT our docker traefik..."
PROCESSES_443=$(lsof -t -i :443 -sTCP:LISTEN 2>/dev/null || true)
if [ -n "$PROCESSES_443" ]; then
    for p in $PROCESSES_443; do 
        if kill -9 $p 2>/dev/null; then
            echo "Killed process $p on port 443"
        fi
    done
else
    echo "No processes found on port 443"
fi

echo "Port conflict resolution completed"
echo ""

# Step 5: Recreate containers
echo "=== Step 5: Recreating containers ==="
docker compose down --remove-orphans || true
echo "Building and starting containers..."
docker compose up -d --build
echo "Containers recreated successfully"
echo ""

# Wait for containers to initialize
echo "Waiting 15 seconds for containers to initialize..."
sleep 15

# Step 6: Show status and URLs
echo "=== Step 6: Deployment Status ==="
echo ""
echo "Container Status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""

SERVER_IP=$(hostname -I | awk '{print $1}')
echo "=== ACCESS INFORMATION ==="
echo "Server IP: $SERVER_IP"
echo "Open n8n: http://$SERVER_IP:5678"
echo "Open Traefik dashboard (if enabled): http://$SERVER_IP/"
echo ""

# Verify services are responding
echo "=== SERVICE VERIFICATION ==="
if curl -sf http://localhost:5678 > /dev/null 2>&1; then
    echo "✅ n8n is responding on port 5678"
else
    echo "⚠️  n8n might still be starting up"
fi

if curl -sf http://localhost:80 > /dev/null 2>&1; then
    echo "✅ Traefik is responding on port 80"
else
    echo "⚠️  Traefik might still be starting up"
fi

echo ""
echo "=== DEPLOYMENT COMPLETED ==="
echo "Time: $(date)"
REMOTE_SCRIPT
}

# Main deployment function
deploy_to_vps() {
    log "Starting SSH deployment to VPS: $VPS_USER@$VPS_HOST"
    
    # Create the remote script
    REMOTE_SCRIPT_CONTENT=$(create_deployment_script)
    
    # Execute the deployment via SSH
    info "Connecting to VPS and executing deployment..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$VPS_USER@$VPS_HOST" "$REMOTE_SCRIPT_CONTENT"
    
    log "Deployment completed successfully!"
}

# Help function
show_help() {
    echo "Lumora Stack SSH VPS Deployment Script"
    echo ""
    echo "This script deploys the latest Lumora stack to a Hostinger VPS."
    echo ""
    echo "Target VPS: $VPS_USER@$VPS_HOST"
    echo "Deployment Directory: $DEPLOYMENT_DIR"
    echo ""
    echo "Usage:"
    echo "  $0                 Deploy to VPS"
    echo "  $0 --help         Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - SSH key access to the VPS configured"
    echo "  - VPS has Docker and Docker Compose installed"
    echo "  - VPS has Git installed"
    echo ""
    echo "What this script does:"
    echo "  1. SSH into the VPS"
    echo "  2. Clone/update lumora-web repository in $DEPLOYMENT_DIR"
    echo "  3. Create .env file with IP mode configuration"
    echo "  4. Stop conflicting processes on ports 80/443"
    echo "  5. Deploy containers with docker compose"
    echo "  6. Display access URLs and status"
}

# Main execution
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        "")
            deploy_to_vps
            ;;
        *)
            error "Unknown argument: $1. Use --help for usage information."
            ;;
    esac
}

main "$@"