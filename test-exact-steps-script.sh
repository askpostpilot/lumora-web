#!/bin/bash

# Test script to verify deploy-n8n-exact-steps.sh contains all required exact steps

set -euo pipefail

SCRIPT_PATH="./deploy-n8n-exact-steps.sh"
TEST_DIR="/tmp/test-exact-steps"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    return 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo "========================================="
echo "🧪 TESTING EXACT STEPS DEPLOYMENT SCRIPT"
echo "========================================="
echo ""

# Test 1: Script contains exact command from step 1
test_step1_command() {
    log "Testing: Step 1 - docker ps command"
    
    if grep -q 'docker ps --format "table {{\.Names}}\\t{{\.Status}}\\t{{\.Ports}}"' "$SCRIPT_PATH"; then
        echo "✅ Step 1 command found: docker ps --format table"
        return 0
    else
        error "❌ Step 1 command missing or incorrect"
        return 1
    fi
}

# Test 2: Script mentions modifying docker-compose.yml
test_step2_dockerfile_mod() {
    log "Testing: Step 2 - docker-compose.yml modification"
    
    if grep -q "docker-compose.yml" "$SCRIPT_PATH" && grep -q '5678:5678' "$SCRIPT_PATH"; then
        echo "✅ Step 2 docker-compose.yml modification found"
        return 0
    else
        error "❌ Step 2 docker-compose.yml modification missing"
        return 1
    fi
}

# Test 3: Script contains exact ufw command from step 3
test_step3_firewall() {
    log "Testing: Step 3 - firewall commands"
    
    if grep -q "ufw status.*grep -qi active" "$SCRIPT_PATH" && grep -q "ufw allow 5678/tcp" "$SCRIPT_PATH"; then
        echo "✅ Step 3 UFW firewall commands found"
    else
        error "❌ Step 3 UFW commands missing"
        return 1
    fi
    
    if grep -q "ss -tulpen.*awk.*LISTEN" "$SCRIPT_PATH"; then
        echo "✅ Step 3 ss listening ports command found"
        return 0
    else
        error "❌ Step 3 ss command missing"
        return 1
    fi
}

# Test 4: Script contains exact curl commands from step 4
test_step4_health_check() {
    log "Testing: Step 4 - health check curl commands"
    
    if grep -q "curl -fsSILm 5 http://127.0.0.1:5678" "$SCRIPT_PATH"; then
        echo "✅ Step 4 curl headers command found"
    else
        error "❌ Step 4 curl headers command missing"
        return 1
    fi
    
    if grep -q "curl -fsm 5 http://127.0.0.1:5678.*head -n 5" "$SCRIPT_PATH"; then
        echo "✅ Step 4 curl content command found"
        return 0
    else
        error "❌ Step 4 curl content command missing"
        return 1
    fi
}

# Test 5: Script contains exact final echo command from step 5
test_step5_final_link() {
    log "Testing: Step 5 - final link echo command"
    
    if grep -q 'echo "OPEN THIS: http://\$(hostname -I | awk' "$SCRIPT_PATH"; then
        echo "✅ Step 5 final link command found"
        return 0
    else
        error "❌ Step 5 final link command missing or incorrect"
        return 1
    fi
}

# Test 6: Script has executable permissions
test_executable() {
    log "Testing: Script executable permissions"
    
    if [ -x "$SCRIPT_PATH" ]; then
        echo "✅ Script is executable"
        return 0
    else
        error "❌ Script is not executable"
        return 1
    fi
}

# Test 7: Script syntax is valid
test_syntax() {
    log "Testing: Script syntax validation"
    
    if bash -n "$SCRIPT_PATH" 2>/dev/null; then
        echo "✅ Script syntax is valid"
        return 0
    else
        error "❌ Script has syntax errors"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    local tests_passed=0
    local total_tests=7
    
    if test_step1_command; then tests_passed=$((tests_passed + 1)); fi
    if test_step2_dockerfile_mod; then tests_passed=$((tests_passed + 1)); fi
    if test_step3_firewall; then tests_passed=$((tests_passed + 1)); fi
    if test_step4_health_check; then tests_passed=$((tests_passed + 1)); fi
    if test_step5_final_link; then tests_passed=$((tests_passed + 1)); fi
    if test_executable; then tests_passed=$((tests_passed + 1)); fi
    if test_syntax; then tests_passed=$((tests_passed + 1)); fi
    
    echo ""
    echo "========================================="
    echo "📊 TEST RESULTS: $tests_passed/$total_tests tests passed"
    echo "========================================="
    
    if [ $tests_passed -eq $total_tests ]; then
        echo ""
        log "🎉 All tests passed! Script implements exact steps correctly."
        echo ""
        echo "📋 VERIFIED IMPLEMENTATION:"
        echo "   ✅ Step 1: docker ps table format command"
        echo "   ✅ Step 2: docker-compose.yml modification with 5678:5678"
        echo "   ✅ Step 3: UFW firewall and ss listening ports commands"
        echo "   ✅ Step 4: Exact curl health check commands"
        echo "   ✅ Step 5: Dynamic IP final link command"
        echo "   ✅ Script is executable and syntactically correct"
        return 0
    else
        error "❌ Some tests failed. Please review the script implementation."
        return 1
    fi
}

# Main execution
main() {
    if [ ! -f "$SCRIPT_PATH" ]; then
        error "Script not found: $SCRIPT_PATH"
        exit 1
    fi
    
    run_all_tests
}

main "$@"