# Lumora Production Deployment with Traefik + Let's Encrypt

This guide provides the exact commands to deploy Lumora with n8n accessible at https://{DOMAIN} using Traefik and Let's Encrypt for SSL certificates.

## Prerequisites

- Ubuntu VPS with Docker and Docker Compose installed
- Domain name pointing to your VPS IP address
- Ports 80 and 443 open on your firewall

## Deployment Commands

Run these commands on your VPS to deploy the complete stack:

### 1. Clone Repository
```bash
cd /opt
git clone https://github.com/askpostpilot/lumora-web.git
cd lumora-web
```

### 2. Configure Environment
```bash
# Copy the environment template
cp .env.example .env

# Edit the configuration file
nano .env
```

Update these values in the `.env` file:
```bash
DOMAIN=your-domain.com
LE_EMAIL=your-email@domain.com
```

The `N8N_ENCRYPTION_KEY` will be automatically generated during deployment.

### 3. Deploy with Traefik + Let's Encrypt
```bash
# Make the deploy script executable
chmod +x deploy-with-traefik.sh

# Run the deployment
./deploy-with-traefik.sh
```

### 4. Verify Deployment

Check container status:
```bash
docker compose ps
```

Check logs:
```bash
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f traefik
docker compose logs -f n8n
```

## What Gets Deployed

1. **Traefik** (ports 80, 443) - Reverse proxy with automatic SSL
2. **n8n** - Workflow automation accessible at https://your-domain.com
3. **Watchtower** - Automatic container updates

## Access URLs

- **n8n Interface**: `https://your-domain.com`
- **Traefik Dashboard**: `https://traefik.your-domain.com` (optional)

## Architecture

```
Internet → Traefik (80/443) → n8n (5678)
```

- Port 5678 is NOT exposed to the host (internal only)
- All traffic goes through Traefik with SSL termination
- HTTP automatically redirects to HTTPS
- Let's Encrypt certificates stored in `./traefik/acme.json`

## Configuration Files

- `docker-compose.yml` - Main service definitions
- `traefik/traefik.yml` - Traefik configuration
- `traefik/acme.json` - Let's Encrypt certificate storage (auto-created)
- `.env` - Environment variables

## Troubleshooting

### Certificate Issues
If SSL certificates don't work immediately:
1. Ensure DNS points to your server
2. Check Traefik logs: `docker compose logs traefik`
3. Wait 2-3 minutes for certificate provisioning

### Service Issues
- Check all containers are running: `docker compose ps`
- Restart services: `docker compose restart`
- View detailed logs: `docker compose logs -f [service-name]`

### DNS Issues
Verify your domain points to the server:
```bash
nslookup your-domain.com
```

## Updates

To update the stack:
```bash
cd /opt/lumora-web
git pull
./deploy-with-traefik.sh
```

## Security Notes

- Only ports 80 and 443 are exposed
- SSL certificates auto-renew via Let's Encrypt
- n8n runs on internal port 5678 (not exposed to host)
- All traffic encrypted with valid SSL certificates