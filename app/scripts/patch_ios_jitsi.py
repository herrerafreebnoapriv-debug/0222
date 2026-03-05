#!/usr/bin/env python3
# iOS 构建前打补丁：注释 GeneratedPluginRegistrant.m 中的 Jitsi 注册，避免启动时 JitsiMeetPlugin.register 崩溃。
# 用法：在 app 目录下执行 python3 scripts/patch_ios_jitsi.py [ios/Runner/GeneratedPluginRegistrant.m]
# 应在 flutter pub get 之后执行；若使用 xcodebuild archive，需在 flutter build ios 之后、archive 之前再执行一次（因 build 可能覆盖该文件）。

import sys
import os


def main():
    default_path = os.path.join(
        os.path.dirname(__file__), "..", "ios", "Runner", "GeneratedPluginRegistrant.m"
    )
    path = sys.argv[1] if len(sys.argv) > 1 else default_path
    path = os.path.normpath(os.path.abspath(path))

    if not os.path.isfile(path):
        print(f"patch_ios_jitsi.py: {path} not found (run from app dir after flutter pub get)", file=sys.stderr)
        sys.exit(1)

    with open(path, "r", encoding="utf-8", newline=None) as f:
        lines = f.readlines()

    if not any("JitsiMeetPlugin registerWithRegistrar" in line for line in lines):
        print("patch_ios_jitsi.py: no Jitsi registration found (already patched or no jitsi dependency)")
        return

    out = []
    i = 0
    in_jitsi_block = False
    while i < len(lines):
        line = lines[i]
        stripped = line.lstrip()
        # 进入 Jitsi 的 #if 块
        if "#if __has_include(<jitsi_meet_flutter_sdk" in line and not in_jitsi_block:
            in_jitsi_block = True
        if in_jitsi_block:
            out.append("// " + line if not line.strip().startswith("//") else line)
            if stripped.startswith("#endif") or stripped.startswith("// #endif"):
                in_jitsi_block = False
            i += 1
            continue
        if "[JitsiMeetPlugin registerWithRegistrar" in line:
            out.append("// " + line if not line.strip().startswith("//") else line)
            i += 1
            continue
        out.append(line)
        i += 1

    with open(path, "w", encoding="utf-8", newline="") as f:
        f.writelines(out)

    print(f"patch_ios_jitsi.py: patched Jitsi in {path}")


if __name__ == "__main__":
    main()
