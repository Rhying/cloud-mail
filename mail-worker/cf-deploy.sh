#!/bin/bash
# Cloudflare Git 集成部署脚本
# 在 CF Git 集成设置中：
#   1. Settings > Build > Build variables 添加 KV_NAMESPACE_ID 和 D1_DATABASE_ID
#   2. 部署命令设为: bash cf-deploy.sh

set -e

if [ -z "$KV_NAMESPACE_ID" ] || [ -z "$D1_DATABASE_ID" ]; then
  echo "错误：请在 CF Git 集成 Build variables 中设置 KV_NAMESPACE_ID 和 D1_DATABASE_ID"
  exit 1
fi

# 用环境变量替换占位符（构建环境是临时的，不会污染仓库）
sed -i "s|\${KV_NAMESPACE_ID}|$KV_NAMESPACE_ID|g" wrangler.toml
sed -i "s|\${D1_DATABASE_ID}|$D1_DATABASE_ID|g" wrangler.toml

echo "已替换 KV/DB ID，开始部署..."
npx wrangler deploy
