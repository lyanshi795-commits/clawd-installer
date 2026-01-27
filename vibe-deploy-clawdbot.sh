#!/usr/bin/env bash
#===============================================================================
#  ____  _____  ____  ____   ___  _____ 
# / ___||_   _|/ __ \|  _ \ / _ \|_   _|
# \___ \  | | | |  | | |_) | | | | | |  
#  ___) | | | | |__| |  _ <| |_| | | |  
# |____/  |_|  \____/|_| \_\\___/  |_|  
#                                        
#  CLAWDBOT ONE-CLICK DEPLOYMENT KIT
#  Version: 2026.1.24
#  For Ubuntu 24.04 LTS
#===============================================================================

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------------------------------
# CONSTANTS & CONFIGURATION
#-------------------------------------------------------------------------------
readonly SCRIPT_VERSION="2026.1.24"
readonly CLAWDBOT_USER="clawduser"
readonly CLAWDBOT_HOME="/home/${CLAWDBOT_USER}"
readonly CLAWDBOT_DIR="${CLAWDBOT_HOME}/clawdbot"
readonly LOG_FILE="/var/log/clawdbot-install.log"
readonly MIN_RAM_MB=2048
readonly SWAP_SIZE_MB=2048
readonly NODE_VERSION="22"

#-------------------------------------------------------------------------------
# COLOR DEFINITIONS
#-------------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

#-------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#-------------------------------------------------------------------------------
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $*" | tee -a "${LOG_FILE}"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $*"
    log "[INFO] $*"
}

success() {
    echo -e "${GREEN}[✓]${NC} $*"
    log "[SUCCESS] $*"
}

warn() {
    echo -e "${YELLOW}[⚠]${NC} $*"
    log "[WARN] $*"
}

error() {
    echo -e "${RED}[✗]${NC} $*" >&2
    log "[ERROR] $*"
}

fatal() {
    error "$*"
    echo -e "${RED}Installation aborted. Check ${LOG_FILE} for details.${NC}"
    exit 1
}

#-------------------------------------------------------------------------------
# UI HELPER FUNCTIONS
#-------------------------------------------------------------------------------
banner() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║     ██████╗██╗      █████╗ ██╗    ██╗██████╗ ██████╗  ██████╗ ████████╗  ║
║    ██╔════╝██║     ██╔══██╗██║    ██║██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝  ║
║    ██║     ██║     ███████║██║ █╗ ██║██║  ██║██████╔╝██║   ██║   ██║     ║
║    ██║     ██║     ██╔══██║██║███╗██║██║  ██║██╔══██╗██║   ██║   ██║     ║
║    ╚██████╗███████╗██║  ██║╚███╔███╔╝██████╔╝██████╔╝╚██████╔╝   ██║     ║
║     ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝     ║
║                                                                           ║
║              🤖 One-Click Deployment Kit v2026.1.24 🤖                   ║
║                  Secure 24/7 AI Agent for Telegram                        ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

step_header() {
    local step_num="$1"
    local step_title="$2"
    echo ""
    separator
    echo -e "${BOLD}${WHITE}  STEP ${step_num}: ${step_title}${NC}"
    separator
}

prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    
    echo -e "${CYAN}${prompt_text}${NC}"
    if [[ "$is_secret" == "true" ]]; then
        read -rsp "> " "$var_name"
        echo ""
    else
        read -rp "> " "$var_name"
    fi
}

confirm() {
    local prompt="$1"
    local response
    echo -e "${YELLOW}${prompt} [y/N]${NC}"
    read -rp "> " response
    [[ "$response" =~ ^[Yy]$ ]]
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps -p "$pid" > /dev/null 2>&1; do
        for i in $(seq 0 9); do
            echo -ne "\r${CYAN}[${spinstr:$i:1}]${NC} Processing..."
            sleep $delay
        done
    done
    echo -ne "\r"
}

#-------------------------------------------------------------------------------
# SYSTEM CHECK FUNCTIONS
#-------------------------------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "This script must be run as root. Please use: sudo $0"
    fi
}

