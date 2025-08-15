#!/bin/bash

# n8n Management Scripts for Lumora
# Utility scripts for daily n8n maintenance

set -euo pipefail

case "${1:-help}" in
  "update")
    echo "Updating n8n safely..."
    cd /opt/solyntra
    docker compose pull
    docker compose up -d
    docker ps
    ;;
  
  "backup")
    echo "Backing up n8n data and files..."
    BACKUP_DATE=$(date +%F)
    
    # Backup n8n data volume
    docker run --rm -v n8n_data:/data -v /root:/backup alpine tar -czf /backup/n8n_data_${BACKUP_DATE}.tgz -C /data .
    
    # Backup files directory
    if [ -d /opt/solyntra/files ]; then
      tar -czf /root/n8n_files_${BACKUP_DATE}.tgz -C /opt/solyntra files
    fi
    
    echo "Backups created:"
    echo "  - /root/n8n_data_${BACKUP_DATE}.tgz"
    echo "  - /root/n8n_files_${BACKUP_DATE}.tgz"
    ;;
  
  "logs")
    echo "Recent n8n logs:"
    docker logs n8n --since 10m
    ;;
  
  "status")
    echo "n8n service status:"
    systemctl status n8n-compose.service --no-pager
    echo ""
    echo "Container status:"
    docker ps | grep n8n || echo "No n8n containers running"
    ;;
  
  "restart")
    echo "Restarting n8n..."
    cd /opt/solyntra
    docker compose down
    docker compose up -d
    echo "n8n restarted"
    ;;
  
  "reset-user")
    echo "Resetting n8n user management..."
    docker exec -it n8n n8n user-management:reset
    ;;
  
  "enable-watchtower")
    echo "Enabling nightly auto-updates with watchtower..."
    cd /opt/solyntra
    # Uncomment watchtower service in docker-compose.yml
    sed -i '/# watchtower:/,/# restart: unless-stopped/ s/^  #/  /' docker-compose.yml
    docker compose up -d
    echo "Watchtower enabled for nightly updates at 03:00"
    ;;
  
  "disable-watchtower")
    echo "Disabling watchtower auto-updates..."
    cd /opt/solyntra
    # Comment watchtower service in docker-compose.yml
    sed -i '/watchtower:/,/restart: unless-stopped/ s/^  /  #/' docker-compose.yml
    docker compose up -d
    echo "Watchtower disabled"
    ;;
  
  "info")
    IP=$(hostname -I | awk '{print $1}')
    echo "n8n Information:"
    echo "  URL: http://${IP}:5678/"
    echo "  Container: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep n8n || echo 'Not running')"
    echo "  Service: $(systemctl is-active n8n-compose.service)"
    echo ""
    echo "Recent User Management logs:"
    docker logs n8n --since 10m | grep -i 'User management' -n || echo "No recent user management logs"
    ;;
  
  "help"|*)
    echo "n8n Management Script for Lumora"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Available commands:"
    echo "  update             - Update n8n to latest version safely"
    echo "  backup             - Backup n8n data and files"
    echo "  logs               - Show recent n8n logs"
    echo "  status             - Show service and container status"
    echo "  restart            - Restart n8n container"
    echo "  reset-user         - Reset n8n user management"
    echo "  enable-watchtower  - Enable nightly auto-updates"
    echo "  disable-watchtower - Disable auto-updates"
    echo "  info               - Show n8n information and access URL"
    echo "  help               - Show this help message"
    ;;
esac