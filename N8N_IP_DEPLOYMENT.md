# n8n IP Mode Deployment Guide

This guide covers deploying n8n in IP mode on a Hostinger VPS to make it accessible at `http://147.79.68.121:5678`.

## Deployment Scripts

There are two deployment scripts available:

### 1. Standard Deployment (`deploy-n8n-ip-mode.sh`)
The main deployment script that uses docker-compose.override.yml for configuration:

1. **SSH Connection**: Connects to `root@147.79.68.121`
2. **Repository Setup**: Clones/updates `lumora-web` in `~/lumora-web`  
3. **Port Configuration**: Creates `docker-compose.override.yml` to publish n8n on port 5678
4. **Service Deployment**: Runs `docker compose up -d --remove-orphans`
5. **Verification**: Checks container status and connectivity
6. **Firewall Setup**: Configures UFW to allow port 5678 if needed
7. **Testing**: Tests local and remote connectivity

### 2. Exact Steps Deployment (`deploy-n8n-exact-steps.sh`)
Alternative script that implements exact steps as specified:

1. **Print Services**: `docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"`
2. **Modify docker-compose.yml**: Directly modifies the main docker-compose.yml to add `ports: - "5678:5678"`
3. **Firewall Setup**: `if ufw status | grep -qi active; then ufw allow 5678/tcp; fi` and `ss -tulpen | awk 'NR==1 || /LISTEN/'`
4. **Health Check**: `curl -fsSILm 5 http://127.0.0.1:5678` and `curl -fsm 5 http://127.0.0.1:5678 | head -n 5`
5. **Final Link**: `echo "OPEN THIS: http://$(hostname -I | awk '{print $1}'):5678"`

## Overview

## Prerequisites

- SSH key access configured for `root@147.79.68.121`
- VPS has Docker and Docker Compose installed
- VPS has Git installed
- UFW firewall (if active) will be automatically configured

## Quick Start

### Option 1: Standard Deployment (Recommended)
1. **Run the main deployment script:**
   ```bash
   ./deploy-n8n-ip-mode.sh
   ```

### Option 2: Exact Steps Deployment
1. **Run the exact steps script:**
   ```bash
   ./deploy-n8n-exact-steps.sh
   ```

2. **Access n8n:**
   - URL: http://147.79.68.121:5678
   - Click: http://147.79.68.121:5678

## What the Script Does

### Step 1: Repository Setup
```bash
cd ~
git clone https://github.com/askpostpilot/lumora-web.git  # if missing
cd ~/lumora-web
```

### Step 2: Create Override File
Creates `docker-compose.override.yml`:
```yaml
services:
  n8n:
    ports:
      - "5678:5678"
```

### Step 3: Deploy Services
```bash
docker compose up -d --remove-orphans
```

### Step 4: Verification
- Checks `docker ps` for port mapping: `0.0.0.0:5678->5678/tcp`
- Tests local connectivity: `curl http://127.0.0.1:5678`

### Step 5: Firewall Configuration
```bash
ufw allow 5678/tcp  # if UFW is active
```

### Step 6: Remote Testing
Tests connectivity from external location to verify public accessibility.

## Expected Output

```
=== n8n IP Mode Deployment Started ===
VPS: 147.79.68.121
Target: http://147.79.68.121:5678

=== Step 1: Setting up lumora-web directory ===
✅ lumora-web directory ready

=== Step 2: Creating docker-compose.override.yml ===
✅ Override file created

=== Step 3: Starting Docker services ===
✅ Docker services started

=== Step 4: Verification ===
Container status:
NAMES     STATUS        PORTS
n8n       Up 30 seconds 0.0.0.0:5678->5678/tcp
traefik   Up 45 seconds 0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
watchtower Up 50 seconds

✅ n8n port mapping confirmed: 0.0.0.0:5678->5678/tcp
✅ n8n is responding locally

=== Step 6: Firewall configuration ===
✅ Port 5678/tcp allowed in firewall

🎯 FINAL ACCESS URL: http://147.79.68.121:5678
```

## Verification Commands

After deployment, verify manually on the VPS:

```bash
# Check container status
docker ps | grep n8n

# Test local connectivity  
curl -I http://127.0.0.1:5678

# Check firewall
ufw status

# Check port is listening
ss -ltn | grep :5678
```

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH access
ssh root@147.79.68.121 "echo 'SSH working'"

# Add your SSH key if needed
ssh-copy-id root@147.79.68.121
```

### Container Not Starting
```bash
# Check logs
docker logs n8n

# Restart services
cd ~/lumora-web
docker compose restart n8n
```

### Port Not Accessible
```bash
# Check if port is listening
ss -ltn | grep :5678

# Test from VPS
curl -I http://127.0.0.1:5678

# Check firewall
ufw status
ufw allow 5678/tcp
```

### n8n Not Loading
```bash
# Wait for n8n to fully start (can take 30-60 seconds)
docker logs -f n8n

# Check if override file exists
cat ~/lumora-web/docker-compose.override.yml
```

## Key Features

- ✅ **Non-Interactive**: Fully automated deployment
- ✅ **Idempotent**: Safe to run multiple times  
- ✅ **Preserves Services**: Keeps Traefik and Watchtower running
- ✅ **Auto-Recovery**: Handles missing directories/files
- ✅ **Firewall Aware**: Configures UFW automatically
- ✅ **Verification**: Tests both local and remote connectivity
- ✅ **Clear Output**: Provides final access URL and status

## Files Created/Modified

- `~/lumora-web/docker-compose.override.yml` - Port mapping for n8n
- UFW rules (if UFW is active) - Allows port 5678/tcp

## Architecture

```
Internet → VPS:5678 → Docker:n8n:5678 → n8n Application
                ↓
         VPS:80/443 → Docker:traefik → Lumora Web
```

The n8n service runs alongside Traefik and other services, with direct port access for IP mode usage.