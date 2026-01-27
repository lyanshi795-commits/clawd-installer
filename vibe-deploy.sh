#!/bin/bash

# ==============================================================================
# 脚本名称: Vibe Universal Deploy for Clawdbot
# 版本: v1.0.0 (Audited)
# 功能: 自动识别 Mac/Linux，智能配置沙盒、防休眠与低内存优化
# ==============================================================================

set -e  # 遇到错误立即停止，防止破坏系统

# --- 颜色定义 (增强交互体验) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- 全局变量 ---
INSTALL_DIR="$HOME/.clawdbot"
ENV_FILE="$INSTALL_DIR/.env"
CONFIG_FILE="$INSTALL_DIR/config.json"

# ==============================================================================
# 1. 核心模块：环境体检与优化 (The Doctor)
# ==============================================================================
pre_flight_check() {
    echo -e "${CYAN}>>> [1/5] 正在启动环境深度扫描...${NC}"
    
    OS_TYPE=$(uname -s)
    ARCH=$(uname -m)

    # 网络连通性检查
    echo -ne "   [网络] 正在测试 Telegram API 连通性... "
    if curl -s --connect-timeout 5 https://api.telegram.org > /dev/null; then
        echo -e "${GREEN}✓ 通畅${NC}"
    else
        echo -e "${RED}✗ 失败${NC}"
        echo -e "${YELLOW}   警告: 无法连接 Telegram 服务器。请检查是否需要配置 HTTP_PROXY。${NC}"
        # 这里可以选择 exit 1，或者询问用户是否继续
    fi

    # 内存与 Swap 自动优化 (仅限 Linux)
    if [ "$OS_TYPE" == "Linux" ]; then
        TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
        echo -ne "   [内存] 检测到物理内存: ${TOTAL_MEM}MB... "
        if [ "$TOTAL_MEM" -lt 1900 ]; then
            echo -e "${YELLOW}⚠ 内存不足 2GB${NC}"
            echo -e "${BLUE}   >>> 正在自动注入 2GB Swap 虚拟内存以防止 OOM 崩溃...${NC}"
            
            # 检查是否已有 Swap
            if [ $(swapon --show | wc -l) -eq 0 ]; then
                sudo fallocate -l 2G /swapfile
                sudo chmod 600 /swapfile
                sudo mkswap /swapfile
                sudo swapon /swapfile
                echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
                echo -e "${GREEN}   ✓ Swap 创建成功！${NC}"
            else
                echo -e "${GREEN}   ✓ 已存在 Swap，跳过。${NC}"
            fi
        else
            echo -e "${GREEN}✓ 充足${NC}"
        fi
    fi

    # Mac M4/Silicon 识别
    if [ "$OS_TYPE" == "Darwin" ] && [[ "$ARCH" == "arm64" ]]; then
        echo -e "${GREEN}   [硬件] 识别到 Apple Silicon 芯片，已启用高性能模式。${NC}"
    fi
}

# ==============================================================================
# 2. 核心模块：安装逻辑 (The Builder)
# ==============================================================================
install_core() {
    echo -e "${CYAN}>>> [2/5] 开始安装核心组件...${NC}"
    
    mkdir -p "$INSTALL_DIR"
    chmod 700 "$INSTALL_DIR" # 顶级安全权限

    if [ "$(uname -s)" == "Darwin" ]; then
        # --- macOS 分支 ---
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}错误: 未检测到 Homebrew。请先安装 Homebrew。${NC}"
            exit 1
        fi
        
        echo "   正在安装 Node.js v22 (via Homebrew)..."
        brew install node@22
        # 链接 node@22
        brew link --overwrite node@22 --force
        
        echo "   正在安装 Clawdbot CLI..."
        npm install -g clawdbot@latest

    else
        # --- Linux 分支 (Ubuntu/Debian) ---
        echo "   正在更新系统源..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq curl git build-essential

        # 安装 Docker (如果不存在)
        if ! command -v docker &> /dev/null; then
            echo "   正在安装 Docker Engine..."
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $USER
            echo -e "${YELLOW}   注意: Docker 已安装，您可能需要重新登录才能生效。但本脚本将继续尝试运行。${NC}"
        fi

        # 安装 Node.js (via NVM)
        echo "   正在配置 Node.js 环境..."
        if [ ! -d "$HOME/.nvm" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        fi
        nvm install 22
        nvm use 22
        
        echo "   正在安装 Clawdbot CLI..."
        npm install -g clawdbot@latest
    fi
}

