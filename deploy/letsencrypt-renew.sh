#!/usr/bin/env bash
# 续期 Let's Encrypt 证书，并将新证书复制到 deploy/certs/ 后重载 Nginx
# 建议加入 crontab：0 3 * * * /opt/0222/deploy/letsencrypt-renew.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEBROOT="$PROJECT_ROOT/deploy/certbot-webroot"
CERTS_DEST="$PROJECT_ROOT/deploy/certs"
COMPOSE_FILE="$PROJECT_ROOT/deploy/docker-compose.yml"

sudo certbot renew --webroot -w "$WEBROOT" --quiet

LE_LIVE="/etc/letsencrypt/live/api.sdkdns.top"
if [[ -f "$LE_LIVE/fullchain.pem" ]]; then
  sudo cp "$LE_LIVE/fullchain.pem" "$CERTS_DEST/fullchain.pem"
  sudo cp "$LE_LIVE/privkey.pem" "$CERTS_DEST/privkey.pem"
  sudo chown "$(whoami)" "$CERTS_DEST/fullchain.pem" "$CERTS_DEST/privkey.pem" 2>/dev/null || true
  cd "$PROJECT_ROOT" && docker compose -f "$COMPOSE_FILE" exec -T proxy nginx -s reload 2>/dev/null || docker compose -f "$COMPOSE_FILE" restart proxy
fi
