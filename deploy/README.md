# MOP 后端与后台管理 - 容器化部署

## 部署位置（必读）

**后端（API）、用户网页端（web）与后台管理页面（admin）必须一并部署在同一台远程服务器上**，不得在本地开发机作为生产环境运行。App、用户端网页等客户端通过配置的 API/域名访问远程机上的 api、web 与 admin。

在**远程机**（即后端服务器，部署 api/web/admin 的那台机器，如 89.223.95.18）上使用 Docker Compose 部署 **api（后端）**、**web（用户端网页）** 与 **admin（管理后台）**，与 ARCHITECTURE 第 7～8 节域名分配一致。下文所有部署步骤与命令均在远程机上执行。**从本机把代码同步到远程机**见 **deploy/GIT-SYNC.md** 第三节「本机 → 远程机（后端服务器）同步代码」。

## 四域与远程机（HTTPS 标准端口，推荐）

规约四域（ARCHITECTURE 第 7 节）分配如下，**当前四个域名已解析到远程机 IP 89.223.95.18**。**部署时已为域名启用 HTTPS 与标准端口 443**，避免在要求标准 HTTPS 的网络/平台环境下被拒绝（如部分应用市场要求 App 使用 HTTPS 标准端口通信）。80 端口仅做跳转至 HTTPS。

| 域名 | 用途 | 推荐访问方式（HTTPS，不加端口） | 说明 |
|------|------|--------------------------------|------|
| **web.sdkdns.top** | 用户端网页 | **https://web.sdkdns.top** | 用户登录/主界面/设置等 |
| **admin.sdkdns.top** | 管理后台及 APK 下载 | **https://admin.sdkdns.top** | 管理员登录、设备/用户/关系、APK 列表 |
| **api.sdkdns.top** | App 通信（REST、Tinode） | **https://api.sdkdns.top** | 凭证 host、登录/enroll、邀请、审计、设备指令等 |
| **jit.sdkdns.top** | Jitsi 音视频与屏幕共享 | （后续部署） | 见 TINODE-JITSI-INTEGRATION.md |

**proxy（Nginx）** 监听 **80**（HTTP→HTTPS 重定向）与 **443**（HTTPS），按域名分流到 api/web/admin，浏览器与 App 使用 **https://web.sdkdns.top**、**https://admin.sdkdns.top**、**https://api.sdkdns.top** 即可，无需写端口。证书配置见下节。

## 前置条件

- **远程机**已安装 Docker 与 Docker Compose（V2）
- 项目代码已放在**远程机**（如 `/www/wwwroot/0222` 或 `~/wwwroot/0222`）

## 证书配置（HTTPS 必选）

proxy 需读取 SSL 证书才能提供 HTTPS。**部署前**在 `deploy/certs/` 下放置 **fullchain.pem** 与 **privkey.pem**。

**采用标准**：部署**必须**使用 **Let's Encrypt** 证书（受信任 CA，浏览器与 App 不报错）。仅在无法满足 Let's Encrypt 前置条件（如域名未解析、80 不可达）时，可临时使用自签名证书用于联调。

### Let's Encrypt（采用标准，必选）

域名已解析到部署机且 80 端口可从公网访问时，在**远程机**项目根目录执行：

```bash
chmod +x deploy/letsencrypt-init.sh
./deploy/letsencrypt-init.sh
```

脚本会申请多域证书（api/web/admin.sdkdns.top）并写入 `deploy/certs/`，执行完成后执行 `docker compose -f deploy/docker-compose.yml restart proxy`。续期与 crontab 配置见 **deploy/certs/README.md**。

### 自签名（仅作临时联调，非标准）

仅在无法使用 Let's Encrypt 时，在项目根目录执行：

```bash
chmod +x deploy/gen-self-signed-cert.sh
./deploy/gen-self-signed-cert.sh
```

会在 `deploy/certs/` 生成上述两个文件（自签名，浏览器会提示「连接不是私密连接」，需手动接受；不满足平台对 HTTPS 证书的要求）。

