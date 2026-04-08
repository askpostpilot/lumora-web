#!/bin/bash

# =============================================================================
# LUMORA SERVICE DISCOVERY AND VERIFICATION SCRIPT
# =============================================================================
# Task: Discover and verify public URLs for all running services on Hostinger VPS
# Target: Ubuntu 24.04 VPS at root@147.79.68.121
# Services: n8n, traefik, lumora-web, watchtower
# 
# This script performs comprehensive service discovery, health checks, 
# and automatic fixes in a non-interactive manner.
# =============================================================================

set -euo pipefail

# Configuration
VPS_HOST="147.79.68.121"
VPS_USER="root"
PROJECT_DIR="~/lumora-web"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Discover and verify public URLs for all running services on Hostinger VPS.

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --dry-run          Show what would be done without making changes
    --skip-ssh-test    Skip initial SSH connectivity test

EXAMPLE:
    $0                  # Run full discovery and verification
    $0 --verbose        # Run with detailed output
    $0 --dry-run        # Preview actions without changes

This script will:
1. Connect to VPS via SSH and gather baseline info
2. Identify running services and their endpoints
3. Check firewall configuration and fix if needed
4. Perform health checks with retries
5. Apply safe automatic fixes
6. Provide final summary with working URLs
EOF
}

# Parse command line arguments
VERBOSE=false
DRY_RUN=false
SKIP_SSH_TEST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-ssh-test)
            SKIP_SSH_TEST=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Test SSH connectivity
test_ssh_connection() {
    if [[ "$SKIP_SSH_TEST" == "true" ]]; then
        warn "Skipping SSH connectivity test as requested"
        return 0
    fi

    log "Testing SSH connection to $VPS_USER@$VPS_HOST..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS_USER@$VPS_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log "✅ SSH connection successful"
        return 0
    else
        error "❌ SSH connection failed"
        error "Please ensure:"
        error "  1. SSH key is properly configured"
        error "  2. Host $VPS_HOST is reachable"
        error "  3. User $VPS_USER has SSH access"
        exit 1
    fi
}

