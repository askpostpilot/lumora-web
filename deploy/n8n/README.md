# n8n Deployment Automation

This directory contains automated deployment scripts for n8n workflow automation on Hostinger VPS.

## 🚀 One-Click Installation

**For Ubuntu 24.04 Hostinger VPS (IP mode, no domain required)**

Copy and paste this **single command** into your Hostinger web terminal:

```bash
set -euo pipefail && apt-get update -y && apt-get install -y curl ca-certificates && mkdir -p /opt/solyntra && cd /opt/solyntra && curl -fsSL https://get.docker.com | sh && apt-get install -y docker-compose-plugin && bash -lc 'REPO_RAW="https://raw.githubusercontent.com/askpostpilot/lumora-web/copilot/fix-e8cc18c5-a02a-4878-b6cb-13e2d6efd8fd"; mkdir -p /opt/solyntra && curl -fsSL "$REPO_RAW/deploy/n8n/install_n8n.sh" -o /root/install_n8n.sh && chmod +x /root/install_n8n.sh && /root/install_n8n.sh'
```

## 📋 Installation Checklist

- [ ] Open Hostinger **Browser terminal** for the VPS
- [ ] Paste the one-liner command above
- [ ] Wait for "Open: http://147.79.68.121:5678/" or an onboarding link from logs
- [ ] Visit the URL and complete n8n's first-time setup

## ⚙️ What Gets Installed

- **n8n**: Latest version via Docker
- **Docker Compose**: For container management
- **Systemd Service**: Auto-start on boot
- **Configuration**: IP mode (no domain/HTTPS required)
- **Data Persistence**: Docker volumes for workflows and settings
- **File Sharing**: `/opt/solyntra/files` mapped to container

## 🛠️ Management Commands

After installation, you can manage n8n with these commands:

```bash
# Check service status
systemctl status n8n-compose.service

# View real-time logs
docker logs n8n -f

# Restart n8n
systemctl restart n8n-compose.service

# Stop n8n
systemctl stop n8n-compose.service

# Start n8n
systemctl start n8n-compose.service
```

## 📁 File Locations

- **Installation**: `/opt/solyntra/`
- **Configuration**: `/opt/solyntra/.env`
- **Docker Compose**: `/opt/solyntra/docker-compose.yml`
- **Shared Files**: `/opt/solyntra/files/`
- **Systemd Service**: `/etc/systemd/system/n8n-compose.service`

## 🔒 Security Notes

- The installation generates a secure encryption key automatically
- **Never change the encryption key** after first run (will break existing data)
- n8n runs on port 5678 (HTTP only, suitable for IP access)
- The script is idempotent - safe to re-run multiple times

## 🌍 Access Information

- **URL**: http://147.79.68.121:5678/
- **Port**: 5678
- **Mode**: IP access (no domain required)
- **First-time setup**: Required on first visit

## ❓ Troubleshooting

If the installation fails or n8n doesn't start:

1. Check Docker service: `systemctl status docker`
2. Check n8n service: `systemctl status n8n-compose.service`
3. View container logs: `docker logs n8n`
4. Restart the service: `systemctl restart n8n-compose.service`

The script includes comprehensive error checking and will report any issues during installation.