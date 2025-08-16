#!/bin/bash

# Test script for deploy-n8n-vps-exact.sh
# Validates that the script contains the exact steps specified in requirements

set -uo pipefail

SCRIPT_PATH="/home/runner/work/lumora-web/lumora-web/deploy-n8n-vps-exact.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test 1: Script exists and is executable
test_script_exists() {
    log "Testing: Script exists and is executable"
    
    if [ -f "$SCRIPT_PATH" ] && [ -x "$SCRIPT_PATH" ]; then
        echo "✅ Script exists and is executable"
        return 0
    else
        echo "❌ Script missing or not executable"
        return 1
    fi
}

# Test 2: Script syntax is valid
test_script_syntax() {
    log "Testing: Script syntax validation"
    
    if bash -n "$SCRIPT_PATH"; then
        echo "✅ Script syntax is valid"
        return 0
    else
        echo "❌ Script has syntax errors"
        return 1
    fi
}

# Test 3: Contains exact required commands
test_exact_commands() {
    log "Testing: Script contains exact required commands"
    
    local required_commands=(
        'docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"'
        'docker compose -f ~/lumora-web/docker-compose.yml up -d'
        'ufw status.*grep -qi active'
        'ufw allow 5678/tcp'
        'ss -tulpen.*awk.*NR==1.*LISTEN'
        'curl -fsSILm 5 http://127.0.0.1:5678'
        'curl -fsm 5 http://127.0.0.1:5678.*head -n 5'
        'hostname -I.*awk.*print.*1'
    )
    
    local found=0
    local total=${#required_commands[@]}
    
    for cmd in "${required_commands[@]}"; do
        if grep -q "$cmd" "$SCRIPT_PATH"; then
            echo "✅ Found required command: $cmd"
            ((found++))
        else
            echo "❌ Missing required command: $cmd"
        fi
    done
    
    echo "Commands found: $found/$total"
    
    if [ $found -eq $total ]; then
        echo "✅ All required commands present"
        return 0
    else
        echo "❌ Some required commands missing"
        return 1
    fi
}

# Test 4: Contains 5 steps structure
test_steps_structure() {
    log "Testing: Script follows 5-step structure"
    
    local steps=(
        "Step 1.*Docker services and port mappings"
        "Step 2.*Check and configure n8n port mapping"
        "Step 3.*Firewall configuration"
        "Step 4.*n8n health check"
        "Step 5.*Final access URL"
    )
    
    local found=0
    local total=${#steps[@]}
    
    for step in "${steps[@]}"; do
        if grep -q "$step" "$SCRIPT_PATH"; then
            echo "✅ Found step: $step"
            ((found++))
        else
            echo "❌ Missing step: $step"
        fi
    done
    
    echo "Steps found: $found/$total"
    
    if [ $found -eq $total ]; then
        echo "✅ All 5 steps present"
        return 0
    else
        echo "❌ Some steps missing"
        return 1
    fi
}

# Test 5: Contains specific output format
test_output_format() {
    log "Testing: Script contains required output format"
    
    local outputs=(
        "OPEN THIS.*hostname -I"
        "VPS_HOST.*147.79.68.121"
        "VPS_USER.*root"
    )
    
    local found=0
    local total=${#outputs[@]}
    
    for output in "${outputs[@]}"; do
        if grep -q "$output" "$SCRIPT_PATH"; then
            echo "✅ Found required output: $output"
            ((found++))
        else
            echo "❌ Missing required output: $output"
        fi
    done
    
    echo "Outputs found: $found/$total"
    
    if [ $found -eq $total ]; then
        echo "✅ All required outputs present"
        return 0
    else
        echo "❌ Some required outputs missing"
        return 1
    fi
}

# Run all tests
main() {
    echo "========================================="
    echo "🧪 TESTING DEPLOY-N8N-VPS-EXACT.SH"
    echo "========================================="
    echo ""
    
    local tests=(
        "test_script_exists"
        "test_script_syntax"
        "test_exact_commands"
        "test_steps_structure"
        "test_output_format"
    )
    
    local passed=0
    local total=${#tests[@]}
    
    for test in "${tests[@]}"; do
        echo ""
        if $test; then
            ((passed++))
        fi
    done
    
    echo ""
    echo "========================================="
    echo "📊 TEST RESULTS: $passed/$total tests passed"
    echo "========================================="
    
    if [ $passed -eq $total ]; then
        echo ""
        log "🎉 All tests passed! Script follows exact requirements."
        echo ""
        echo "📋 NEXT STEPS:"
        echo "   1. Ensure SSH access to root@147.79.68.121 is configured"
        echo "   2. Run: ./deploy-n8n-vps-exact.sh"
        echo "   3. Access n8n at: http://147.79.68.121:5678"
        return 0
    else
        echo ""
        error "❌ Some tests failed. Please review the script."
        return 1
    fi
}

main "$@"