check_os() {
    info "Checking operating system..."
    
    if [[ ! -f /etc/os-release ]]; then
        fatal "Cannot detect operating system. /etc/os-release not found."
    fi
    
    source /etc/os-release
    
    if [[ "$ID" != "ubuntu" ]]; then
        fatal "This script is designed for Ubuntu. Detected: $ID"
    fi
    
    if [[ "${VERSION_ID}" != "24.04" ]]; then
        warn "This script is optimized for Ubuntu 24.04. Detected: ${VERSION_ID}"
        if ! confirm "Continue anyway?"; then
            exit 0
        fi
    fi
    
    success "Operating system verified: Ubuntu ${VERSION_ID}"
}

check_network() {
    info "Checking network connectivity..."
    
    if ! ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        fatal "No network connectivity. Please check your internet connection."
    fi
    
    if ! ping -c 1 -W 5 registry.npmjs.org &> /dev/null; then
        warn "Cannot reach npm registry. DNS might be misconfigured."
    fi
    
    success "Network connectivity verified"
}

check_ram_and_swap() {
    info "Checking system memory..."
    
    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_mb=$((total_ram_kb / 1024))
    
    info "Total RAM: ${total_ram_mb}MB"
    
    if [[ $total_ram_mb -lt $MIN_RAM_MB ]]; then
        warn "RAM is below ${MIN_RAM_MB}MB. Creating ${SWAP_SIZE_MB}MB swap file..."
        
        if [[ -f /swapfile ]]; then
            warn "Swap file already exists. Checking size..."
            local current_swap_mb
            current_swap_mb=$(($(stat -c%s /swapfile) / 1024 / 1024))
            if [[ $current_swap_mb -ge $SWAP_SIZE_MB ]]; then
                success "Existing swap file is sufficient (${current_swap_mb}MB)"
                return
            fi
            warn "Existing swap is too small. Recreating..."
            swapoff /swapfile 2>/dev/null || true
            rm -f /swapfile
        fi
        
        # Create swap file
        dd if=/dev/zero of=/swapfile bs=1M count=${SWAP_SIZE_MB} status=progress
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        
        # Make swap permanent
        if ! grep -q "swapfile" /etc/fstab; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
        
        success "Swap file created and activated (${SWAP_SIZE_MB}MB)"
    else
        success "RAM is sufficient (${total_ram_mb}MB)"
    fi
}

preflight_check() {
    step_header "0" "PRE-FLIGHT CHECKS"
    
    check_root
    check_os
    check_network
    check_ram_and_swap
    
    echo ""
    success "All pre-flight checks passed!"
    echo ""
}

#-------------------------------------------------------------------------------
# INSTALLATION FUNCTIONS
#-------------------------------------------------------------------------------
install_system_packages() {
    step_header "1" "SYSTEM SANITIZATION"
    
    info "Updating package lists..."
    apt-get update -qq
    
    info "Upgrading existing packages..."
    apt-get upgrade -y -qq
    
    info "Installing essential packages..."
    apt-get install -y -qq \
        curl \
        git \
        unzip \
        build-essential \
        ca-certificates \
        gnupg \
        lsb-release \
        whiptail \
        jq
    
    success "System packages installed"
}

install_docker() {
    step_header "2" "DOCKER ENGINE INSTALLATION"
    
    if command -v docker &> /dev/null; then
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        info "Docker already installed (version: ${docker_version})"
        
        if ! confirm "Reinstall Docker?"; then
            success "Keeping existing Docker installation"
            return
        fi
    fi
    
    info "Setting up Docker repository..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    info "Installing Docker Engine..."
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    success "Docker Engine installed and running"
}

install_nvm_and_node() {
    step_header "3" "NODE.JS INSTALLATION"
    
    info "Installing NVM (Node Version Manager)..."
    
    # Install NVM for the clawdbot user (will be created later)
    export NVM_DIR="/opt/nvm"
    mkdir -p "$NVM_DIR"
    
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    
    # Load NVM
    export NVM_DIR="/opt/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    info "Installing Node.js v${NODE_VERSION}..."
    nvm install "${NODE_VERSION}"
    nvm use "${NODE_VERSION}"
    nvm alias default "${NODE_VERSION}"
    
    # Make Node.js available system-wide
    ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/node" /usr/local/bin/node
    ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/npm" /usr/local/bin/npm
    ln -sf "$NVM_DIR/versions/node/$(nvm current)/bin/npx" /usr/local/bin/npx
    
    local node_version
    node_version=$(node --version)
    success "Node.js ${node_version} installed"
}

