#!/usr/bin/env bash
# 比对本机与远程 0222 源码是否一致（比较 api、admin-test-UI、deploy 下文件列表与大小）
# 用法：
#   1) 本机 Git Bash：在项目根目录执行 ./deploy/diff-local-remote.sh
#   2) 或先在本机生成 local-list.txt，在远程生成 remote-list.txt 后，用 diff 比较两个文件
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REMOTE="${REMOTE:-root@89.223.95.18}"
REMOTE_PATH="${REMOTE_PATH:-/opt/0222}"

echo "=== 本机清单 (api, admin-test-UI, deploy) -> deploy/local-list.txt ==="
find api admin-test-UI deploy -type f 2>/dev/null | while read f; do
  if [ -f "$f" ]; then
    printf "%s %s\n" "$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f" 2>/dev/null)" "$f"
  fi
done | sort > deploy/local-list.txt 2>/dev/null || true

# 若在 Windows 本机无 find/stat，用下面一行在 PowerShell 生成 local-list.txt：
# Get-ChildItem -Path api, admin-test-UI, deploy -Recurse -File | ForEach-Object { "$($_.Length) $($_.FullName.Replace((Get-Location).Path + '\', '').Replace('\','/'))" } | Sort-Object | Set-Content deploy/local-list.txt

if ! command -v ssh >/dev/null 2>&1; then
  echo "未检测到 ssh，请在本机用 PowerShell 生成 local-list.txt 后，在远程机执行："
  echo "  cd $REMOTE_PATH && find api admin-test-UI deploy -type f -exec stat -c '%s %n' {} \; | sed 's|$REMOTE_PATH/||' | sort > deploy/remote-list.txt"
  echo "再将 remote-list.txt 拷回本机 deploy/ 后执行：diff deploy/local-list.txt deploy/remote-list.txt"
  exit 0
fi

echo "=== 远程清单 $REMOTE:$REMOTE_PATH -> deploy/remote-list.txt ==="
ssh "$REMOTE" "cd $REMOTE_PATH && find api admin-test-UI deploy -type f -exec stat -c '%s %n' {} \;" 2>/dev/null | sed "s|$REMOTE_PATH/||g" | sort > deploy/remote-list.txt || true

if [ ! -s deploy/remote-list.txt ]; then
  echo "无法获取远程清单（请检查 ssh $REMOTE 是否可用）。请手动在远程机执行："
  echo "  cd $REMOTE_PATH && find api admin-test-UI deploy -type f -exec stat -c '%s %n' {} \; | sed 's|$REMOTE_PATH/||' | sort > deploy/remote-list.txt"
  exit 1
fi

echo "=== diff deploy/local-list.txt deploy/remote-list.txt ==="
if diff -q deploy/local-list.txt deploy/remote-list.txt >/dev/null 2>&1; then
  echo "一致：本机与远程文件列表及大小相同。"
else
  diff deploy/local-list.txt deploy/remote-list.txt || true
  echo "存在差异（上为 diff 输出）。"
fi
