# 开发/测试环境 HTTPS 证书

四域在开发或测试环境如需 HTTPS，可使用**自签名证书**或**内网 CA**。本目录提供自签名示例脚本。**目标环境**：远程开发机 **Ubuntu 22.04**。

## 方式一：脚本生成自签名证书（推荐用于开发）

在 **Ubuntu 22.04（远程开发机）** 或 Linux / macOS / WSL 下执行：

```bash
cd dev-env/certs
chmod +x gen-certs.sh
./gen-certs.sh
```

（若已执行 dev-env 目录下的 **setup-env.sh** 前置脚本，OpenSSL 已检测或安装；Ubuntu 22.04 默认也带 `openssl`。）

脚本会生成：

- `ca.key` / `ca.crt`：内网 CA（用于多域统一信任）
- `web.local.crt` + `web.local.key`，以及 `admin.local`、`api.local`、`jit.local` 的证书与私钥

**信任证书**（避免浏览器/系统报错）：

- **Ubuntu 22.04**：将 `ca.crt` 复制到系统证书目录后更新信任库：
  ```bash
  sudo cp ca.crt /usr/local/share/ca-certificates/mop-dev-ca.crt
  sudo update-ca-certificates
  ```
  之后本机 curl/Chromium 等会信任该 CA 签发的证书。若在远程服务器上生成证书，需将 `ca.crt` 拷到**你本机**（Windows/macOS）并导入浏览器或系统“受信任的根证书”，浏览器访问时才不报错。
- **Windows**：双击 `ca.crt`，选择“安装证书” → “本地计算机” → “受信任的根证书颁发机构”。
- **macOS**：`sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt`

若使用 **正式开发域名**（如 api.sdkdns.top），可修改 `gen-certs.sh` 中的 `DOMAINS` 变量为对应域名后再执行。

## 方式二：使用 mkcert（本地信任最简单）

安装 [mkcert](https://github.com/FiloSottile/mkcert) 后：

```bash
mkcert -install
mkcert web.local admin.local api.local jit.local
# 或正式域名：mkcert web.sdkdns.top admin.sdkdns.top api.sdkdns.top jit.sdkdns.top
```

生成的 `*.pem` 供 Nginx/Caddy 或各服务使用。

## 方式三：生产环境

生产环境使用**自申请 SSL 证书**（如 Let's Encrypt），见 ARCHITECTURE.md 第 8 节。
