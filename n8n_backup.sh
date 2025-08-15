#!/bin/bash
set -euo pipefail

# n8n Daily Backup Script
# Backs up n8n data to /var/backups/n8n with 14-day retention

BACKUP_DIR="/var/backups/n8n"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/opt/solyntra"
TEMP_DIR="/tmp/n8n_backup_$TIMESTAMP"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Save docker-compose.yml and .env files for restoration reference
cp "$PROJECT_DIR/docker-compose.yml" "$TEMP_DIR/" 2>/dev/null || true
cp "$PROJECT_DIR/.env" "$TEMP_DIR/" 2>/dev/null || true

# Export n8n_data volume to tar file
echo "[$(date)] Starting n8n backup..."
docker run --rm -v lumora-web_n8n_data:/src -v "$TEMP_DIR":/dst alpine sh -c 'cd /src && tar czf /dst/n8n_data.tgz .'

# Create final compressed backup
tar czf "$BACKUP_DIR/n8n_backup_$TIMESTAMP.tgz" -C "$TEMP_DIR" .

# Clean up temporary directory
rm -rf "$TEMP_DIR"

# Rotate backups: keep 14 newest (14 days)
cd "$BACKUP_DIR"
ls -1t n8n_backup_*.tgz 2>/dev/null | tail -n +15 | xargs -r rm -f

echo "[$(date)] Backup completed: $BACKUP_DIR/n8n_backup_$TIMESTAMP.tgz"