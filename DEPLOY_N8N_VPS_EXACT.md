# n8n VPS Deployment Script (Exact Steps)

This script (`deploy-n8n-vps-exact.sh`) follows the exact 5 steps specified in the requirements to SSH into the Hostinger VPS and ensure n8n is properly configured and accessible.

## What it does

The script SSHs into `root@147.79.68.121` non-interactively and executes these exact steps:

### Step 1: Print docker services and port mappings
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Step 2: Confirm n8n exposes host port 5678->5678
- Checks if n8n container already has the correct port mapping
- If not, creates `docker-compose.override.yml` with port configuration:
```yaml
services:
  n8n:
    ports:
      - "5678:5678"
```
- Runs: `docker compose -f ~/lumora-web/docker-compose.yml up -d`

### Step 3: Open firewall on the server
```bash
if ufw status | grep -qi active; then ufw allow 5678/tcp; fi
ss -tulpen | awk 'NR==1 || /LISTEN/'
```

### Step 4: Health-check n8n
```bash
curl -fsSILm 5 http://127.0.0.1:5678 || true
curl -fsm 5 http://127.0.0.1:5678 | head -n 5 || true
```

### Step 5: Print final link to open from laptop
```bash
echo "OPEN THIS: http://$(hostname -I | awk '{print $1}'):5678"
```

## Usage

```bash
# Show help
./deploy-n8n-vps-exact.sh --help

# Deploy n8n
./deploy-n8n-vps-exact.sh
```

## Prerequisites

- SSH key access configured for `root@147.79.68.121`
- VPS has Docker and Docker Compose installed
- VPS has Git installed (for cloning lumora-web if needed)

## Testing

Run the test script to validate the implementation:

```bash
./test-deploy-n8n-vps-exact.sh
```

## Access URL

After successful deployment, n8n will be accessible at:
**http://147.79.68.121:5678**

## Implementation Notes

- The script uses `docker-compose.override.yml` instead of modifying the main `docker-compose.yml` file directly for safer configuration management
- All commands follow the exact format specified in the requirements
- Error handling ensures graceful failures
- Non-interactive execution suitable for automation