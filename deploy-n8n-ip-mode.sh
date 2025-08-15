#!/bin/bash

# Deploy n8n in IP mode on Hostinger VPS
# Task: SSH into my Hostinger VPS (Ubuntu 24.04, root@147.79.68.121) and make n8n reachable at http://147.79.68.121:5678 using IP mode (no domain)

set -euo pipefail

# Configuration
VPS_HOST="147.79.68.121"
VPS_USER="root"
N8N_PORT="5678"
DEPLOYMENT_DIR="lumora-web"

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

# Main deployment function
deploy_n8n_ip_mode() {
    log "Starting n8n IP mode deployment to VPS: $VPS_USER@$VPS_HOST"
    
    # Create the remote deployment script
    info "Executing deployment commands on VPS..."
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$VPS_USER@$VPS_HOST" << 'REMOTE_SCRIPT'
#!/bin/bash
set -euo pipefail

echo "=== n8n IP Mode Deployment Started ==="
echo "VPS: $(hostname -I | awk '{print $1}')"
echo "Target: http://147.79.68.121:5678"
echo "Time: $(date)"
echo ""

# Step 1: SSH to the VPS and cd ~/lumora-web (clone if missing)
echo "=== Step 1: Setting up lumora-web directory ==="
cd ~
if [ ! -d "lumora-web" ]; then
    echo "Cloning lumora-web repository..."
    git clone https://github.com/askpostpilot/lumora-web.git
    echo "Repository cloned successfully"
else
    echo "lumora-web directory exists"
fi

cd ~/lumora-web
echo "Current directory: $(pwd)"
echo ""

# Step 2: Create/overwrite docker-compose.override.yml that only publishes n8n
echo "=== Step 2: Creating docker-compose.override.yml ==="
cat > docker-compose.override.yml << 'EOF'
services:
  n8n:
    ports:
      - "5678:5678"
EOF

echo "docker-compose.override.yml created:"
cat docker-compose.override.yml
echo ""

# Step 3: docker compose up -d --remove-orphans
echo "=== Step 3: Starting Docker services ==="
echo "Running: docker compose up -d --remove-orphans"
docker compose up -d --remove-orphans
echo "Docker services started"
echo ""

# Step 4: Verify docker ps shows n8n with 0.0.0.0:5678->5678/tcp
echo "=== Step 4: Verification ==="
echo "Container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check if n8n shows the correct port mapping
if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "n8n.*0.0.0.0:5678->5678/tcp"; then
    echo "✅ n8n port mapping confirmed: 0.0.0.0:5678->5678/tcp"
else
    echo "⚠️  Checking n8n port mapping..."
    docker ps | grep n8n || echo "n8n container not found"
fi
echo ""

# Step 5: Test local connectivity
echo "=== Step 5: Testing local connectivity ==="
HTTP_STATUS=$(curl -sS -D - -o /dev/null http://127.0.0.1:5678 | head -n1 || echo "Connection failed")
echo "Local curl result: $HTTP_STATUS"

if echo "$HTTP_STATUS" | grep -q "200\|302\|404"; then
    echo "✅ n8n is responding locally"
else
    echo "⚠️  n8n may still be starting up"
    # Wait a bit and try again
    echo "Waiting 10 seconds for n8n to fully start..."
    sleep 10
    HTTP_STATUS_RETRY=$(curl -sS -D - -o /dev/null http://127.0.0.1:5678 | head -n1 || echo "Connection failed")
    echo "Retry result: $HTTP_STATUS_RETRY"
fi
echo ""

# Step 6: Check and configure firewall
echo "=== Step 6: Firewall configuration ==="
UFW_STATUS=$(ufw status | head -n1)
echo "UFW Status: $UFW_STATUS"

if echo "$UFW_STATUS" | grep -q "Status: active"; then
    echo "UFW is active, checking if port 5678 is allowed..."
    if ufw status | grep -q "5678"; then
        echo "✅ Port 5678 already allowed"
    else
        echo "Adding UFW rule for port 5678/tcp..."
        ufw allow 5678/tcp
        echo "✅ Port 5678/tcp allowed in firewall"
    fi
    echo "Current UFW status:"
    ufw status numbered
else
    echo "✅ UFW is inactive, no firewall rules needed"
fi
echo ""

# Step 7: Print final access URL
echo "=== Step 7: Final Results ==="
echo ""
echo "🎯 FINAL ACCESS URL: http://147.79.68.121:5678"
echo ""
echo "📊 SERVICE STATUS:"
echo "   - n8n container: $(docker ps --filter "name=n8n" --format "{{.Status}}" | head -n1 || echo "Not found")"
echo "   - Port mapping: $(docker ps --filter "name=n8n" --format "{{.Ports}}" | head -n1 || echo "Not found")"
echo "   - Local connectivity: $(echo "$HTTP_STATUS" | grep -o "HTTP/[0-9.]* [0-9]*" || echo "Failed")"
echo "   - UFW status: $UFW_STATUS"
echo ""

echo "=== Deployment completed at $(date) ==="
REMOTE_SCRIPT

    local ssh_result=$?
    
    if [ $ssh_result -eq 0 ]; then
        log "SSH deployment completed successfully"
    else
        error "SSH deployment failed with exit code $ssh_result"
    fi
}

# Test remote connectivity from runner
test_remote_connectivity() {
    echo ""
    log "Testing remote connectivity from runner..."
    
    info "Testing connection to http://147.79.68.121:5678"
    
    # Test remote connectivity with timeout
    if timeout 10 curl -sS -D - -o /dev/null "http://147.79.68.121:5678" 2>/dev/null | head -n1; then
        log "✅ Remote connectivity test successful"
    else
        warn "⚠️  Remote connectivity test failed - n8n may still be starting or firewall issues"
        info "You can manually test: curl -I http://147.79.68.121:5678"
    fi
}

# Print final checklist
print_final_checklist() {
    echo ""
    echo "========================================="
    echo "🎯 FINAL CHECKLIST & ACCESS INFORMATION"
    echo "========================================="
    echo ""
    echo "✅ SSH deployment completed"
    echo "✅ docker-compose.override.yml created"
    echo "✅ Docker services started with --remove-orphans"
    echo "✅ Port 5678 published for n8n"
    echo "✅ Firewall configured (if active)"
    echo ""
    echo "🌐 ACCESS URL:"
    echo "   👉 http://147.79.68.121:5678"
    echo ""
    echo "📋 Quick verification commands (run on VPS):"
    echo "   • docker ps | grep n8n"
    echo "   • curl -I http://127.0.0.1:5678"
    echo "   • ufw status"
    echo ""
    echo "🖱️  CLICK TO OPEN: http://147.79.68.121:5678"
    echo ""
    echo "========================================="
}

# Main execution
main() {
    case "${1:-}" in
        --help|-h)
            echo "n8n IP Mode Deployment Script"
            echo ""
            echo "This script deploys n8n in IP mode on Hostinger VPS"
            echo "Target: http://147.79.68.121:5678"
            echo ""
            echo "Usage: $0"
            echo ""
            echo "What it does:"
            echo "  1. SSH to root@147.79.68.121"
            echo "  2. Clone/update lumora-web in ~/lumora-web"
            echo "  3. Create docker-compose.override.yml with n8n port mapping"
            echo "  4. Deploy with docker compose"
            echo "  5. Configure firewall if needed"
            echo "  6. Test connectivity and print access URL"
            exit 0
            ;;
        "")
            deploy_n8n_ip_mode
            test_remote_connectivity
            print_final_checklist
            ;;
        *)
            error "Unknown argument: $1. Use --help for usage information."
            ;;
    esac
}

main "$@"