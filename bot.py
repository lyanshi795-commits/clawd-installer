import os
import requests
import telebot
import sys

# 1. 从环境变量读取配置 (不做任何预设，全靠客户填)
TOKEN = os.getenv("TG_TOKEN")
BASE_URL = os.getenv("BASE_URL")
API_KEY = os.getenv("API_KEY")
MODEL_NAME = os.getenv("MODEL_NAME")
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", "You are a helpful assistant.")

# 2. 启动检查：如果没填关键信息，直接报错停止
if not TOKEN or not BASE_URL or not API_KEY or not MODEL_NAME:
    print("❌ 启动失败：缺少必要配置！")
    print("请检查 .env 文件是否填写完整。")
    sys.exit(1)

print(f"🚀 正在启动 | 目标服务器: {BASE_URL} | 模型: {MODEL_NAME}")

bot = telebot.TeleBot(TOKEN)

@bot.message_handler(func=lambda m: True)
def handle_message(message):
    # 显示"对方正在输入..."，提升体验
    bot.send_chat_action(message.chat.id, 'typing')
    
    try:
        headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        }
        
        # --- 3. 智能地址清洗逻辑 (这是核心容错点) ---
        # 无论客户填的是 https://api.abc.com 还是 https://api.abc.com/v1
        # 我们都统一处理，防止拼装出 /v1/v1 这种错误
        clean_url = BASE_URL.rstrip('/') # 去掉末尾斜杠
        if clean_url.endswith('/v1'):
            api_endpoint = f"{clean_url}/chat/completions"
        else:
            api_endpoint = f"{clean_url}/v1/chat/completions"

        payload = {
            "model": MODEL_NAME,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": message.text}
            ]
        }
        
        # 设置超时，防止卡死
        response = requests.post(api_endpoint, json=payload, headers=headers, timeout=60)
        
        if response.status_code == 200:
            # 兼容各种 API 返回格式
            try:
                content = response.json()['choices'][0]['message']['content']
                bot.reply_to(message, content)
            except:
                bot.reply_to(message, "⚠️ API 返回了无法解析的数据")
        else:
            # 把具体的错误码回传给客户，方便他们找卖家退款
            bot.reply_to(message, f"❌ 服务商报错 ({response.status_code}):\n{response.text}")

    except Exception as e:
        bot.reply_to(message, f"💥 内部错误: {str(e)}")

bot.infinity_polling()
