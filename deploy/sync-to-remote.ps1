# 将 0222 项目从本机同步到 89.223.95.18（不涉及 GitHub）
# 必须在【本机】运行（会用到本机 ssh 到远程）。若 Cursor 终端已连到远程，请新开「本地」终端再运行。
# 用法：在项目根目录执行 .\deploy\sync-to-remote.ps1
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$bashPath = ($ProjectRoot -replace '\\','/' -replace '^([A-Za-z]):','/$1').ToLowerInvariant()
$bash = "C:\Program Files\Git\bin\bash.exe"

if (-not (Test-Path $bash)) {
    Write-Host "未找到 Git Bash: $bash"
    exit 1
}

Write-Host "=== 同步 0222 到 root@89.223.95.18:/www/wwwroot/0222 ===" -ForegroundColor Cyan
& $bash -c "export REMOTE=root@89.223.95.18 REMOTE_PATH=/www/wwwroot/0222; cd '$bashPath'; bash -c '
if command -v rsync >/dev/null 2>&1; then
  rsync -avz --delete --exclude=.git --exclude=node_modules --exclude=dist --exclude=*.pem --exclude=.env --exclude=deploy/certbot-webroot . \$REMOTE:\$REMOTE_PATH/
else
  echo \"（使用 tar+ssh 同步）\"
  tar cf - --exclude=.git --exclude=node_modules --exclude=dist --exclude=*.pem --exclude=.env --exclude=deploy/certbot-webroot . | ssh \$REMOTE \"mkdir -p \$REMOTE_PATH && cd \$REMOTE_PATH && tar xf -\"
fi
'"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host ""
Write-Host "同步完成。在远程机执行以下命令使新代码生效：" -ForegroundColor Green
Write-Host "  cd /www/wwwroot/0222 && NO_GIT=1 ./deploy/update-backend.sh" -ForegroundColor Yellow
