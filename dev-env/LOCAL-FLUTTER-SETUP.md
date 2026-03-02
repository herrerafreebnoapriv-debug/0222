# 本机 Flutter 开发环境配置（Android / iOS）

本文档说明在**本机（Windows）**配置 Flutter 开发环境，用于开发 **Android** 与 **iOS** 端 App 代码。**后端、四域服务（api、admin、web、jit）均在远程 mop2 服务器上运行**，见 [README.md](README.md)「研发服务器与项目目录」。

---

## 环境分工

| 位置 | 用途 | 说明 |
|------|------|------|
| **本机（Windows）** | Flutter App 开发、Android 构建与调试、**iOS 代码编写**（iOS 包由 GitHub 构建服务产出） | Flutter SDK、Android Studio / Android SDK、模拟器或真机；iOS 在本机出代码后推送到仓库，由 **GitHub 提供的 iOS 打包服务**（如 GitHub Actions macOS runner）构建，沿用此前 mop 项目做法 |
| **远程 mop2（89.223.95.18）** | api、admin、web、jit、Docker、数据库、四域联调 | 见 dev-env/README.md；App 通过配置的 api 域名（如 api.sdkdns.top 或服务器 IP）连接后端 |

本机 Flutter 工程通过 **API Host** 指向 mop2 上的 api 服务进行联调；hosts 或发布配置中将四域域名解析到 89.223.95.18 即可。

---

## 1. 安装 Flutter SDK（本机 Windows）

1. **下载 Flutter SDK**  
   - 本机已通过 **Git 克隆** 安装到 **C:\src\flutter**（`git clone https://github.com/flutter/flutter.git -b stable --depth 1`），并已将 **C:\src\flutter\bin** 加入用户 PATH。  
   - 若需重装或使用其他路径：打开 [https://docs.flutter.dev/get-started/install/windows](https://docs.flutter.dev/get-started/install/windows) 或 [https://flutter.cn/docs/get-started/install/windows](https://flutter.cn/docs/get-started/install/windows)（国内镜像），下载最新稳定版并解压到不含空格与中文的路径，例如 `C:\src\flutter`。

2. **配置环境变量**  
   - 将 Flutter 的 **bin** 目录加入系统 **Path**，例如：`C:\src\flutter\bin`。  
   - 可选：新增 `PUB_HOSTED_URL`、`FLUTTER_STORAGE_BASE_URL`（国内镜像加速，见 Flutter 中文网）。

3. **验证安装**  
   在 PowerShell 或 CMD 中执行：
   ```bash
   flutter doctor
   ```
   根据提示安装缺失依赖（如 Android Studio、Visual Studio 等）。

---

## 2. Android 开发环境（本机 Windows）

1. **Android SDK（本机已配置方式）**  
   - 本机已使用 **Android 命令行工具**（cmdline-tools）+ **Microsoft OpenJDK 17** 安装 SDK，无需完整 Android Studio。  
   - **SDK 路径**：`%LOCALAPPDATA%\Android\Sdk`；**JAVA_HOME**：`C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot`（已写入用户环境变量）。  
   - 已安装：platform-tools、platforms;android-29、android-35、android-36、build-tools;28.0.3 与 34.0.0；已执行 `flutter doctor --android-licenses` 接受许可。  
   - 若需完整 IDE，可再安装 **Android Studio**（winget install Google.AndroidStudio）；否则用命令行 + Cursor/VS Code 即可开发 Android。

2. **配置 Android SDK**  
   - 打开 Android Studio → **Settings / Preferences** → **Languages & Frameworks** → **Android SDK**。  
   - 确认 **Android SDK Location**（如 `C:\Users\你的用户名\AppData\Local\Android\Sdk`）。  
   - 安装 **Android SDK Platform** 对应规约最低版本 **API 29（Android 10）** 及以上。

3. **接受许可**  
   在终端执行：
   ```bash
   flutter doctor --android-licenses
   ```
   按提示输入 `y` 接受所有许可。

4. **再次检查**  
   ```bash
   flutter doctor
   ```
   确保 **Android toolchain** 为 ✓；可连接真机或创建 AVD 进行运行与调试。

---

## 3. iOS：本机出代码 + GitHub 打包服务

**流程**：在本机编写 **iOS 相关代码**（Dart/Flutter 及 iOS 原生桥接等），推送到仓库后，使用 **GitHub 提供的 iOS 打包服务**（如 **GitHub Actions** 的 macOS runner）进行构建与产出 IPA。**此前 mop 项目已采用该方式**，本项目沿用。

- **本机（Windows）**：编写与调试 **Dart/Flutter 及 iOS 平台代码**，无需在本机安装 Xcode 或 macOS。  
- **构建与签名**：在仓库中配置 **GitHub Actions workflow**（macOS 环境、Xcode、CocoaPods、`flutter build ios` 或 Xcode 归档），推送后由 GitHub 自动或手动触发构建；签名证书与描述文件通过 GitHub Secrets 配置（与 mop 项目一致）。  
- **规约**：iOS 最低版本 **iOS 17.0**，workflow 中需指定对应 Xcode 与部署目标。

**实现时**：在仓库 `.github/workflows/` 下新增或复用 **iOS 构建 workflow**（参考此前 mop 项目的 CI 配置），确保 Flutter 版本、CocoaPods、证书与 Secrets 与 mop 实践一致。

---

## 4. 本机与远程联调

- **API 地址**：Flutter App 中配置的 API Host 指向 **mop2 服务器**上的 api 服务。若 api 使用域名（如 `api.sdkdns.top`），需在本机 **hosts** 中将该域名解析到 `89.223.95.18`；若直接使用 IP，可配置为 `http://89.223.95.18:端口`（具体端口由 mop2 上 api 暴露方式决定）。  
- **证书**：若 api 使用 HTTPS 且为自签名证书，真机/模拟器需信任该证书或开发阶段使用 HTTP（仅测试环境）。  
- **四域**：web、admin、jit 同样部署在 mop2 上，按 ARCHITECTURE 与 dev-env 配置；App 仅需能访问 api（及 Tinode、Jitsi 的端点）即可。

---

## 5. 推荐本机目录与仓库

- 将 **0222** 项目（或 Flutter App 子项目）放在本机目录，例如 `C:\Users\robot\Documents\0222`。  
- Flutter App 代码可在该仓库下新建目录（如 `app`）或单独仓库，通过 **git submodule** 或复制方式与规约仓库关联。  
- 后端、admin、web、jit 的代码与运行环境在 **mop2 服务器**上（如 `/www/wwwroot/0222`），本机通过 **Remote-SSH** 连接 mop2 编辑与部署，或通过 git 与本机同步。

---

## 6. 快速检查清单

| 项 | 本机（Windows） | 说明 |
|----|-----------------|------|
| Flutter SDK | ✓ 安装并加入 Path | `flutter doctor` |
| Android SDK | ✓ API 29+，许可已接受 | `flutter doctor --android-licenses` |
| iOS 构建 | 本机出代码 → 推送到仓库 → **GitHub iOS 打包服务** | 沿用此前 mop 项目 workflow（macOS runner + Xcode） |
| 连接 mop2 api | 配置 Host 或 hosts | App 指向 89.223.95.18 上的 api |
| 后端 / 四域 | 在 mop2 上运行 | 见 dev-env/README.md |

更多规约与架构见项目根目录 [README.md](../README.md)、[ARCHITECTURE.md](../ARCHITECTURE.md)。
