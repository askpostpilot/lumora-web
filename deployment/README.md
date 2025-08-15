# n8n Deployment for Lumora

This directory contains the deployment infrastructure for n8n (workflow automation) to support the Lumora social media automation platform.

## Overview

n8n is deployed using Docker Compose on a Hostinger VPS running Ubuntu 24.04. The deployment includes:

- **n8n**: Workflow automation platform
- **Persistent storage**: For n8n data and shared files
- **Auto-start**: Systemd service for boot-time startup
- **Management scripts**: For maintenance and updates

## Quick Deployment

### Prerequisites

- Ubuntu 24.04 VPS with Docker and Docker Compose installed
- Root access to the server
- Server IP: 147.79.68.121

### Deploy n8n

1. **SSH into your VPS:**
   ```bash
   ssh root@147.79.68.121
   ```

2. **Copy the deployment script to the server and run it:**
   ```bash
   curl -o deploy-n8n.sh https://raw.githubusercontent.com/your-repo/deployment/deploy-n8n.sh
   chmod +x deploy-n8n.sh
   ./deploy-n8n.sh
   ```

   Or manually copy the contents of `deploy-n8n.sh` and run it.

3. **Open firewall port (if needed):**
   - In Hostinger panel: VPS → Firewall
   - Add allow rule for TCP port 5678

4. **Access n8n:**
   - Open: http://147.79.68.121:5678/
   - Complete the initial setup

## Files Structure

```
/opt/solyntra/
├── .env                    # Environment variables
├── docker-compose.yml      # Docker Compose configuration
├── files/                  # Shared files directory
└── backups/               # Auto-generated backups
```

## Configuration Files

### docker-compose.yml

Defines the n8n service with:
- Port mapping: 5678:5678
- Persistent volumes for data and files
- Environment variables from .env file
- Restart policy: unless-stopped
- Optional watchtower for auto-updates (commented)

### .env

Contains n8n configuration:
- `N8N_PORT`: Service port (5678)
- `N8N_ENCRYPTION_KEY`: Auto-generated secure key
- `GENERIC_TIMEZONE`: Asia/Kolkata
- `TZ`: Timezone setting
- Domain settings (optional)

### n8n-compose.service

Systemd service for auto-starting n8n on boot:
- Starts after Docker service
- Working directory: /opt/solyntra
- Auto-enables on system startup

## Management

### Daily Commands

Update n8n safely:
```bash
cd /opt/solyntra && docker compose pull && docker compose up -d && docker ps
```

Backup n8n data:
```bash
docker run --rm -v n8n_data:/data alpine tar -czf - /data > /root/n8n_data_$(date +%F).tgz
tar -czf /root/n8n_files_$(date +%F).tgz -C /opt/solyntra files
```

View logs:
```bash
docker logs n8n --since 10m
```

### Management Script

Use the included management script:

```bash
# Copy management script to server
scp manage-n8n.sh root@147.79.68.121:/usr/local/bin/
chmod +x /usr/local/bin/manage-n8n.sh

# Usage examples
manage-n8n.sh status      # Check service status
manage-n8n.sh update      # Update n8n safely
manage-n8n.sh backup      # Create backups
manage-n8n.sh logs        # View recent logs
manage-n8n.sh info        # Show access URL and status
```

## Auto-Updates (Optional)

Enable nightly auto-updates:
```bash
manage-n8n.sh enable-watchtower
```

This uncomments the watchtower service which will:
- Check for updates daily at 03:00
- Automatically update and restart n8n
- Clean up old images

## Troubleshooting

### Container not starting

Check logs:
```bash
docker logs n8n
```

Check service status:
```bash
systemctl status n8n-compose.service
```

### Can't access n8n web interface

1. Check if container is running:
   ```bash
   docker ps | grep n8n
   ```

2. Check if port 5678 is open:
   ```bash
   ss -tlnp | grep :5678
   ```

3. Check firewall settings in Hostinger panel

### Reset user management

```bash
docker exec -it n8n n8n user-management:reset
```

### Complete reset

Stop and remove everything:
```bash
cd /opt/solyntra
docker compose down -v  # WARNING: This removes data!
docker compose up -d
```

## Security Notes

- Change default passwords during n8n setup
- The encryption key in `.env` is auto-generated and should be kept secure
- Consider setting up domain + HTTPS for production use
- Regular backups are recommended

## Integration with Lumora

n8n can be integrated with the Lumora web platform to:
- Handle scheduled social media posts
- Process webhooks from social platforms
- Automate content workflows
- Generate analytics and reports
- Manage user notifications

The shared `/files` directory allows data exchange between n8n workflows and the Lumora web application.

## Support

For issues specific to n8n, refer to the [n8n documentation](https://docs.n8n.io/).
For deployment issues, check the logs and service status as described above.