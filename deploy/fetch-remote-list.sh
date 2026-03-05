#!/usr/bin/env bash
# 从本机 SSH 到远程，拉取 /opt/0222 下 api、admin-test-UI、deploy 的文件清单到 deploy/remote-list.txt
# 在项目根目录执行：bash deploy/fetch-remote-list.sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REMOTE="${REMOTE:-root@89.223.95.18}"
REMOTE_PATH="${REMOTE_PATH:-/opt/0222}"
ssh "$REMOTE" "cd $REMOTE_PATH && find api admin-test-UI deploy -type f -exec stat -c '%s %n' {} \;" | sed "s|$REMOTE_PATH/||g" | sort > deploy/remote-list.txt
echo "已写入 deploy/remote-list.txt"
