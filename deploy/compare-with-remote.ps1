# 比对本机与远程机 0222 项目差异（api、admin-test-UI、deploy）
# 用法：在项目根目录执行 .\deploy\compare-with-remote.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$localList = Join-Path $root "deploy\local-list.txt"
$remoteList = Join-Path $root "deploy\remote-list.txt"

# 1. 确保本机清单存在
if (-not (Test-Path $localList)) {
    Write-Host "正在生成本机清单 deploy/local-list.txt ..."
    Set-Location $root
    Get-ChildItem -Path api, admin-test-UI, deploy -Recurse -File -ErrorAction SilentlyContinue |
        ForEach-Object { $rel = $_.FullName.Replace("$root\", "").Replace("\", "/"); "$($_.Length) $rel" } |
        Sort-Object | Set-Content -Path $localList -Encoding UTF8
}
$localCount = (Get-Content $localList -ErrorAction SilentlyContinue).Count
Write-Host "本机清单: $localCount 个文件 (deploy/local-list.txt)"

# 2. 检查远程清单
if (-not (Test-Path $remoteList) -or ((Get-Item $remoteList).Length -eq 0)) {
    Write-Host ""
    Write-Host "未找到远程清单或文件为空。请先连接远程并生成清单：" -ForegroundColor Yellow
    Write-Host '  1) 连接: ssh root@89.223.95.18'
    Write-Host '  2) 在远程执行:'
    Write-Host '     cd /opt/0222 && find api admin-test-UI deploy -type f -exec stat -c ''%s %n'' {} \; | sed ''s|/opt/0222/||'' | sort > deploy/remote-list.txt'
    Write-Host '  3) 将远程文件拷到本机 deploy/（在本机 Git Bash 执行）:'
    Write-Host "     scp root@89.223.95.18:/opt/0222/deploy/remote-list.txt $($root -replace '\\','/')/deploy/"
    Write-Host '  4) 再运行本脚本: .\deploy\compare-with-remote.ps1'
    exit 1
}
$remoteCount = (Get-Content $remoteList -ErrorAction SilentlyContinue).Count
Write-Host "远程清单: $remoteCount 个文件 (deploy/remote-list.txt)"

# 3. 比对
Write-Host ""
Write-Host "=== diff 结果 ===" -ForegroundColor Cyan
$diff = Compare-Object (Get-Content $localList) (Get-Content $remoteList)
if (-not $diff) {
    Write-Host "一致：本机与远程文件列表及大小相同。" -ForegroundColor Green
} else {
    $onlyLocal = ($diff | Where-Object SideIndicator -eq "=>").Count
    $onlyRemote = ($diff | Where-Object SideIndicator -eq "<=").Count
    Write-Host "存在差异: 仅本机 $onlyLocal 条, 仅远程 $onlyRemote 条." -ForegroundColor Yellow
    $diff | ForEach-Object { $_.InputObject }
}
