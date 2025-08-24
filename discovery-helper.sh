#!/bin/bash

# =============================================================================
# COMPREHENSIVE VPS SERVICE DISCOVERY - INTEGRATION HELPER
# =============================================================================
# This script provides integration helpers for the discover-services.sh script
# and can be run before/after deployment to verify service accessibility.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISCOVERY_SCRIPT="$SCRIPT_DIR/discover-services.sh"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"; }

show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Integration helper for VPS service discovery and verification.

COMMANDS:
    discover        Run full service discovery (default)
    quick-check     Quick health check of known endpoints
    pre-deploy      Pre-deployment verification
    post-deploy     Post-deployment verification
    debug           Debug mode with verbose output
    help            Show this help message

OPTIONS:
    --dry-run       Preview actions without making changes
    --verbose       Enable verbose output
    --force         Force execution even if checks fail

EXAMPLES:
    $0                          # Run full discovery
    $0 quick-check              # Quick endpoint verification
    $0 post-deploy --verbose    # Detailed post-deployment check
    $0 debug                    # Debug with full verbosity

This helper integrates with existing deployment scripts and provides
comprehensive service discovery for the Hostinger VPS environment.
EOF
}

# Quick health check of common endpoints
quick_check() {
    log "Performing quick health check..."
    
    local endpoints=(
        "http://147.79.68.121"
        "http://147.79.68.121:5678"
        "https://147.79.68.121"
    )
    
    echo "🩺 Quick Health Check Results:"
    echo "================================"
    
    for endpoint in "${endpoints[@]}"; do
        echo -n "Testing $endpoint ... "
        if timeout 5 curl -fsSL "$endpoint" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ WORKING${NC}"
        else
            echo -e "${RED}❌ FAILED${NC}"
        fi
    done
    
    echo ""
    log "Quick check completed"
}

# Pre-deployment verification
pre_deploy_check() {
    log "Running pre-deployment verification..."
    
    echo "🔍 Pre-deployment Checklist:"
    echo "=========================="
    
    # Check if SSH key is configured
    echo -n "SSH key access to VPS ... "
    if ssh -o ConnectTimeout=5 -o BatchMode=yes root@147.79.68.121 "echo 'SSH OK'" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ CONFIGURED${NC}"
    else
        echo -e "${YELLOW}⚠️  NEEDS SETUP${NC}"
        warn "SSH key access not configured. You may need to:"
        warn "  1. Add your SSH public key to the VPS"
        warn "  2. Ensure SSH agent is running locally"
    fi
    
    # Check required tools
    local tools=("ssh" "curl" "docker")
    for tool in "${tools[@]}"; do
        echo -n "Tool: $tool ... "
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ AVAILABLE${NC}"
        else
            echo -e "${RED}❌ MISSING${NC}"
        fi
    done
    
    # Check discovery script
    echo -n "Discovery script ... "
    if [[ -f "$DISCOVERY_SCRIPT" && -x "$DISCOVERY_SCRIPT" ]]; then
        echo -e "${GREEN}✅ READY${NC}"
    else
        echo -e "${RED}❌ MISSING${NC}"
        error "Discovery script not found or not executable"
        return 1
    fi
    
    echo ""
    log "Pre-deployment check completed"
}

# Post-deployment verification
post_deploy_check() {
    log "Running post-deployment verification..."
    
    echo "🎯 Post-deployment Verification:"
    echo "==============================="
    
    # Run full discovery
    if [[ -f "$DISCOVERY_SCRIPT" ]]; then
        "$DISCOVERY_SCRIPT" "${OPTIONS[@]}"
    else
        error "Discovery script not found"
        return 1
    fi
    
    log "Post-deployment verification completed"
}

# Debug mode with maximum verbosity
debug_mode() {
    log "Running in debug mode..."
    
    echo "🐛 Debug Information:"
    echo "==================="
    
    echo "Environment:"
    echo "  Script directory: $SCRIPT_DIR"
    echo "  Discovery script: $DISCOVERY_SCRIPT"
    echo "  Working directory: $(pwd)"
    echo "  User: $(whoami)"
    echo "  Date: $(date)"
    echo ""
    
    echo "Available tools:"
    for tool in ssh curl docker git; do
        echo -n "  $tool: "
        if command -v "$tool" >/dev/null 2>&1; then
            echo "$(which "$tool") ($(command "$tool" --version 2>/dev/null | head -n1 || echo 'version unknown'))"
        else
            echo "not found"
        fi
    done
    echo ""
    
    echo "SSH configuration test:"
    ssh -vvv -o ConnectTimeout=10 root@147.79.68.121 "echo 'Debug SSH test successful'" 2>&1 | head -20
    echo ""
    
    # Run discovery with maximum verbosity
    OPTIONS+=(--verbose)
    "$DISCOVERY_SCRIPT" "${OPTIONS[@]}"
}

# Parse command line arguments
COMMAND="discover"
OPTIONS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        discover|quick-check|pre-deploy|post-deploy|debug|help)
            COMMAND="$1"
            shift
            ;;
        --dry-run|--verbose|--force|--skip-ssh-test)
            OPTIONS+=("$1")
            shift
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute the requested command
case "$COMMAND" in
    "help")
        show_usage
        ;;
    "quick-check")
        quick_check
        ;;
    "pre-deploy")
        pre_deploy_check
        ;;
    "post-deploy")
        post_deploy_check
        ;;
    "debug")
        debug_mode
        ;;
    "discover")
        if [[ -f "$DISCOVERY_SCRIPT" ]]; then
            "$DISCOVERY_SCRIPT" "${OPTIONS[@]}"
        else
            error "Discovery script not found at $DISCOVERY_SCRIPT"
            exit 1
        fi
        ;;
    *)
        error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac