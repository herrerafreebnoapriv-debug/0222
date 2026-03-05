#!/usr/bin/env bash
# iOS 构建前打补丁：注释 GeneratedPluginRegistrant.m 中的 Jitsi 注册，避免启动时 JitsiMeetPlugin.register 崩溃。
# 用法：在 app 目录下执行 bash scripts/patch_ios_jitsi.sh [ios/Runner/GeneratedPluginRegistrant.m]
# 优先调用同目录下的 patch_ios_jitsi.py（跨平台、行为稳定）；若无 Python 则回退到 sed。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FILE="${1:-ios/Runner/GeneratedPluginRegistrant.m}"
if [ ! -f "$APP_DIR/$FILE" ]; then
  echo "patch_ios_jitsi.sh: $FILE not found (run from app dir after flutter pub get)" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/patch_ios_jitsi.py" ]; then
  (cd "$APP_DIR" && python3 scripts/patch_ios_jitsi.py "$FILE")
  exit $?
fi

# 回退：sed 注释 Jitsi 的 #if...#endif 整块及 [JitsiMeetPlugin registerWithRegistrar:...] 一行
if grep -q 'JitsiMeetPlugin registerWithRegistrar' "$APP_DIR/$FILE"; then
  sed -i.bak \
    -e '/^#if __has_include(<jitsi_meet_flutter_sdk/,/^#endif$/s/^/\/\/ /' \
    -e '/\[JitsiMeetPlugin registerWithRegistrar/s/^/\/\/ /' \
    "$APP_DIR/$FILE"
  rm -f "$APP_DIR/$FILE.bak"
  echo "patch_ios_jitsi.sh: patched Jitsi in $FILE"
else
  echo "patch_ios_jitsi.sh: no Jitsi registration found in $FILE (already patched or no jitsi dependency)"
fi
