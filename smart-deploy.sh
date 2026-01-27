#!/usr/bin/env bash
#===============================================================================
#   _____ __  __          _____ _______   ____  ______ ____  _     ______   __
#  / ____|  \/  |   /\   |  __ \__   __| |  _ \|  ____|  _ \| |   / __ \ \ / /
# | (___ | \  / |  /  \  | |__) | | |    | | | | |__  | |_) | |  | |  | \ V / 
#  \___ \| |\/| | / /\ \ |  _  /  | |    | | | |  __| |  __/| |  | |  | |> <  
#  ____) | |  | |/ ____ \| | \ \  | |    | |_| | |____| |   | |__| |__| / . \ 
# |_____/|_|  |_/_/    \_\_|  \_\ |_|    |____/|______|_|   |_____\____/_/ \_\
#                                                                             
#  CLAWDBOT AGNOSTIC INTELLIGENT INSTALLER
#  Version: 2026.1.24
#  Supports: macOS (Intel/Apple Silicon) & Linux (Ubuntu/Debian)
#===============================================================================

set -euo pipefail
IFS=$'\n\t'

#-------------------------------------------------------------------------------
# CONSTANTS
#-------------------------------------------------------------------------------
readonly SCRIPT_VERSION="2026.1.24"
readonly CLAWDBOT_DIR="${HOME}/.clawdbot"
readonly CONFIG_DIR="${CLAWDBOT_DIR}/config"
readonly LOG_DIR="${CLAWDBOT_DIR}/logs"
readonly ENV_FILE="${CLAWDBOT_DIR}/.env"
readonly CONFIG_FILE="${CONFIG_DIR}/config.json"
readonly NODE_VERSION="22"

#-------------------------------------------------------------------------------
# COLOR PALETTE
#-------------------------------------------------------------------------------
readonly NC='\033[0m'           # No Color
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

# Status Colors
readonly GREEN='\033[0;32m'     # Success
readonly RED='\033[0;31m'       # Error
readonly YELLOW='\033[1;33m'    # Warning
readonly CYAN='\033[0;36m'      # Info

# Platform Colors
readonly BLUE='\033[0;34m'      # macOS specific
readonly MAGENTA='\033[0;35m'   # Linux VPS specific
readonly WHITE='\033[1;37m'     # Headers

# Emoji support check
if [[ "$(printf '\xE2\x9C\x93')" == "✓" ]]; then
    readonly EMOJI_CHECK="✅"
    readonly EMOJI_CROSS="❌"
    readonly EMOJI_WARN="⚠️"
    readonly EMOJI_MAC="🍎"
    readonly EMOJI_LINUX="🐧"
    readonly EMOJI_ROCKET="🚀"
    readonly EMOJI_LOCK="🔐"
    readonly EMOJI_GEAR="⚙️"
else
    readonly EMOJI_CHECK="[OK]"
    readonly EMOJI_CROSS="[X]"
    readonly EMOJI_WARN="[!]"
    readonly EMOJI_MAC="[MAC]"
    readonly EMOJI_LINUX="[LNX]"
    readonly EMOJI_ROCKET="[>>]"
    readonly EMOJI_LOCK="[*]"
    readonly EMOJI_GEAR="[#]"
fi

#-------------------------------------------------------------------------------
# ENVIRONMENT DETECTION VARIABLES
#-------------------------------------------------------------------------------
DETECTED_OS=""
DETECTED_ARCH=""
DETECTED_ENV=""          # "cloud" or "physical"
IS_MACOS=false
IS_LINUX=false
IS_ARM64=false
IS_X86_64=false
IS_CLOUD_VPS=false
NEEDS_SUDO=false

#-------------------------------------------------------------------------------
# LOGGING FUNCTIONS
#-------------------------------------------------------------------------------
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} - $*" >> "${LOG_DIR}/install.log" 2>/dev/null || true
}

info() {
    echo -e "${CYAN}[INFO]${NC} $*"
    log "[INFO] $*"
}

success() {
    echo -e "${GREEN}${EMOJI_CHECK}${NC} $*"
    log "[SUCCESS] $*"
}

