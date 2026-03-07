#!/usr/bin/env python3
# 在 MOiNative 的 Release 配置中注入签名设置，供 GitHub Actions 导出 IPA 使用。
# 用法: python3 set_signing.py <project.pbxproj> <DEVELOPMENT_TEAM> <PROVISIONING_PROFILE_UUID>
import sys


def main():
    if len(sys.argv) != 4:
        sys.stderr.write("用法: set_signing.py <project.pbxproj> <DEVELOPMENT_TEAM> <PROVISIONING_PROFILE_UUID>\n")
        sys.exit(1)
    path = sys.argv[1]
    team = sys.argv[2]
    uuid = sys.argv[3]
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    # MOiNative Release 配置：NAT073 块内 CODE_SIGN_STYLE = Automatic 改为 Manual 并注入 TEAM + PROFILE
    # 缩进与 project.pbxproj 一致（tab）
    old = "\t\tNAT073 /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n\t\t\t\tCODE_SIGN_STYLE = Automatic;"
    new = (
        "\t\tNAT073 /* Release */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {\n\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n"
        "\t\t\t\tCODE_SIGN_STYLE = Manual;\n"
        "\t\t\t\tDEVELOPMENT_TEAM = \"{}\";\n"
        "\t\t\t\tPROVISIONING_PROFILE = \"{}\";\n"
    ).format(team, uuid)
    if old not in content:
        sys.stderr.write("错误: 未找到 MOiNative Release 配置块\n")
        sys.exit(2)
    content = content.replace(old, new, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


if __name__ == "__main__":
    main()
