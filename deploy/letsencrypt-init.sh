#!/usr/bin/env bash
# 在远程机项目根目录执行，为 api/web/admin.sdkdns.top 申请 Let's Encrypt 证书并写入 deploy/certs/
# 前置：域名已解析到本机，proxy 已启动且已配置 deploy/certbot-webroot 挂载（见 deploy/README.md）
# 使用 webroot 方式，无需停止 Nginx。

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEBROOT="$PROJECT_ROOT/deploy/certbot-webroot"
CERTS_DEST="$PROJECT_ROOT/deploy/certs"
DOMAINS="api.sdkdns.top web.sdkdns.top admin.sdkdns.top"

mkdir -p "$WEBROOT"
mkdir -p "$CERTS_DEST"

if ! command -v certbot &>/dev/null; then
  echo "请先安装 certbot，例如："
  echo "  Ubuntu/Debian: sudo apt update && sudo apt install -y certbot"
  echo "  CentOS/RHEL:   sudo yum install -y certbot"
  exit 1
fi

# 可选：自定义 Let's Encrypt 通知邮箱，例如 export LETSENCRYPT_EMAIL=your@example.com
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@sdkdns.top}"
echo "使用 webroot: $WEBROOT"
echo "申请域名: $DOMAINS"
sudo certbot certonly --webroot -w "$WEBROOT" \
  -d api.sdkdns.top -d web.sdkdns.top -d admin.sdkdns.top \
  --non-interactive --agree-tos --email "$LETSENCRYPT_EMAIL" \
  --preferred-challenges http

# 证书目录以第一个域名为名
LE_LIVE="/etc/letsencrypt/live/api.sdkdns.top"
sudo cp "$LE_LIVE/fullchain.pem" "$CERTS_DEST/fullchain.pem"
sudo cp "$LE_LIVE/privkey.pem" "$CERTS_DEST/privkey.pem"
sudo chown "$(whoami)" "$CERTS_DEST/fullchain.pem" "$CERTS_DEST/privkey.pem" 2>/dev/null || true

echo "证书已写入 $CERTS_DEST/"
echo "请重载或重启 proxy 使 Nginx 加载新证书："
echo "  cd $PROJECT_ROOT && docker compose -f deploy/docker-compose.yml restart proxy"