warn() {
    echo -e "${YELLOW}${EMOJI_WARN}${NC} $*"
    log "[WARN] $*"
}

error() {
    echo -e "${RED}${EMOJI_CROSS}${NC} $*" >&2
    log "[ERROR] $*"
}

fatal() {
    error "$*"
    exit 1
}

mac_info() {
    echo -e "${BLUE}${EMOJI_MAC} [macOS]${NC} $*"
    log "[macOS] $*"
}

linux_info() {
    echo -e "${MAGENTA}${EMOJI_LINUX} [Linux]${NC} $*"
    log "[Linux] $*"
}

#-------------------------------------------------------------------------------
# UI HELPER FUNCTIONS
#-------------------------------------------------------------------------------
banner() {
    echo -e "${MAGENTA}"
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ██████╗██╗      █████╗ ██╗    ██╗██████╗ ██████╗  ██████╗ ████████╗        ║
║  ██╔════╝██║     ██╔══██╗██║    ██║██╔══██╗██╔══██╗██╔═══██╗╚══██╔══╝        ║
║  ██║     ██║     ███████║██║ █╗ ██║██║  ██║██████╔╝██║   ██║   ██║           ║
║  ██║     ██║     ██╔══██║██║███╗██║██║  ██║██╔══██╗██║   ██║   ██║           ║
║  ╚██████╗███████╗██║  ██║╚███╔███╔╝██████╔╝██████╔╝╚██████╔╝   ██║           ║
║   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ ╚═════╝ ╚═════╝  ╚═════╝    ╚═╝           ║
║                                                                               ║
║            ${EMOJI_ROCKET} Agnostic Intelligent Installer v2026.1.24 ${EMOJI_ROCKET}                ║
║                    Cross-Platform • Zero Config • Secure                      ║
╚═══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

separator() {
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

step_header() {
    local step_num="$1"
    local step_title="$2"
    local color="${3:-$WHITE}"
    echo ""
    separator
    echo -e "${BOLD}${color}  STEP ${step_num}: ${step_title}${NC}"
    separator
}

prompt_secret() {
    local prompt_text="$1"
    local var_name="$2"
    
    echo -e "${CYAN}${prompt_text}${NC}"
    read -rsp "  > " "$var_name"
    echo ""
}

prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    local default="${3:-}"
    
    if [[ -n "$default" ]]; then
        echo -e "${CYAN}${prompt_text} ${DIM}[${default}]${NC}"
    else
        echo -e "${CYAN}${prompt_text}${NC}"
    fi
    read -rp "  > " "$var_name"
    
    # Use default if empty
    if [[ -z "${!var_name}" && -n "$default" ]]; then
        eval "$var_name='$default'"
    fi
}

confirm() {
    local prompt="$1"
    local response
    echo -e "${YELLOW}${prompt} [y/N]${NC}"
    read -rp "  > " response
    [[ "$response" =~ ^[Yy]$ ]]
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps -p "$pid" > /dev/null 2>&1; do
        for i in $(seq 0 9); do
            printf "\r${CYAN}  [${spinstr:$i:1}]${NC} Processing..."
            sleep $delay
        done
    done
    printf "\r"
}

#-------------------------------------------------------------------------------
# ENVIRONMENT DETECTION (THE BRAIN)
#-------------------------------------------------------------------------------
detect_os() {
    local uname_out
    uname_out=$(uname -s)
    
    case "$uname_out" in
        Darwin*)
            DETECTED_OS="macOS"
            IS_MACOS=true
            ;;
        Linux*)
            DETECTED_OS="Linux"
            IS_LINUX=true
            ;;
        *)
            fatal "Unsupported operating system: $uname_out"
            ;;
    esac
}

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        arm64|aarch64)
            DETECTED_ARCH="arm64"
            IS_ARM64=true
            ;;
        x86_64|amd64)
            DETECTED_ARCH="x86_64"
            IS_X86_64=true
            ;;
        *)
            warn "Unknown architecture: $arch - defaulting to x86_64"
            DETECTED_ARCH="x86_64"
            IS_X86_64=true
            ;;
    esac
}