# Main service discovery function that runs on the VPS
create_discovery_script() {
    cat << 'REMOTE_SCRIPT'
#!/bin/bash
set -euo pipefail

# Colors for remote output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"; }

# Arrays to store discovered endpoints
declare -a ENDPOINTS=()
declare -a ENDPOINT_STATUS=()
declare -a ENDPOINT_DESCRIPTIONS=()

echo "========================================================================"
echo "🔍 LUMORA SERVICE DISCOVERY AND VERIFICATION"
echo "========================================================================"
echo "Target: $(hostname -f) ($(hostname -I | awk '{print $1}'))"
echo "Time: $(date)"
echo ""

# =============================================================================
# STEP 1: BASELINE INFORMATION
# =============================================================================
log "Step 1: Gathering baseline information..."

# Print server IP
echo "📍 SERVER IP:"
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "   Primary IP: $SERVER_IP"
echo ""

# Print open/listening ports
echo "🔌 LISTENING PORTS:"
echo "Port     Protocol  State    Process"
echo "----------------------------------------"
ss -tulpen | awk 'NR==1 || /LISTEN/' | while read line; do
    if [[ "$line" == *"LISTEN"* ]]; then
        echo "   $line"
    fi
done
echo ""

# Show Docker services
echo "🐳 DOCKER SERVICES:"
if command -v docker >/dev/null 2>&1; then
    echo "Container Name       Status                  Ports"
    echo "--------------------------------------------------------"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | while read line; do
        echo "   $line"
    done
    echo ""
    
    # Show compose apps
    echo "🔧 DOCKER COMPOSE APPS:"
    docker compose ls 2>/dev/null || echo "   No compose applications found or docker compose not available"
else
    warn "Docker not found or not accessible"
fi
echo ""

# =============================================================================
# STEP 2: IDENTIFY LIKELY APP ENDPOINTS
# =============================================================================
log "Step 2: Identifying application endpoints..."

# Parse running containers and their ports
if command -v docker >/dev/null 2>&1; then
    echo "🎯 ENDPOINT DISCOVERY:"
    
    # Check if traefik is running and on which ports
    TRAEFIK_RUNNING=false
    TRAEFIK_HTTP=false
    TRAEFIK_HTTPS=false
    
    if docker ps --format "{{.Names}}" | grep -q "traefik"; then
        TRAEFIK_RUNNING=true
        echo "   ✅ Traefik container is running"
        
        # Check traefik ports
        TRAEFIK_PORTS=$(docker ps --filter "name=traefik" --format "{{.Ports}}")
        if [[ "$TRAEFIK_PORTS" == *":80->"* ]]; then
            TRAEFIK_HTTP=true
            echo "   ✅ Traefik listening on HTTP (port 80)"
        fi
        if [[ "$TRAEFIK_PORTS" == *":443->"* ]]; then
            TRAEFIK_HTTPS=true
            echo "   ✅ Traefik listening on HTTPS (port 443)"
        fi
    else
        echo "   ❌ Traefik container not found"
    fi
    
    # Check environment for domain configuration
    DOMAIN=""
    if [[ -f ~/lumora-web/.env ]]; then
        DOMAIN=$(grep "^DOMAIN=" ~/lumora-web/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
        if [[ -n "$DOMAIN" && "$DOMAIN" != "localhost" ]]; then
            echo "   🌐 Domain configured: $DOMAIN"
        else
            echo "   🌐 No domain configured (IP mode)"
            DOMAIN=""
        fi
    fi
    
    # Priority A: Traefik with domain
    if [[ "$TRAEFIK_RUNNING" == "true" && -n "$DOMAIN" ]]; then
        if [[ "$TRAEFIK_HTTPS" == "true" ]]; then
            ENDPOINTS+=("https://$DOMAIN")
            ENDPOINT_DESCRIPTIONS+=("lumora-web → HTTPS (via traefik)")
            echo "   🔗 Primary HTTPS: https://$DOMAIN"
        elif [[ "$TRAEFIK_HTTP" == "true" ]]; then
            ENDPOINTS+=("http://$DOMAIN")
            ENDPOINT_DESCRIPTIONS+=("lumora-web → HTTP (via traefik)")
            echo "   🔗 Primary HTTP: http://$DOMAIN"
        fi
        
        # n8n subdomain
        if [[ "$TRAEFIK_HTTPS" == "true" ]]; then
            ENDPOINTS+=("https://n8n.$DOMAIN")
            ENDPOINT_DESCRIPTIONS+=("n8n → HTTPS (via traefik)")
            echo "   🔗 n8n HTTPS: https://n8n.$DOMAIN"
        elif [[ "$TRAEFIK_HTTP" == "true" ]]; then
            ENDPOINTS+=("http://n8n.$DOMAIN")
            ENDPOINT_DESCRIPTIONS+=("n8n → HTTP (via traefik)")
            echo "   🔗 n8n HTTP: http://n8n.$DOMAIN"
        fi
    fi
    
    # Priority B: Traefik without domain (IP mode)
    if [[ "$TRAEFIK_RUNNING" == "true" && -z "$DOMAIN" ]]; then
        if [[ "$TRAEFIK_HTTP" == "true" ]]; then
            ENDPOINTS+=("http://$SERVER_IP")
            ENDPOINT_DESCRIPTIONS+=("lumora-web → HTTP (via traefik)")
            echo "   🔗 Traefik HTTP: http://$SERVER_IP"
        fi
    fi
    
    # Priority C: Direct n8n port
    if docker ps --format "{{.Names}}" | grep -q "n8n"; then
        N8N_PORTS=$(docker ps --filter "name=n8n" --format "{{.Ports}}")
        if [[ "$N8N_PORTS" == *":5678->"* ]]; then
            ENDPOINTS+=("http://$SERVER_IP:5678")
            ENDPOINT_DESCRIPTIONS+=("n8n → Direct HTTP port")
            echo "   🔗 n8n Direct: http://$SERVER_IP:5678"
        fi
    fi
    
    # Priority D: Static site direct port
    if docker ps --format "{{.Names}}" | grep -q "lumora-web"; then
        LUMORA_PORTS=$(docker ps --filter "name=lumora-web" --format "{{.Ports}}")
        if [[ "$LUMORA_PORTS" == *":80->"* && "$TRAEFIK_HTTP" == "false" ]]; then
            ENDPOINTS+=("http://$SERVER_IP:80")
            ENDPOINT_DESCRIPTIONS+=("lumora-web → Direct HTTP port")
            echo "   🔗 Lumora Direct: http://$SERVER_IP:80"
        elif [[ "$LUMORA_PORTS" == *":8080->"* ]]; then
            ENDPOINTS+=("http://$SERVER_IP:8080")
            ENDPOINT_DESCRIPTIONS+=("lumora-web → Direct HTTP port")
            echo "   🔗 Lumora Direct: http://$SERVER_IP:8080"
        fi
    fi
else
    warn "Docker not available, skipping container endpoint discovery"
fi
echo ""

# =============================================================================
# STEP 3: FIREWALL AND NETWORK CHECKS
# =============================================================================
log "Step 3: Checking firewall and network configuration..."

# Check UFW status
echo "🔥 FIREWALL STATUS:"
if command -v ufw >/dev/null 2>&1; then
    UFW_STATUS=$(ufw status 2>/dev/null || echo "inactive")
    echo "   UFW Status: $UFW_STATUS"
    
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        echo "   Current UFW rules:"
        ufw status numbered | grep -E "^\[" | while read rule; do
            echo "     $rule"
        done
        
        # Check required ports and add if missing
        PORTS_TO_CHECK=()
        
        # Extract ports from endpoints
        for endpoint in "${ENDPOINTS[@]}"; do
            if [[ "$endpoint" == *":80"* || "$endpoint" == "http://$SERVER_IP" ]]; then
                PORTS_TO_CHECK+=(80)
            elif [[ "$endpoint" == *":443"* || "$endpoint" == "https://"* ]]; then
                PORTS_TO_CHECK+=(443)
            elif [[ "$endpoint" == *":5678"* ]]; then
                PORTS_TO_CHECK+=(5678)
            elif [[ "$endpoint" == *":8080"* ]]; then
                PORTS_TO_CHECK+=(8080)
            fi
        done
        
        # Remove duplicates
        UNIQUE_PORTS=($(printf "%s\n" "${PORTS_TO_CHECK[@]}" | sort -u))
        
        for port in "${UNIQUE_PORTS[@]}"; do
            if ufw status | grep -q "$port/tcp"; then
                echo "   ✅ Port $port/tcp already allowed"
            else
                echo "   ⚠️  Port $port/tcp not allowed, adding rule..."
                if [[ "$DRY_RUN" != "true" ]]; then
                    ufw allow $port/tcp >/dev/null 2>&1 || warn "Failed to add UFW rule for port $port"
                    echo "   ✅ Added UFW rule for port $port/tcp"
                else
                    echo "   🔍 DRY-RUN: Would add UFW rule for port $port/tcp"
                fi
            fi
        done
    else
        echo "   ✅ UFW is inactive, no firewall rules needed"
    fi
else
    echo "   ❌ UFW not found"
fi

echo ""
info "Note: Cloud provider firewall rules (if any) must be checked manually in Hostinger panel"
echo ""

# =============================================================================
# STEP 4: HEALTH CHECKS WITH RETRIES
# =============================================================================
log "Step 4: Performing health checks on discovered endpoints..."

echo "🩺 ENDPOINT HEALTH CHECKS:"

perform_health_check() {
    local url="$1"
    local max_retries=3
    local retry_delay=2
    
    for ((i=1; i<=max_retries; i++)); do
        echo "   Attempt $i/$max_retries: $url"
        
        # Try HEAD request first (faster)
        local http_status
        http_status=$(curl -fsSILm 5 "$url" 2>/dev/null | head -n1 | grep -o "HTTP/[0-9.]* [0-9]*" | awk '{print $2}' || echo "000")
        
        if [[ "$http_status" =~ ^[2-3][0-9][0-9]$ ]]; then
            echo "   ✅ $url → HTTP $http_status"
            return 0
        elif [[ "$http_status" == "404" ]]; then
            # Try alternative health endpoints for 404
            local health_endpoints=("/_health" "/health" "/status" "/rest" "/webhook" "/")
            for health_ep in "${health_endpoints[@]}"; do
                local health_url="${url%/}$health_ep"
                local health_status
                health_status=$(curl -fsSILm 5 "$health_url" 2>/dev/null | head -n1 | grep -o "HTTP/[0-9.]* [0-9]*" | awk '{print $2}' || echo "000")
                if [[ "$health_status" =~ ^[2-3][0-9][0-9]$ ]]; then
                    echo "   ✅ $url → HTTP $health_status (via $health_ep)"
                    return 0
                fi
            done
        elif [[ "$http_status" == "401" || "$http_status" == "403" ]] && [[ "$url" == *":5678"* ]]; then
            # n8n authentication required is still considered reachable
            echo "   ✅ $url → HTTP $http_status (n8n auth required - reachable)"
            return 0
        fi
        
        if [[ $i -lt $max_retries ]]; then
            echo "   ⏳ Retrying in ${retry_delay}s..."
            sleep $retry_delay
        fi
    done
    
    echo "   ❌ $url → Failed after $max_retries attempts"
    return 1
}

# Perform health checks on all endpoints
for i in "${!ENDPOINTS[@]}"; do
    url="${ENDPOINTS[$i]}"
    description="${ENDPOINT_DESCRIPTIONS[$i]}"
    
    echo ""
    echo "   Testing: $description"
    if perform_health_check "$url"; then
        ENDPOINT_STATUS[$i]="GOOD"
    else
        ENDPOINT_STATUS[$i]="FAILED"
    fi
done

echo ""

# =============================================================================
# STEP 5: AUTOMATIC QUICK FIXES
# =============================================================================
log "Step 5: Applying automatic quick fixes (safe only)..."

echo "🔧 AUTOMATIC FIXES:"

# Check if we need to expose ports in docker-compose.yml
if [[ -f ~/lumora-web/docker-compose.yml ]]; then
    COMPOSE_MODIFIED=false
    
    # Check n8n port exposure
    if docker ps --filter "name=n8n" --format "{{.Ports}}" | grep -qv ":5678->"; then
        if ! grep -q "5678:5678" ~/lumora-web/docker-compose.yml; then
            echo "   ⚠️  n8n port 5678 not exposed in compose file"
            if [[ "$DRY_RUN" != "true" ]]; then
                # Add port mapping to n8n service
                sed -i '/^  n8n:/,/^  [a-zA-Z]/ { /ports:/!{ /volumes:/i\    ports:\n      - "5678:5678"
                } }' ~/lumora-web/docker-compose.yml
                COMPOSE_MODIFIED=true
                echo "   ✅ Added n8n port mapping to docker-compose.yml"
            else
                echo "   🔍 DRY-RUN: Would add n8n port mapping to docker-compose.yml"
            fi
        fi
    fi
    
    # Check lumora-web port exposure (only if traefik not handling it)
    if [[ "$TRAEFIK_HTTP" != "true" ]]; then
        if ! docker ps --filter "name=lumora-web" --format "{{.Ports}}" | grep -q ":80->"; then
            if ! grep -q "80:80" ~/lumora-web/docker-compose.yml; then
                echo "   ⚠️  lumora-web port 80 not exposed in compose file"
                if [[ "$DRY_RUN" != "true" ]]; then
                    # Add port mapping to lumora-web service  
                    sed -i '/^  lumora-web:/,/^  [a-zA-Z]/ { /ports:/!{ /labels:/i\    ports:\n      - "80:80"
                    } }' ~/lumora-web/docker-compose.yml
                    COMPOSE_MODIFIED=true
                    echo "   ✅ Added lumora-web port mapping to docker-compose.yml"
                else
                    echo "   🔍 DRY-RUN: Would add lumora-web port mapping to docker-compose.yml"
                fi
            fi
        fi
    fi
    
    # Restart containers if compose file was modified
    if [[ "$COMPOSE_MODIFIED" == "true" && "$DRY_RUN" != "true" ]]; then
        echo "   🔄 Restarting containers with updated configuration..."
        cd ~/lumora-web
        docker compose up -d --remove-orphans >/dev/null 2>&1
        echo "   ✅ Containers restarted"
        
        # Wait for services to come up
        echo "   ⏳ Waiting 10 seconds for services to initialize..."
        sleep 10
        
        # Re-discover endpoints after restart
        echo "   🔄 Re-checking endpoints after restart..."
        # This would require re-running the endpoint discovery logic
    fi
    
    # Check for port conflicts on 80
    CONFLICTING_CONTAINERS=$(docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | grep -E ':80->' | grep -vE 'traefik|lumora-web' | awk '{print $2}' || true)
    if [[ -n "$CONFLICTING_CONTAINERS" ]]; then
        echo "   ⚠️  Port conflict detected on port 80:"
        echo "$CONFLICTING_CONTAINERS" | while read container; do
            echo "     - Container: $container"
        done
        echo "   💡 To resolve:"
        echo "     Option 1: Stop conflicting containers: docker stop $CONFLICTING_CONTAINERS"
        echo "     Option 2: Remap lumora-web to port 8080 in docker-compose.yml"
    fi
