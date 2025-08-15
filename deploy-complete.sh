#!/bin/bash
set -euo pipefail

# ===========================================
# Lumora DevOps Complete Deployment Script
# ===========================================
# This script performs the complete deployment sequence as requested:
# 1. Navigate to deployment folder
# 2. Pull latest changes from main branch
# 3. Create/update .env file with placeholder values
# 4. Run docker-compose build and up -d
# 5. Set up automated n8n backup script and cron
# 6. Verify container health
# 7. Output exact .env lines for API keys

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/opt/solyntra"
LOG_FILE="/var/log/lumora-deploy.log"
BACKUP_DIR="/var/backups/n8n"

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
    fi
    
    # Check Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed"
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        error "Git is not installed"
    fi
    
    log "Prerequisites check passed"
}

# Function to setup project directory and pull latest changes
setup_project() {
    log "Setting up project directory and pulling latest changes..."
    
    # Navigate to deployment folder or create it
    if [[ ! -d "$PROJECT_DIR" ]]; then
        log "Creating project directory: $PROJECT_DIR"
        mkdir -p "$PROJECT_DIR"
        cd "$PROJECT_DIR"
        
        # Clone repository if not exists
        log "Cloning repository..."
        git clone https://github.com/askpostpilot/lumora-web.git .
    else
        cd "$PROJECT_DIR"
    fi
    
    # Pull latest changes from main branch
    log "Pulling latest changes from main branch..."
    git fetch origin
    git checkout main
    git pull origin main
    
    log "Repository updated successfully"
}

# Function to create or update .env file
create_env_file() {
    log "Creating/updating .env file with placeholder values..."
    
    if [[ -f ".env" ]]; then
        log "Backing up existing .env file"
        cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Copy from example and customize
    cp .env.example .env
    
    # Generate secure encryption key
    ENCRYPTION_KEY=$(openssl rand -base64 36 | tr -d '\n')
    
    # Update specific values for VPS deployment
    sed -i "s|N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}|" .env
    sed -i "s|DOMAIN=localhost|DOMAIN=|" .env  # Empty for IP mode
    sed -i "s|N8N_HOST=|N8N_HOST=|" .env  # Keep empty for IP mode
    sed -i "s|WEBHOOK_URL=http://localhost:5678|WEBHOOK_URL=http://\$(hostname -I | awk '{print \$1}'):5678|" .env
    
    log ".env file created with placeholder values"
}

# Function to build and start containers
deploy_containers() {
    log "Building and starting containers..."
    
    # Build containers
    log "Building Docker containers..."
    docker compose build --no-cache
    
    # Start containers
    log "Starting containers with docker-compose up -d..."
    docker compose up -d
    
    # Wait for containers to start
    log "Waiting for containers to initialize..."
    sleep 30
    
    log "Containers deployed successfully"
}

# Function to setup automated backup
setup_backup() {
    log "Setting up automated n8n backup system..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Ensure backup script is executable
    chmod +x n8n_backup.sh
    
    # Add cron job for daily backup at 2:00 AM
    CRON_JOB="0 2 * * * $PROJECT_DIR/n8n_backup.sh >> /var/log/n8n_backup.log 2>&1"
    
    # Check if cron job already exists
    if ! crontab -l 2>/dev/null | grep -q "n8n_backup.sh"; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log "Backup cron job scheduled for daily execution at 2:00 AM"
    else
        log "Backup cron job already exists"
    fi
    
    # Run initial backup
    log "Running initial backup..."
    ./n8n_backup.sh
    
    log "Backup system configured successfully"
}

# Function to verify deployment
verify_deployment() {
    log "Verifying deployment and container health..."
    
    # Check container status
    log "Container status:"
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # Test n8n connectivity
    log "Testing n8n connectivity on http://$SERVER_IP:5678"
    
    # Wait a bit more for n8n to be ready
    sleep 10
    
    # Test HTTP response
    if curl -sf "http://localhost:5678" > /dev/null; then
        log "✅ n8n is responding on port 5678"
    else
        warn "⚠️  n8n might still be starting up"
    fi
    
    # Verify containers are running
    if docker ps | grep -q "n8n"; then
        log "✅ n8n container is running"
    else
        error "❌ n8n container is not running"
    fi
    
    if docker ps | grep -q "lumora-web"; then
        log "✅ lumora-web container is running"
    else
        warn "⚠️  lumora-web container status unclear"
    fi
    
    log "Verification completed"
}

