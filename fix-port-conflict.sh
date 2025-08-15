#!/bin/bash

# SSH into Hostinger VPS and fix the port-80 conflict, then restart the Lumora (n8n+Traefik) stack
# Run everything as root in a bash shell, non‑interactive, stopping on errors.

# 0) Sanity
set -euo pipefail
echo "== Host uname =="
uname -a
echo "== Docker =="
docker --version
docker compose version || true

# 1) Show what holds ports 80/443 (for logs)
echo "== Who listens on :80 and :443 =="
ss -ltnp '( sport = :80 )' || true
ss -ltnp '( sport = :443 )' || true
systemctl is-active nginx && echo "nginx is ACTIVE" || echo "nginx not active"

# 2) Stop any host nginx that could block :80/:443
if systemctl list-unit-files | grep -q '^nginx\.service'; then
systemctl stop nginx || true
systemctl disable nginx || true
fi

# 3) Stop any Docker container (NOT our Traefik) that publishes port 80
CONFLICT_IDS="$(docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' \
| grep -E ':80->' \
| grep -vE 'traefik' \
| awk '{print $1}')"
if [ -n "${CONFLICT_IDS:-}" ]; then
echo "== Stopping conflicting containers on :80 =="
docker stop $CONFLICT_IDS || true
docker rm $CONFLICT_IDS || true
fi

# 4) Go to deployment folder (clone if missing)
cd ~/lumora-web 2>/dev/null || {
git clone https://github.com/askpostpilot/lumora-web.git ~/lumora-web
cd ~/lumora-web
}

# 5) Pull latest and ensure .env exists (IP mode – no domain yet)
git fetch --all --prune
# Try to checkout main, fallback to current branch if main doesn't exist
git checkout main 2>/dev/null || {
    echo "Main branch not found, using current branch: $(git branch --show-current)"
}
# Only pull if we're on a tracking branch
if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    git pull --ff-only
else
    echo "Not on a tracking branch, skipping pull"
fi

if [ ! -f .env ]; then
KEY="$(openssl rand -base64 48 | tr -d '\n')"
cat > .env <<EOF
# Runtime (IP mode)
N8N_PORT=5678
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64
N8N_ENCRYPTION_KEY=$KEY

# Leave empty while using IP:5678 (no domain yet)
DOMAIN=
LE_EMAIL=
EOF
chmod 600 .env
fi

# 6) Start/refresh the stack
docker compose pull
docker compose up -d --remove-orphans

# 7) Health & access info
echo "== Containers =="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo "== Local checks =="
curl -sI http://127.0.0.1:80 | head -n1 || true
curl -sI http://127.0.0.1:5678 | head -n1 || true

# Get actual server IP dynamically
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "== Open these in your browser =="
echo "Traefik landing (if exposed): http://$SERVER_IP/"
echo "n8n editor (IP mode): http://$SERVER_IP:5678"