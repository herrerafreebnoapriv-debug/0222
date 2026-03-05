# 本机同步 0222 到 89.223.95.18（纯命令行）

**连接远程服务器命令：** `ssh root@89.223.95.18`

本机需能执行该命令直连。在**本机**任意终端中执行下面其中一种方式即可。若项目不在 `C:\Users\robot\Documents\0222`，请先 `cd` 到自己的项目根目录。

---

## 方式一：Git Bash（推荐）

打开 **Git Bash**（开始菜单搜 “Git Bash”），执行：

```bash
cd /c/Users/robot/Documents/0222
export REMOTE=root@89.223.95.18
export REMOTE_PATH=/www/wwwroot/0222
tar cf - --exclude='.git' --exclude='node_modules' --exclude='dist' --exclude='*.pem' --exclude='.env' --exclude='deploy/certbot-webroot' . | ssh $REMOTE "mkdir -p $REMOTE_PATH && cd $REMOTE_PATH && tar xf -"
```

同步完成后，在**已连到远程机的终端**里执行编译重启：

```bash
cd /www/wwwroot/0222 && NO_GIT=1 ./deploy/update-backend.sh
```

---

## 方式二：本机有 rsync 时

在 Git Bash 或已安装 rsync 的终端执行：

```bash
cd /c/Users/robot/Documents/0222
rsync -avz --delete --exclude='.git' --exclude='node_modules' --exclude='dist' --exclude='*.pem' --exclude='.env' --exclude='deploy/certbot-webroot' . root@89.223.95.18:/www/wwwroot/0222/
```

然后同上，在远程机执行：`cd /www/wwwroot/0222 && NO_GIT=1 ./deploy/update-backend.sh`

---

## 方式三：PowerShell + scp（无 tar/rsync 时）

scp 无法排除目录，会连同 .git 等一起拷，仅作备用：

```powershell
cd c:\Users\robot\Documents\0222
scp -r api admin-test-UI app-test-UI deploy dev-env *.md root@89.223.95.18:/www/wwwroot/0222/
```

（若报错可改为只拷必要目录：`scp -r api admin-test-UI deploy root@89.223.95.18:/www/wwwroot/0222/`）

同步后在远程机执行：`cd /www/wwwroot/0222 && NO_GIT=1 ./deploy/update-backend.sh`
