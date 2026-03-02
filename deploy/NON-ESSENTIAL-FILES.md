# 推送到仓库前：可排除的非必要文件与目录

推送前建议确保以下内容**已被 .gitignore 排除**或**从待上传目录中删除**，以减小仓库体积、加快克隆与推送。

---

## 一、app 目录（Flutter，体积主要来源）

| 路径 | 说明 | 是否已在 .gitignore |
|------|------|---------------------|
| `app/build/` | Flutter 构建输出（APK、中间文件等） | ✓ app/.gitignore |
| `app/.dart_tool/` | Dart 分析/插件缓存 | ✓ |
| `app/.pub-cache/`、`app/.pub/` | Pub 缓存 | ✓ |
| `app/.flutter-plugins-dependencies` | 插件依赖清单（可再生成） | ✓ |
| `app/android/build/` | Android Gradle 构建根目录 | ✓ 已补全 |
| `app/android/app/build/` | Android 应用构建产物 | ✓ 已补全 |
| `app/android/.gradle/` | Gradle 缓存 | ✓ android/.gitignore |
| `app/android/local.properties` | 本机 SDK 路径（勿提交） | ✓ |
| `app/android/captures/` | 截图等 | ✓ |
| `app/ios/Pods/` | CocoaPods 依赖（可 pod install 再生成） | ✓ ios/.gitignore |
| `app/ios/Flutter/` 下框架与生成文件 | Flutter 引擎与生成配置 | ✓ |
| `app/ios/build/`、`DerivedData/` | Xcode 构建产物 | ✓ 已补全 |

**结论**：使用 `git add .` 推送时，上述内容会被忽略；若你是**直接复制整个 app 文件夹**到远程机再推送，请先在远程机**删除**这些目录再 `git add`，否则会一起被提交。

---

## 二、项目根目录及其他

| 路径 | 说明 | 是否已在 .gitignore |
|------|------|---------------------|
| `deploy/certs/*.pem` | SSL 证书与私钥（安全） | ✓ 根 .gitignore、deploy/certs/.gitignore |
| `.env`、`*.local` | 环境与本地配置 | ✓ 根 .gitignore |
| `*.log` | 日志 | ✓ |
| `.idea/`、`.vscode/`（可选） | IDE 配置 | 部分 |

---

## 三、推送前在远程机做一次「瘦身」（若已整目录上传过）

若你之前把**整个 app**（含 build、.dart_tool 等）都上传到了远程机，建议在远程机执行一次删除再提交，避免首次推送包含大量构建产物：

```bash
cd /opt/0222

# 删除 app 下不需要提交的目录（仅删本地，不影响本机）
rm -rf app/build
rm -rf app/.dart_tool
rm -rf app/.pub-cache
rm -rf app/.pub
rm -f app/.flutter-plugins-dependencies
rm -rf app/android/build
rm -rf app/android/app/build
rm -rf app/android/.gradle
rm -rf app/ios/Pods
rm -rf app/ios/build
rm -rf app/ios/Flutter/App.framework
rm -rf app/ios/Flutter/Flutter.framework
rm -rf app/ios/Flutter/ephemeral
# 以上按需执行，若目录不存在会报错可忽略

# 再添加并提交
git add .
git status   # 确认没有 build、.dart_tool、Pods 等被加入
git commit -m "chore: initial push, exclude build artifacts"
git push -u origin main
```

之后在任意机器上 `git clone` 后，在 app 目录执行 `flutter pub get`（以及 iOS 的 `pod install`）即可恢复依赖与构建环境。

---

## 四、建议保留、必须提交的内容

- `app/pubspec.yaml`、`app/pubspec.lock`（依赖定义与锁定）
- `app/lib/**`（源码）
- `app/ios/Runner/**`（除 Flutter 生成与 build 外）
- `app/android/app/src/**`、`app/android/*.gradle*`、`gradle/wrapper/` 等（工程与脚本）
- `app/test/`（测试）
- 根目录文档、`api/`、`admin-test-UI/`、`app-test-UI/`、`deploy/` 等

这样推送后仓库体积会小很多，克隆和后续同步也会更快。
