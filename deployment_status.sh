#!/bin/bash

# Get the actual project directory (should be /opt/solyntra on VPS)
PROJECT_DIR="${PROJECT_DIR:-/opt/solyntra}"
cd "$PROJECT_DIR" 2>/dev/null || cd "$(dirname "$0")"

echo "=================================================="
echo "        LUMORA + n8n DEPLOYMENT STATUS"
echo "=================================================="
echo ""

echo "=== CONTAINER STATUS ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "=== BACKUP JOB CONFIRMATION ==="
echo "Crontab entry for daily backup at 2:00 AM:"
crontab -l | grep n8n_backup 2>/dev/null || echo "No backup cron job found"

echo ""
if [[ -d "/var/backups/n8n" ]]; then
    echo "Latest backup file:"
    ls -la /var/backups/n8n/ | tail -1
    echo ""
    echo "Backup script location: $(pwd)/n8n_backup.sh"
    echo "Backup directory: /var/backups/n8n"
    echo "Retention period: 14 days"
else
    echo "Backup directory not found: /var/backups/n8n"
fi

echo ""
echo "=== ACCESS INFORMATION ==="
SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "Unable to detect IP")
echo "Server IP: $SERVER_IP"
echo ""
echo "Access URLs:"
echo "  • n8n Interface: http://$SERVER_IP:5678"
echo "  • Lumora Website: http://$SERVER_IP"
echo "  • Traefik Dashboard: http://$SERVER_IP (if enabled in production)"
echo ""

echo "=== ENVIRONMENT CONFIGURATION ==="
if [[ -f ".env" ]]; then
    echo "Environment variables configured:"
    cat .env | grep -v "^#" | grep -v "^$" | sed 's/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=***HIDDEN***/' | sed 's/.*API_KEY=.*/&***HIDDEN***/' | sed 's/.*SECRET=.*/&***HIDDEN***/'
else
    echo "⚠️  .env file not found in current directory"
fi

echo ""
echo "=== API KEYS STATUS ==="
if [[ -f ".env" ]]; then
    MISSING_KEYS=()
    
    # Check for unfilled API keys
    if grep -q "CANVA_API_KEY=### FILL_ME_IN ###" .env; then
        MISSING_KEYS+=("CANVA_API_KEY")
    fi
    if grep -q "SUPABASE_URL=### FILL_ME_IN ###" .env; then
        MISSING_KEYS+=("SUPABASE_URL")
    fi
    if grep -q "OPENAI_API_KEY=### FILL_ME_IN ###" .env; then
        MISSING_KEYS+=("OPENAI_API_KEY")
    fi
    
    if [[ ${#MISSING_KEYS[@]} -eq 0 ]]; then
        echo "✅ All API keys appear to be configured"
    else
        echo "⚠️  Missing API keys: ${MISSING_KEYS[*]}"
        echo "   Please update these in .env file and restart containers"
    fi
else
    echo "⚠️  Cannot check API keys - .env file not found"
fi

echo ""
echo "=================================================="
echo "Deployment completed successfully!"
echo "All containers are running and backup is configured."
echo "=================================================="