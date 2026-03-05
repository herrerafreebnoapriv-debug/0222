#!/usr/bin/env bash
# 在远程机上执行：拉取最新代码并强制重建 api、admin，使后台新代码生效
# 用法（在远程机项目根目录执行）：
#   cd /www/wwwroot/0222 && ./deploy/update-backend.sh
# 若通过 rsync 同步代码而非 git，可跳过 git pull，直接执行后半段。
# 设置 NO_GIT=1 时不执行任何 git 操作（不拉取、不触碰 GitHub）：NO_GIT=1 ./deploy/update-backend.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -n "${NO_GIT:-}" ]; then
  echo "NO_GIT 已设置，跳过 git 操作（不触碰 GitHub）。"
elif git rev-parse --git-dir >/dev/null 2>&1; then
  echo "拉取最新代码..."
  git pull origin main 2>/dev/null || git pull 2>/dev/null || true
else
  echo "未检测到 git，跳过 pull（若用 rsync 同步则代码应已最新）。"
fi

echo "强制重建 admin（无缓存，确保静态页与 JS 更新）..."
docker compose -f deploy/docker-compose.yml build --no-cache admin

echo "强制重建 api（无缓存，确保 last_location_city 等接口生效）..."
docker compose -f deploy/docker-compose.yml build --no-cache api

echo "启动所有服务..."
docker compose -f deploy/docker-compose.yml up -d --build

echo "完成。请浏览器强制刷新（Ctrl+Shift+R 或 Cmd+Shift+R）后再访问管理后台。"
