# 本机移动端目录与依赖位置

项目根目录下的 **app** 为 Flutter 移动端（Android / iOS），以下路径均为本机绝对路径。

---

## 一、移动端项目目录（0222/app）

| 路径 | 说明 |
|------|------|
| **c:\Users\robot\Documents\0222\app** | 移动端项目根目录（Flutter 工程） |
| app\lib | Dart 源码（core、screens、services、utils、l10n） |
| app\android | Android 原生工程（Kotlin、Gradle） |
| app\ios | iOS 原生工程（Xcode） |
| app\assets\images | 资源图片 |
| app\test | 单元/测试 |
| app\pubspec.yaml | Flutter 依赖与版本（name: mop_app, version: 1.0.6+7） |

---

## 二、依赖与缓存位置

### 1. Flutter / Dart（Pub 包）

| 用途 | 路径 |
|------|------|
| Pub 包缓存 | **C:\Users\robot\AppData\Roaming\Pub\Cache** |
| 项目已解析依赖 | app\.dart_tool\package_config.json（及 .dart_tool 下其它生成文件） |
| 依赖声明 | app\pubspec.yaml（dependencies / dev_dependencies） |

### 2. Flutter SDK（由 android\local.properties 指定）

| 用途 | 路径 |
|------|------|
| Flutter SDK | **C:\src\flutter** |
| 当前版本 | Flutter 3.41.2，Dart 3.11.0（以 `flutter --version` 为准） |

### 3. Android 构建与 SDK

| 用途 | 路径 |
|------|------|
| Android SDK | **C:\Users\robot\AppData\Local\Android\Sdk** |
| 配置来源 | app\android\local.properties（sdk.dir、flutter.sdk） |
| Gradle 缓存 / 构建 | app\android\.gradle（含 8.14 等版本） |
| Gradle 发行版 | gradle-wrapper 拉取：gradle-8.14（见 app\android\gradle\wrapper\gradle-wrapper.properties） |
| 应用构建输出 | app\build\app\outputs（APK 等） |
| 插件构建中间产物 | app\build\（各 Flutter 插件子目录） |

### 4. Android 工程关键文件

| 文件 | 说明 |
|------|------|
| app\android\app\build.gradle.kts | 应用级构建（applicationId: com.mop.mop_app，minSdk 29，arm64-v8a） |
| app\android\build.gradle.kts | 根级构建、build 目录重定向到 ../../build |
| app\android\settings.gradle.kts | 插件与 Flutter SDK 路径（从 local.properties 读 flutter.sdk） |
| app\android\local.properties | 本机 sdk.dir、flutter.sdk（勿提交版本库） |

### 5. iOS（本机若未装 Xcode 可仅作参考）

| 用途 | 路径 |
|------|------|
| iOS 工程 | app\ios\Runner.xcworkspace / Runner.xcodeproj |
| Flutter 生成文件 | app\ios\Flutter\ephemeral |

---

## 三、常用命令（在 app 目录下）

```bash
cd c:\Users\robot\Documents\0222\app
flutter pub get          # 拉取/更新 Pub 依赖到 Pub Cache 并写 .dart_tool
flutter clean            # 清理 build、.dart_tool 等
flutter build apk        # 构建 Android APK（输出在 build/app/outputs）
```

---

## 四、依赖汇总（pubspec.yaml 主要项）

- **运行时**：flutter_secure_storage, http, qr_flutter, device_info_plus, package_info_plus, crypto, encrypt, pointycastle, shared_preferences, image_picker, permission_handler, geolocator, geocoding, jitsi_meet_flutter_sdk 等  
- **开发**：flutter_test, flutter_launcher_icons, flutter_lints  
- **SDK**：Dart ^3.11.0，Flutter SDK
