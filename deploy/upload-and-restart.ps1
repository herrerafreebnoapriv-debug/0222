# 在 Cursor 自带终端运行：上传代码到远程机并编译重启（不碰 GitHub）
# 用法：Cursor 中按 Ctrl+` 打开终端，cd 到项目根目录后执行：
#   .\deploy\upload-and-restart.ps1
# 需本机 ssh root@89.223.95.18 可直连；由您在本机终端执行才会使用您的 SSH 密钥。
$ErrorActionPreference = "Stop"
$REMOTE = "root@89.223.95.18"
$REMOTE_PATH = "/www/wwwroot/0222"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
# Git Bash 路径：C:\Users\robot\Documents\0222 -> /c/Users/robot/Documents/0222
$bashPath = ($ProjectRoot -replace '\\','/' -replace '^([A-Za-z]):','/$1').ToLowerInvariant()

$bash = "C:\Program Files\Git\bin\bash.exe"
if (-not (Test-Path $bash)) {
    Write-Host "未找到 Git Bash: $bash"
    exit 1
}

Write-Host "=== 执行 upload-and-restart.sh（REMOTE=$REMOTE REMOTE_PATH=$REMOTE_PATH）===" -ForegroundColor Cyan
$scriptPath = "$bashPath/deploy/upload-and-restart.sh"
& $bash -c "export REMOTE='$REMOTE' REMOTE_PATH='$REMOTE_PATH'; cd '$bashPath' && bash '$scriptPath'"
exit $LASTEXITCODE
