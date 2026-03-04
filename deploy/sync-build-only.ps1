# 仅将已构建的 APK 复制为带版本号文件名并同步到 api（不再执行 clean/build）
# 用法（在项目根目录执行）：
#   $env:BUILD_TOKEN="xxx"; $env:API_BASE="https://api.sdkdns.top"; .\deploy\sync-build-only.ps1
# 可选：$env:DOWNLOAD_URL="https://admin.example.com/apks/mop_v1.0.5_6.apk"

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$APP = Join-Path $ROOT "app"

$VER_LINE = (Get-Content (Join-Path $APP "pubspec.yaml") | Select-String '^version:').Line -replace 'version:\s*',''
$BUILD_NAME = ($VER_LINE -split '\+')[0].Trim()
$BUILD_NUMBER = ($VER_LINE -split '\+')[1].Trim()
$FILE_NAME = "mop_v$($BUILD_NAME)_$BUILD_NUMBER.apk" -replace '\s',''

$OUT_DIR = Join-Path $APP "build\app\outputs\flutter-apk"
$OUT_APK = Join-Path $OUT_DIR "app-release.apk"
if (-not (Test-Path $OUT_APK)) {
    Write-Error "APK not found. Build first: cd app; flutter build apk --target-platform android-arm64"
    exit 1
}
Copy-Item $OUT_APK (Join-Path $OUT_DIR $FILE_NAME) -Force
Write-Host "Copied: $OUT_DIR\$FILE_NAME"

if (-not $env:BUILD_TOKEN -or -not $env:API_BASE) {
    Write-Host "BUILD_TOKEN or API_BASE not set, skip build-sync."
    exit 0
}

$API_BASE = $env:API_BASE.TrimEnd('/')
$DOWNLOAD_URL = if ($env:DOWNLOAD_URL) { $env:DOWNLOAD_URL } else { "$API_BASE/apks/$FILE_NAME" }
$CHANGE_LOG = if ($env:CHANGE_LOG) { $env:CHANGE_LOG } else { "Build $BUILD_NAME ($BUILD_NUMBER)" }

$body = @{ version = $BUILD_NAME; build = [int]$BUILD_NUMBER; file_name = $FILE_NAME; download_url = $DOWNLOAD_URL; change_log = $CHANGE_LOG } | ConvertTo-Json
Write-Host "Syncing to $API_BASE/api/v1/internal/build-sync ..."
try {
    $r = Invoke-WebRequest -Uri "$API_BASE/api/v1/internal/build-sync" -Method POST -Headers @{ "Content-Type" = "application/json"; "X-Build-Token" = $env:BUILD_TOKEN } -Body $body -UseBasicParsing
    if ($r.StatusCode -eq 200) { Write-Host "build-sync OK (200)." } else { Write-Host "build-sync failed: $($r.StatusCode)"; exit 1 }
} catch {
    Write-Host "build-sync error: $_"
    exit 1
}
