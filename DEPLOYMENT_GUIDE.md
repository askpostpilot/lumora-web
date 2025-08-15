# Quick n8n Deployment Guide

## SSH Connection and Deployment

1. **Connect to your VPS:**
   ```bash
   ssh root@147.79.68.121
   ```

2. **Run the deployment (one of these methods):**

   **Method A: Direct script execution**
   ```bash
   curl -sSL https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-070d26fd-435e-444e-ba6e-9cd7fa8b5fc2/deployment/deploy-n8n.sh | bash
   ```

   **Method B: Download and inspect first**
   ```bash
   wget https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-070d26fd-435e-444e-ba6e-9cd7fa8b5fc2/deployment/deploy-n8n.sh
   chmod +x deploy-n8n.sh
   ./deploy-n8n.sh
   ```

   **Method C: Copy-paste script contents**
   - Copy the entire contents of `deployment/deploy-n8n.sh`
   - Paste into a file on the server
   - Make executable and run

3. **Open firewall (if needed):**
   - Hostinger Control Panel → VPS → Firewall
   - Add rule: Allow TCP port 5678

4. **Access n8n:**
   - URL: http://147.79.68.121:5678/
   - Complete the initial user setup

## Post-Deployment

**Install management script (recommended):**
```bash
wget https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-070d26fd-435e-444e-ba6e-9cd7fa8b5fc2/deployment/manage-n8n.sh -O /usr/local/bin/manage-n8n
chmod +x /usr/local/bin/manage-n8n
```

**Daily commands:**
```bash
manage-n8n info        # Show status and access URL
manage-n8n update      # Update n8n safely
manage-n8n backup      # Create backups
manage-n8n logs        # View recent logs
```

## Expected Output

After successful deployment, you should see:
- ✅ Docker containers running
- ✅ n8n accessible at http://147.79.68.121:5678/
- ✅ Service auto-starts on boot
- ✅ Setup complete message with next steps

## Troubleshooting

If the deployment fails, check:
1. Docker is installed: `docker --version`
2. Docker Compose is available: `docker compose version`
3. Server has internet access
4. Port 5678 is not already in use: `ss -tlnp | grep :5678`

For detailed troubleshooting, see `deployment/README.md`.