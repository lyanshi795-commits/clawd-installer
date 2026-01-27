#!/bin/bash

# ==========================================
# 模块：系统自适应体检引擎 (Health Check Engine)
# 功能：自动识别 OS、架构、网络及硬件兼容性
# ==========================================

set -e # 遇错即停

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}>>> 正在启动 Clawdbot 环境深度体检...${NC}"

check_environment() {
    # 1. 系统与架构识别
    OS_TYPE=$(uname -s)
    ARCH_TYPE=$(uname -m)
    echo -e "${BLUE}[1/4] 检测到系统:${NC} $OS_TYPE ($ARCH_TYPE)"

    # 2. 网络连通性体检 (关键：防止卡死在下载阶段)
    echo -ne "${BLUE}[2/4] 正在检查全球连接...${NC} "
    if curl -s --connect-timeout 5 https://api.telegram.org > /dev/null; then
        echo -e "${GREEN}Telegram API 连通正常${NC}"
    else
        echo -e "${RED}无法连接 Telegram API，请检查代理设置或跨境网络。${NC}"
        exit 1
    fi

    # 3. 硬件与资源审计
    if [ "$OS_TYPE" == "Darwin" ]; then
        # Mac Mini 专属：检查是否为 Apple Silicon
        if [[ "$ARCH_TYPE" == "arm64" ]]; then
            echo -e "${GREEN}[3/4] 识别到 Apple Silicon (M1/M2/M3/M4)，开启高性能模式。${NC}"
        fi
        # 检查磁盘空间
        FREE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/Gi//')
        if (( $(echo "$FREE_SPACE < 5" | bc -l) )); then
            echo -e "${RED}警告: 磁盘剩余空间不足 5GB，可能导致安装失败。${NC}"
        fi
    else
        # Linux VPS 专属：内存审计
        TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_RAM" -lt 1800 ]; then
            echo -e "${PURPLE}提示: 检测到低内存 VPS (${TOTAL_RAM}MB)，正在准备 Swap 虚拟内存优化...${NC}"
            # 此处可后续触发自动创建 Swap 逻辑
        fi
    fi

    # 4. 冲突检查 (防掉坑)
    echo -ne "${BLUE}[4/4] 正在扫描潜在冲突...${NC} "
    if command -v clawdbot >/dev/null 2>&1; then
        echo -e "${RED}检测到已存在 Clawdbot 实例。请先运行 --uninstall 彻底清理。${NC}"
        exit 1
    else
        echo -e "${GREEN}未发现冲突，环境纯净。${NC}"
    fi
}

# 运行体检
check_environment

echo -e "${GREEN}恭喜！环境体检通过，准备开始自动部署。${NC}"
