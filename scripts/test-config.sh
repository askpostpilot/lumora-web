#!/usr/bin/env bash
set -euo pipefail

# Test script for validating the deployment configuration

echo "=== Deployment Configuration Test ==="

# Check if required files exist
FILES=(
    "docker-compose.yml"
    "Dockerfile"
    "nginx.conf"
    ".env.example"
    "scripts/deploy-https.sh"
    "scripts/hardening.sh"
    "systemd/n8n-compose.service"
    "DEPLOYMENT.md"
)

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        exit 1
    fi
done

# Check if scripts are executable
SCRIPTS=(
    "scripts/deploy-https.sh"
    "scripts/hardening.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -x "$script" ]]; then
        echo "✓ $script is executable"
    else
        echo "✗ $script is not executable"
        exit 1
    fi
done

# Validate docker-compose.yml syntax
echo "Testing Docker Compose configuration..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose config -q && echo "✓ docker-compose.yml syntax is valid"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose config -q && echo "✓ docker-compose.yml syntax is valid"
else
    echo "⚠ Docker Compose not available for validation"
fi

# Check for required environment variables in .env.example
REQUIRED_VARS=("DOMAIN" "LE_EMAIL" "N8N_ENCRYPTION_KEY")
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^$var=" .env.example; then
        echo "✓ $var defined in .env.example"
    else
        echo "✗ $var missing from .env.example"
        exit 1
    fi
done

echo "✓ All deployment configuration tests passed!"
echo ""
echo "Next steps:"
echo "1. Copy to VPS: scp -r . root@your-vps:/opt/solyntra"
echo "2. Configure .env file with your domain and email"
echo "3. Run: ./scripts/deploy-https.sh"
echo "4. Run: ./scripts/hardening.sh"