#!/usr/bin/env bash
# MOP 四域开发/测试环境 - 前置环境检测与安装
# 目标：Ubuntu 22.04。检测并安装 Docker、Docker Compose、OpenSSL、ca-certificates 等。
# 使用：chmod +x setup-env.sh && ./setup-env.sh（建议使用 sudo 以允许安装缺失软件）

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========== MOP 四域开发环境 - 前置检测与安装 =========="

# 1) 系统检测
if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "当前系统: $ID $VERSION_ID"
  if [ "$ID" = "ubuntu" ] && [ "${VERSION_ID%%.*}" = "22" ]; then
    echo -e "${GREEN}[OK] 目标环境 Ubuntu 22.04 兼容。${NC}"
  else
    echo -e "${YELLOW}[提示] 非 Ubuntu 22.04，以下步骤可能需自行适配（如包名、命令）。${NC}"
  fi
else
  echo -e "${YELLOW}[提示] 无法读取 /etc/os-release，按通用 Linux 处理。${NC}"
fi

# 2) 检测并安装 OpenSSL
if command -v openssl &>/dev/null; then
  echo -e "${GREEN}[OK] OpenSSL: $(openssl version)${NC}"
else
  echo "[安装] OpenSSL..."
  sudo apt-get update -qq
  sudo apt-get install -y openssl
  echo -e "${GREEN}[OK] OpenSSL 已安装。${NC}"
fi

# 3) 检测并安装 ca-certificates（证书信任库）
if [ -d /usr/share/ca-certificates ] || dpkg -l ca-certificates &>/dev/null; then
  echo -e "${GREEN}[OK] ca-certificates 已存在。${NC}"
else
  echo "[安装] ca-certificates..."
  sudo apt-get update -qq
  sudo apt-get install -y ca-certificates
  echo -e "${GREEN}[OK] ca-certificates 已安装。${NC}"
fi

# 4) 检测并安装 Docker
if command -v docker &>/dev/null; then
  echo -e "${GREEN}[OK] Docker: $(docker --version)${NC}"
else
  echo "[安装] Docker (docker.io)..."
  sudo apt-get update -qq
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker 2>/dev/null || true
  echo -e "${GREEN}[OK] Docker 已安装。${NC}"
  echo -e "${YELLOW}[建议] 将当前用户加入 docker 组以便无 sudo 运行: sudo usermod -aG docker $USER${NC}"
  echo -e "${YELLOW}       修改后需重新登录或执行 newgrp docker 生效。${NC}"
fi

# 5) 检测 Docker Compose V2
if docker compose version &>/dev/null; then
  echo -e "${GREEN}[OK] Docker Compose: $(docker compose version --short 2>/dev/null || docker compose version)${NC}"
else
  echo "[安装] Docker Compose V2 (docker-compose-v2)..."
  sudo apt-get update -qq
  sudo apt-get install -y docker-compose-v2 || sudo apt-get install -y docker-compose-plugin
  if docker compose version &>/dev/null; then
    echo -e "${GREEN}[OK] Docker Compose 已安装。${NC}"
  else
    echo -e "${RED}[失败] Docker Compose 未就绪，请手动安装: https://docs.docker.com/compose/install/${NC}"
    exit 1
  fi
fi

# 6) /etc/hosts 是否可写（仅检测，不自动修改）
if [ -w /etc/hosts ]; then
  echo -e "${GREEN}[OK] /etc/hosts 当前用户可写。${NC}"
else
  echo -e "${YELLOW}[提示] /etc/hosts 需 root 修改，请使用: sudo nano /etc/hosts${NC}"
fi

# 7) 可选：curl（用于后续健康检查等）
if command -v curl &>/dev/null; then
  echo -e "${GREEN}[OK] curl 已安装。${NC}"
else
  echo "[安装] curl..."
  sudo apt-get update -qq
  sudo apt-get install -y curl
  echo -e "${GREEN}[OK] curl 已安装。${NC}"
fi

echo ""
echo "========== 前置环境就绪 =========="
echo "下一步建议："
echo "  1) 编辑 hosts: sudo nano /etc/hosts  （参考同目录 hosts.sample）"
echo "  2) 生成证书:   cd certs && ./gen-certs.sh && sudo cp ca.crt /usr/local/share/ca-certificates/mop-dev-ca.crt && sudo update-ca-certificates"
echo "  3) 启动四域:   在 dev-env 目录执行 docker compose up -d（需先将占位镜像替换为实际服务）"
echo "详见 README.md。"