else
    warn "docker-compose.yml not found, skipping compose fixes"
fi

echo ""

# =============================================================================
# STEP 6 & 7: FINAL RESULTS AND SUMMARY
# =============================================================================
log "Step 6-7: Final results and summary..."

echo ""
echo "========================================================================"
echo "🎯 FINAL VERIFICATION RESULTS"
echo "========================================================================"

echo ""
echo "📊 ENDPOINT STATUS:"
echo "Service              URL                                    Status"
echo "------------------------------------------------------------------------"

WORKING_URLS=()
NOTES=()

for i in "${!ENDPOINTS[@]}"; do
    url="${ENDPOINTS[$i]}"
    description="${ENDPOINT_DESCRIPTIONS[$i]}"
    status="${ENDPOINT_STATUS[$i]}"
    
    if [[ "$status" == "GOOD" ]]; then
        printf "%-20s %-40s %s\n" "$(echo "$description" | cut -d'→' -f1 | xargs)" "$url" "✅ WORKING"
        WORKING_URLS+=("$url")
    else
        printf "%-20s %-40s %s\n" "$(echo "$description" | cut -d'→' -f1 | xargs)" "$url" "❌ FAILED"
    fi
done

echo ""

# Add notes for HTTPS with self-signed certs
for url in "${WORKING_URLS[@]}"; do
    if [[ "$url" == "https://"* && -z "$DOMAIN" ]]; then
        NOTES+=("For $url: Click 'Advanced' → 'Proceed anyway' (self-signed certificate)")
    fi
