#!/usr/bin/env bash
# MOP 四域开发/测试环境 - 自签名证书生成脚本
# 生成：内网 CA + web/admin/api/jit 四域证书（默认 .local，可改为正式域名）
# 使用：chmod +x gen-certs.sh && ./gen-certs.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 开发环境默认 .local；正式域名可改为 web.sdkdns.top 等
DOMAINS="web.local admin.local api.local jit.local"
DAYS=825
CA_KEY="ca.key"
CA_CRT="ca.crt"

# 1) 内网 CA
if [ ! -f "$CA_KEY" ]; then
  openssl genrsa -out "$CA_KEY" 4096
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days "$DAYS" -out "$CA_CRT" \
    -subj "/CN=MOP Dev CA"
  echo "已生成内网 CA: $CA_CRT"
fi

# 2) 各域证书
for name in $DOMAINS; do
  out_crt="${name}.crt"
  out_key="${name}.key"
  if [ -f "$out_crt" ]; then
    echo "已存在 $out_crt，跳过"
    continue
  fi
  openssl genrsa -out "$out_key" 2048
  openssl req -new -key "$out_key" -out "${name}.csr" \
    -subj "/CN=$name"
  echo "subjectAltName=DNS:$name" > "${name}.ext"
  openssl x509 -req -in "${name}.csr" -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
    -out "$out_crt" -days "$DAYS" -sha256 -extfile "${name}.ext"
  rm -f "${name}.csr" "${name}.ext"
  echo "已生成 $out_crt + $out_key"
done

echo "完成。将 $CA_CRT 安装到系统/浏览器「受信任的根证书」后可访问 https 不报错。"