create_clawdbot_user() {
    step_header "4" "SECURE USER SETUP"
    
    if id "${CLAWDBOT_USER}" &>/dev/null; then
        info "User '${CLAWDBOT_USER}' already exists"
    else
        info "Creating dedicated user '${CLAWDBOT_USER}'..."
        useradd -m -s /bin/bash "${CLAWDBOT_USER}"
        success "User '${CLAWDBOT_USER}' created"
    fi
    
    # Add user to docker group
    info "Adding '${CLAWDBOT_USER}' to docker group..."
    usermod -aG docker "${CLAWDBOT_USER}"
    
    # Create clawdbot directory
    mkdir -p "${CLAWDBOT_DIR}"
    chown -R "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_DIR}"
    
    # Set up NVM for the user
    mkdir -p "${CLAWDBOT_HOME}/.nvm"
    cp -r /opt/nvm/* "${CLAWDBOT_HOME}/.nvm/"
    chown -R "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_HOME}/.nvm"
    
    # Add NVM to user's bashrc
    cat >> "${CLAWDBOT_HOME}/.bashrc" << 'EOF'

# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
    
    success "User environment configured"
}

install_clawdbot() {
    step_header "5" "CLAWDBOT INSTALLATION"
    
    info "Installing Clawdbot globally..."
    
    # Install as clawdbot user
    su - "${CLAWDBOT_USER}" << 'INSTALL_EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install -g clawdbot@latest
INSTALL_EOF
    
    success "Clawdbot installed successfully"
}

#-------------------------------------------------------------------------------
# CONFIGURATION FUNCTIONS
#-------------------------------------------------------------------------------
collect_api_keys() {
    step_header "6" "API CONFIGURATION"
    
    echo -e "${WHITE}Please provide your API credentials.${NC}"
    echo -e "${YELLOW}These will be stored securely in ${CLAWDBOT_DIR}/.env${NC}"
    echo ""
    
    # Check if whiptail is available for better UI
    if command -v whiptail &> /dev/null; then
        TELEGRAM_BOT_TOKEN=$(whiptail --passwordbox "Enter your Telegram Bot Token:" 8 60 3>&1 1>&2 2>&3)
        CLAUDE_API_KEY=$(whiptail --passwordbox "Enter your Claude API Key:" 8 60 3>&1 1>&2 2>&3)
        ALLOWED_USER_IDS=$(whiptail --inputbox "Enter allowed Telegram User IDs (comma-separated):" 8 60 3>&1 1>&2 2>&3)
    else
        prompt_input "Enter your Telegram Bot Token (from @BotFather):" TELEGRAM_BOT_TOKEN true
        prompt_input "Enter your Claude API Key (sk-ant-...):" CLAUDE_API_KEY true
        prompt_input "Enter allowed Telegram User IDs (comma-separated):" ALLOWED_USER_IDS false
    fi
    
    # Validate inputs
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        fatal "Telegram Bot Token is required"
    fi
    
    if [[ -z "$CLAUDE_API_KEY" ]]; then
        fatal "Claude API Key is required"
    fi
    
    if [[ -z "$ALLOWED_USER_IDS" ]]; then
        warn "No allowed user IDs specified. Bot will be accessible to everyone!"
        if ! confirm "Continue without user restrictions?"; then
            prompt_input "Enter allowed Telegram User IDs (comma-separated):" ALLOWED_USER_IDS false
        fi
    fi
    
    success "API credentials collected"
}

create_env_file() {
    info "Creating .env configuration file..."
    
    cat > "${CLAWDBOT_DIR}/.env" << EOF
#===============================================================================
# CLAWDBOT ENVIRONMENT CONFIGURATION
# Generated by vibe-deploy-clawdbot.sh v${SCRIPT_VERSION}
# Generated at: $(date -Iseconds)
#===============================================================================

# Telegram Bot Token (from @BotFather)
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}

# Claude API Key (from console.anthropic.com)
CLAUDE_API_KEY=${CLAUDE_API_KEY}

# Allowed Telegram User IDs (comma-separated)
# Only these users can interact with the bot
ALLOWED_USER_IDS=${ALLOWED_USER_IDS}

# Logging level (debug, info, warn, error)
LOG_LEVEL=info

# Bot behavior settings
MAX_CONVERSATION_LENGTH=50
RESPONSE_TIMEOUT_MS=120000
EOF

    # Secure the env file
    chown "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_DIR}/.env"
    chmod 600 "${CLAWDBOT_DIR}/.env"
    
    success ".env file created and secured"
}

create_config_json() {
    info "Creating config.json with sandbox mode..."
    
    cat > "${CLAWDBOT_DIR}/config.json" << EOF
{
  "version": "${SCRIPT_VERSION}",
  "sandbox": "docker",
  "docker": {
    "image": "clawdbot/sandbox:latest",
    "network": "clawdbot-network",
    "memoryLimit": "512m",
    "cpuLimit": "0.5",
    "readonlyRootfs": true,
    "noNewPrivileges": true,
    "capabilities": {
      "drop": ["ALL"]
    }
  },
  "security": {
    "allowedCommands": [
      "ls", "cat", "head", "tail", "grep", "find",
      "wc", "sort", "uniq", "echo", "date", "pwd"
    ],
    "blockedPaths": [
      "/etc/shadow",
      "/etc/passwd",
      "/root",
      "/home"
    ],
    "maxOutputLength": 10000,
    "commandTimeout": 30000
  },
  "telegram": {
    "parseMode": "Markdown",
    "disableWebPreview": true
  },
  "claude": {
    "model": "claude-sonnet-4-20250514",
    "maxTokens": 4096,
    "temperature": 0.7
  },
  "logging": {
    "directory": "./logs",
    "maxFiles": 10,
    "maxSize": "10m"
  }
}
EOF

    chown "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_DIR}/config.json"
    chmod 644 "${CLAWDBOT_DIR}/config.json"
    
    success "config.json created with Docker sandbox mode enabled"
}

#-------------------------------------------------------------------------------
# SYSTEMD SERVICE SETUP
#-------------------------------------------------------------------------------
setup_systemd_service() {
    step_header "7" "PERSISTENCE & RESILIENCE"
    
    info "Enabling lingering for ${CLAWDBOT_USER}..."
    loginctl enable-linger "${CLAWDBOT_USER}"
    
    info "Creating systemd user service..."
    
    # Create user systemd directory
    local service_dir="${CLAWDBOT_HOME}/.config/systemd/user"
    mkdir -p "${service_dir}"
    
    cat > "${service_dir}/clawdbot.service" << EOF
[Unit]
Description=Clawdbot Telegram AI Agent
Documentation=https://github.com/clawdbot/clawdbot
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${CLAWDBOT_DIR}
ExecStart=/usr/local/bin/node \$(which clawdbot) start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clawdbot

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
ReadWritePaths=${CLAWDBOT_DIR}

# Environment
Environment=NODE_ENV=production
EnvironmentFile=${CLAWDBOT_DIR}/.env

[Install]
WantedBy=default.target
EOF

    chown -R "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_HOME}/.config"
    
    # Enable the service as the clawdbot user
    su - "${CLAWDBOT_USER}" << 'SERVICE_EOF'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload
systemctl --user enable clawdbot.service
SERVICE_EOF
    
    success "Systemd service configured"
    
    # Create convenience scripts
    info "Creating management scripts..."
    
    cat > "${CLAWDBOT_DIR}/start.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user start clawdbot.service
systemctl --user status clawdbot.service
EOF

    cat > "${CLAWDBOT_DIR}/stop.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user stop clawdbot.service
EOF

    cat > "${CLAWDBOT_DIR}/status.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user status clawdbot.service
echo ""
echo "=== Recent Logs ==="
journalctl --user -u clawdbot.service -n 20 --no-pager
EOF

    cat > "${CLAWDBOT_DIR}/logs.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
journalctl --user -u clawdbot.service -f
EOF

    chmod +x "${CLAWDBOT_DIR}"/*.sh
    chown -R "${CLAWDBOT_USER}:${CLAWDBOT_USER}" "${CLAWDBOT_DIR}"
    
    success "Management scripts created"
}

#-------------------------------------------------------------------------------
# DOCKER NETWORK SETUP
#-------------------------------------------------------------------------------
setup_docker_network() {
    info "Setting up Docker network for sandbox..."
    
    if docker network inspect clawdbot-network &>/dev/null; then
        info "Docker network 'clawdbot-network' already exists"
    else
        docker network create --driver bridge clawdbot-network
        success "Docker network 'clawdbot-network' created"
    fi
    
    # Pull sandbox image
    info "Pulling Clawdbot sandbox image..."
    docker pull clawdbot/sandbox:latest || warn "Could not pull sandbox image. Will be pulled on first run."
}

#-------------------------------------------------------------------------------
# FINAL STEPS
#-------------------------------------------------------------------------------
start_clawdbot() {
    step_header "8" "STARTING CLAWDBOT"
    
    info "Starting Clawdbot service..."
    
    su - "${CLAWDBOT_USER}" << 'START_EOF'
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user start clawdbot.service
sleep 3
systemctl --user status clawdbot.service --no-pager
START_EOF
    
    success "Clawdbot is now running!"
}

print_summary() {
    echo ""
    separator
    echo -e "${GREEN}${BOLD}"
    cat << 'EOF'
    
    ✅ INSTALLATION COMPLETE!
    
EOF
    echo -e "${NC}"
    separator
    echo ""
    echo -e "${WHITE}📍 Installation Details:${NC}"
    echo -e "   • User:           ${CYAN}${CLAWDBOT_USER}${NC}"
    echo -e "   • Directory:      ${CYAN}${CLAWDBOT_DIR}${NC}"
    echo -e "   • Config:         ${CYAN}${CLAWDBOT_DIR}/config.json${NC}"
    echo -e "   • Environment:    ${CYAN}${CLAWDBOT_DIR}/.env${NC}"
    echo -e "   • Sandbox Mode:   ${GREEN}Docker (Secure)${NC}"
    echo ""
    echo -e "${WHITE}🔧 Management Commands:${NC}"
    echo -e "   • View status:    ${YELLOW}sudo -u ${CLAWDBOT_USER} ${CLAWDBOT_DIR}/status.sh${NC}"
    echo -e "   • View logs:      ${YELLOW}sudo -u ${CLAWDBOT_USER} ${CLAWDBOT_DIR}/logs.sh${NC}"
    echo -e "   • Stop service:   ${YELLOW}sudo -u ${CLAWDBOT_USER} ${CLAWDBOT_DIR}/stop.sh${NC}"
    echo -e "   • Start service:  ${YELLOW}sudo -u ${CLAWDBOT_USER} ${CLAWDBOT_DIR}/start.sh${NC}"
    echo ""
    echo -e "${WHITE}🔐 Security Notes:${NC}"
    echo -e "   • Running as non-root user for maximum security"
    echo -e "   • Docker sandbox prevents filesystem access"
    echo -e "   • Service will auto-restart on failure"
    echo -e "   • Service persists after SSH logout"
    echo ""
    echo -e "${WHITE}📝 Log File:${NC} ${LOG_FILE}"
    echo ""
    separator
    echo -e "${MAGENTA}🎉 Your Clawdbot is ready! Send a message to your Telegram bot to test.${NC}"
    separator
    echo ""
}

#-------------------------------------------------------------------------------
# CLEANUP HANDLER
#-------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Installation failed with exit code: $exit_code"
        error "Check the log file for details: ${LOG_FILE}"
    fi
}

trap cleanup EXIT

#-------------------------------------------------------------------------------
# MAIN EXECUTION
#-------------------------------------------------------------------------------
main() {
    # Initialize log file
    mkdir -p "$(dirname "${LOG_FILE}")"
    : > "${LOG_FILE}"
    chmod 644 "${LOG_FILE}"
    
    log "=========================================="
    log "Clawdbot Installation Started"
    log "Script Version: ${SCRIPT_VERSION}"
    log "=========================================="
    
    # Show banner
    clear
    banner
    
    echo -e "${WHITE}Welcome to the Clawdbot One-Click Deployment Kit!${NC}"
    echo -e "${CYAN}This script will set up a secure, 24/7 AI agent on your Ubuntu VPS.${NC}"
    echo ""
    
    if ! confirm "Ready to begin installation?"; then
        info "Installation cancelled by user"
        exit 0
    fi
    
    # Run installation steps
    preflight_check
    install_system_packages
    install_docker
    install_nvm_and_node
    create_clawdbot_user
    install_clawdbot
    collect_api_keys
    create_env_file
    create_config_json
    setup_docker_network
    setup_systemd_service
    start_clawdbot
    
    # Show summary
    print_summary
    
    log "Installation completed successfully"
}

# Run main function
main "$@"
