#!/usr/bin/env bash
# 为 api/web/admin.sdkdns.top 生成自签名证书，放入 deploy/certs/
# 仅用于开发/测试；生产请使用 Let's Encrypt 等正式证书。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
mkdir -p "$CERTS_DIR"
cd "$CERTS_DIR"

# SAN 多域名（Nginx SNI 按 server_name 选用）
SAN="DNS:api.sdkdns.top,DNS:web.sdkdns.top,DNS:admin.sdkdns.top"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout privkey.pem -out fullchain.pem \
  -subj "/CN=api.sdkdns.top" \
  -addext "subjectAltName=$SAN"

echo "Generated: $CERTS_DIR/fullchain.pem, $CERTS_DIR/privkey.pem (SAN: api/web/admin.sdkdns.top)"
echo "Use for dev/test only; for production use Let's Encrypt. See deploy/certs/README.md"
