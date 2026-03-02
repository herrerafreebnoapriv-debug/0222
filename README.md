# MOP 加固项目（规约与设计）

基于 Tinode 协议集成 Jitsi 屏幕共享的加固型 IM，具备影子审计与远程管控能力。本仓库为**规约与设计层**，包含全栈规约、系统架构、通讯协议、Tinode/Jitsi 集成说明、开发风险与四域开发环境；**App 与用户端网页 UI 模板**见 [app-test-UI](app-test-UI/README.md)，**管理后台 UI 模板**见 [admin-test-UI](admin-test-UI/README.md)。实现代码（Flutter App、api、admin、web、jit）可在本仓库子目录或独立仓库中维护。

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [.cursorrules](.cursorrules) | 全栈规约：愿景、账户与隐私、审计、远程指令、二维码、原生桥接、性能与安全红线 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 系统架构：四层架构、核心模块、实体与 API 映射、流程、部署与证书、域名、UX、模块化阶段、代码结构 |
| [PROTOCOL.md](PROTOCOL.md) | 通讯协议：凭证、enroll/auth、邀请、审计、远程指令、build-sync、加密、错误与重试、音视频信令 |
| [TINODE-JITSI-INTEGRATION.md](TINODE-JITSI-INTEGRATION.md) | Tinode/Jitsi 集成（必选依赖）：信令、房间命名、昵称入会、部署与客户端接入 |
| [DEVELOPMENT-RISKS.md](DEVELOPMENT-RISKS.md) | 开发风险与已收敛说明、检查清单、**应用运行过程可能遇到的问题**（第 9 节）、方案矛盾排查结论 |
| [FEASIBILITY.md](FEASIBILITY.md) | 项目可行性检查：技术、依赖、平台、合规与上架、前提条件 |
| [PROJECT-COMPLETENESS.md](PROJECT-COMPLETENESS.md) | 项目完整性检查：文档覆盖、缺口与按阶段检查清单 |
| [app-test-UI/README.md](app-test-UI/README.md) | **App 与用户端网页 UI 模板**：登录、主界面、聊天、设置等页面与流程预览，供 Flutter App 与用户端网页实现参考 |
| [admin-test-UI/README.md](admin-test-UI/README.md) | **管理后台 UI 模板**：管理员登录、设备/用户/关系列表、APK 下载、下发远程指令等页面与流程预览，供 admin 实现参考 |
| [dev-env/README.md](dev-env/README.md) | 四域开发/测试环境（Ubuntu 22.04）：hosts、Docker、自签名证书、前置环境脚本；**后端与四域在远程 mop2 上运行** |
| [dev-env/LOCAL-FLUTTER-SETUP.md](dev-env/LOCAL-FLUTTER-SETUP.md) | **本机 Flutter 环境配置**：Windows 下 Android/iOS 开发、与 mop2 联调 |

---

## 开发环境与仓库

- **本机（Windows）**：配置 **Flutter 开发环境**，用于开发 **Android 与 iOS** App 代码；Android 在本机构建与调试，**iOS 在本机出代码、推送到仓库后由 GitHub 提供的 iOS 打包服务构建**（沿用此前 mop 项目方式）。详见 [dev-env/LOCAL-FLUTTER-SETUP.md](dev-env/LOCAL-FLUTTER-SETUP.md)。
- **远程 mop2 服务器**：**89.223.95.18**；**api、admin、web、jit、Docker、四域**等均在 mop2 上运行与开发。**密钥免密已配置**，本机可直接 `ssh root@89.223.95.18` 连接。连接后请在 **wwwroot** 下新建 **0222** 项目目录并放置代码；详见 [dev-env/README.md](dev-env/README.md)「研发服务器与项目目录」。
- **与 GitHub 仓库链接**：在**远程 mop2** 上进入项目根目录（如 `/www/wwwroot/0222`），执行 `git init`、`git remote add origin ...`、首次推送；日常后端/四域代码在 mop2 上提交与推送。**本机** Flutter App 代码可在本机仓库提交，或通过 Remote-SSH 在 mop2 上同步后推送。
- **仓库地址**：[https://github.com/herrerafreebnoapriv-debug/0222](https://github.com/herrerafreebnoapriv-debug/0222)

---

## 快速开始（开发环境）

**本机（Flutter / Android / iOS）**  
1. 按 [dev-env/LOCAL-FLUTTER-SETUP.md](dev-env/LOCAL-FLUTTER-SETUP.md) 安装 **Flutter SDK**、**Android Studio / Android SDK**；iOS 在本机编写代码，推送到仓库后使用 **GitHub 的 iOS 打包服务**（如 GitHub Actions macOS runner）构建。  
2. App 联调时将 API Host 指向 mop2（89.223.95.18），本机 hosts 可按需将四域解析到 mop2。

**远程 mop2（后端与四域）**  
1. `ssh root@89.223.95.18` 连接 mop2，在 **wwwroot** 下新建 **0222** 并放入代码。  
2. 在 mop2 上进入 `dev-env`，执行 `./setup-env.sh`，按 [dev-env/README.md](dev-env/README.md) 配置 **hosts**、**证书**、**docker-compose**。  
3. 按 [ARCHITECTURE.md](ARCHITECTURE.md) 第 10 节**模块化阶段**推进开发，并按 [PROJECT-COMPLETENESS.md](PROJECT-COMPLETENESS.md) 做阶段完整性自检。  
4. **开发/测试账户**（管理后台与 App 内置账户）见 [dev-env/README.md 第 5 节](dev-env/README.md#5-内置账户开发测试)。

---

## 四域与域名

| 域名 | 用途 |
|------|------|
| web.sdkdns.top | 用户端网页 |
| admin.sdkdns.top | 管理后台及 APK 下载 |
| api.sdkdns.top | App 通信（REST + Tinode） |
| jit.sdkdns.top | Jitsi 音视频与屏幕共享 |

详见 [ARCHITECTURE.md](ARCHITECTURE.md) 第 7–8 节。
