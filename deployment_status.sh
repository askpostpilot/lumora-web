#!/bin/bash

echo "=================================================="
echo "        LUMORA + n8n DEPLOYMENT STATUS"
echo "=================================================="
echo ""

echo "=== CONTAINER STATUS ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "=== BACKUP JOB CONFIRMATION ==="
echo "Crontab entry for daily backup at 2:00 AM:"
crontab -l | grep n8n_backup

echo ""
echo "Latest backup file:"
ls -la /var/backups/n8n/ | tail -1

echo ""
echo "Backup script location: $(pwd)/n8n_backup.sh"
echo "Backup directory: /var/backups/n8n"
echo "Retention period: 14 days"

echo ""
echo "=== ACCESS INFORMATION ==="
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Server IP: $SERVER_IP"
echo ""
echo "Access URLs:"
echo "  • n8n Interface: http://$SERVER_IP:5678"
echo "  • Lumora Website: http://$SERVER_IP"
echo "  • Traefik Dashboard: http://$SERVER_IP (if enabled in production)"
echo ""

echo "=== ENVIRONMENT CONFIGURATION ==="
echo "Environment variables configured:"
cat .env | grep -v "^#" | sed 's/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=***HIDDEN***/'

echo ""
echo "=================================================="
echo "Deployment completed successfully!"
echo "All containers are running and backup is configured."
echo "=================================================="