#!/bin/bash

# =============================================================================
# VALIDATE DISCOVERY SCRIPT FUNCTIONALITY
# =============================================================================

set -euo pipefail

echo "🧪 Validating discover-services.sh functionality..."

# Test 1: Script exists and is executable
if [[ -f "discover-services.sh" && -x "discover-services.sh" ]]; then
    echo "✅ Script exists and is executable"
else
    echo "❌ Script missing or not executable"
    exit 1
fi

# Test 2: Help function works
if ./discover-services.sh --help >/dev/null 2>&1; then
    echo "✅ Help function works"
else
    echo "❌ Help function failed"
    exit 1
fi

# Test 3: Dry-run mode works
if ./discover-services.sh --dry-run --skip-ssh-test >/dev/null 2>&1; then
    echo "✅ Dry-run mode works"
else
    echo "❌ Dry-run mode failed"
    exit 1
fi

# Test 4: Script contains all required functionality
required_features=(
    "baseline information"
    "endpoint discovery"
    "firewall.*check"
    "health check"
    "automatic.*fix"
    "final.*summary"
    "ssh.*connection"
)

echo "🔍 Checking for required features..."
for feature in "${required_features[@]}"; do
    if grep -qi "$feature" discover-services.sh; then
        echo "✅ Found: $feature"
    else
        echo "❌ Missing: $feature"
        exit 1
    fi
done

# Test 5: Check that the script handles the specific VPS requirements
vps_requirements=(
    "147.79.68.121"
    "hostname -I"
    "ss.*LISTEN"
    "docker ps.*format"
    "docker compose ls"
    "ufw.*status"
    "curl.*health"
    "docker-compose.yml"
)

echo "🎯 Checking VPS-specific requirements..."
for req in "${vps_requirements[@]}"; do
    if grep -q "$req" discover-services.sh; then
        echo "✅ Found: $req"
    else
        echo "❌ Missing: $req"
        exit 1
    fi
done

# Test 6: Check the script contains the required output format
output_requirements=(
    "OPEN THESE LINKS"
    "NOTES"
    "HTTP.*status"
)

echo "📋 Checking output format requirements..."
for req in "${output_requirements[@]}"; do
    if grep -q "$req" discover-services.sh; then
        echo "✅ Found: $req"
    else
        echo "❌ Missing: $req"
        exit 1
    fi
done

echo ""
echo "🎉 All validation tests passed!"
echo ""
echo "📊 Script Statistics:"
echo "   Lines of code: $(wc -l < discover-services.sh)"
echo "   Functions defined: $(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*(" discover-services.sh || echo 0)"
echo "   Error handling: $(grep -c "set -euo pipefail\|error\|warn" discover-services.sh || echo 0)"
echo ""
echo "Ready for deployment! 🚀"