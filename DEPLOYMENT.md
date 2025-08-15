# Lumora + n8n VPS Deployment

This repository contains a complete deployment package for running the Lumora website alongside n8n with HTTPS via Traefik on an Ubuntu VPS.

## Features

- **HTTPS Termination**: Automatic SSL certificates via Let's Encrypt
- **Reverse Proxy**: Traefik for routing and load balancing
- **n8n Integration**: Workflow automation platform
- **Security Hardening**: Automated backups, health checks, and firewall
- **Auto-Updates**: Watchtower for container updates

## Prerequisites

- Ubuntu 24.04 VPS with root access
- Docker and Docker Compose installed
- Domain name pointing to your VPS IP (YOUR_SERVER_IP)

## Quick Start

1. **Clone and deploy to VPS:**
   ```bash
   cd /opt
   git clone https://github.com/askpostpilot/lumora-web.git solyntra
   cd solyntra
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   nano .env
   ```
   Update:
   - `DOMAIN=your-domain.com`
   - `LE_EMAIL=your-email@domain.com`
   - `N8N_ENCRYPTION_KEY=your-secure-random-key`

3. **Deploy with HTTPS:**
   ```bash
   ./scripts/deploy-https.sh
   ```

4. **Apply hardening:**
   ```bash
   ./scripts/hardening.sh
   ```

5. **Setup systemd service:**
   ```bash
   cp systemd/n8n-compose.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable n8n-compose.service
   ```

## Architecture

```
Internet → Traefik (443/80) → Services
                             ├── Lumora Web (nginx)
                             ├── n8n (5678)
                             └── Traefik Dashboard
```

## Service URLs

After deployment, access:

- **Lumora Website**: `https://your-domain.com`
- **n8n Interface**: `https://n8n.your-domain.com`
- **Traefik Dashboard**: `https://traefik.your-domain.com`

## Security Features

### Automated Backups
- Daily backups at 02:10
- 7-day retention
- Includes n8n data and configuration
- Location: `/opt/solyntra/backups/`

### Health Monitoring
- 5-minute health checks
- Auto-restart on failures
- Service healing capabilities

### Firewall Configuration
- UFW basic rules (22, 80, 443)
- Deny all other incoming
- Allow all outgoing

### Container Updates
- Watchtower runs daily at 03:00
- Automatic image updates
- Container cleanup

## Manual Operations

### View logs:
```bash
cd /opt/solyntra
docker compose logs -f
```

### Restart services:
```bash
systemctl restart n8n-compose.service
```

### Manual backup:
```bash
/opt/solyntra/backup_n8n.sh
```

### Check health:
```bash
/opt/solyntra/healthcheck.sh
```

### View timers:
```bash
systemctl list-timers | grep n8n
```

## Troubleshooting

### DNS Issues
Verify your domain points to the VPS:
```bash
dig +short A your-domain.com
```

### SSL Certificate Issues
Check Traefik logs:
```bash
docker compose logs traefik
```

### Service Health
Check container status:
```bash
docker ps
```

### Firewall Issues
Check UFW status:
```bash
ufw status verbose
```

## Updating

To update the deployment:

1. Pull latest changes:
   ```bash
   cd /opt/solyntra
   git pull
   ```

2. Rebuild and restart:
   ```bash
   docker compose build --no-cache
   docker compose up -d
   ```

## File Structure

```
/opt/solyntra/
├── docker-compose.yml      # Main service definitions
├── Dockerfile             # Lumora web container
├── nginx.conf             # Nginx configuration
├── .env                   # Environment variables
├── scripts/
│   ├── deploy-https.sh    # HTTPS deployment script
│   └── hardening.sh       # Security hardening script
├── systemd/
│   └── n8n-compose.service # Systemd service file
├── backups/               # Automated backups
├── traefik/
│   └── acme.json         # Let's Encrypt certificates
└── [website files]       # Static website content
```

## Support

For issues with this deployment setup, check the logs and ensure all prerequisites are met. The scripts are idempotent and safe to re-run.