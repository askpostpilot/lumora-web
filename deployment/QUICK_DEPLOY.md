# Quick Deployment Summary

## One-Line Deployment Command

SSH into your VPS and run this single command to deploy n8n:

```bash
cd /opt/solyntra && curl -sSL https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-5230b8f1-5dfa-451c-9db1-78a7ffa5f88e/deployment/n8n-deploy-local.sh | bash
```

## What This Does

1. ✅ Verifies Docker installation
2. ✅ Ensures `/opt/solyntra/docker-compose.yml` and `.env` exist
3. ✅ Updates `.env` with required n8n variables (preserves existing values)
4. ✅ Generates secure encryption key if missing
5. ✅ Pulls latest n8n images and starts containers
6. ✅ Creates systemd service for auto-start on boot
7. ✅ Verifies deployment and connectivity

## Expected Output

```
=== n8n Deployment Script (Local Execution) ===
Running on: your-vps-hostname
User: root
=============================
=== Docker Version Check ===
Docker version 28.3.3, build a61...
Docker Compose version v2.39.1
=============================
=== Setting up directories ===
Required files verified
=== Updating .env file ===
Added N8N_PORT=5678
Added GENERIC_TIMEZONE=Asia/Kolkata
Added TZ=Asia/Kolkata
Added N8N_PAYLOAD_SIZE_MAX=64
Added N8N_HOST=
Added LE_EMAIL=
Added N8N_ENCRYPTION_KEY=<generated-key>
Environment file updated successfully
=== Starting n8n service ===
[+] Pulling 1/1
 ✔ n8n Pulled
[+] Running 1/1
 ✔ Container n8n Started
=== Creating systemd service ===
Systemd service created and enabled
Waiting for containers to start...
=== Verification ===
Docker containers status:
NAMES    STATUS              PORTS
n8n      Up X seconds        0.0.0.0:5678->5678/tcp

Testing local connectivity:
HTTP Status: HTTP/1.1 200 OK
n8n content found: ✓

=== Deployment Summary ===
Access URL: http://147.79.68.121:5678
Service Status: active
Service Enabled: enabled

=== Deployment Complete ===
n8n should now be accessible at: http://147.79.68.121:5678
```

## Access Your n8n Instance

After deployment, open: **http://147.79.68.121:5678**

## Quick Checks

```bash
# Check container status
docker ps

# Check service status  
systemctl status n8n-compose.service

# Check logs
docker logs n8n

# Test local connectivity
curl -I http://127.0.0.1:5678
```

## If Something Goes Wrong

### Container not starting:
```bash
docker logs n8n
docker compose up -d --force-recreate
```

### Port not accessible:
```bash
# Check if port is listening
ss -tlnp | grep 5678

# Check firewall
ufw status
ufw allow 5678
```

### Reset everything:
```bash
cd /opt/solyntra
docker compose down
docker compose up -d
systemctl restart n8n-compose.service
```

## Environment Variables Added/Updated

The script ensures these are set in `/opt/solyntra/.env`:

```env
N8N_PORT=5678                    # n8n port
GENERIC_TIMEZONE=Asia/Kolkata    # Application timezone  
TZ=Asia/Kolkata                  # System timezone
N8N_PAYLOAD_SIZE_MAX=64          # Max payload size in MB
N8N_HOST=                        # Empty for IP mode
LE_EMAIL=                        # Empty (no SSL)
N8N_ENCRYPTION_KEY=xxxxx         # Auto-generated secure key
```

## Service Management

```bash
# Start n8n
systemctl start n8n-compose.service

# Stop n8n
systemctl stop n8n-compose.service  

# Check status
systemctl status n8n-compose.service

# Enable auto-start (already done by script)
systemctl enable n8n-compose.service

# Disable auto-start
systemctl disable n8n-compose.service
```

## File Locations

- **Project Directory:** `/opt/solyntra/`
- **Docker Compose:** `/opt/solyntra/docker-compose.yml`
- **Environment:** `/opt/solyntra/.env`
- **Systemd Service:** `/etc/systemd/system/n8n-compose.service`
- **Container Name:** `n8n`

---

**That's it!** Your n8n instance should now be running and accessible at http://147.79.68.121:5678