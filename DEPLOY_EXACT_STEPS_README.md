# deploy-n8n-exact-steps.sh

A script that implements exact steps for deploying n8n in IP mode on Hostinger VPS.

## Purpose

This script performs the exact steps specified for making n8n reachable at `http://147.79.68.121:5678` using IP mode (no domain required).

## Usage

```bash
./deploy-n8n-exact-steps.sh
```

## What It Does

The script SSHs into `root@147.79.68.121` and performs these exact steps:

### Step 1: Print Docker Services
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Step 2: Configure n8n Port Mapping
- Checks if n8n exposes host port 5678→5678
- If not, modifies `~/lumora-web/docker-compose.yml` to include:
  ```yaml
  ports:
    - "5678:5678"
  ```
- Then runs: `docker compose -f ~/lumora-web/docker-compose.yml up -d`

### Step 3: Open Firewall
```bash
if ufw status | grep -qi active; then ufw allow 5678/tcp; fi
ss -tulpen | awk 'NR==1 || /LISTEN/'
```

### Step 4: Health-check n8n
```bash
curl -fsSILm 5 http://127.0.0.1:5678 || true
curl -fsm 5 http://127.0.0.1:5678 | head -n 5 || true
```

### Step 5: Print Final Link
```bash
echo "OPEN THIS: http://$(hostname -I | awk '{print $1}'):5678"
```

## Features

- **Non-interactive**: Runs completely automated via SSH
- **Safety**: Creates timestamped backups before modifying docker-compose.yml
- **Exact Implementation**: Follows the specified commands precisely
- **Dynamic IP**: Uses `hostname -I` to detect server IP dynamically
- **Error Handling**: Continues on errors where specified with `|| true`

## Requirements

- SSH access to `root@147.79.68.121`
- VPS has Docker and Docker Compose installed
- `~/lumora-web` directory exists or can be cloned

## Testing

Run the test script to verify the implementation:

```bash
./test-exact-steps-script.sh
```

## Differences from Standard Script

Unlike `deploy-n8n-ip-mode.sh`, this script:
- Modifies `docker-compose.yml` directly instead of using override files
- Uses exact command formats as specified
- Implements specific curl commands with exact flags
- Uses dynamic IP detection for the final URL

## Output

The script will output progress and end with:
```
OPEN THIS: http://147.79.68.121:5678
```

Access n8n at the provided URL to complete setup.