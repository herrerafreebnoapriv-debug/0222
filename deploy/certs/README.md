# SSL 证书目录

proxy 容器从此目录读取 HTTPS 证书，**部署前必须放置**：

- **fullchain.pem**：证书链（证书 + 中间证）
- **privkey.pem**：私钥

**采用标准**：部署须使用 **Let's Encrypt** 证书；自签名仅在不满足 Let's Encrypt 条件时作临时联调用。

---

## 方式一：Let's Encrypt（采用标准，必选）

使用受信任 CA 签发，浏览器与 App 不会报证书错误，满足平台对 HTTPS 标准端口与证书的要求。需满足：**域名 api/web/admin.sdkdns.top 已解析到部署机**，且 **80 端口可从公网访问**（用于 ACME HTTP-01 校验）。

### 1. 首次申请（webroot，无需停 Nginx）

在**远程机**上，先确保 proxy 已启动并已挂载 `deploy/certbot-webroot`（见 `deploy/docker-compose.yml`）。若脚本曾在 Windows 上编辑，先去除 CRLF：`sed -i 's/\r$//' deploy/letsencrypt-init.sh deploy/letsencrypt-renew.sh`。然后执行：

```bash
cd /opt/0222   # 或你的项目根目录
chmod +x deploy/letsencrypt-init.sh
./deploy/letsencrypt-init.sh
```

脚本会：安装检查 certbot → 使用 webroot 向 Let's Encrypt 申请证书（多域 SAN：api/web/admin.sdkdns.top）→ 将 `fullchain.pem`、`privkey.pem` 复制到本目录。  
首次运行若未安装 certbot，按提示安装，例如：

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y certbot
# CentOS/RHEL
sudo yum install -y certbot
```

申请成功后，**重启 proxy** 使 Nginx 加载新证书：

```bash
docker compose -f deploy/docker-compose.yml restart proxy
```

### 2. 续期与自动化

Let's Encrypt 证书约 90 天有效，建议配置定时续期。在远程机执行：

```bash
# 手动续期并重载 Nginx
./deploy/letsencrypt-renew.sh
```

加入 crontab（每天 03:00 检查续期）：

```bash
sudo crontab -e
# 添加一行（路径按实际项目根目录修改）：
0 3 * * * /opt/0222/deploy/letsencrypt-renew.sh
```

### 3. 可选：自定义邮箱

首次申请时脚本默认使用 `admin@sdkdns.top` 作为 Let's Encrypt 通知邮箱。需修改时编辑 `deploy/letsencrypt-init.sh` 中 `--email` 参数，或设置环境变量后自行执行：

```bash
sudo certbot certonly --webroot -w /opt/0222/deploy/certbot-webroot \
  -d api.sdkdns.top -d web.sdkdns.top -d admin.sdkdns.top \
  --agree-tos --email your@email.com
sudo cp /etc/letsencrypt/live/api.sdkdns.top/fullchain.pem deploy/certs/
sudo cp /etc/letsencrypt/live/api.sdkdns.top/privkey.pem deploy/certs/
```

---

## 方式二：自签名（仅临时联调，非标准）

浏览器会提示「连接不是私密连接」或 `NET::ERR_CERT_AUTHORITY_INVALID`，需手动接受；不满足部分平台对 HTTPS 证书的要求。仅在无法使用 Let's Encrypt 时用于内网或临时联调。

在项目根目录执行：

```bash
chmod +x deploy/gen-self-signed-cert.sh
./deploy/gen-self-signed-cert.sh
```

会在 `deploy/certs/` 下生成 fullchain.pem 与 privkey.pem（SAN：api/web/admin.sdkdns.top）。  
**注意**：若在 Windows 上编辑过该脚本，在 Linux 上需先去除 CRLF：`sed -i 's/\r$//' deploy/gen-self-signed-cert.sh`。

---

## 直接挂载宿主机 Let's Encrypt（可选）

若希望 proxy 直接读宿主机 Let's Encrypt 目录（不复制到 deploy/certs），可在 `deploy/docker-compose.yml` 的 proxy 的 `volumes` 中增加或替换为：

```yaml
- /etc/letsencrypt/live/api.sdkdns.top:/etc/nginx/certs:ro
```

此时 Nginx 仍使用 `/etc/nginx/certs/fullchain.pem` 与 `privkey.pem`（即宿主机该目录下的文件）。续期后执行 `docker compose ... restart proxy` 或 `nginx -s reload` 即可。