## 部署步骤

1. **进入项目根目录**（即包含 `admin-test-UI`、`deploy` 的目录）：
   ```bash
   cd /www/wwwroot/0222
   # 或 cd ~/wwwroot/0222
   ```

2. **确保证书就绪**（见上节）：`deploy/certs/fullchain.pem` 与 `deploy/certs/privkey.pem` 已存在。

3. **构建并启动**：
   ```bash
   docker compose -f deploy/docker-compose.yml up -d --build
   ```

4. **查看状态**：
   ```bash
   docker compose -f deploy/docker-compose.yml ps
   ```

## 代码更新后使改动生效（后台新代码未生效时必读）

**现象**：改动了 admin-test-UI（设备列表、地区栏、应用名等）或 api（如设备定位上报接口），但远程访问后台仍为旧版。

**原因**：admin 与 api 都是构建进 Docker 镜像的，仅 `up -d --build` 可能用到旧镜像缓存；浏览器也可能缓存了旧 JS/HTML。

**在远程机上执行（任选其一）：**

**方式一（推荐，一键更新 api + admin）：**
```bash
cd /www/wwwroot/0222   # 或你的项目根目录
chmod +x deploy/update-backend.sh
./deploy/update-backend.sh
```
脚本会：拉取最新代码（若为 git 仓库）、**强制无缓存重建 admin**、重建 api 并启动。执行后在浏览器**强制刷新**（Ctrl+Shift+R 或 Cmd+Shift+R）再访问 https://admin.sdkdns.top。

**方式二（手动）：**
```bash
cd /www/wwwroot/0222
git pull origin main   # 若用 rsync 同步则跳过，直接下一步
docker compose -f deploy/docker-compose.yml build --no-cache admin
docker compose -f deploy/docker-compose.yml up -d --build
```
同样需要浏览器强制刷新或清空缓存后再访问后台。

- **api**：新接口（如 `POST /device/location`、设备表 `last_location_city`）需重建 api 容器后生效。
- **admin**：静态页与 JS 在镜像构建时拷贝进容器，必须 **`build --no-cache admin`** 才能保证用到最新 `admin-test-UI/` 下的文件。

## 访问方式

**推荐（HTTPS 标准端口，不加端口）**：启动后使用 **https://** 域名访问，满足平台对标准 HTTPS 的要求。  
- 用户端网页：**https://web.sdkdns.top**  
- 管理后台：**https://admin.sdkdns.top**  
- API（App/邀请链接等）：**https://api.sdkdns.top**  

访问 **http://** 同上域名时会自动 301 跳转到 **https://**。

| 服务 | 主机端口 | 说明 |
|------|----------|------|
| **proxy** | **80, 443** | Nginx 反向代理：80 重定向到 HTTPS，**443 提供 HTTPS**，按域名分流到 api/web/admin |
| **api** | 8080 | 后端 REST API；调试可直连 `http://89.223.95.18:8080` |
| **web** | 8082 | 用户端网页；调试可直连 `http://89.223.95.18:8082` |
| **admin** | 8081 | 管理后台；调试可直连 `http://89.223.95.18:8081` |

四域已解析到 89.223.95.18，用户与 App 使用 **https://** 域名即可，无需写端口，符合标准网络与上架要求。

**配置说明**：用户端网页（https://web.sdkdns.top）与管理后台（https://admin.sdkdns.top）在标准域名下访问时，**默认 API 基地址为 https://api.sdkdns.top**，无需在登录页填写；邀请链接、App 内置 Host 已使用 HTTPS 域名。

## 首次部署配置检查清单

