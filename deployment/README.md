# n8n Deployment for Lumora

This directory contains the deployment scripts and configuration for setting up n8n workflow automation as part of the Lumora infrastructure.

## Quick Start

To deploy n8n on an Ubuntu 24.04 server with Docker & Docker Compose:

```bash
# Copy and paste this one-liner into your VPS (root shell):
curl -fsSL https://raw.githubusercontent.com/askpostpilot/lumora-web/main/deployment/n8n-installer.sh | bash
```

Or download and run manually:

```bash
wget https://raw.githubusercontent.com/askpostpilot/lumora-web/main/deployment/n8n-installer.sh
chmod +x n8n-installer.sh
sudo ./n8n-installer.sh
```

## Configuration Options

The installer supports two deployment modes:

### 1. HTTP Mode (Default)
- Exposes n8n directly on port 5678
- No domain required
- Accessible via `http://your-server-ip:5678`

### 2. HTTPS Mode (with domain)
- Requires a domain name pointed to your server
- Automatic SSL certificate via Let's Encrypt
- HTTP to HTTPS redirect
- Accessible via `https://your-domain.com`

To enable HTTPS mode, edit `/opt/solyntra/.env` before or after running the installer:

```env
N8N_HOST=your-domain.com
LE_EMAIL=your-email@domain.com
```

Then restart: `sudo systemctl restart n8n-compose.service`

## What the Installer Does

1. **Creates deployment structure** in `/opt/solyntra/`
2. **Configures environment** with secure encryption keys
3. **Sets up Docker Compose** with n8n and optional Traefik
4. **Creates systemd service** for auto-start on reboot
5. **Opens firewall ports** if UFW is active (ports 80/443 for HTTPS)
6. **Validates deployment** and provides access information

## File Structure

After installation:

```
/opt/solyntra/
├── .env                    # Environment configuration
├── docker-compose.yml     # Docker services definition
├── files/                 # n8n file storage directory
└── *.bak-*                # Backup files (if updating)
```

## Management Commands

```bash
# Check service status
sudo systemctl status n8n-compose.service

# View logs
sudo docker logs n8n

# Restart services
sudo systemctl restart n8n-compose.service

# Stop services
sudo systemctl stop n8n-compose.service

# View all containers
sudo docker ps
```

## Requirements

- Ubuntu 24.04 LTS
- Docker 20.10+
- Docker Compose v2.0+
- Root access
- Internet connectivity

## Security Features

- Strong random encryption key generation
- File backups with timestamps
- Restricted file permissions
- Optional HTTPS with automatic certificate renewal
- Firewall configuration (UFW support)

## Troubleshooting

### n8n not accessible
1. Check firewall: `sudo ufw status`
2. Verify containers: `sudo docker ps`
3. Check logs: `sudo docker logs n8n`

### HTTPS certificate issues
1. Ensure domain points to server IP
2. Check Traefik logs: `sudo docker logs traefik`
3. Verify ports 80/443 are open
4. Wait up to 10 minutes for certificate issuance

### Service not starting on reboot
1. Check service status: `sudo systemctl status n8n-compose.service`
2. Enable if needed: `sudo systemctl enable n8n-compose.service`

## Support

For issues related to this deployment script, please open an issue in the [lumora-web repository](https://github.com/askpostpilot/lumora-web).

For n8n-specific questions, refer to the [official n8n documentation](https://docs.n8n.io/).