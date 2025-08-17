# SolyntraAI Web - AI-Powered Social Media Automation Platform

A cutting-edge static website for the SolyntraAI artificial intelligence social media automation platform with integrated n8n deployment capabilities and premium metallic 3D design.

## Quick Start (Static Website)

This repository contains the static website files for SolyntraAI. For local development:

```bash
# Serve locally (requires a web server)
python3 -m http.server 8000
# or
npx serve .
```

## Production Deployment (VPS with n8n)

For production deployment on an Ubuntu VPS with HTTPS, n8n integration, and security hardening, see [DEPLOYMENT.md](DEPLOYMENT.md).

### Quick Deploy

```bash
# On your VPS (as root):
cd /opt
git clone https://github.com/askpostpilot/lumora-web.git solyntra
cd solyntra
cp .env.example .env
nano .env  # Configure DOMAIN, LE_EMAIL, N8N_ENCRYPTION_KEY
./scripts/install.sh
```

This will set up:
- ✅ Lumora website with HTTPS
- ✅ n8n workflow automation
- ✅ Traefik reverse proxy
- ✅ Let's Encrypt SSL certificates
- ✅ Automated backups and monitoring
- ✅ Security hardening

## Features

- **Static Website**: Fast, modern design for Lumora platform
- **Production Ready**: Complete Docker deployment with HTTPS
- **n8n Integration**: Workflow automation platform
- **Security**: Automated backups, health checks, firewall
- **Easy Management**: Systemd services and monitoring

## Architecture

```
Static Website + Production Deployment:
┌─────────────────┐    ┌──────────────────────────────────┐
│ Static Files    │    │ Production (Docker + HTTPS)      │
│ - HTML/CSS/JS   │───▶│ ┌─────────┐ ┌─────────┐ ┌─────┐ │
│ - Nginx config  │    │ │ Traefik │─│ Lumora  │ │ n8n │ │
│ - Assets        │    │ │ (SSL)   │ │ Website │ │     │ │
└─────────────────┘    │ └─────────┘ └─────────┘ └─────┘ │
                       └──────────────────────────────────┘
```

## File Structure

```
lumora-web/
├── index.html              # Homepage
├── pricing.html           # Pricing page
├── dashboard.html         # Dashboard preview
├── assets/                # CSS, JS, images
├── policies/              # Legal pages
│
├── Dockerfile             # Container for static site
├── docker-compose.yml     # Full production stack
├── nginx.conf             # Web server config
├── .env.example          # Configuration template
│
├── scripts/              # Deployment automation
│   ├── install.sh        # Master installation script
│   ├── deploy-https.sh   # HTTPS setup
│   ├── hardening.sh      # Security measures
│   └── test-config.sh    # Configuration testing
│
├── systemd/              # System service files
│   └── n8n-compose.service
│
└── DEPLOYMENT.md         # Full deployment guide
```

## Development

The static website uses:
- Modern CSS with gradients and animations
- Vanilla JavaScript for interactions
- Responsive design
- Clean, professional styling

## Support

- For website issues: Check the HTML/CSS/JS files
- For deployment issues: See [DEPLOYMENT.md](DEPLOYMENT.md)
- For n8n configuration: Check the docker-compose.yml

## License

This project is part of the Lumora platform.