#!/bin/bash

# 定义仓库基础地址 (指向你的 GitHub)
REPO_URL="https://raw.githubusercontent.com/lyanshi795-commits/clawd-installer/main"

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   AI 机器人一键部署系统 (Vibe版)       ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. 准备目录
mkdir -p ~/my-ai-bot
cd ~/my-ai-bot

# 2. 从 GitHub 下载最新的核心代码 (这就叫 OTA 更新!)
echo "⬇️  正在拉取最新核心代码..."
curl -s -o bot.py "$REPO_URL/bot.py"
curl -s -o Dockerfile "$REPO_URL/Dockerfile"

# 3. 交互式收集信息
read -p "1️⃣ 请输入 Telegram Bot Token: " TG_TOKEN
read -p "2️⃣ 请输入 API 接口地址 (例如 https://qinzhiai.com): " BASE_URL
# 自动补全 https
if [[ $BASE_URL != http* ]]; then BASE_URL="https://$BASE_URL"; fi

read -p "3️⃣ 请输入 API Key (sk-xxxx): " API_KEY
read -p "4️⃣ 请输入模型名 (默认 gpt-4o): " MODEL_NAME
MODEL_NAME=${MODEL_NAME:-"gpt-4o"}

# 4. 生成配置
cat <<EOF > .env
TG_TOKEN=$TG_TOKEN
BASE_URL=$BASE_URL
API_KEY=$API_KEY
MODEL_NAME=$MODEL_NAME
SYSTEM_PROMPT=你是 Ly Anshi 的 AI 助手。
EOF

# 5. 构建并启动
echo "🚀 正在构建并启动..."
docker build -t vibe-bot .
docker rm -f vibe-bot-container 2>/dev/null
docker run -d --name vibe-bot-container --restart always --env-file .env vibe-bot

echo -e "${GREEN}✅ 部署完成！快去 Telegram 测试吧！${NC}"