detect_environment() {
    # Check for virtualization indicators
    if $IS_LINUX; then
        # Check common virtualization indicators
        if [[ -f /sys/class/dmi/id/product_name ]]; then
            local product_name
            product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
            
            case "$product_name" in
                *"Virtual"*|*"VMware"*|*"KVM"*|*"QEMU"*|*"Xen"*|*"Droplet"*|*"Linode"*|*"Google Compute"*|*"Amazon EC2"*)
                    IS_CLOUD_VPS=true
                    DETECTED_ENV="cloud"
                    return
                    ;;
            esac
        fi
        
        # Check for hypervisor via cpuinfo
        if grep -qi "hypervisor" /proc/cpuinfo 2>/dev/null; then
            IS_CLOUD_VPS=true
            DETECTED_ENV="cloud"
            return
        fi
        
        # Check systemd-detect-virt
        if command -v systemd-detect-virt &>/dev/null; then
            local virt_type
            virt_type=$(systemd-detect-virt 2>/dev/null || echo "none")
            if [[ "$virt_type" != "none" ]]; then
                IS_CLOUD_VPS=true
                DETECTED_ENV="cloud"
                return
            fi
        fi
        
        # Default to cloud for Linux (most common use case)
        IS_CLOUD_VPS=true
        DETECTED_ENV="cloud"
    else
        # macOS is typically physical
        DETECTED_ENV="physical"
        IS_CLOUD_VPS=false
    fi
}

check_sudo_requirement() {
    if $IS_LINUX && $IS_CLOUD_VPS; then
        # Check if we can use sudo
        if sudo -n true 2>/dev/null; then
            NEEDS_SUDO=true
        elif [[ $EUID -eq 0 ]]; then
            NEEDS_SUDO=false
        else
            warn "Some operations may require sudo access"
            NEEDS_SUDO=true
        fi
    fi
}

run_detection() {
    step_header "1" "ENVIRONMENT DETECTION" "$CYAN"
    
    info "Analyzing your system..."
    echo ""
    
    detect_os
    detect_architecture
    detect_environment
    check_sudo_requirement
    
    # Display detection results
    echo -e "  ${WHITE}Operating System:${NC}  ${GREEN}${DETECTED_OS}${NC}"
    echo -e "  ${WHITE}Architecture:${NC}      ${GREEN}${DETECTED_ARCH}${NC}"
    echo -e "  ${WHITE}Environment:${NC}       ${GREEN}${DETECTED_ENV}${NC}"
    
    if $IS_MACOS; then
        if $IS_ARM64; then
            echo -e "  ${WHITE}Chip:${NC}              ${GREEN}Apple Silicon (M-series)${NC}"
        else
            echo -e "  ${WHITE}Chip:${NC}              ${GREEN}Intel${NC}"
        fi
    fi
    
    echo ""
    
    if $IS_MACOS; then
        mac_info "Detected macOS - Will use Homebrew & LaunchAgents"
    else
        linux_info "Detected Linux VPS - Will use Docker sandbox & systemd"
    fi
    
    success "Environment detection complete"
}

#-------------------------------------------------------------------------------
# DIRECTORY SETUP
#-------------------------------------------------------------------------------
setup_directories() {
    info "Creating Clawdbot directories..."
    
    mkdir -p "${CLAWDBOT_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${LOG_DIR}"
    
    # Set strict permissions (especially important for macOS)
    chmod 700 "${CLAWDBOT_DIR}"
    chmod 700 "${CONFIG_DIR}"
    chmod 755 "${LOG_DIR}"
    
    success "Directories created with secure permissions"
}

#-------------------------------------------------------------------------------
# macOS SPECIFIC FUNCTIONS
#-------------------------------------------------------------------------------
install_homebrew() {
    mac_info "Checking Homebrew..."
    
    if command -v brew &>/dev/null; then
        local brew_version
        brew_version=$(brew --version | head -1)
        info "Homebrew already installed: ${brew_version}"
    else
        mac_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon
        if $IS_ARM64; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
        fi
        
        success "Homebrew installed"
    fi
}