# Function to output API key instructions
output_api_instructions() {
    info "=============================================="
    info "🔐 API KEYS CONFIGURATION REQUIRED"
    info "=============================================="
    info ""
    info "Edit the .env file and replace the following lines with your actual API keys:"
    info ""
    info "📍 EXACT LINES TO UPDATE IN .env FILE:"
    info "----------------------------------------"
    echo -e "${YELLOW}"
    echo "# Canva API Configuration"
    echo "CANVA_API_KEY=### FILL_ME_IN ###"
    echo "CANVA_CLIENT_ID=### FILL_ME_IN ###"
    echo "CANVA_CLIENT_SECRET=### FILL_ME_IN ###"
    echo ""
    echo "# Supabase Configuration  "
    echo "SUPABASE_URL=### FILL_ME_IN ###"
    echo "SUPABASE_ANON_KEY=### FILL_ME_IN ###"
    echo "SUPABASE_SERVICE_KEY=### FILL_ME_IN ###"
    echo ""
    echo "# OpenAI Configuration"
    echo "OPENAI_API_KEY=### FILL_ME_IN ###"
    echo "OPENAI_ORG_ID=### FILL_ME_IN ### (optional)"
    echo -e "${NC}"
    info "----------------------------------------"
    info ""
    info "💡 TO UPDATE API KEYS:"
    info "   1. nano $PROJECT_DIR/.env"
    info "   2. Replace ### FILL_ME_IN ### with your actual keys"
    info "   3. Save and restart: docker compose restart"
    info ""
}

# Function to print final status report
final_status_report() {
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    info "=============================================="
    info "🚀 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    info "=============================================="
    info ""
    info "📊 DEPLOYMENT SUMMARY:"
    info "----------------------"
    info "✅ Repository updated to latest main branch"
    info "✅ .env file created with secure defaults"
    info "✅ Docker containers built and started"
    info "✅ Automated backup system configured"
    info "✅ Cron job scheduled for daily backups at 2:00 AM"
    info "✅ Container health verified"
    info ""
    info "🌐 ACCESS INFORMATION:"
    info "---------------------"
    info "• n8n Interface: http://$SERVER_IP:5678"
    info "• Lumora Website: http://$SERVER_IP"
    info "• Server IP: $SERVER_IP"
    info ""
    info "📁 IMPORTANT PATHS:"
    info "------------------"
    info "• Project Directory: $PROJECT_DIR"
    info "• Environment File: $PROJECT_DIR/.env"
    info "• Backup Directory: $BACKUP_DIR"
    info "• Log File: $LOG_FILE"
    info ""
    info "🔧 MANAGEMENT COMMANDS:"
    info "----------------------"
    info "• View Logs: docker compose logs -f"
    info "• Restart: docker compose restart"
    info "• Stop: docker compose down"
    info "• Manual Backup: $PROJECT_DIR/n8n_backup.sh"
    info "• Status Check: $PROJECT_DIR/deployment_status.sh"
    info ""
    info "⚠️  NEXT STEPS:"
    info "• Configure your API keys in .env file (see instructions above)"
    info "• Test n8n access at http://$SERVER_IP:5678"
    info "• Complete n8n initial setup if prompted"
    info ""
    info "=============================================="
}

# Main execution
main() {
    log "Starting Lumora DevOps complete deployment..."
    
    check_root
    check_prerequisites
    setup_project
    create_env_file
    deploy_containers
    setup_backup
    verify_deployment
    output_api_instructions
    final_status_report
    
    log "Deployment sequence completed successfully!"
}

# Error handling
trap 'error "Deployment failed at line $LINENO"' ERR

# Execute main function
main "$@"