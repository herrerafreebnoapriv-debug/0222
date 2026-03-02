# 四域开发/测试环境说明

本目录用于解决「**hosts、docker network、自签名/内网 CA 提前设计**」，避免 web / admin / api / jit 四域联调困难。

**环境分工**：**本机（Windows）** 配置 **Flutter** 开发环境，用于开发 **Android 与 iOS** App 代码（详见 [LOCAL-FLUTTER-SETUP.md](LOCAL-FLUTTER-SETUP.md)）。**后端、api、admin、web、jit、Docker 与四域**均在 **远程 mop2 服务器**（89.223.95.18）上进行开发与运行；下文第 0～4 节针对**远程 mop2（Ubuntu 22.04）** 环境。

**目标环境**：远程开发机为 **Ubuntu 22.04**；以下 hosts 路径、证书信任与 Docker 命令均按该系统说明。其他 Linux 发行版可参照执行。

## 研发服务器与项目目录

**研发服务器**：使用 **mop2 服务器**（**89.223.95.18**）进行本项目的测试与研发。**密钥免密已配置**：本机可直接免密连接该服务器（使用 **C:\Users\robot\.ssh** 下密钥）。

**连接后**，在服务器上于 **wwwroot** 目录下新建 **0222** 项目目录，再将本仓库代码放入该目录（如通过 git clone 或上传）。

**操作步骤**：

1. **连接 mop2 服务器**（在本机终端执行，默认 root 用户免密）：
   ```bash
   ssh root@89.223.95.18
   ```
   若使用其他用户名，将 `root` 替换为实际用户名即可。

2. **创建项目目录**（登录服务器后执行）：
   - 若 **wwwroot** 在系统 Web 根路径（如宝塔等面板常见为 `/www/wwwroot`）：
     ```bash
     sudo mkdir -p /www/wwwroot/0222
     sudo chown $USER:$USER /www/wwwroot/0222
     cd /www/wwwroot/0222
     ```
   - 若 **wwwroot** 在当前用户目录下：
     ```bash
     mkdir -p ~/wwwroot/0222
     cd ~/wwwroot/0222
     ```

3. **放入代码**：在 `0222` 目录内执行 `git clone`（若从仓库拉取）或将本地项目上传至该目录。后续在 **0222** 目录下执行 dev-env 的前置脚本、hosts、Docker 等步骤，见下文第 0～4 节。

## 项目与 GitHub 仓库链接

开发在远程机上进行时，项目与仓库的关联应在**远程开发机**上完成。在项目根目录执行：

```bash
git init
git remote add origin https://github.com/herrerafreebnoapriv-debug/0222.git
```

首次推送：`git add .` → `git commit -m "Initial commit"` → `git branch -M main` → `git push -u origin main`。之后日常在远程机上 `git push` / `git pull` 即可。详见根目录 [README.md](../README.md)「开发环境与仓库」。

## 0. 前置环境检测与安装

在配置 hosts、证书与 Docker 前，建议先在同一台开发机（Ubuntu 22.04）上执行**前置环境检测与安装**，确保依赖就绪。

**一键执行**（在 `dev-env` 目录下）：

```bash
chmod +x setup-env.sh
./setup-env.sh
```

建议使用 `sudo ./setup-env.sh`，以便在缺少软件时自动安装。

**脚本会检测并视需安装**：

| 依赖 | 用途 | 缺失时动作 |
|------|------|------------|
| OpenSSL | 生成自签名证书（certs/gen-certs.sh） | `apt install openssl` |
| ca-certificates | 系统证书信任库（信任自签名 CA） | `apt install ca-certificates` |
| Docker | 运行四域容器 | `apt install docker.io` 并启用服务 |
| Docker Compose V2 | 编排 web/admin/api/jit | `apt install docker-compose-v2` |
| curl | 可选，健康检查与调试 | `apt install curl` |

**额外说明**：

- 若 Docker 首次安装，脚本会提示将当前用户加入 `docker` 组（`sudo usermod -aG docker $USER`），加入后需**重新登录**或执行 `newgrp docker` 后，方可无 sudo 运行 `docker compose`。
- `/etc/hosts` 仅做可写性检测，不自动修改；需手动编辑 hosts 时脚本会提示使用 `sudo nano /etc/hosts`。

执行完成后，脚本会输出**下一步建议**（hosts、证书、docker compose）。再按下面第 1～4 节操作即可。

## 1. 域名与 hosts

四域对应关系（与 ARCHITECTURE 第 7 节一致）：

| 域名 | 用途 |
|------|------|
| web.sdkdns.top | 用户端网页 |
| admin.sdkdns.top | 管理后台及 APK 下载 |
| api.sdkdns.top | App 通信（REST + Tinode） |
| jit.sdkdns.top | Jitsi 音视频 |

