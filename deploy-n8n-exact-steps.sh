#!/bin/bash

# Deploy n8n in IP mode with exact steps as specified
# SSH into Hostinger VPS (Ubuntu 24.04, root@147.79.68.121) 
# Non-interactive. Find the correct public URL for n8n in IP mode and make sure it's reachable.

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

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

# Main deployment function following exact steps
deploy_n8n_exact_steps() {
    log "Starting n8n IP mode deployment with exact steps to VPS: $VPS_USER@$VPS_HOST"
    
    info "Executing exact deployment commands on VPS..."
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$VPS_USER@$VPS_HOST" << 'REMOTE_SCRIPT'
#!/bin/bash
set -euo pipefail

echo "=== n8n IP Mode Deployment - Exact Steps ==="
echo "VPS: $(hostname -I | awk '{print $1}')"
echo "Time: $(date)"
echo ""

# Step 1: Print docker services and port mappings
echo "=== Step 1: Print docker services and port mappings ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Step 2: Confirm n8n exposes host port 5678->5678. If not, modify ~/lumora-web/docker-compose.yml
echo "=== Step 2: Confirm n8n port mapping and modify if needed ==="

# Ensure we're in the correct directory
cd ~/lumora-web 2>/dev/null || {
    echo "lumora-web directory not found, cloning..."
    cd ~
    git clone https://github.com/askpostpilot/lumora-web.git
    cd ~/lumora-web
}

echo "Current directory: $(pwd)"

# Check if n8n has the correct port mapping
N8N_PORT_CHECK=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -c "n8n.*0.0.0.0:5678->5678" || echo "0")

if [ "$N8N_PORT_CHECK" -eq 0 ]; then
    echo "n8n port 5678 not properly exposed, modifying ~/lumora-web/docker-compose.yml..."
    
    # Backup original file
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
    
    # Check if n8n service already has ports section
    if grep -A 20 "^  n8n:" docker-compose.yml | grep -q "^    ports:"; then
        echo "n8n service already has ports section, checking if 5678:5678 is present..."
        if grep -A 20 "^  n8n:" docker-compose.yml | grep -q "5678:5678"; then
            echo "✅ Port 5678:5678 already present in docker-compose.yml"
        else
            echo "Adding 5678:5678 to existing ports section..."
            # Add 5678:5678 to the existing ports section
            sed -i '/^  n8n:/,/^  [a-zA-Z]/ {
                /^    ports:/a\      - "5678:5678"
            }' docker-compose.yml
        fi
    else
        echo "Adding ports section with 5678:5678 to n8n service..."
        # Add ports section right after n8n service declaration
        sed -i '/^  n8n:/a\    ports:\n      - "5678:5678"' docker-compose.yml
    fi
    
    echo "Modified docker-compose.yml includes:"
    echo "ports:"
    echo "  - \"5678:5678\""
    echo ""
    
    # Run docker compose command as specified
    echo "Running: docker compose -f ~/lumora-web/docker-compose.yml up -d"
    docker compose -f ~/lumora-web/docker-compose.yml up -d
else
    echo "✅ n8n port 5678 already properly exposed"
fi
echo ""

# Step 3: Open firewall on the server
echo "=== Step 3: Open firewall on the server ==="
if ufw status | grep -qi active; then 
    echo "UFW is active, allowing port 5678/tcp..."
    ufw allow 5678/tcp
    echo "✅ Port 5678/tcp allowed"
else
    echo "✅ UFW is not active, no firewall changes needed"
fi

echo "Listening ports:"
ss -tulpen | awk 'NR==1 || /LISTEN/'
echo ""

# Step 4: Health-check n8n
echo "=== Step 4: Health-check n8n ==="
echo "Testing n8n HTTP headers:"
curl -fsSILm 5 http://127.0.0.1:5678 || true
echo ""

echo "Testing n8n response content (first 5 lines):"
curl -fsm 5 http://127.0.0.1:5678 | head -n 5 || true
echo ""

# Step 5: Print final link to open from laptop
echo "=== Step 5: Final link ==="
echo "OPEN THIS: http://$(hostname -I | awk '{print $1}'):5678"
echo ""

echo "=== Deployment completed at $(date) ==="
REMOTE_SCRIPT

    local ssh_result=$?
    
    if [ $ssh_result -eq 0 ]; then
        log "✅ SSH deployment completed successfully"
    else
        error "❌ SSH deployment failed with exit code $ssh_result"
    fi
}

# Main execution
main() {
    case "${1:-}" in
        --help|-h)
            echo "n8n IP Mode Deployment Script - Exact Steps"
            echo ""
            echo "This script performs the exact steps specified for n8n IP mode deployment"
            echo "Target: http://147.79.68.121:5678"
            echo ""
            echo "Usage: $0"
            echo ""
            echo "Exact steps performed:"
            echo "  1) Print docker services and port mappings"
            echo "  2) Confirm n8n exposes host port 5678->5678, modify docker-compose.yml if needed"
            echo "  3) Open firewall and show listening ports"
            echo "  4) Health-check n8n with specific curl commands"
            echo "  5) Print final link with dynamic IP detection"
            exit 0
            ;;
        "")
            deploy_n8n_exact_steps
            ;;
        *)
            error "Unknown argument: $1. Use --help for usage information."
            ;;
    esac
}

main "$@"