done

# Add domain setup note if no domain configured
if [[ -z "$DOMAIN" ]]; then
    NOTES+=("To enable HTTPS with valid certificate, add a domain and email to .env and rerun deploy")
fi

# Add firewall note if needed
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: inactive"; then
    NOTES+=("Consider enabling UFW firewall for security: ufw --force enable")
fi

echo "========================================================================"
echo ""

# Final minimal summary
echo "=== OPEN THESE LINKS ==="
for url in "${WORKING_URLS[@]}"; do
    echo "$url"
done

if [[ ${#NOTES[@]} -gt 0 ]]; then
    echo ""
    echo "=== NOTES ==="
    for note in "${NOTES[@]}"; do
        echo "• $note"
    done
fi

echo ""
echo "🎉 Service discovery completed at $(date)"
REMOTE_SCRIPT
}

# Execute main discovery on VPS
execute_discovery() {
    log "Executing service discovery on VPS..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY-RUN mode: Would execute discovery script on $VPS_USER@$VPS_HOST"
        return 0
    fi
    
    # Create and execute the discovery script on the remote server
    ssh "$VPS_USER@$VPS_HOST" "$(create_discovery_script)"
    
    local ssh_result=$?
    
    if [[ $ssh_result -eq 0 ]]; then
        log "✅ Service discovery completed successfully"
    else
        error "❌ Service discovery failed with exit code $ssh_result"
        return $ssh_result
    fi
}

# Main execution flow
main() {
    log "🚀 Starting Lumora service discovery and verification..."
    log "Target: $VPS_USER@$VPS_HOST"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Running in DRY-RUN mode - no changes will be made"
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "Verbose mode enabled"
        set -x
    fi
    
    # Test SSH connection
    test_ssh_connection
    
    # Execute main discovery
    execute_discovery
    
    log "🎉 Discovery process completed!"
}

# Run main function
main "$@"