install_node_macos() {
    mac_info "Installing Node.js v${NODE_VERSION}..."
    
    if command -v node &>/dev/null; then
        local current_version
        current_version=$(node --version | tr -d 'v' | cut -d. -f1)
        if [[ "$current_version" -ge "${NODE_VERSION}" ]]; then
            info "Node.js v$(node --version) already installed"
            return
        fi
    fi
    
    brew install "node@${NODE_VERSION}"
    brew link --force --overwrite "node@${NODE_VERSION}"
    
    success "Node.js v${NODE_VERSION} installed via Homebrew"
}

install_clawdbot_macos() {
    mac_info "Installing Clawdbot..."
    
    npm install -g clawdbot@latest
    
    success "Clawdbot installed globally"
}

create_launchagent() {
    mac_info "Creating LaunchAgent for persistence..."
    
    local launch_agents_dir="${HOME}/Library/LaunchAgents"
    local plist_file="${launch_agents_dir}/com.clawdbot.daemon.plist"
    
    mkdir -p "${launch_agents_dir}"
    
    # Get the path to clawdbot and node
    local clawdbot_path
    local node_path
    clawdbot_path=$(which clawdbot)
    node_path=$(which node)
    
    cat > "${plist_file}" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.clawdbot.daemon</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-ims</string>
        <string>${node_path}</string>
        <string>${clawdbot_path}</string>
        <string>start</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>${CLAWDBOT_DIR}</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
    
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/clawdbot.out.log</string>
    
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/clawdbot.err.log</string>
    
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOF

    # Load the LaunchAgent
    launchctl unload "${plist_file}" 2>/dev/null || true
    launchctl load "${plist_file}"
    
    success "LaunchAgent created with caffeinate anti-sleep wrapper"
    mac_info "Your Mac will stay awake while Clawdbot runs"
}

