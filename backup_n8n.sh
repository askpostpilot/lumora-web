#!/usr/bin/env bash
set -euo pipefail

# n8n backup script - daily at 2:00 AM, retain 14 days
TS="$(date +%Y%m%d_%H%M%S)"
BKDIR="/var/backups/n8n"
mkdir -p "$BKDIR"

# Temporary directory for backup assembly
TMP="/tmp/n8n-backup-$TS"
mkdir -p "$TMP"

# Change to the docker-compose directory
cd /home/runner/work/lumora-web/lumora-web

# Save compose + env files
cp -a docker-compose.yml "$TMP"/
cp -a .env "$TMP"/ 2>/dev/null || true

# Export n8n_data volume to a tar inside TMP
docker run --rm -v lumora-web_n8n_data:/src -v "$TMP":/dst alpine sh -c 'cd /src && tar czf /dst/n8n_data.tgz .'

# Final bundle
tar czf "$BKDIR/n8n_backup_$TS.tgz" -C "$TMP" .
rm -rf "$TMP"

# Rotate: keep 14 newest (14 days retention)
ls -1t "$BKDIR"/n8n_backup_*.tgz 2>/dev/null | tail -n +15 | xargs -r rm -f

echo "[$(date)] Backup completed: n8n_backup_$TS.tgz"