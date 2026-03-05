#!/usr/bin/env python3
# 从 iOS 构建的插件列表中移除 jitsi_meet_flutter_sdk，使 iOS 不安装/不链接 Jitsi，避免启动崩溃。
# 用法：在 app 目录下执行 python3 scripts/remove_ios_jitsi_plugin.py
# 应在 flutter pub get 之后、flutter build ios / pod install 之前执行。

import json
import os
import sys

PLUGIN_NAME = "jitsi_meet_flutter_sdk"


def main():
    app_dir = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..")
    )
    deps_path = os.path.join(app_dir, ".flutter-plugins-dependencies")
    plugins_path = os.path.join(app_dir, ".flutter-plugins")

    changed = False

    # 1. .flutter-plugins（若存在）：按行移除 jitsi_meet_flutter_sdk=...
    if os.path.isfile(plugins_path):
        with open(plugins_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        new_lines = [ln for ln in lines if not ln.strip().startswith(PLUGIN_NAME + "=")]
        if len(new_lines) != len(lines):
            with open(plugins_path, "w", encoding="utf-8") as f:
                f.writelines(new_lines)
            changed = True

    # 2. .flutter-plugins-dependencies：从 plugins.ios 中移除 jitsi_meet_flutter_sdk
    if not os.path.isfile(deps_path):
        print("remove_ios_jitsi_plugin.py: .flutter-plugins-dependencies not found", file=sys.stderr)
        sys.exit(1)

    with open(deps_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    plugins = data.get("plugins") or {}
    ios_list = plugins.get("ios") or []
    new_ios = [p for p in ios_list if p.get("name") != PLUGIN_NAME]
    if len(new_ios) != len(ios_list):
        plugins["ios"] = new_ios
        data["plugins"] = plugins
        with open(deps_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        changed = True

    if changed:
        print(f"remove_ios_jitsi_plugin.py: removed {PLUGIN_NAME} from iOS plugin list")
    else:
        print(f"remove_ios_jitsi_plugin.py: {PLUGIN_NAME} not in iOS list (already removed)")


if __name__ == "__main__":
    main()
