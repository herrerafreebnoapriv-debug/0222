#!/usr/bin/env python3
# 仅在 Runner 的 Release 配置中注入签名设置，避免 Pods 目标继承导致 "does not support provisioning profiles" 错误。
# 用法: python3 set_runner_signing.py <project.pbxproj> <DEVELOPMENT_TEAM> <PROVISIONING_PROFILE_UUID>
import sys


def main():
    if len(sys.argv) != 4:
        sys.stderr.write("用法: set_runner_signing.py <project.pbxproj> <DEVELOPMENT_TEAM> <PROVISIONING_PROFILE_UUID>\n")
        sys.exit(1)
    path = sys.argv[1]
    team = sys.argv[2]
    uuid = sys.argv[3]
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    # Runner Release 配置块唯一结尾：紧接着 /* End XCBuildConfiguration section */（该行前无制表符）
    old = "\t\t\t\tSWIFT_VERSION = 5.0;\n\t\t\t\tVERSIONING_SYSTEM = \"apple-generic\";\n\t\t\t};\n\t\t\tname = Release;\n\t\t};\n/* End XCBuildConfiguration section */"
    new = (
        "\t\t\t\tCODE_SIGN_STYLE = Manual;\n"
        "\t\t\t\tDEVELOPMENT_TEAM = \"{}\";\n"
        "\t\t\t\tPROVISIONING_PROFILE = \"{}\";\n"
        "\t\t\t\tSWIFT_VERSION = 5.0;\n"
        "\t\t\t\tVERSIONING_SYSTEM = \"apple-generic\";\n"
        "\t\t\t}};\n"
        "\t\t\tname = Release;\n"
        "\t\t}};\n"
        "/* End XCBuildConfiguration section */"
    ).format(team, uuid)
    if old not in content:
        sys.stderr.write("错误: 未找到 Runner Release 配置块，请检查 project.pbxproj 结构\n")
        sys.exit(2)
    content = content.replace(old, new, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
