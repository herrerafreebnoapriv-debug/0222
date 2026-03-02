# 在远程机与 GitHub 之间同步项目

项目仓库：[https://github.com/herrerafreebnoapriv-debug/0222](https://github.com/herrerafreebnoapriv-debug/0222)

本机无法直连 GitHub 时，可在**远程机**（如 89.223.95.18）上完成首次推送与后续同步。

---

## 一、首次从远程机推送到 GitHub

在**远程机**上执行（项目已放在 `/opt` 下时）：

```bash
cd /opt/0222
# 若项目在 /opt 下其它目录，请改为实际路径，如 cd /opt/0222-mop

# 安装 git（若未安装）
apt update && apt install -y git

# 若尚未初始化
git init
git branch -M main

# 添加远程仓库
git remote add origin https://github.com/herrerafreebnoapriv-debug/0222.git
# 若已添加过但地址不对，可先删除再加：git remote remove origin

# 添加所有文件并提交（证书 *.pem 已被 .gitignore 排除）
git add .
git status
git commit -m "chore: initial push from remote server"

# 推送（仓库为空时可直接 push；若 GitHub 已有 README 等，可先 pull --rebase 再 push）
git push -u origin main
```

若推送时要求登录，请使用 **Personal Access Token（PAT）** 作为密码，或配置 SSH 后改用 SSH 地址：

```bash
git remote set-url origin git@github.com:herrerafreebnoapriv-debug/0222.git
git push -u origin main
```

---

## 二、每次修改后同步到仓库

在**远程机**项目目录下执行：

```bash
cd /opt/0222   # 或你的实际项目路径

git add .
git status
git commit -m "描述本次修改"
git push origin main
```

可将上述命令保存为脚本，便于一键同步，例如：

```bash
# 保存为 /opt/0222/deploy/sync-to-github.sh，然后 chmod +x deploy/sync-to-github.sh
#!/bin/bash
set -e
cd "$(dirname "$0")/.."
git add .
if git diff --cached --quiet; then
  echo "无变更，跳过提交"
  exit 0
fi
git commit -m "${1:-sync: update from remote}"
git push origin main
echo "已推送到 GitHub"
```

使用方式：`./deploy/sync-to-github.sh` 或 `./deploy/sync-to-github.sh "fix: 修复登录页"`。

---

## 三、本机与远程机代码不一致时

- **本机修改后**：用 scp/rsync 或其它方式把变更同步到远程机 `/opt/0222`，再在远程机执行上面的「每次修改后同步」。
- **远程机先改、本机后拉**：在本机（若能访问 GitHub）执行 `git pull origin main`；若本机不能访问 GitHub，可从远程机用 `scp` 把 `.git` 或补丁拷回本机后再合并。
