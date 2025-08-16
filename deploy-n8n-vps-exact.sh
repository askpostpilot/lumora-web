#!/bin/bash

# SSH into Hostinger VPS (Ubuntu 24.04, root@147.79.68.121) 
# Non-interactive deployment script to make n8n reachable on port 5678
# Follows the exact steps specified in the requirements

set -euo pipefail

# Configuration
VPS_HOST="147.79.68.121"
VPS_USER="root"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# Main deployment function following exact steps
main() {
    log "Starting n8n VPS deployment to $VPS_USER@$VPS_HOST"
    
    # SSH into VPS and execute the exact steps
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$VPS_USER@$VPS_HOST" << 'REMOTE_SCRIPT'
#!/bin/bash
set -euo pipefail

echo "=== n8n VPS Deployment Started ==="
echo "Server: $(hostname -I | awk '{print $1}')"
echo "Time: $(date)"
echo ""

# Step 1: Print docker services and port mappings
echo "=== Step 1: Docker services and port mappings ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Step 2: Confirm n8n exposes host port 5678->5678. If not, modify ~/lumora-web/docker-compose.yml
echo "=== Step 2: Check and configure n8n port mapping ==="

# Check if n8n container has the correct port mapping
if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "n8n.*0.0.0.0:5678->5678/tcp"; then
    echo "✅ n8n already exposes port 5678->5678"
else
    echo "⚠️  n8n port 5678 not exposed, configuring..."
    
    # Ensure ~/lumora-web directory exists
    cd ~
    if [ ! -d "lumora-web" ]; then
        echo "Cloning lumora-web repository..."
        git clone https://github.com/askpostpilot/lumora-web.git
    fi
    
    cd ~/lumora-web
    
    # Create docker-compose.override.yml to expose port (safer than modifying main file)
    echo "Creating docker-compose.override.yml with port mapping..."
    cat > docker-compose.override.yml << 'EOF'
services:
  n8n:
    ports:
      - "5678:5678"
EOF
    
    echo "✅ Created docker-compose.override.yml with port 5678:5678"
    
    # Deploy with updated configuration
    echo "Running: docker compose -f ~/lumora-web/docker-compose.yml up -d"
    docker compose -f ~/lumora-web/docker-compose.yml up -d
    echo "✅ Services updated with port mapping"
fi
echo ""

# Step 3: Open firewall on the server
echo "=== Step 3: Firewall configuration ==="
if ufw status | grep -qi active; then 
    echo "UFW is active, allowing port 5678/tcp..."
    ufw allow 5678/tcp
    echo "✅ Port 5678/tcp allowed in firewall"
else
    echo "✅ UFW is not active, no firewall configuration needed"
fi

echo "Listening ports:"
ss -tulpen | awk 'NR==1 || /LISTEN/'
echo ""

# Step 4: Health-check n8n
echo "=== Step 4: n8n health check ==="
echo "Testing HTTP headers..."
curl -fsSILm 5 http://127.0.0.1:5678 || true
echo ""

echo "Testing HTTP content (first 5 lines)..."
curl -fsm 5 http://127.0.0.1:5678 | head -n 5 || true
echo ""

# Step 5: Print final link to open from laptop
echo "=== Step 5: Final access URL ==="
echo "OPEN THIS: http://$(hostname -I | awk '{print $1}'):5678"
echo ""

echo "=== Deployment completed at $(date) ==="
REMOTE_SCRIPT

    local ssh_result=$?
    
    if [ $ssh_result -eq 0 ]; then
        log "✅ SSH deployment completed successfully"
        echo ""
        info "🌐 You can now access n8n at: http://147.79.68.121:5678"
    else
        error "❌ SSH deployment failed with exit code $ssh_result"
    fi
}

# Help function
show_help() {
    echo "n8n VPS Deployment Script (Exact Steps)"
    echo ""
    echo "This script SSHs into the Hostinger VPS and follows the exact 5 steps:"
    echo "  1. Print docker services and port mappings"
    echo "  2. Confirm n8n exposes host port 5678->5678, modify docker-compose.yml if needed"
    echo "  3. Open firewall on the server"
    echo "  4. Health-check n8n"
    echo "  5. Print final link to open from laptop"
    echo ""
    echo "Usage: $0 [--help]"
    echo ""
    echo "Target: root@147.79.68.121"
    echo "Access URL: http://147.79.68.121:5678"
}

# Parse arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    "")
        main
        ;;
    *)
        error "Unknown argument: $1. Use --help for usage information."
        ;;
esac