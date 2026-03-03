#!/usr/bin/env bash
# 从本机将代码同步到远程机（后端服务器）
# 用法（在项目根目录执行）：
#   REMOTE=root@89.223.95.18 REMOTE_PATH=/www/wwwroot/0222 ./deploy/sync-to-remote.sh
# 或先 export REMOTE、REMOTE_PATH 再执行。
set -e
cd "$(dirname "$0")/.."
REMOTE="${REMOTE:?请设置 REMOTE，例如 root@89.223.95.18}"
REMOTE_PATH="${REMOTE_PATH:?请设置 REMOTE_PATH，例如 /www/wwwroot/0222}"
echo "同步到 $REMOTE:$REMOTE_PATH ..."
rsync -avz --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='dist' \
  --exclude='*.pem' \
  --exclude='.env' \
  --exclude='deploy/certbot-webroot' \
  . "$REMOTE:$REMOTE_PATH/"
echo "同步完成。请在远程机执行以下命令使后台新代码生效："
echo "  cd $REMOTE_PATH && ./deploy/update-backend.sh"
echo "（或手动： cd $REMOTE_PATH && docker compose -f deploy/docker-compose.yml build --no-cache admin && docker compose -f deploy/docker-compose.yml up -d --build）"
