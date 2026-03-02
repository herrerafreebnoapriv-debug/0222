#!/usr/bin/env bash
# 在远程机项目根目录执行：将当前修改提交并推送到 GitHub
# 用法：在项目根目录执行 ./deploy/sync-to-github.sh  或  ./deploy/sync-to-github.sh "提交说明"
set -e
cd "$(dirname "$0")/.."
MSG="${1:-sync: update from remote}"
git add .
if git diff --cached --quiet; then
  echo "无变更，跳过提交"
  exit 0
fi
git commit -m "$MSG"
git push origin main
echo "已推送到 GitHub (main)"
