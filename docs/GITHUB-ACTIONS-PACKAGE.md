# 使用 GitHub Actions 打包（Android / iOS）

## 一、推送代码到 GitHub

在项目根目录执行（确保已配置远程仓库与鉴权）：

```bash
git add .
git status
git commit -m "chore: iOS 17.0、checkOverlayPermission、Podfile、iOS workflow 与 device_id 约定"
git push origin main
```

若当前分支不是 `main`，改为：`git push origin <你的分支名>`。推送后 GitHub Actions 会根据 workflow 的 `on.push.branches` 自动触发（若修改了 `app/` 或 workflow 文件）。

---

## 二、在 GitHub 上操作 Actions 打包

### 1. 打开 Actions 页面

1. 浏览器打开仓库：**https://github.com/herrerafreebnoapriv-debug/0222**
2. 顶部菜单点击 **Actions**。

### 2. 选择 workflow

- **iOS Build**：用于 iOS 用户端 App 构建（macOS runner、Xcode 16、Flutter，无签名验证编译）。
- 若后续添加了 Android workflow，会多出对应条目。

### 3. 手动触发一次（可选）

若希望不依赖 push 立即跑一次：

1. 左侧点击 **iOS Build**（或你添加的 workflow 名称）。
2. 右侧点击 **Run workflow**。
3. 选择分支（通常 `main`），再点 **Run workflow**。
4. 页面会跳转到本次运行的详情，可查看日志。

### 4. 查看运行结果与日志

1. 在 **Actions** 页的 **All workflows** 列表中，点击某次 **Run**（如 “iOS Build” 或 commit 信息）。
2. 左侧点击 **build** job，右侧展开各 **Step** 查看日志。
3. **绿色勾**表示该 job 成功；**红叉**表示失败，点进失败 step 看报错。

### 5. 当前 iOS workflow 产出说明

- **iOS Build** 当前步骤：`flutter build ios --release --no-codesign`，仅验证在 macOS/Xcode 下能否编译通过，**不产出可安装的 IPA**。
- 若要产出 IPA 并上报 build-sync：需在仓库 **Settings → Secrets and variables → Actions** 中配置签名证书与描述文件、以及 `BUILD_TOKEN`、`API_BASE` 等，并在 workflow 中增加 archive、export、上传与调用 build-sync 的步骤（可后续按需添加）。

### 6. Android 打包（若已有 workflow）

若仓库中有 Android 的 workflow（例如 `android-build.yml`）：

1. 在 **Actions** 中选择该 workflow。
2. **Run workflow** 选择分支后运行。
3. 成功后若 workflow 中配置了产物上传，可在该 run 页面底部 **Artifacts** 中下载 APK。

---

## 三、常见问题

| 问题 | 处理 |
|------|------|
| 推送后没有自动跑 | 检查 push 是否包含 `app/**` 或该 workflow 文件；分支是否在 workflow 的 `on.push.branches` 中。 |
| iOS 构建失败 | 查看失败 step 日志（常见：CocoaPods、Xcode 版本、Flutter 版本）；本地可先执行 `cd app && flutter build ios --no-codesign` 对比。 |
| 需要 IPA / 签名 | 在仓库 Secrets 中配置 Apple 证书与描述文件，并在 workflow 中增加 export 与上传步骤。 |
| 需要 APK 并 build-sync | 使用或参考 `deploy/build-and-sync.sh` 的 build-sync 逻辑，在 Android workflow 中增加上传与 POST build-sync 的步骤。 |

---

## 四、仓库与分支

- **仓库**：https://github.com/herrerafreebnoapriv-debug/0222  
- **默认分支**：一般为 `main`，以仓库实际为准。  
- **Workflow 文件**：`.github/workflows/ios-build.yml`（iOS）；Android 若有则同样在 `.github/workflows/` 下。
