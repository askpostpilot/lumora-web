#!/bin/bash

# ===========================================
# Lumora DevOps Post-Deployment Verification
# ===========================================
# This script verifies the deployment is complete and working

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="/opt/solyntra"
ISSUES=()

echo "=============================================="
echo "🔍 POST-DEPLOYMENT VERIFICATION"
echo "=============================================="
echo ""

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    if [[ -d "$PROJECT_DIR" ]]; then
        cd "$PROJECT_DIR"
    else
        echo -e "${RED}❌ Cannot find project directory${NC}"
        exit 1
    fi
fi

echo "📍 Current directory: $(pwd)"
echo ""

# 1. Check Docker containers
echo "🐳 CONTAINER STATUS CHECK"
echo "=========================="
if docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E "(n8n|lumora-web)" > /dev/null; then
    echo -e "${GREEN}✅ Docker containers are running${NC}"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "(n8n|lumora-web|traefik)"
else
    echo -e "${RED}❌ Some containers may not be running${NC}"
    ISSUES+=("Docker containers not running properly")
fi
echo ""

# 2. Check n8n connectivity  
echo "🌐 CONNECTIVITY CHECK"
echo "====================="
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

if curl -sf http://localhost:5678 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ n8n is accessible on port 5678${NC}"
else
    echo -e "${YELLOW}⚠️  n8n may still be starting up or not accessible${NC}"
    ISSUES+=("n8n not responding on port 5678")
fi

echo "🔗 Access URLs:"
echo "   • n8n Interface: http://$SERVER_IP:5678"
echo "   • Lumora Website: http://$SERVER_IP"
echo ""

# 3. Check backup system
echo "💾 BACKUP SYSTEM CHECK"
echo "======================"
if crontab -l 2>/dev/null | grep -q "n8n_backup.sh"; then
    echo -e "${GREEN}✅ Backup cron job is scheduled${NC}"
    echo "   Cron entry: $(crontab -l | grep n8n_backup.sh)"
else
    echo -e "${RED}❌ Backup cron job not found${NC}"
    ISSUES+=("Backup cron job not scheduled")
fi

if [[ -x "n8n_backup.sh" ]]; then
    echo -e "${GREEN}✅ Backup script is executable${NC}"
else
    echo -e "${RED}❌ Backup script not found or not executable${NC}"
    ISSUES+=("Backup script issues")
fi

if [[ -d "/var/backups/n8n" ]]; then
    BACKUP_COUNT=$(ls -1 /var/backups/n8n/*.tgz 2>/dev/null | wc -l || echo 0)
    echo -e "${GREEN}✅ Backup directory exists${NC} (${BACKUP_COUNT} backups found)"
else
    echo -e "${YELLOW}⚠️  Backup directory not found${NC}"
    ISSUES+=("Backup directory missing")
fi
echo ""

# 4. Check environment configuration
echo "⚙️  ENVIRONMENT CHECK"
echo "===================="
if [[ -f ".env" ]]; then
    echo -e "${GREEN}✅ .env file exists${NC}"
    
    # Check for unfilled placeholders
    UNFILLED=$(grep -c "### FILL_ME_IN ###" .env 2>/dev/null || echo 0)
    if [[ $UNFILLED -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Found $UNFILLED unfilled API keys${NC}"
        echo "   Please update these in .env file:"
        grep "### FILL_ME_IN ###" .env | sed 's/=.*//' | sed 's/^/   - /'
        ISSUES+=("API keys need to be configured")
    else
        echo -e "${GREEN}✅ All API keys appear to be configured${NC}"
    fi
    
    # Check for encryption key
    if grep -q "^N8N_ENCRYPTION_KEY=.*[a-zA-Z0-9]" .env && ! grep -q "### FILL_ME_IN ###" .env; then
        echo -e "${GREEN}✅ n8n encryption key is set${NC}"
    else
        echo -e "${RED}❌ n8n encryption key not properly configured${NC}"
        ISSUES+=("n8n encryption key missing")
    fi
else
    echo -e "${RED}❌ .env file not found${NC}"
    ISSUES+=(".env file missing")
fi
echo ""

# 5. Final status
echo "📊 OVERALL STATUS"
echo "================="
if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "${GREEN}🎉 DEPLOYMENT VERIFICATION PASSED!${NC}"
    echo ""
    echo "✅ All systems are operational"
    echo "✅ Containers are running"
    echo "✅ Backup system is configured"
    echo "✅ Configuration files are present"
    echo ""
    echo "🚀 Your Lumora + n8n deployment is ready!"
    echo ""
    echo "🔗 Next steps:"
    echo "   1. Open http://$SERVER_IP:5678 to access n8n"
    echo "   2. Complete n8n initial setup if prompted"
    echo "   3. Configure any remaining API keys if needed"
else
    echo -e "${RED}❌ DEPLOYMENT VERIFICATION FOUND ISSUES:${NC}"
    printf '   • %s\n' "${ISSUES[@]}"
    echo ""
    echo -e "${YELLOW}🔧 Recommended actions:${NC}"
    echo "   1. Review the issues listed above"
    echo "   2. Check container logs: docker compose logs"
    echo "   3. Ensure .env file is properly configured"
    echo "   4. Restart containers if needed: docker compose restart"
    echo ""
    exit 1
fi

echo "=============================================="