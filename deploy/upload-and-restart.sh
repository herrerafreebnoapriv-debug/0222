#!/usr/bin/env bash
# 将本机代码上传到远程机并编译重启（不执行任何 git 操作，不触碰 GitHub）
# 用法（在项目根目录执行；需本机 ssh root@89.223.95.18 可直连远程机；有 rsync 时用 rsync，否则用 tar+ssh）：
#   REMOTE=root@89.223.95.18 REMOTE_PATH=/www/wwwroot/0222 ./deploy/upload-and-restart.sh
set -e
cd "$(dirname "$0")/.."
REMOTE="${REMOTE:?请设置 REMOTE，例如 root@89.223.95.18}"
REMOTE_PATH="${REMOTE_PATH:?请设置 REMOTE_PATH，例如 /www/wwwroot/0222}"

echo "=== 1/2 同步代码到 $REMOTE:$REMOTE_PATH（不涉及 GitHub）==="
if command -v rsync >/dev/null 2>&1; then
  rsync -avz --delete \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='*.pem' \
    --exclude='.env' \
    --exclude='deploy/certbot-webroot' \
    . "$REMOTE:$REMOTE_PATH/"
else
  echo "（未检测到 rsync，使用 tar+ssh 同步）"
  tar cf - \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='dist' \
    --exclude='*.pem' \
    --exclude='.env' \
    --exclude='deploy/certbot-webroot' \
    --exclude='./deploy/certbot-webroot' \
    . | ssh "$REMOTE" "mkdir -p $REMOTE_PATH && cd $REMOTE_PATH && tar xf -"
fi

echo ""
echo "=== 2/2 在远程机编译并重启（NO_GIT=1，不触碰 GitHub）==="
ssh "$REMOTE" "cd $REMOTE_PATH && NO_GIT=1 ./deploy/update-backend.sh"

echo ""
echo "全部完成。请浏览器强制刷新（Ctrl+Shift+R）后再访问管理后台。"
