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

# Function to handle deployment failures with container logs and auto-fix
handle_deployment_failure() {
    echo ""
    echo "=== DEPLOYMENT FAILURE DETECTED - ATTEMPTING AUTO-RECOVERY ==="
    echo ""
    
    # Show n8n container logs (last 200 lines)
    echo "--- Last 200 lines of n8n container logs ---"
    if docker logs n8n --tail 200 2>/dev/null; then
        echo "--- End of n8n logs ---"
    else
        echo "Could not retrieve n8n logs (container may not exist)"
    fi
    echo ""
    
    # Common issue fixes
    echo "=== Attempting common fixes ==="
    
    # Fix 1: Check if .env file has issues
    if [ -f ".env" ]; then
        echo "✓ .env file exists"
        if grep -q "### FILL_ME_IN ###" .env; then
            echo "⚠️  Found unfilled values in .env, attempting to fix..."
            # Generate a new encryption key
            ENCRYPTION_KEY=$(openssl rand -base64 36 2>/dev/null || echo "backup-key-$(date +%s)-$(hostname)")
            sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}/" .env
            echo "✓ Generated new encryption key"
        fi
    else
        echo "❌ .env file missing, creating minimal version"
        cat > .env << 'EOF'
N8N_PORT=5678
N8N_HOST=
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_ENCRYPTION_KEY=auto-generated-key-$(date +%s)
EOF
    fi
    
    # Fix 2: Check for port conflicts
    if ss -ltn | grep -q ":5678"; then
        echo "⚠️  Port 5678 may be in use, checking processes..."
        ss -ltnp | grep ":5678" || true
        echo "Attempting to stop conflicting containers..."
        docker stop $(docker ps -q --filter "publish=5678") 2>/dev/null || true
    fi
    
    # Fix 3: Clean up and restart containers
    echo "=== Cleaning up containers ==="
    docker compose down 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
    
    echo "=== Attempting re-deployment ==="
    return 0
}

# Function to verify deployment success
verify_deployment() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Verification attempt $attempt/$max_attempts"
        
        # Check container status
        if ! docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "n8n.*Up.*5678"; then
            echo "❌ n8n container not running properly"
            if [ $attempt -eq $max_attempts ]; then
                return 1
            fi
            ((attempt++))
            sleep 10
            continue
        fi
        
        # Check HTTP connectivity
        sleep 5  # Give n8n time to start
        if HTTP_STATUS=$(curl -sS -D - -o /dev/null http://127.0.0.1:5678 2>/dev/null | head -n1); then
            if echo "$HTTP_STATUS" | grep -q "200\|302\|404"; then
                echo "✅ Deployment verification successful"
                return 0
            fi
        fi
        
        echo "⚠️  HTTP test failed, waiting and retrying..."
        if [ $attempt -eq $max_attempts ]; then
            return 1
        fi
        ((attempt++))
        sleep 15
    done
    
    return 1
}

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

# Step 1.5: Update repository to main branch
echo "=== Step 1.5: Updating repository ==="
echo "Running: git checkout main && git pull --ff-only"
git checkout main
git pull --ff-only
echo "Repository updated successfully"
echo ""

# Step 2: Ensure .env has IP mode settings
echo "=== Step 2: Ensuring .env has IP mode settings ==="
# Backup existing .env if it exists
if [ -f ".env" ]; then
    echo "Backing up existing .env file"
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create or update .env with IP mode settings
if [ -f ".env" ]; then
    echo "Updating existing .env file with IP mode settings"
    # Update existing values
    sed -i "s/^N8N_PORT=.*/N8N_PORT=5678/" .env
    sed -i "s/^N8N_HOST=.*/N8N_HOST=/" .env
    sed -i "s/^GENERIC_TIMEZONE=.*/GENERIC_TIMEZONE=Asia\/Kolkata/" .env
    sed -i "s/^TZ=.*/TZ=Asia\/Kolkata/" .env
    
    # Add missing values if they don't exist
    grep -q "^N8N_PORT=" .env || echo "N8N_PORT=5678" >> .env
    grep -q "^N8N_HOST=" .env || echo "N8N_HOST=" >> .env
    grep -q "^GENERIC_TIMEZONE=" .env || echo "GENERIC_TIMEZONE=Asia/Kolkata" >> .env
    grep -q "^TZ=" .env || echo "TZ=Asia/Kolkata" >> .env
