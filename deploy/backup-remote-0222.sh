#!/usr/bin/env bash
# 在远程机执行：将 /opt/0222 压缩为 0222-305-1538bak.tar.gz（放在 /opt 或当前目录）
# 用法：ssh root@89.223.95.18 连接后执行：
#   cd /opt && tar czvf 0222-305-1538bak.tar.gz 0222
# 压缩包生成在 /opt/0222-305-1538bak.tar.gz
set -e
cd /opt
tar czvf 0222-305-1538bak.tar.gz 0222
echo "已生成 /opt/0222-305-1538bak.tar.gz"
