# VPS Service Discovery and Verification

This directory contains comprehensive service discovery tools for the Hostinger VPS deployment of Lumora + n8n services.

## Overview

The service discovery system automatically:
1. Connects to your Hostinger VPS via SSH
2. Discovers all running services (n8n, traefik, lumora-web, etc.)
3. Identifies public URLs and endpoints
4. Checks firewall configuration
5. Performs health checks with retries
6. Applies safe automatic fixes
7. Provides a final summary with working URLs

## Files

### Main Scripts

- **`discover-services.sh`** - Main service discovery and verification script
- **`discovery-helper.sh`** - Integration helper with multiple commands
- **`validate-discovery.sh`** - Validation tests for the discovery scripts

### Test Scripts

- **`test-discovery-logic.sh`** - Local testing of discovery logic
- **`test-deployment-logic.sh`** - Existing deployment logic tests

## Quick Start

### Basic Discovery

```bash
# Run full service discovery
./discover-services.sh

# Preview what would be done (no changes)
./discover-services.sh --dry-run

# Verbose output
./discover-services.sh --verbose
```

### Using the Helper

```bash
# Quick health check
./discovery-helper.sh quick-check

# Pre-deployment verification
./discovery-helper.sh pre-deploy

# Post-deployment verification
./discovery-helper.sh post-deploy

# Debug mode
./discovery-helper.sh debug
```

## Detailed Usage

### SSH Connection

The script connects to your Hostinger VPS at `root@147.79.68.121`. Ensure you have:

1. SSH key configured for passwordless access
2. Root access to the VPS
3. Network connectivity to the VPS

### Service Discovery Process

1. **Baseline Information**
   - Server IP address
   - Open/listening ports
   - Docker services status
   - Docker Compose applications

2. **Endpoint Identification**
   - Priority A: Traefik with domain (HTTPS/HTTP)
   - Priority B: Traefik without domain (IP mode)
   - Priority C: Direct n8n port (5678)
   - Priority D: Direct static site port (80/8080)

3. **Firewall Verification**
   - UFW status and rules
   - Automatic port rule addition if needed
   - Cloud provider firewall notifications

4. **Health Checks**
   - HTTP/HTTPS endpoint testing
   - Multiple retry attempts
   - Alternative health endpoint testing
   - n8n authentication detection

5. **Automatic Fixes**
   - Port exposure in docker-compose.yml
   - UFW firewall rule addition
   - Port conflict resolution
   - Container restart if needed

### Output Format

The script provides a standardized output format:

```
=== OPEN THESE LINKS ===
http://147.79.68.121
http://147.79.68.121:5678

=== NOTES ===
• For HTTPS URLs: Click 'Advanced' → 'Proceed anyway' (self-signed certificate)
• To enable HTTPS with valid certificate, add domain and email to .env
```

## Configuration

### Environment Variables

The script reads configuration from `~/lumora-web/.env`:

- `DOMAIN` - Your domain name (empty for IP mode)
- `LE_EMAIL` - Let's Encrypt email (empty for IP mode)
- `N8N_PORT` - n8n port (default: 5678)

### Docker Compose

The script can automatically modify `docker-compose.yml` to expose required ports:

- n8n: `"5678:5678"`
- lumora-web: `"80:80"` (if not behind Traefik)

## Integration with Existing Scripts

### With Deployment Scripts

```bash
# Run discovery after deployment
./deploy-vps.sh && ./discover-services.sh

# Post-deployment verification
./deploy-complete.sh && ./discovery-helper.sh post-deploy
```

### With Verification Scripts

```bash
# Enhanced verification
./verify-deployment.sh && ./discover-services.sh
```

## Troubleshooting

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh root@147.79.68.121 "echo 'Connection test'"

# Check SSH key
ssh-add -l

# Manual key addition if needed
ssh-copy-id root@147.79.68.121
```

### Service Discovery Issues

```bash
# Run in debug mode
./discovery-helper.sh debug

# Check individual components
./discovery-helper.sh quick-check

# Validate script functionality
./validate-discovery.sh
```

### Common Issues

1. **SSH Permission Denied**
   - Ensure SSH key is properly configured
   - Check that root login is enabled on VPS

2. **Services Not Found**
   - Verify Docker containers are running
   - Check if services are properly deployed

3. **Port Access Issues**
   - Verify UFW firewall rules
   - Check cloud provider firewall settings
   - Ensure ports are exposed in docker-compose.yml

4. **Health Check Failures**
   - Services may still be starting up
   - Check container logs: `docker logs <container-name>`
   - Verify service configuration

## Advanced Usage

### Custom SSH Configuration

```bash
# Use custom SSH options
ssh -o ConnectTimeout=30 root@147.79.68.121 "$(cat discover-services.sh | grep -A 1000 'REMOTE_SCRIPT')"
```

### Scripted Integration

```bash
#!/bin/bash
# Deploy and verify in one go
set -euo pipefail

echo "Starting deployment..."
./deploy-vps.sh

echo "Waiting for services to stabilize..."
sleep 30

echo "Running service discovery..."
./discover-services.sh

echo "Deployment and verification complete!"
```

### Custom Health Checks

The script includes built-in health check endpoints:
- `/_health`
- `/health`
- `/status`
- `/rest`
- `/webhook`

## Security Considerations

- The script only makes safe modifications
- UFW rules are added, never removed
- No sensitive data is logged or transmitted
- All changes are reversible
- Dry-run mode available for testing

## Support

For issues or questions:

1. Run the validation script: `./validate-discovery.sh`
2. Check debug output: `./discovery-helper.sh debug`
3. Review the logs and error messages
4. Ensure all prerequisites are met

## Version History

- v1.0 - Initial release with comprehensive service discovery
- Features: SSH connection, endpoint discovery, health checks, automatic fixes