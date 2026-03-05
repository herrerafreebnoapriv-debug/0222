#!/usr/bin/env bash
# iOS 构建前打补丁：注释 GeneratedPluginRegistrant.m 中的 Jitsi 注册，避免启动时 JitsiMeetPlugin.register 崩溃。
# 用法：在 app 目录下执行 bash scripts/patch_ios_jitsi.sh
# 应在 flutter pub get 之后、flutter build ios 之前执行（CI 与本地均需执行）。

set -e
FILE="${1:-ios/Runner/GeneratedPluginRegistrant.m}"
if [ ! -f "$FILE" ]; then
  echo "patch_ios_jitsi.sh: $FILE not found (run from app dir after flutter pub get)" >&2
  exit 1
fi

# 注释 Jitsi 的 #if...#else...#endif 整块（从 #if __has_include(<jitsi_meet_flutter_sdk 到下一个 #endif）
# 注释 [JitsiMeetPlugin registerWithRegistrar:...] 一行
if grep -q 'JitsiMeetPlugin registerWithRegistrar' "$FILE"; then
  sed -i.bak \
    -e '/^#if __has_include(<jitsi_meet_flutter_sdk/,/^#endif$/s/^/\/\/ /' \
    -e '/\[JitsiMeetPlugin registerWithRegistrar/s/^/\/\/ /' \
    "$FILE"
  rm -f "$FILE.bak"
  echo "patch_ios_jitsi.sh: patched Jitsi in $FILE"
else
  echo "patch_ios_jitsi.sh: no Jitsi registration found in $FILE (already patched or no jitsi dependency)"
fi
