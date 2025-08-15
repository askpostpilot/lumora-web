# n8n Deployment on Hostinger VPS

This directory contains deployment scripts and documentation for setting up n8n on a Hostinger VPS in IP mode (without domain).

## 📋 Files in this Directory

- **`QUICK_DEPLOY.md`** - One-line deployment command and quick reference
- **`MANUAL_INSTRUCTIONS.md`** - Step-by-step manual deployment guide  
- **`n8n-deploy-local.sh`** - Script to run directly on the VPS
- **`n8n-deploy.sh`** - Remote SSH deployment script (requires SSH access)
- **`README.md`** - This comprehensive guide

## 🚀 Quick Start

**One-line deployment command (run on your VPS):**

```bash
cd /opt/solyntra && curl -sSL https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-5230b8f1-5dfa-451c-9db1-78a7ffa5f88e/deployment/n8n-deploy-local.sh | bash
```

**Then access:** http://YOUR_SERVER_IP:5678

## Environment

- **VPS:** Ubuntu 24.04
- **IP:** YOUR_SERVER_IP
- **User:** root
- **Docker:** 28.3.3
- **Docker Compose:** v2.39.1
- **Project Directory:** /opt/solyntra
- **Port:** 5678

## Prerequisites

Before running the deployment script, ensure:

1. Docker and Docker Compose are installed on the VPS
2. `/opt/solyntra/docker-compose.yml` exists
3. `/opt/solyntra/.env` exists
4. SSH access to root@YOUR_SERVER_IP is configured
5. Port 5678 is open on the VPS

## Deployment Options

### Option 1: Quick One-Line Deployment (Recommended)

SSH into your VPS and run:

```bash
cd /opt/solyntra && curl -sSL https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-5230b8f1-5dfa-451c-9db1-78a7ffa5f88e/deployment/n8n-deploy-local.sh | bash
```

### Option 2: Download and Run Script

```bash
ssh root@YOUR_SERVER_IP
cd /opt/solyntra
wget https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-5230b8f1-5dfa-451c-9db1-78a7ffa5f88e/deployment/n8n-deploy-local.sh
chmod +x n8n-deploy-local.sh
./n8n-deploy-local.sh
```

### Option 3: Remote SSH Deployment (if SSH access is available)

From this repository:

```bash
./deployment/n8n-deploy.sh
```

This script will:

1. SSH into the VPS
2. Verify Docker installation
3. Ensure required directories and files exist
4. Update/complete the `.env` file with required variables:
   - `N8N_PORT=5678`
   - `GENERIC_TIMEZONE=Asia/Kolkata`
   - `TZ=Asia/Kolkata`
   - `N8N_PAYLOAD_SIZE_MAX=64`
   - `N8N_HOST=` (empty for IP mode)
   - `LE_EMAIL=` (empty)
   - `N8N_ENCRYPTION_KEY` (auto-generated if missing)
5. Pull and start n8n containers
6. Create systemd service for auto-start on boot
7. Verify the deployment

## Environment Variables

The script ensures these environment variables are set in `/opt/solyntra/.env`:

- **N8N_PORT:** Port for n8n (5678)
- **GENERIC_TIMEZONE:** Timezone (Asia/Kolkata)
- **TZ:** System timezone (Asia/Kolkata)
- **N8N_PAYLOAD_SIZE_MAX:** Maximum payload size (64MB)
- **N8N_HOST:** Empty for IP mode access
- **LE_EMAIL:** Empty (no SSL certificate needed for IP mode)
- **N8N_ENCRYPTION_KEY:** Auto-generated 48-character base64 key

## Systemd Service

The script creates `/etc/systemd/system/n8n-compose.service` with:

- Auto-start on boot
- Dependency on Docker service
- Working directory: `/opt/solyntra`
- Start command: `docker compose up -d`
- Stop command: `docker compose down`

## Access

After successful deployment:

- **URL:** http://YOUR_SERVER_IP:5678
- **Status:** Check with `systemctl status n8n-compose.service`
- **Logs:** View with `docker logs n8n`

## Troubleshooting

If the deployment fails:

1. Check Docker service: `systemctl status docker`
2. Verify files exist: `ls -la /opt/solyntra/`
3. Check container logs: `docker logs n8n`
4. Test port access: `curl -I http://127.0.0.1:5678`

## Safety

The deployment script is idempotent and safe to re-run. It will:

- Preserve existing environment variable values
- Only update empty or missing values
- Not overwrite existing encryption keys
- Gracefully handle already-running services

## Manual Commands

If you need to manage the service manually:

```bash
# Start n8n
systemctl start n8n-compose.service

# Stop n8n  
systemctl stop n8n-compose.service

# Check status
systemctl status n8n-compose.service

# View logs
docker logs n8n

# Reset user management (if needed)
docker exec -it n8n n8n user-management:reset
```