#!/usr/bin/env bash
# MOP APK 构建并同步至 api（PROTOCOL 第 5 节）
# 用法：
#   BUILD_TOKEN=xxx API_BASE=http://api:80 [DOWNLOAD_URL=https://...] ./deploy/build-and-sync.sh
# 或从项目根目录：
#   BUILD_TOKEN=xxx API_BASE=http://api:80 ./deploy/build-and-sync.sh
#
# 环境变量：
#   BUILD_TOKEN  必填，与 api 的 BUILD_TOKEN 一致
#   API_BASE     api 基地址（如 http://localhost:8080 或 https://api.sdkdns.top）
#   DOWNLOAD_URL 可选，APK 下载链接；不设则使用 API_BASE + /apks/ + 文件名（需自行托管）
#   BUILD_NAME   version 名，默认从 app/pubspec.yaml 读取
#   BUILD_NUMBER build 号，默认从 app/pubspec.yaml 的 version 的 + 后数字读取

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
cd "$APP"

# 从 pubspec 读取 version（格式 1.0.0+102）
VER_LINE=$(grep '^version:' pubspec.yaml | sed 's/version: *//')
BUILD_NAME="${BUILD_NAME:-$(echo "$VER_LINE" | cut -d+ -f1)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(echo "$VER_LINE" | cut -d+ -f2)}"
FILE_NAME="mop_v${BUILD_NAME}_${BUILD_NUMBER}.apk"
FILE_NAME="${FILE_NAME// /}"

echo "Building Flutter APK (version=$BUILD_NAME, build=$BUILD_NUMBER)..."
flutter build apk --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

OUT_DIR="build/app/outputs/flutter-apk"
OUT_APK="$OUT_DIR/app-release.apk"
if [ ! -f "$OUT_APK" ]; then
  echo "Expected $OUT_APK not found"
  exit 1
fi

cp "$OUT_APK" "$OUT_DIR/$FILE_NAME"
echo "Built: $OUT_DIR/$FILE_NAME"

if [ -z "$BUILD_TOKEN" ] || [ -z "$API_BASE" ]; then
  echo "BUILD_TOKEN or API_BASE not set, skip build-sync."
  exit 0
fi

API_BASE="${API_BASE%/}"
DOWNLOAD_URL="${DOWNLOAD_URL:-$API_BASE/apks/$FILE_NAME}"
CHANGE_LOG="${CHANGE_LOG:-Build $BUILD_NAME ($BUILD_NUMBER)}"

echo "Syncing to $API_BASE/api/v1/internal/build-sync ..."
HTTP_CODE=$(curl -s -o /tmp/build-sync-resp.txt -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Build-Token: $BUILD_TOKEN" \
  -d "{\"version\":\"$BUILD_NAME\",\"build\":$BUILD_NUMBER,\"file_name\":\"$FILE_NAME\",\"download_url\":\"$DOWNLOAD_URL\",\"change_log\":\"$CHANGE_LOG\"}" \
  "$API_BASE/api/v1/internal/build-sync")

if [ "$HTTP_CODE" = "200" ]; then
  echo "build-sync OK (200)."
else
  echo "build-sync failed (HTTP $HTTP_CODE):"
  cat /tmp/build-sync-resp.txt
  exit 1
fi
