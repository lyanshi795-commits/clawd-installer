# Clawdbot Auto-Deployer

[![脚本体检](https://github.com/lyanshi795-commits/clawd-installer/actions/workflows/test.yml/badge.svg)](https://github.com/lyanshi795-commits/clawd-installer/actions/workflows/test.yml)

一键部署你的私人 AI 代理 🤖

## 📁 项目结构

```
├── index.html          # 落地页 (部署到 GitHub Pages)
├── vibe-deploy.sh      # 部署脚本 (用户在 VPS 上运行)
├── README.md           # 你正在看的文档
└── lib/
    └── healthcheck.sh  # 环境检测模块
```

## 🚀 一键部署命令

```bash
curl -fsSL https://raw.githubusercontent.com/lyanshi795-commits/clawd-installer/main/vibe-deploy.sh | bash
```

## 💰 商业模式

| 组件 | 部署位置 | 成本 | 收益 |
|------|----------|------|------|
| 落地页 | GitHub Pages | $0 | 流量入口 |
| 脚本 | GitHub Raw | $0 | 自动化交付 |
| Bot 运行 | 客户的 VPS | $5-10/月 (客户付) | **Affiliate 佣金** |

## 🔗 链接

- **落地页:** https://lyanshi795-commits.github.io/clawd-installer/
- **脚本 Raw:** https://raw.githubusercontent.com/lyanshi795-commits/clawd-installer/main/vibe-deploy.sh

## 📄 License

MIT
