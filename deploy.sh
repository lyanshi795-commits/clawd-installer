#!/bin/bash

# 定义颜色，让安装过程看起来很酷
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Clawdbot Vibe Deployer v1.0.0       ${NC}"
echo -e "${BLUE}   Powered by Ly Anshi One-Person Co.  ${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 1. 检查是否为 Root 用户
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[Error] 请使用 root 用户运行此脚本 (Please run as root)${NC}"
  exit 1
fi

# 2. 自动配置 Swap (内存扩展) - 专为 $6 Vultr 机器设计
# 如果内存小于 2GB 且没有 Swap，则创建 2GB 虚拟内存
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ $TOTAL_MEM -lt 2000000 ]; then
    echo -e "${BLUE}[System] 检测到低内存环境 ($((TOTAL_MEM/1024))MB)，正在创建 Swap 虚拟内存...${NC}"
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
        echo -e "${GREEN}[Success] 2GB Swap 创建成功！${NC}"
    else
        echo -e "${GREEN}[Info] Swap 已存在，跳过。${NC}"
    fi
fi

# 3. 检查并安装 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${BLUE}[Installer] 正在安装 Docker 环境...${NC}"
    curl -fsSL https://get.docker.com | bash -s docker
    echo -e "${GREEN}[Success] Docker 安装完成！${NC}"
else
    echo -e "${GREEN}[Info] Docker 已安装。${NC}"
fi

# 4. 获取用户密钥 (交互式)
echo ""
echo -e "${BLUE}--- 配置你的私人特工 ---${NC}"
read -p "请输入你的 Telegram Bot Token: " TG_TOKEN
read -p "请输入你的 Anthropic API Key (sk-ant...): " CLAUDE_KEY

if [ -z "$TG_TOKEN" ] || [ -z "$CLAUDE_KEY" ]; then
    echo -e "${RED}[Error] 必须提供 Token 和 API Key 才能启动！${NC}"
    exit 1
fi

# 5. 创建配置目录
mkdir -p /root/clawdbot-data

# 6. 启动 Clawdbot 容器
echo ""
echo -e "${BLUE}[Deploy] 正在拉取并启动 Clawdbot...${NC}"

# 这里的镜像用了 clawdbot 官方或者你指定的镜像，确保这里是最新的
docker run -d \
  --name clawdbot \
  --restart always \
  --network host \
  -v /root/clawdbot-data:/app/data \
  -e TELEGRAM_BOT_TOKEN="$TG_TOKEN" \
  -e ANTHROPIC_API_KEY="$CLAUDE_KEY" \
  ghcr.io/m1guelpf/clawdbot:latest

# 7. 验证结果
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}   SUCCESS! 部署成功！                 ${NC}"
    echo -e "${GREEN}   现在去 Telegram 给你的机器人发消息吧！ ${NC}"
    echo -e "${GREEN}=========================================${NC}"
else
    echo -e "${RED}[Error] 部署失败，请检查上面的错误信息。${NC}"
fi
