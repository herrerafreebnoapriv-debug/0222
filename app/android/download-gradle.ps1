# 手动下载 Gradle 8.14 并放入缓存，便于查看进度与大小
# 文件约 150MB，下载完成后在项目根执行: flutter build apk

$ErrorActionPreference = "Stop"
$url = "https://services.gradle.org/distributions/gradle-8.14-all.zip"
$gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE ".gradle" }
# Gradle 对同一 distributionUrl 使用的子目录名（由 URL 生成，通常固定）
$hashDir = "c2qonpi39x1mddn7hk5gh9iqj"
$distDir = Join-Path $gradleUserHome "wrapper\dists\gradle-8.14-all\$hashDir"
$zipPath = Join-Path $distDir "gradle-8.14-all.zip"

if (Test-Path $zipPath) {
    $len = (Get-Item $zipPath).Length
    Write-Host "已存在: $zipPath ($([math]::Round($len/1MB, 2)) MB)，无需重复下载。"
    exit 0
}

New-Item -ItemType Directory -Path $distDir -Force | Out-Null
Write-Host "下载 Gradle 8.14 (~150 MB) 到: $zipPath"
Write-Host ""

# 使用 curl 显示进度（Windows 10+ 自带）
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if ($curl) {
    & curl.exe -L -# -o $zipPath $url
} else {
    # 无 curl 时用 PowerShell 带进度下载
    $ProgressPreference = "Continue"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
}

if (Test-Path $zipPath) {
    $len = (Get-Item $zipPath).Length
    Write-Host ""
    Write-Host "下载完成: $([math]::Round($len/1MB, 2)) MB。请执行: flutter build apk"
} else {
    Write-Host "下载失败，请检查网络或代理。"
    exit 1
}
