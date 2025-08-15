#!/usr/bin/env bash
set -euo pipefail

# Hardening script for n8n VPS deployment
# Implements watchtower, daily backup, healthcheck, and basic firewall

PROJECT_DIR="/opt/solyntra"
LOG_FILE="/var/log/lumora-hardening.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
fi

log "Starting hardening process..."

# Step 0: Preflight checks
log "Step 0: Preflight checks..."
if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Directory $PROJECT_DIR doesn't exist"
fi

cd "$PROJECT_DIR"
if ! docker compose version >/dev/null 2>&1; then
    error "Docker compose not working in $PROJECT_DIR"
fi

# Create required directories
mkdir -p "${PROJECT_DIR}/files" "${PROJECT_DIR}/backups"
chown root:root "$PROJECT_DIR" -R
log "Created directories and set ownership"

# Step 1: Watchtower already added to docker-compose.yml
log "Step 1: Watchtower service already configured in docker-compose.yml"

# Step 2: Daily backup script
log "Step 2: Setting up daily backup..."
cat > "${PROJECT_DIR}/backup_n8n.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
BKDIR="/opt/solyntra/backups"
mkdir -p "$BKDIR"

# Temporary directory for backup assembly
TMP="/opt/solyntra/.tmp-backup-$TS"
mkdir -p "$TMP"

# Save compose + env files
cp -a /opt/solyntra/docker-compose.yml "$TMP"/
cp -a /opt/solyntra/.env "$TMP"/ 2>/dev/null || true

# Export n8n_data volume to a tar inside TMP
docker run --rm -v n8n_data:/src -v "$TMP":/dst alpine sh -c 'cd /src && tar czf /dst/n8n_data.tgz .'

# Final bundle
tar czf "$BKDIR/n8n_backup_$TS.tgz" -C "$TMP" .
rm -rf "$TMP"

# Rotate: keep 7 newest
ls -1t "$BKDIR"/n8n_backup_*.tgz | tail -n +8 | xargs -r rm -f

echo "[$(date)] Backup completed: n8n_backup_$TS.tgz"
EOF

chmod +x "${PROJECT_DIR}/backup_n8n.sh"
log "Created backup script"

# Create systemd service for backup
cat > /etc/systemd/system/n8n-backup.service << EOF
[Unit]
Description=n8n daily backup

[Service]
Type=oneshot
ExecStart=${PROJECT_DIR}/backup_n8n.sh
EOF

# Create systemd timer for backup
cat > /etc/systemd/system/n8n-backup.timer << EOF
[Unit]
Description=Run n8n-backup daily at 02:10

[Timer]
OnCalendar=*-*-* 02:10:00
Persistent=true
Unit=n8n-backup.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now n8n-backup.timer
log "Backup timer enabled and started"

# Step 3: Healthcheck & self-heal
log "Step 3: Setting up healthcheck..."
cat > "${PROJECT_DIR}/healthcheck.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd /opt/solyntra

# Check container is up
if ! docker compose ps --status running | grep -q "n8n"; then
    echo "[$(date)] [healthcheck] n8n container not running, restarting stack…"
    docker compose up -d
    exit 0
fi

# App health endpoint
if ! curl -fsS --max-time 5 http://127.0.0.1:5678/rest/health >/dev/null; then
    echo "[$(date)] [healthcheck] /rest/health failed, restarting n8n service…"
    docker compose restart n8n || docker compose up -d
fi
EOF

chmod +x "${PROJECT_DIR}/healthcheck.sh"
log "Created healthcheck script"

# Create systemd service for healthcheck
cat > /etc/systemd/system/n8n-health.service << EOF
[Unit]
Description=n8n healthcheck

[Service]
Type=oneshot
ExecStart=${PROJECT_DIR}/healthcheck.sh
EOF

# Create systemd timer for healthcheck
cat > /etc/systemd/system/n8n-health.timer << EOF
[Unit]
Description=Run n8n-health every 5 minutes

[Timer]
OnUnitActiveSec=5min
AccuracySec=1min
Persistent=true
Unit=n8n-health.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now n8n-health.timer
log "Healthcheck timer enabled and started"

# Step 4: Basic firewall
log "Step 4: Configuring firewall..."
UFW_STATUS=$(ufw status | head -n1)
if [[ "$UFW_STATUS" == "Status: inactive" ]]; then
    log "UFW is inactive, configuring basic rules..."
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    log "UFW firewall enabled"
else
    warn "UFW is already active, current rules:"
    ufw status verbose
fi

# Step 5: Report back
log "Step 5: Final status report"
log "Container status:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

log "Active timers:"
systemctl list-timers --all | grep -E 'n8n-(backup|health)' || true

if [[ "$UFW_STATUS" != "Status: inactive" ]]; then
    log "Firewall status:"
    ufw status verbose
fi

log "=== Hardening Complete ==="
log "✓ Watchtower configured for automatic updates"
log "✓ Daily backups to ${PROJECT_DIR}/backups (7 retained)"
log "✓ 5-minute healthcheck enabled"
log "✓ Firewall configured"