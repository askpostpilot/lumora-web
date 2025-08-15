# n8n IP Mode Deployment Files

This directory contains scripts and documentation for deploying n8n in IP mode on the Hostinger VPS.

## Files

### Core Scripts
- **`deploy-n8n-ip-mode.sh`** - Main deployment script for SSH deployment to VPS
- **`test-n8n-deployment.sh`** - Test script to validate deployment logic without SSH

### Documentation  
- **`N8N_IP_DEPLOYMENT.md`** - Complete deployment guide and troubleshooting
- **`DEPLOYMENT_FILES_README.md`** - This file

## Quick Start

```bash
# Test the deployment script logic
./test-n8n-deployment.sh

# Deploy to VPS (requires SSH access)
./deploy-n8n-ip-mode.sh

# Access n8n
# http://147.79.68.121:5678
```

## What This Achieves

✅ **n8n accessible at**: http://147.79.68.121:5678  
✅ **IP mode** (no domain required)  
✅ **Port 5678** published directly  
✅ **Traefik preserved** (still handles port 80/443)  
✅ **Watchtower preserved** (continues auto-updates)  
✅ **Firewall configured** (UFW allows port 5678)  
✅ **Non-interactive deployment**  
✅ **Auto-recovery** from common issues  

## Architecture

The deployment creates this setup:

```
Internet
  ├─ :5678 → n8n (Direct IP access)
  ├─ :80   → Traefik → Lumora Web  
  └─ :443  → Traefik → SSL (when domain configured)
```

## Key Technical Details

- Uses `docker-compose.override.yml` to add port mapping
- Preserves existing docker-compose.yml unchanged  
- Deploys to `~/lumora-web` (not `/opt/solyntra`)
- Configures UFW firewall automatically
- Tests both local and remote connectivity
- Provides clear success/failure feedback

## Prerequisites

- SSH key access to `root@147.79.68.121`
- VPS has Docker + Docker Compose installed
- VPS has Git installed

## Support

See `N8N_IP_DEPLOYMENT.md` for complete deployment guide and troubleshooting steps.