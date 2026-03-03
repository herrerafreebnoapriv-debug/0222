# 应用图标与中英文名称设置说明

## 一、应用名称（中英文）

### Android（已配置）

- **英文**：编辑 `android/app/src/main/res/values/strings.xml`，修改 `app_name` 的取值。
- **中文**：编辑 `android/app/src/main/res/values-zh/strings.xml`，修改 `app_name` 的取值。  
  系统语言为中文时，桌面和任务栏会显示该名称。
- 主清单已使用 `android:label="@string/app_name"`，无需再改 `AndroidManifest.xml`。

### iOS（已创建本地化文件）

- **默认/英文**：`ios/Runner/Base.lproj/InfoPlist.strings` 中修改 `CFBundleDisplayName` 与 `CFBundleName`。
- **简体中文**：`ios/Runner/zh-Hans.lproj/InfoPlist.strings` 中修改上述两个键的取值。
- 若要在真机上按系统语言切换中英文名，需在 **Xcode** 中把这两个 `InfoPlist.strings` 加入工程并配置本地化：
  1. 用 Xcode 打开 `ios/Runner.xcworkspace`；
  2. 在左侧选中 Runner → 右键 `Base.lproj` → Add Files to "Runner" → 选 `InfoPlist.strings`（Base）；
  3. 选中刚加入的 `InfoPlist.strings` → 右侧 File Inspector → Localization 中勾选 Base、添加 Chinese (Simplified)，并确保 `zh-Hans.lproj/InfoPlist.strings` 被关联为简体中文版本；
  4. 或：Project → Info → Localizations 中已有 Chinese, Simplified 时，为 `InfoPlist.strings` 添加对应语言版本即可。

未配置 Xcode 本地化时，桌面显示名仍以 `Info.plist` 中的 `CFBundleDisplayName` 为准（当前为 "Mop App"），可直接改 `Info.plist` 做单一名称。

---

## 二、应用图标

### 方式一：使用 flutter_launcher_icons（推荐）

1. 在 `pubspec.yaml` 的 `dev_dependencies` 中添加：
   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.14.3
   ```

2. 在 `pubspec.yaml` 末尾添加配置（路径按你实际图标文件改）：
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/images/app_icon.png"   # 建议 1024x1024 一张图
     # 可选：自适应图标（Android）
     # adaptive_icon_background: "#3D3A36"
     # adaptive_icon_foreground: "assets/images/app_icon_foreground.png"
   ```

3. 准备一张 **1024×1024** 的 PNG 作为图标（可放在 `assets/images/app_icon.png`，并在 `flutter` → `assets` 中声明该文件或目录）。

4. 在项目根目录执行：
   ```bash
   flutter pub get
   dart run flutter_launcher_icons
   ```
   会生成 Android 各分辨率与 iOS `AppIcon.appiconset` 所需图片。

### 方式二：手动替换

- **Android**：在 `android/app/src/main/res/` 下准备（若不存在则新建）：
  - `mipmap-mdpi/ic_launcher.png`（约 48×48）
  - `mipmap-hdpi/ic_launcher.png`（约 72×72）
  - `mipmap-xhdpi/ic_launcher.png`（约 96×96）
  - `mipmap-xxhdpi/ic_launcher.png`（约 144×144）
  - `mipmap-xxxhdpi/ic_launcher.png`（约 192×192）  
  主清单中已使用 `android:icon="@mipmap/ic_launcher"`，替换上述文件即可。

- **iOS**：在 `ios/Runner/Assets.xcassets/AppIcon.appiconset/` 中按 `Contents.json` 里列出的尺寸替换对应 PNG（如 20@2x、20@3x、29@1x… 直至 1024@1x），或使用 Xcode 打开该 AppIcon 后拖入一张 1024×1024 由 Xcode 自动生成各尺寸。

---

修改名称或图标后，建议执行一次 **清理并重新构建**（如 `flutter clean && flutter pub get`，再 `flutter build apk` / `flutter build ios`），以确保安装包中的图标与名称已更新。