**开发/测试环境**：在运行四域的那台机器（本机或远程服务器）上，让上述域名解析到该机，否则浏览器/App 无法访问。

- 复制 [hosts.sample](hosts.sample) 中内容，追加到 **hosts**：
  - **Ubuntu 22.04（远程开发机）**：`/etc/hosts`，需 `sudo` 编辑（如 `sudo nano /etc/hosts`）。
  - **Windows（本机浏览器访问时）**：`C:\Windows\System32\drivers\etc\hosts`
  - **macOS**：`/etc/hosts`
- 若开发在**远程服务器**上：在**服务器**上编辑 `/etc/hosts` 时可将四域指向 `127.0.0.1`；在**本机**若要通过浏览器访问远程四域，则在本机 hosts 中把四域指向该**服务器 IP**（内网或公网）。
- 可选：仅用 `.local` 域名（见 hosts.sample 场景二），各服务配置中统一使用 `api.local` 等，与正式域名隔离。

## 2. Docker 网络（docker-compose）

四域若用 Docker 部署，须在同一 **docker network** 内，容器间用**服务名**互访（如 `http://api:80`）。

- 若已执行**第 0 节** `setup-env.sh`，Docker 与 Docker Compose 应已就绪；否则需先安装（见第 0 节或手动 `sudo apt install -y docker.io docker-compose-v2`）。
- 使用 [docker-compose.yml](docker-compose.yml)：当前为**占位配置**（镜像名为 placeholder/*），实际开发时替换为各项目镜像或 `build: ./path`。
- 启动：在 `dev-env` 目录执行  
  `docker compose up -d`
- 同一网络 `mop-four-domain` 下：admin 调 api 用 `http://api:80` 或 `https://api:443`，web 前端由**浏览器**访问 api 时仍用对外域名（如 `https://api.sdkdns.top`），由反向代理或端口映射到 api 容器。

## 3. HTTPS 证书（自签名/内网 CA）

开发或测试环境如需 HTTPS（Tinode/Jitsi 等常要求），可用自签名或内网 CA，避免证书错误导致联调失败。

- 见 [certs/README.md](certs/README.md)：提供 **gen-certs.sh** 生成四域自签名证书，以及 **mkcert** 的用法；证书安装到系统/浏览器「受信任的根证书」后即可正常访问。
- 生产环境使用自申请 SSL（如 Let's Encrypt），见 ARCHITECTURE 第 8 节。

## 4. 联调顺序建议

1. **前置环境**：在开发机上执行 `./setup-env.sh`（建议 `sudo`），完成依赖检测与安装。
2. 配置 **hosts**，确保四域解析到开发机。
3. 生成并信任 **certs**（若用 HTTPS）。
4. 用 **docker-compose** 起四域（或先起 api，再起 web/admin/jit），确认容器间能通过服务名访问。
5. 按 ARCHITECTURE 第 10 节模块化阶段做业务联调（先 api/web/admin，再 jit）。

更多风险与约定见项目根目录 **DEVELOPMENT-RISKS.md**。

---

## 5. 内置账户（开发/测试）

以下账户用于开发与联调，**仅限非生产环境**；生产环境须修改或禁用内置管理员、并勿依赖种子用户。

### 5.1 管理后台内置账户

管理端登录（POST /api/v1/admin/auth）支持以下**内置管理员**（API 内置校验，无需配置环境变量）：

| 角色         | 用户名    | 密码     |
|--------------|------------|----------|
| 超级管理员   | zhanan089  | zn666@   |
| 管理员       | zn0000     | zn0000   |

- 使用方式：在管理后台登录页输入上述**用户名**与**密码**，请求会由 api 校验并返回 `admin_token`（需部署时配置 `ADMIN_TOKEN`，返回的即该 Token）。
- 校验顺序：先校验内置账户，匹配则返回 Token；否则若配置了 `ADMIN_USERNAME`/`ADMIN_PASSWORD` 则校验环境变量；再否则校验 `password == ADMIN_TOKEN`（便于开发）。

### 5.2 App / 用户端内置账户（种子用户）

用于 **App 或用户端网页** 账密登录（POST /api/v1/auth/login）的测试账户：

| 说明     | 用户名   | 密码    |
|----------|----------|---------|
| 内置测试用户 | user123 | 123456 |

- 使用方式：登录时 **identity** 填 `user123`，**password** 填 `123456`。
- 说明：api 启动时会自动**种子**该用户（若数据库中尚不存在 username=user123）；手机号等为占位，仅用于开发/测试。生产环境应关闭种子或删除该账户。
