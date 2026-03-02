# 本机、远程机与 GitHub 同步说明

- **本机**：你当前开发的电脑。
- **远程机**：后端服务器（部署 api/web/admin 的那台机器，如 89.223.95.18）。文档中「远程机」均指此后端服务器，**不是** GitHub。
- **GitHub**：代码托管仓库 [https://github.com/herrerafreebnoapriv-debug/0222](https://github.com/herrerafreebnoapriv-debug/0222)。需要与 GitHub 同步时会明确写出「GitHub」。

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

## 三、本机 → 远程机（后端服务器）同步代码

把本机当前代码同步到**远程机**（后端服务器），使服务器上的代码与本机一致。

### 方式 A：本机用 rsync/scp 推到远程机（推荐）

在本机执行（需能 SSH 登录远程机）：

```bash
# 在项目根目录执行，按实际修改 REMOTE 和路径
export REMOTE="root@89.223.95.18"           # 或 your_user@your-server-ip
export REMOTE_PATH="/www/wwwroot/0222"        # 或 /opt/0222

# rsync：排除 .git、node_modules、dist 等，与远程机目录同步
rsync -avz --delete \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='dist' \
  --exclude='*.pem' \
  --exclude='.env' \
  . "$REMOTE:$REMOTE_PATH/"
```

Windows 本机可用 Git Bash、WSL 或 PowerShell 的 `scp -r` 做整目录拷贝（无 rsync 时）：

```powershell
scp -r . "$REMOTE`:${REMOTE_PATH}/"
```

同步完成后，在**远程机**上重建并重启容器使改动生效：

```bash
cd /www/wwwroot/0222   # 或你的 REMOTE_PATH
docker compose -f deploy/docker-compose.yml up -d --build
```

### 方式 B：远程机从 GitHub 拉取

若本机已把代码推送到 GitHub，可在**远程机**上执行：

```bash
cd /www/wwwroot/0222   # 或 /opt/0222
git pull origin main
docker compose -f deploy/docker-compose.yml up -d --build
```

这样远程机与 GitHub 上 main 分支一致（前提是本机已 push）。

### 如何确认远程机代码与本机一致

- **在本机**查看当前最新提交：`git log -1 --oneline`
- **在远程机**（SSH 登录后）在项目目录执行：`git log -1 --oneline`（若远程机用 git 管理）；或对比关键文件、目录的修改时间。
- 若使用方式 A（rsync），两边目录内容一致即表示一致；若使用方式 B（git pull），两边 `git log -1 --oneline` 相同即表示一致。

## 四、本机与远程机代码不一致时（其他情况）

- **本机修改后**：按上面「三」用 rsync/scp 同步到远程机，或在远程机从 GitHub 拉取（若已 push）。
- **远程机先改、本机后拉**：在本机（若能访问 GitHub）执行 `git pull origin main`；若本机不能访问 GitHub，可从远程机用 `scp` 把 `.git` 或补丁拷回本机后再合并。