create_macos_management_scripts() {
    mac_info "Creating management scripts..."
    
    # Start script
    cat > "${CLAWDBOT_DIR}/start.sh" << 'EOF'
#!/bin/bash
launchctl load ~/Library/LaunchAgents/com.clawdbot.daemon.plist
echo "✅ Clawdbot started"
launchctl list | grep clawdbot
EOF

    # Stop script
    cat > "${CLAWDBOT_DIR}/stop.sh" << 'EOF'
#!/bin/bash
launchctl unload ~/Library/LaunchAgents/com.clawdbot.daemon.plist
echo "⏹️  Clawdbot stopped"
EOF

    # Status script
    cat > "${CLAWDBOT_DIR}/status.sh" << EOF
#!/bin/bash
echo "=== Clawdbot Service Status ==="
if launchctl list | grep -q clawdbot; then
    echo "✅ Status: Running"
    launchctl list | grep clawdbot
else
    echo "⏹️  Status: Stopped"
fi
echo ""
echo "=== Recent Logs ==="
tail -20 "${LOG_DIR}/clawdbot.out.log" 2>/dev/null || echo "No logs yet"
EOF

    # Logs script
    cat > "${CLAWDBOT_DIR}/logs.sh" << EOF
#!/bin/bash
tail -f "${LOG_DIR}/clawdbot.out.log" "${LOG_DIR}/clawdbot.err.log"
EOF

    chmod +x "${CLAWDBOT_DIR}"/*.sh
    
    success "Management scripts created"
}

run_macos_setup() {
    step_header "2" "macOS INSTALLATION" "$BLUE"
    
    install_homebrew
    install_node_macos
    install_clawdbot_macos
    create_macos_management_scripts
}

#-------------------------------------------------------------------------------
# LINUX VPS SPECIFIC FUNCTIONS
#-------------------------------------------------------------------------------
maybe_sudo() {
    if $NEEDS_SUDO && [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

install_docker_linux() {
    linux_info "Setting up Docker..."
    
    if command -v docker &>/dev/null; then
        local docker_version
        docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        info "Docker already installed: v${docker_version}"
        return
    fi
    
    linux_info "Installing Docker Engine..."
    
    # Update and install prerequisites
    maybe_sudo apt-get update -qq
    maybe_sudo apt-get install -y -qq \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    maybe_sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | maybe_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    maybe_sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | maybe_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    maybe_sudo apt-get update -qq
    maybe_sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    maybe_sudo usermod -aG docker "$USER"
    
    # Start Docker
    maybe_sudo systemctl start docker
    maybe_sudo systemctl enable docker
    
    success "Docker Engine installed"
}

install_node_linux() {
    linux_info "Installing Node.js v${NODE_VERSION}..."
    
    if command -v node &>/dev/null; then
        local current_version
        current_version=$(node --version | tr -d 'v' | cut -d. -f1)
        if [[ "$current_version" -ge "${NODE_VERSION}" ]]; then
            info "Node.js v$(node --version) already installed"
            return
        fi
    fi
    
    # Install via NodeSource
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | maybe_sudo bash -
    maybe_sudo apt-get install -y -qq nodejs
    
    success "Node.js v${NODE_VERSION} installed"
}

install_clawdbot_linux() {
    linux_info "Installing Clawdbot..."
    
    npm install -g clawdbot@latest
    
    success "Clawdbot installed globally"
}

configure_ufw() {
    linux_info "Configuring UFW firewall..."
    
    if ! command -v ufw &>/dev/null; then
        maybe_sudo apt-get install -y -qq ufw
    fi
    
    # Allow SSH first (critical!)
    maybe_sudo ufw allow 22/tcp
    
    # Enable UFW (non-interactive)
    echo "y" | maybe_sudo ufw enable
    
    success "UFW firewall configured (SSH allowed)"
}

setup_systemd_linux() {
    linux_info "Setting up systemd user service..."
    
    # Enable lingering for current user
    maybe_sudo loginctl enable-linger "$USER"
    
    # Create user systemd directory
    local service_dir="${HOME}/.config/systemd/user"
    mkdir -p "${service_dir}"
    
    # Get paths
    local node_path
    local clawdbot_path
    node_path=$(which node)
    clawdbot_path=$(which clawdbot)
    
    cat > "${service_dir}/clawdbot.service" << EOF
[Unit]
Description=Clawdbot Telegram AI Agent
Documentation=https://github.com/clawdbot/clawdbot
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${CLAWDBOT_DIR}
ExecStart=${node_path} ${clawdbot_path} start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clawdbot

# Security
NoNewPrivileges=true
PrivateTmp=true

# Environment
Environment=NODE_ENV=production
EnvironmentFile=${ENV_FILE}

[Install]
WantedBy=default.target
EOF

    # Reload and enable
    systemctl --user daemon-reload
    systemctl --user enable clawdbot.service
    
    success "systemd user service configured with lingering"
}

create_linux_management_scripts() {
    linux_info "Creating management scripts..."
    
    # Start script
    cat > "${CLAWDBOT_DIR}/start.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user start clawdbot.service
echo "✅ Clawdbot started"
systemctl --user status clawdbot.service --no-pager
EOF

    # Stop script
    cat > "${CLAWDBOT_DIR}/stop.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user stop clawdbot.service
echo "⏹️  Clawdbot stopped"
EOF

    # Status script
    cat > "${CLAWDBOT_DIR}/status.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
echo "=== Clawdbot Service Status ==="
systemctl --user status clawdbot.service --no-pager
echo ""
echo "=== Recent Logs ==="
journalctl --user -u clawdbot.service -n 20 --no-pager
EOF

    # Logs script
    cat > "${CLAWDBOT_DIR}/logs.sh" << 'EOF'
#!/bin/bash
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
journalctl --user -u clawdbot.service -f
EOF

    chmod +x "${CLAWDBOT_DIR}"/*.sh
    
    success "Management scripts created"
}

setup_docker_network() {
    linux_info "Setting up Docker sandbox network..."
    
    # Need to run docker commands in a new shell to pick up group membership
    if ! docker network inspect clawdbot-network &>/dev/null 2>&1; then
        maybe_sudo docker network create --driver bridge clawdbot-network
        success "Docker network 'clawdbot-network' created"
    else
        info "Docker network already exists"
    fi
}

run_linux_setup() {
    step_header "2" "LINUX VPS INSTALLATION" "$MAGENTA"
    
    install_docker_linux
    install_node_linux
    install_clawdbot_linux
    configure_ufw
    setup_docker_network
    setup_systemd_linux
    create_linux_management_scripts
}

#-------------------------------------------------------------------------------
# UNIFIED CONFIGURATION
#-------------------------------------------------------------------------------
collect_credentials() {
    step_header "3" "API CONFIGURATION" "$CYAN"
    
    echo -e "${WHITE}${EMOJI_LOCK} Let's configure your API credentials.${NC}"
    echo -e "${DIM}These will be stored securely in ${ENV_FILE}${NC}"
    echo ""
    
    # Telegram Bot Token
    prompt_secret "Enter your Telegram Bot Token (from @BotFather):" TELEGRAM_BOT_TOKEN
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        fatal "Telegram Bot Token is required"
    fi
    
    # Claude API Key
    prompt_secret "Enter your Claude API Key (sk-ant-...):" CLAUDE_API_KEY
    
    if [[ -z "$CLAUDE_API_KEY" ]]; then
        fatal "Claude API Key is required"
    fi
    
    # Allowed User IDs
    prompt_input "Enter allowed Telegram User IDs (comma-separated, or leave empty for all):" ALLOWED_USER_IDS ""
    
    if [[ -z "$ALLOWED_USER_IDS" ]]; then
        warn "No user restrictions - bot accessible to everyone"
    fi
    
    success "Credentials collected"
}

create_env_file() {
    info "Creating secure .env file..."
    
    cat > "${ENV_FILE}" << EOF
#===============================================================================
# CLAWDBOT ENVIRONMENT CONFIGURATION
# Generated by smart-deploy.sh v${SCRIPT_VERSION}
# Generated at: $(date -Iseconds)
# Platform: ${DETECTED_OS} (${DETECTED_ARCH})
#===============================================================================

# Telegram Bot Token (from @BotFather)
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}

# Claude API Key (from console.anthropic.com)
CLAUDE_API_KEY=${CLAUDE_API_KEY}

# Allowed Telegram User IDs (comma-separated)
ALLOWED_USER_IDS=${ALLOWED_USER_IDS:-}

# Logging level
LOG_LEVEL=info
EOF

    # Secure permissions
    chmod 600 "${ENV_FILE}"
    
    success ".env file created with secure permissions (600)"
}

create_config_json() {
    info "Creating config.json..."
    
    local sandbox_mode="none"
    if $IS_LINUX; then
        sandbox_mode="docker"
    fi
    
    cat > "${CONFIG_FILE}" << EOF
{
  "version": "${SCRIPT_VERSION}",
  "platform": "${DETECTED_OS}",
  "architecture": "${DETECTED_ARCH}",
  "sandbox": "${sandbox_mode}",
  "docker": {
    "enabled": ${IS_LINUX},
    "image": "clawdbot/sandbox:latest",
    "network": "clawdbot-network",
    "memoryLimit": "512m",
    "cpuLimit": "0.5"
  },
  "security": {
    "sandboxMode": "${sandbox_mode}",
    "restrictedPaths": ["/etc", "/root", "/var"],
    "allowedCommands": ["ls", "cat", "head", "tail", "grep", "echo", "date"]
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
    "directory": "${LOG_DIR}",
    "maxFiles": 10
  }
}
EOF

    chmod 644 "${CONFIG_FILE}"
    
    if $IS_LINUX; then
        linux_info "Docker sandbox mode enabled by default"
    else
        mac_info "Native execution mode (macOS sandboxing)"
    fi
    
    success "config.json created"
}

#-------------------------------------------------------------------------------
# SELF-HEALTH CHECK
#-------------------------------------------------------------------------------
run_health_check() {
    step_header "4" "SELF-HEALTH CHECK" "$GREEN"
    
    local all_passed=true
    
    echo -e "  ${WHITE}Checking installation...${NC}"
    echo ""
    
    # Check Node.js
    if command -v node &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Node.js: $(node --version)"
    else
        echo -e "  ${RED}✗${NC} Node.js: Not found"
        all_passed=false
    fi
    
    # Check npm
    if command -v npm &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} npm: $(npm --version)"
    else
        echo -e "  ${RED}✗${NC} npm: Not found"
        all_passed=false
    fi
    
    # Check Clawdbot
    if command -v clawdbot &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Clawdbot: Installed"
    else
        echo -e "  ${RED}✗${NC} Clawdbot: Not found"
        all_passed=false
    fi
    
    # Check Docker (Linux only)
    if $IS_LINUX; then
        if command -v docker &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
        else
            echo -e "  ${RED}✗${NC} Docker: Not found"
            all_passed=false
        fi
    fi
    
    # Check config files
    if [[ -f "${ENV_FILE}" ]]; then
        echo -e "  ${GREEN}✓${NC} .env file: Present (secure)"
    else
        echo -e "  ${RED}✗${NC} .env file: Missing"
        all_passed=false
    fi
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        echo -e "  ${GREEN}✓${NC} config.json: Present"
    else
        echo -e "  ${RED}✗${NC} config.json: Missing"
        all_passed=false
    fi
    
    # Check persistence
    echo ""
    echo -e "  ${WHITE}Checking persistence...${NC}"
    echo ""
    
    if $IS_MACOS; then
        if [[ -f "${HOME}/Library/LaunchAgents/com.clawdbot.daemon.plist" ]]; then
            echo -e "  ${GREEN}✓${NC} LaunchAgent: Configured"
        else
            echo -e "  ${YELLOW}○${NC} LaunchAgent: Not yet created"
        fi
    else
        if systemctl --user is-enabled clawdbot.service &>/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} systemd service: Enabled"
        else
            echo -e "  ${YELLOW}○${NC} systemd service: Not yet enabled"
        fi
    fi
    
    echo ""
    
    # API connectivity test
    info "Testing Telegram API connectivity..."
    
    local telegram_test
    telegram_test=$(curl -s -o /dev/null -w "%{http_code}" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe" 2>/dev/null || echo "000")
    
    if [[ "$telegram_test" == "200" ]]; then
        echo -e "  ${GREEN}✓${NC} Telegram API: Connected"
    elif [[ "$telegram_test" == "401" ]]; then
        echo -e "  ${RED}✗${NC} Telegram API: Invalid token"
        all_passed=false
    else
        echo -e "  ${YELLOW}○${NC} Telegram API: Could not verify (HTTP ${telegram_test})"
    fi
    
    # Claude API test
    info "Testing Claude API connectivity..."
    
    local claude_test
    claude_test=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "x-api-key: ${CLAUDE_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        "https://api.anthropic.com/v1/messages" 2>/dev/null || echo "000")
    
    if [[ "$claude_test" == "400" || "$claude_test" == "200" ]]; then
        # 400 is expected without a body, means auth worked
        echo -e "  ${GREEN}✓${NC} Claude API: Connected"
    elif [[ "$claude_test" == "401" ]]; then
        echo -e "  ${RED}✗${NC} Claude API: Invalid key"
        all_passed=false
    else
        echo -e "  ${YELLOW}○${NC} Claude API: Could not verify (HTTP ${claude_test})"
    fi
    
    echo ""
    
    if $all_passed; then
        success "All health checks passed!"
    else
        warn "Some checks failed - please review the output above"
    fi
}

#-------------------------------------------------------------------------------
# START SERVICE
#-------------------------------------------------------------------------------
start_service() {
    step_header "5" "STARTING CLAWDBOT" "$GREEN"
    
    if $IS_MACOS; then
        create_launchagent
        mac_info "Service started via LaunchAgent"
    else
        systemctl --user start clawdbot.service
        linux_info "Service started via systemd"
    fi
    
    sleep 2
    
    success "Clawdbot is now running!"
}

#-------------------------------------------------------------------------------
# FINAL SUMMARY
#-------------------------------------------------------------------------------
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
    echo -e "   • Platform:       ${CYAN}${DETECTED_OS} (${DETECTED_ARCH})${NC}"
    echo -e "   • Environment:    ${CYAN}${DETECTED_ENV}${NC}"
    echo -e "   • Directory:      ${CYAN}${CLAWDBOT_DIR}${NC}"
    echo -e "   • Config:         ${CYAN}${CONFIG_FILE}${NC}"
    echo -e "   • Secrets:        ${CYAN}${ENV_FILE}${NC}"
    
    if $IS_LINUX; then
        echo -e "   • Sandbox:        ${GREEN}Docker (Secure)${NC}"
    else
        echo -e "   • Anti-Sleep:     ${GREEN}caffeinate enabled${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}🔧 Management Commands:${NC}"
    echo -e "   • View status:    ${YELLOW}${CLAWDBOT_DIR}/status.sh${NC}"
    echo -e "   • View logs:      ${YELLOW}${CLAWDBOT_DIR}/logs.sh${NC}"
    echo -e "   • Stop service:   ${YELLOW}${CLAWDBOT_DIR}/stop.sh${NC}"
    echo -e "   • Start service:  ${YELLOW}${CLAWDBOT_DIR}/start.sh${NC}"
    
    echo ""
    separator
    echo -e "${MAGENTA}${EMOJI_ROCKET} Your Clawdbot is ready! Send a message to your Telegram bot to test.${NC}"
    separator
    echo ""
}

#-------------------------------------------------------------------------------
# CLEANUP
#-------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Installation failed with exit code: $exit_code"
        error "Check logs at: ${LOG_DIR}/install.log"
    fi
}

trap cleanup EXIT

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
main() {
    # Initialize logging early
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    log "=========================================="
    log "Smart Deploy Started"
    log "Script Version: ${SCRIPT_VERSION}"
    log "=========================================="
    
    clear
    banner
    
    echo -e "${WHITE}Welcome to the Clawdbot Agnostic Intelligent Installer!${NC}"
    echo -e "${CYAN}This script automatically detects your environment and configures everything.${NC}"
    echo ""
    
    if ! confirm "Ready to begin?"; then
        info "Installation cancelled"
        exit 0
    fi
    
    # Phase 0: Deep health check (using modular engine if available)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    if [[ -f "${script_dir}/lib/healthcheck.sh" ]]; then
        info "Loading health check module..."
        source "${script_dir}/lib/healthcheck.sh"
        run_full_healthcheck || {
            if ! confirm "Health check found issues. Continue anyway?"; then
                fatal "Installation aborted due to health check failures"
            fi
        }
        
        # Use health check results
        if $HEALTHCHECK_NEEDS_SWAP; then
            step_header "0.5" "SWAP CREATION" "$MAGENTA"
            linux_info "Creating 2GB swap file for low-memory VPS..."
            maybe_sudo fallocate -l 2G /swapfile 2>/dev/null || maybe_sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
            maybe_sudo chmod 600 /swapfile
            maybe_sudo mkswap /swapfile
            maybe_sudo swapon /swapfile
            if ! grep -q "swapfile" /etc/fstab 2>/dev/null; then
                echo "/swapfile none swap sw 0 0" | maybe_sudo tee -a /etc/fstab > /dev/null
            fi
            success "Swap file created and activated"
        fi
    else
        info "Health check module not found, using built-in detection"
    fi
    
    # Phase 1: Detection
    run_detection
    
    # Phase 2: Setup directories
    setup_directories
    
    # Phase 3: Platform-specific installation
    if $IS_MACOS; then
        run_macos_setup
    else
        run_linux_setup
    fi
    
    # Phase 4: Unified configuration
    collect_credentials
    create_env_file
    create_config_json
    
    # Phase 5: Health check
    run_health_check
    
    # Phase 6: Start service
    start_service
    
    # Show summary
    print_summary
    
    log "Installation completed successfully"
}

main "$@"
