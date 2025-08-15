# 🚀 Lumora DevOps Complete Deployment Guide

## Overview

This guide provides the complete deployment sequence for Lumora + n8n on your Hostinger VPS as requested in your DevOps task. All steps are designed to be executed in sequence without pausing unless there's an error.

## 🎯 What This Deployment Does

1. ✅ SSH into your Hostinger VPS using existing credentials
2. ✅ Navigate to the Lumora deployment folder
3. ✅ Pull the latest changes from the main branch
4. ✅ Create or update .env file with placeholder values for all required variables
5. ✅ Run docker-compose build and docker-compose up -d to start all containers
6. ✅ Set up the automated n8n backup script and schedule it via cron
7. ✅ Verify container health using docker ps and confirm n8n is running
8. ✅ Output the exact .env lines where you must paste your API keys

## 🔧 Prerequisites

- Ubuntu 24.04 VPS with root access
- Docker and Docker Compose installed
- Git installed
- SSH access to your Hostinger VPS

## 🚀 Quick Deployment (One Command)

SSH into your VPS and run this single command for complete deployment:

```bash
curl -sSL https://raw.githubusercontent.com/askpostpilot/lumora-web/main/deploy-complete.sh | bash
```

## 📋 Manual Step-by-Step Deployment

If you prefer to run the deployment manually, follow these steps:

### 1. SSH into your VPS
```bash
ssh root@your-vps-ip
```

### 2. Navigate to deployment directory and clone/update repository
```bash
# Create deployment directory if it doesn't exist
mkdir -p /opt/solyntra
cd /opt/solyntra

# Clone repository (if first time) or update existing
if [ ! -d ".git" ]; then
    git clone https://github.com/askpostpilot/lumora-web.git .
else
    git fetch origin
    git checkout main
    git pull origin main
fi
```

### 3. Create/update .env file with placeholders
```bash
# Copy example and customize
cp .env.example .env

# Generate secure encryption key
ENCRYPTION_KEY=$(openssl rand -base64 36 | tr -d '\n')
sed -i "s|N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}|" .env
```

### 4. Build and start containers
```bash
docker compose build --no-cache
docker compose up -d
```

### 5. Set up automated backup
```bash
# Make backup script executable
chmod +x n8n_backup.sh

# Create backup directory
mkdir -p /var/backups/n8n

# Schedule daily backup at 2:00 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /opt/solyntra/n8n_backup.sh >> /var/log/n8n_backup.log 2>&1") | crontab -

# Run initial backup
./n8n_backup.sh
```

### 6. Verify deployment
```bash
# Check container status
docker ps

# Verify n8n is accessible
curl -I http://localhost:5678

# Run status script
./deployment_status.sh
```

## 🔐 API Keys Configuration

After deployment, you **MUST** configure your API keys in the `.env` file. Edit `/opt/solyntra/.env` and replace these exact lines:

```env
# Canva API Configuration
CANVA_API_KEY=### FILL_ME_IN ###
CANVA_CLIENT_ID=### FILL_ME_IN ###
CANVA_CLIENT_SECRET=### FILL_ME_IN ###

# Supabase Configuration  
SUPABASE_URL=### FILL_ME_IN ###
SUPABASE_ANON_KEY=### FILL_ME_IN ###
SUPABASE_SERVICE_KEY=### FILL_ME_IN ###

# OpenAI Configuration
OPENAI_API_KEY=### FILL_ME_IN ###
OPENAI_ORG_ID=### FILL_ME_IN ### (optional)
```

### To update API keys:
```bash
nano /opt/solyntra/.env
# Replace ### FILL_ME_IN ### with your actual keys
# Save and exit (Ctrl+X, then Y, then Enter)

# Restart containers to apply changes
cd /opt/solyntra
docker compose restart
```

## 🌐 Access Information

After successful deployment:

- **n8n Interface**: `http://YOUR-VPS-IP:5678`
- **Lumora Website**: `http://YOUR-VPS-IP`
- **Traefik Dashboard**: `http://YOUR-VPS-IP` (if enabled)

Replace `YOUR-VPS-IP` with your actual VPS IP address (likely 147.79.68.121).

## 🔍 Verification Commands

```bash
# Check all container status
docker ps

# View container logs
docker compose logs -f

# Check backup system
crontab -l | grep n8n_backup
ls -la /var/backups/n8n/

# Run full status check
/opt/solyntra/deployment_status.sh
```

## 🛠 Management Commands

```bash
cd /opt/solyntra

# Restart all services
docker compose restart

# Stop all services  
docker compose down

# Start all services
docker compose up -d

# View logs
docker compose logs -f

# Manual backup
./n8n_backup.sh

# Check deployment status
./deployment_status.sh
```

## 🔄 Updating the Deployment

To update to the latest version:

```bash
cd /opt/solyntra
git pull origin main
docker compose build --no-cache
docker compose up -d
```

## 📊 Expected Final Status

After successful deployment, you should see:

```
✅ Repository updated to latest main branch
✅ .env file created with secure defaults  
✅ Docker containers built and started
✅ Automated backup system configured
✅ Cron job scheduled for daily backups at 2:00 AM
✅ Container health verified

🌐 Access URLs:
• n8n Interface: http://YOUR-VPS-IP:5678
• Lumora Website: http://YOUR-VPS-IP
```

## 🚨 Troubleshooting

### If containers fail to start:
```bash
docker compose logs
docker system prune -a
docker compose up -d
```

### If n8n is not accessible:
```bash
# Check if port 5678 is open
ss -tulpn | grep 5678

# Check n8n container logs
docker logs n8n

# Restart n8n container
docker compose restart n8n
```

### If backup fails:
```bash
# Check backup script permissions
ls -la /opt/solyntra/n8n_backup.sh

# Make executable if needed
chmod +x /opt/solyntra/n8n_backup.sh

# Test backup manually
/opt/solyntra/n8n_backup.sh
```

## 📞 Support

If you encounter issues:

1. Check the deployment logs: `cat /var/log/lumora-deploy.log`
2. Run the status script: `/opt/solyntra/deployment_status.sh`
3. Verify all prerequisites are met
4. Ensure your .env file has proper values (not placeholders)

---

**🎉 Deployment Complete!** Your Lumora + n8n system should now be running and accessible. Don't forget to configure your API keys for full functionality.