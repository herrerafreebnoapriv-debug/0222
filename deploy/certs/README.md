# SSL 证书目录

proxy 容器需从此目录读取 HTTPS 证书，**部署前必须放置**：

- **fullchain.pem**：证书链（证书 + 中间证）
- **privkey.pem**：私钥

## 方式一：Let's Encrypt（生产推荐）

在远程机上用 certbot 申请多域证书（单证 SAN，覆盖 api/web/admin）：

```bash
sudo apt install certbot
sudo certbot certonly --standalone -d api.sdkdns.top -d web.sdkdns.top -d admin.sdkdns.top
sudo cp /etc/letsencrypt/live/api.sdkdns.top/fullchain.pem deploy/certs/
sudo cp /etc/letsencrypt/live/api.sdkdns.top/privkey.pem deploy/certs/
sudo chown "$USER" deploy/certs/*.pem
```

续期后复制新证到本目录并重载 nginx。

## 方式二：自签名（开发/测试）

在项目根目录执行：

```bash
chmod +x deploy/gen-self-signed-cert.sh
./deploy/gen-self-signed-cert.sh
```

会在 deploy/certs/ 下生成 fullchain.pem 与 privkey.pem（SAN：api/web/admin.sdkdns.top）。

## 直接挂载宿主机 Let's Encrypt（可选）

在 docker-compose.yml 的 proxy volumes 中改为：

```yaml
- /etc/letsencrypt/live/api.sdkdns.top:/etc/nginx/certs:ro
```