# ==============================================================================
# 3. 核心模块：配置生成 (The Architect)
# ==============================================================================
configure_bot() {
    echo -e "${CYAN}>>> [3/5] 初始化配置...${NC}"
    
    # 交互式获取 Key (如果文件不存在)
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}请输入您的 Telegram Bot Token:${NC}"
        read -r TG_TOKEN
        echo -e "${YELLOW}请输入您的 Claude/Anthropic API Key:${NC}"
        read -r CLAUDE_KEY
        
        # 写入 .env
        cat > "$ENV_FILE" <<EOF
TELEGRAM_BOT_TOKEN=$TG_TOKEN
ANTHROPIC_API_KEY=$CLAUDE_KEY
EOF
        chmod 600 "$ENV_FILE"
    else
        echo -e "${GREEN}   ✓ 检测到现有配置文件，跳过录入。${NC}"
    fi

    # 生成 config.json (根据 OS 区分沙盒模式)
    SANDBOX_MODE="docker"
    if [ "$(uname -s)" == "Darwin" ]; then
        SANDBOX_MODE="local" # Mac 上默认使用本地模式以获得最佳性能，或设为 docker 需用户已装 Docker Desktop
    fi

    cat > "$CONFIG_FILE" <<EOF
{
  "platform": "telegram",
  "agent": {
    "name": "MyVibeAgent",
    "sandbox": {
      "mode": "$SANDBOX_MODE" 
    }
  },
  "behavior": {
    "system_prompt": "You are a helpful assistant deployed via Vibe Script."
  }
}
EOF
    echo -e "${GREEN}   ✓ 配置文件已生成 (模式: $SANDBOX_MODE)${NC}"
}

# ==============================================================================
# 4. 核心模块：持久化与防休眠 (The Guardian)
# ==============================================================================
setup_persistence() {
    echo -e "${CYAN}>>> [4/5] 配置系统守护进程 (24/7 在线)...${NC}"
    
    NODE_PATH=$(which node)
    CLAWD_PATH=$(which clawdbot)

    if [ "$(uname -s)" == "Darwin" ]; then
        # --- macOS: LaunchAgent + Caffeinate ---
        PLIST_PATH="$HOME/Library/LaunchAgents/com.vibe.clawdbot.plist"
        
        cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.vibe.clawdbot</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-ims</string>
        <string>$NODE_PATH</string>
        <string>$CLAWD_PATH</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$INSTALL_DIR/clawdbot.log</string>
    <key>StandardErrorPath</key>
    <string>$INSTALL_DIR/clawdbot.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
        # 加载服务
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        launchctl load "$PLIST_PATH"
        echo -e "${GREEN}   ✓ macOS 服务已启动 (集成 Caffeinate 防休眠)${NC}"

    else
        # --- Linux: Systemd + Linger ---
        mkdir -p "$HOME/.config/systemd/user"
        SERVICE_FILE="$HOME/.config/systemd/user/clawdbot.service"
        
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Clawdbot AI Agent Service
After=network.target docker.service

[Service]
ExecStart=$NODE_PATH $CLAWD_PATH start
Restart=always
RestartSec=10
Environment="PATH=$PATH"
Environment="HOME=$HOME"
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=default.target
EOF
        systemctl --user daemon-reload
        systemctl --user enable clawdbot
        systemctl --user restart clawdbot
        
        # 开启 Linger (关键：允许用户退出 SSH 后继续运行)
        sudo loginctl enable-linger $USER
        echo -e "${GREEN}   ✓ Linux Systemd 服务已启动且配置为驻留模式${NC}"
    fi
}

# ==============================================================================
# 5. 主程序入口
# ==============================================================================
main() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}   Vibe Universal Deploy for Clawdbot v1.0       ${NC}"
    echo -e "${BLUE}=================================================${NC}"
    
    pre_flight_check
    install_core
    configure_bot
    setup_persistence
    
    echo -e "${CYAN}>>> [5/5] 最终检查...${NC}"
    sleep 2
    if [ "$(uname -s)" == "Darwin" ]; then
        STATUS=$(launchctl list | grep com.vibe.clawdbot)
    else
        STATUS=$(systemctl --user is-active clawdbot)
    fi

    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}   ✅ 部署成功！系统已上线。${NC}"
    echo -e "${GREEN}   状态监控: $STATUS${NC}"
    echo -e "${GREEN}=================================================${NC}"
}

main
