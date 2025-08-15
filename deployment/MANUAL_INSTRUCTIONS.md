# Manual n8n Deployment Instructions

Since SSH connectivity to your VPS isn't available from this environment, follow these manual instructions to deploy n8n on your Hostinger VPS.

## Option 1: Download and Run the Script

1. **SSH into your VPS:**
   ```bash
   ssh root@YOUR_SERVER_IP
   ```

2. **Download the deployment script:**
   ```bash
   cd /opt/solyntra
   wget https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-5230b8f1-5dfa-451c-9db1-78a7ffa5f88e/deployment/n8n-deploy-local.sh
   chmod +x n8n-deploy-local.sh
   ```

3. **Run the deployment script:**
   ```bash
   ./n8n-deploy-local.sh
   ```

## Option 2: Manual Step-by-Step Commands

If you prefer to run commands manually, execute these steps on your VPS:

### 1. SSH into VPS and verify Docker
```bash
ssh root@YOUR_SERVER_IP
docker --version
docker compose version
```

### 2. Setup directories and verify files
```bash
mkdir -p /opt/solyntra/files
cd /opt/solyntra
ls -la docker-compose.yml .env
```

### 3. Update .env file
```bash
# Backup current .env
cp .env .env.backup

# Add/update required variables (only if missing or empty)
echo "N8N_PORT=5678" >> .env
echo "GENERIC_TIMEZONE=Asia/Kolkata" >> .env
echo "TZ=Asia/Kolkata" >> .env
echo "N8N_PAYLOAD_SIZE_MAX=64" >> .env
echo "N8N_HOST=" >> .env
echo "LE_EMAIL=" >> .env

# Generate encryption key if missing
if ! grep -q "^N8N_ENCRYPTION_KEY=" .env || [ -z "$(grep '^N8N_ENCRYPTION_KEY=' .env | cut -d'=' -f2-)" ]; then
    ENCRYPTION_KEY=$(openssl rand -base64 36 | tr -d '\n')
    echo "N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}" >> .env
fi

# Remove any duplicate entries and clean up
sort .env | uniq > .env.tmp && mv .env.tmp .env
```

### 4. Start n8n services
```bash
docker compose pull
docker compose up -d
```

### 5. Create systemd service
```bash
cat > /etc/systemd/system/n8n-compose.service << 'EOF'
[Unit]
Description=n8n Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/solyntra
RemainAfterExit=yes
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable n8n-compose.service
systemctl start n8n-compose.service
```

### 6. Verify deployment
```bash
# Wait for containers to start
sleep 10

# Check container status
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Test HTTP connectivity
curl -sI http://127.0.0.1:5678 | head -n1

# Check for n8n content
curl -s http://127.0.0.1:5678 | grep -i 'n8n'

# Check service status
systemctl status n8n-compose.service
```

### 7. Get onboarding information (if needed)
```bash
# Check recent logs for user management info
docker logs n8n --since 5m | grep -i 'User management'

# Or reset user management if needed
docker exec -it n8n n8n user-management:reset
```

## Expected Results

After successful deployment, you should see:

1. **Container Status:**
   ```
   NAMES    STATUS              PORTS
   n8n      Up X minutes        0.0.0.0:5678->5678/tcp
   ```

2. **HTTP Test:**
   ```
   HTTP/1.1 200 OK
   ```
   or
   ```
   HTTP/1.1 302 Found
   ```

3. **Service Status:**
   ```
   ● n8n-compose.service - n8n Docker Compose Service
        Loaded: loaded (/etc/systemd/system/n8n-compose.service; enabled; vendor preset: enabled)
        Active: active (exited) since...
   ```

4. **Access URL:** http://YOUR_SERVER_IP:5678

## Environment Variables

The deployment ensures these variables are set in `/opt/solyntra/.env`:

```
N8N_PORT=5678
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
N8N_PAYLOAD_SIZE_MAX=64
N8N_HOST=
LE_EMAIL=
N8N_ENCRYPTION_KEY=<generated-base64-key>
```

## Troubleshooting

### If containers don't start:
```bash
docker logs n8n
docker compose logs
```

### If port 5678 is not accessible:
```bash
# Check if port is listening
ss -tlnp | grep 5678

# Check firewall (if ufw is used)
ufw status
ufw allow 5678
```

### If systemd service fails:
```bash
systemctl status n8n-compose.service
journalctl -u n8n-compose.service
```

### To restart everything:
```bash
systemctl stop n8n-compose.service
docker compose down
docker compose pull
docker compose up -d
systemctl start n8n-compose.service
```

## Final Verification

Once deployed, you should be able to:

1. **Access n8n:** Open http://YOUR_SERVER_IP:5678 in your browser
2. **See n8n interface:** Complete initial setup if prompted
3. **Auto-start:** Service will automatically start on VPS reboot

## Support

If you encounter issues:

1. Check the deployment logs and error messages
2. Verify all prerequisites are met
3. Ensure docker-compose.yml and .env files are properly configured
4. Check network connectivity and firewall settings