| 项 | 说明 |
|----|------|
| 证书 | **采用标准** Let's Encrypt：先启动 proxy（可暂用自签名），在远程机执行 `deploy/letsencrypt-init.sh` 后重启 proxy；`deploy/certs/fullchain.pem`、`privkey.pem` 就绪。详见 **deploy/certs/README.md** |
| 域名解析 | api/web/admin.sdkdns.top 已解析到部署机（如 89.223.95.18） |
| API 环境变量 | api 容器内 `API_HOST`、`WEB_HOST` 为 `https://api.sdkdns.top`、`https://web.sdkdns.top`（compose 已配） |
| 用户端/管理端 | 通过上述域名访问时默认请求 api 域名，无需再填 API 基地址 |

## 浏览器无法访问时排查

**说明**：后台管理页面和用户端网页只有在**远程机上执行过部署**并且**容器正常运行**后才能访问。若你尚未在远程机（如 89.223.95.18）上执行过 `docker compose -f deploy/docker-compose.yml up -d --build`，需要先完成部署。

按下面顺序排查：

### 1. 确认是否已部署、容器是否在跑

在**远程机**上执行：

```bash
cd /www/wwwroot/0222   # 或你的项目根目录
docker compose -f deploy/docker-compose.yml ps
```

- 若 **api、web、admin** 为 `Up`，说明至少这三个服务已启动。
- 若 **proxy** 为 `Exit` 或反复重启，多半是**证书未配置**（见下）。

### 2. 未配置证书时：先用「IP + 端口」访问

**proxy 依赖证书**，未在 `deploy/certs/` 下放置 `fullchain.pem`、`privkey.pem` 时，proxy 会启动失败，**80/443 和域名都会打不开**。此时可**不依赖 proxy**，直接用容器暴露的端口访问（假设部署机 IP 为 89.223.95.18）：

| 页面 | 临时访问地址（未配证书时用） |
|------|------------------------------|
| **用户端网页** | **http://89.223.95.18:8082** |
| **管理后台** | **http://89.223.95.18:8081** |
| API（调试） | http://89.223.95.18:8080 |

在浏览器输入上述地址即可。管理后台登录后需在「API 基地址」填 `http://89.223.95.18:8080`（或配置好证书后填 `https://api.sdkdns.top`）。

### 3. 配好证书后：用域名 + HTTPS 访问

在项目根目录执行 `./deploy/gen-self-signed-cert.sh` 生成自签名证书，或将 Let's Encrypt 证书放入 `deploy/certs/` 后，重新启动：

```bash
docker compose -f deploy/docker-compose.yml up -d --build
```

再访问 **https://web.sdkdns.top**（用户端）、**https://admin.sdkdns.top**（管理后台）。**采用标准为 Let's Encrypt**，按 **deploy/certs/README.md** 执行 `deploy/letsencrypt-init.sh` 后浏览器不再报证书错误。

### 4. 防火墙与端口

确认部署机已放行 **80、443、8080、8081、8082**（云主机需在安全组/防火墙中开放）。本地或其它机器才能访问：

- `telnet 89.223.95.18 8081` 或 `curl -I http://89.223.95.18:8081` 可快速测试 8081 是否可达。

### 5. 小结

| 情况 | 用户端网页 | 管理后台 |
|------|------------|----------|
| 未部署 / 容器未起 | 无法访问 | 无法访问 |
| 已部署，未配证书 | **http://89.223.95.18:8082** | **http://89.223.95.18:8081** |
| 已部署且已配证书 | https://web.sdkdns.top | https://admin.sdkdns.top |

## 常用命令

```bash
# 停止
docker compose -f deploy/docker-compose.yml down

# 查看日志
docker compose -f deploy/docker-compose.yml logs -f

# 仅重新构建并启动
docker compose -f deploy/docker-compose.yml up -d --build
```

## 环境变量（api 服务）

部署 api 时建议设置以下环境变量（可在 `docker-compose.yml` 的 api 的 `environment` 中配置，或使用 `env_file`）：

