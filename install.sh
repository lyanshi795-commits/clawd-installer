#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   AI 机器人一键部署向导 (客户交付版)   ${NC}"
echo -e "${GREEN}=========================================${NC}"
echo "请准备好您购买的 API Key 和服务器地址。"
echo ""

# --- 1. 收集 Telegram Token ---
while [[ -z "$TG_TOKEN" ]]; do
    read -p "1️⃣ 请输入您的 Telegram Bot Token: " TG_TOKEN
done

# --- 2. 收集 API 地址 (不做默认，只给示例) ---
echo ""
echo "2️⃣ 请输入 API 接口地址 (Base URL)"
echo "   示例: https://api.openai.com 或 https://qinzhiai.com"
read -p "   请输入: " BASE_URL

# 自动补全 https (很多客户会忘写)
if [[ $BASE_URL != http* ]]; then
    BASE_URL="https://$BASE_URL"
    echo "   已自动为您添加 https:// -> $BASE_URL"
fi

# --- 3. 收集 API Key ---
echo ""
while [[ -z "$API_KEY" ]]; do
    read -p "3️⃣ 请输入您的 API Key (通常以 sk- 开头): " API_KEY
done

# --- 4. 选择模型 (让客户自己决定) ---
echo ""
echo "4️⃣ 请输入您想使用的模型名称"
echo "   常用推荐: gpt-4o, claude-3-5-sonnet, deepseek-chat"
read -p "   请输入模型名: " MODEL_NAME
# 如果客户直接回车，给一个兜底
MODEL_NAME=${MODEL_NAME:-"gpt-4o"}

# --- 5. 设置人设 ---
echo ""
echo "5️⃣ 给机器人设定一个身份 (System Prompt)"
read -p "   (直接回车默认为'智能助手'): " SYSTEM_PROMPT
SYSTEM_PROMPT=${SYSTEM_PROMPT:-"你是一个智能助手。"}

# --- 6. 生成配置文件 ---
echo ""
echo "📝 正在生成配置..."
cat <<EOF > .env
TG_TOKEN=$TG_TOKEN
BASE_URL=$BASE_URL
API_KEY=$API_KEY
MODEL_NAME=$MODEL_NAME
SYSTEM_PROMPT=$SYSTEM_PROMPT
EOF

# --- 7. 创建 Dockerfile (如果不存在) ---
if [ ! -f Dockerfile ]; then
cat <<EOF > Dockerfile
FROM python:3.9-slim
WORKDIR /app
RUN pip install pyTelegramBotAPI requests
COPY bot.py .
CMD ["python", "bot.py"]
EOF
fi

# --- 8. 启动 ---
echo "🚀 正在构建并启动..."
# 停止旧的
docker rm -f ai-bot 2>/dev/null

# 构建镜像
docker build -t customer-bot . >/dev/null 2>&1

# 启动容器 (读取刚生成的 .env)
docker run -d \
  --name ai-bot \
  --restart always \
  --env-file .env \
  customer-bot

echo -e "${GREEN}✅ 部署成功！您的机器人已在后台运行。${NC}"
echo -e "${GREEN}👉 想要修改配置？修改目录下的 .env 文件然后运行 docker restart ai-bot 即可。${NC}"