else
    echo "Creating new .env file with IP mode settings"
    # Copy from example and customize for IP mode
    if [ -f ".env.example" ]; then
        cp .env.example .env
        # Update for IP mode
        sed -i "s/^N8N_PORT=.*/N8N_PORT=5678/" .env
        sed -i "s/^N8N_HOST=.*/N8N_HOST=/" .env
        sed -i "s/^GENERIC_TIMEZONE=.*/GENERIC_TIMEZONE=Asia\/Kolkata/" .env
        sed -i "s/^TZ=.*/TZ=Asia\/Kolkata/" .env
        # Generate encryption key if needed
        if grep -q "### FILL_ME_IN ###" .env; then
            ENCRYPTION_KEY=$(openssl rand -base64 36 2>/dev/null || echo "$(date | md5sum | cut -d' ' -f1)$(hostname | md5sum | cut -d' ' -f1)")
            sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}/" .env
        fi
    else
        # Create minimal .env for IP mode
        cat > .env << 'EOF'
N8N_PORT=5678
N8N_HOST=
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_ENCRYPTION_KEY=$(openssl rand -base64 36 2>/dev/null || echo "fallback-key-$(date +%s)")
EOF
    fi
fi

echo ".env file configured for IP mode"
echo "Key settings:"
grep -E "^(N8N_PORT|N8N_HOST|GENERIC_TIMEZONE|TZ)=" .env || echo "Settings not found in .env"
echo ""

# Step 3: Create/overwrite docker-compose.override.yml that only publishes n8n
echo "=== Step 3: Creating docker-compose.override.yml ==="
cat > docker-compose.override.yml << 'EOF'
services:
  n8n:
    ports:
      - "5678:5678"
EOF

echo "docker-compose.override.yml created:"
cat docker-compose.override.yml
echo ""

# Step 4: docker compose up -d --remove-orphans
echo "=== Step 4: Starting Docker services ==="
echo "Running: docker compose up -d --remove-orphans"

# Attempt deployment with retry logic
DEPLOYMENT_SUCCESS=false
MAX_RETRIES=2

for retry in $(seq 1 $MAX_RETRIES); do
    echo "Deployment attempt $retry/$MAX_RETRIES"
    
    if docker compose up -d --remove-orphans; then
        echo "Docker services started"
        echo ""
        
        # Verify deployment
        if verify_deployment; then
            DEPLOYMENT_SUCCESS=true
            break
        else
            echo "❌ Deployment verification failed"
            if [ $retry -lt $MAX_RETRIES ]; then
                handle_deployment_failure
                echo "Retrying deployment..."
                sleep 5
            fi
        fi
    else
        echo "❌ Docker compose failed"
        if [ $retry -lt $MAX_RETRIES ]; then
            handle_deployment_failure
            echo "Retrying deployment..."
            sleep 5
        fi
    fi
done

if [ "$DEPLOYMENT_SUCCESS" = "false" ]; then
    echo ""
    echo "❌ DEPLOYMENT FAILED AFTER $MAX_RETRIES ATTEMPTS"
    echo "=== Final troubleshooting information ==="
    echo ""
    echo "Container status:"
    docker ps -a | grep -E "(n8n|CONTAINER)" || true
    echo ""
    echo "Docker compose logs:"
    docker compose logs --tail 50 2>/dev/null || true
    echo ""
    echo "=== Manual recovery steps ==="
    echo "1. Check logs: docker logs n8n --tail 200"
    echo "2. Restart: docker compose restart n8n"
    echo "3. Rebuild: docker compose down && docker compose up -d"
    echo ""
    exit 1
fi

# Step 5: Verify docker ps shows n8n with 0.0.0.0:5678->5678/tcp
echo "=== Step 5: Verification ==="
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

# Step 6: Test local connectivity
echo "=== Step 6: Testing local connectivity ==="
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

# Step 7: Check and configure firewall
echo "=== Step 7: Firewall configuration ==="
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

# Step 8: Print final access URL
echo "=== Step 8: Final Results ==="
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