| 变量 | 必填 | 说明 |
|------|------|------|
| `ADMIN_TOKEN` | 建议 | 管理端鉴权 Token；不设则管理端接口 403。与后台登录后使用的 token 一致（内置账户登录时返回的即此值）。 |
| `BUILD_TOKEN` | 可选 | build-sync 鉴权；CI 调用 POST /api/v1/internal/build-sync 时 Header `X-Build-Token` 须与此一致。不设则 build-sync 返回 403。 |
| `API_HOST` | 可选 | 对外 API 地址（如 https://api.sdkdns.top），用于邀请链接等，默认 https://api.sdkdns.top。 |
| `WEB_HOST` | 可选 | 用户端网页域名，用于邀请链接，默认 https://web.sdkdns.top。 |
| `TERMS_VERSION` | 可选 | 当前用户须知版本号（整数），默认 1。 |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | 可选 | 管理端账号密码；若设置则登录时校验，否则可使用内置账户（见 dev-env/README 第 5 节）。 |

示例（在 `deploy/docker-compose.yml` 的 api 的 `environment` 中追加）：

```yaml
environment:
  - PORT=80
  - DB_PATH=/data/mop.db
  - ADMIN_TOKEN=your_admin_secret
  - BUILD_TOKEN=your_build_sync_secret
  - API_HOST=https://api.sdkdns.top
```

## 镜像说明

- **mop-proxy**：由 **deploy/Dockerfile.proxy** 构建，Nginx 反向代理，监听 **80（重定向到 HTTPS）与 443（HTTPS）**，按 **api/web/admin.sdkdns.top** 分流。证书来自 `deploy/certs/`（fullchain.pem、privkey.pem），**推荐仅通过 https:// 域名访问（标准端口）**。
- **mop-api**：由 **api/Dockerfile** 多阶段构建（Go 1.21 + Alpine），提供完整 REST API。SQLite 存于 `/data`，volume `mop-api-data` 持久化。环境变量见上表及 `api/README.md`。
- **mop-web**：由 **deploy/Dockerfile.web** 构建，基于 **app-test-UI** 静态资源。推荐 **https://web.sdkdns.top**；登录页 API 基地址填 **https://api.sdkdns.top**。
- **mop-admin**：由 **deploy/Dockerfile.admin** 构建，基于 **admin-test-UI** 静态资源。推荐 **https://admin.sdkdns.top**；后台内 API 基地址填 **https://api.sdkdns.top**，使用内置账户或 ADMIN_TOKEN 登录。

## APK 构建并同步（build-sync）

在**项目根目录**或 **app** 所在机器上（需安装 Flutter），可使用脚本构建 APK 并上报至 **远程机上的 api**：

```bash
# 必填：与远程机 api 配置一致的 BUILD_TOKEN；API_BASE 为远程机 api 地址（推荐 HTTPS 标准端口）
export BUILD_TOKEN=your_build_sync_secret
export API_BASE=https://api.sdkdns.top

# 可选：若 APK 已上传至其他地址，可指定下载链接
# export DOWNLOAD_URL=https://admin.sdkdns.top/apks/mop_v1.0.0_1.apk

chmod +x deploy/build-and-sync.sh
./deploy/build-and-sync.sh
```

脚本会读取 `app/pubspec.yaml` 的 `version`（如 1.0.0+1），执行 `flutter build apk --target-platform android-arm64`（**仅构建 arm64-v8a**，不包含 x86/armeabi-v7a），将产物命名为 `mop_v{version}_{build}.apk`，并向 `API_BASE/api/v1/internal/build-sync` 发送 POST（Header: X-Build-Token）。未设置 `BUILD_TOKEN` 或 `API_BASE` 时仅构建不同步。详见 ARCHITECTURE.md 第 6 节。

## 与 dev-env 的关系

- **dev-env/docker-compose.yml**：四域占位（api/admin/web/jit），镜像名为 placeholder，用于本地/联调设计。
- **deploy/docker-compose.yml**：**proxy（反向代理）+ api + web（用户网页端）+ admin** 同机部署，在远程机（如 89.223.95.18）上构建并运行；通过 proxy 使用域名访问、无需加端口，jit 为后续阶段。
