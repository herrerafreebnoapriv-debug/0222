# MOP APK 构建并同步至 api（Windows PowerShell）
# 用法：在项目根目录执行
#   $env:BUILD_TOKEN="xxx"; $env:API_BASE="https://api.sdkdns.top"; .\deploy\build-and-sync.ps1
# 不设置 BUILD_TOKEN/API_BASE 时仅构建并生成带版本号 APK，不同步。

$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$APP = Join-Path $ROOT "app"
Set-Location $APP

$VER_LINE = (Get-Content pubspec.yaml | Select-String '^version:').Line -replace 'version:\s*',''
$BUILD_NAME = if ($env:BUILD_NAME) { $env:BUILD_NAME } else { ($VER_LINE -split '\+')[0].Trim() }
$BUILD_NUMBER = if ($env:BUILD_NUMBER) { $env:BUILD_NUMBER } else { ($VER_LINE -split '\+')[1].Trim() }
$FILE_NAME = "mop_v$($BUILD_NAME)_$BUILD_NUMBER.apk" -replace '\s',''

Write-Host "Cleaning..."
flutter clean | Out-Null
Write-Host "Getting dependencies..."
flutter pub get | Out-Null
Write-Host "Building APK (version=$BUILD_NAME, build=$BUILD_NUMBER, arm64)..."
flutter build apk --target-platform android-arm64 --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"

$OUT_DIR = "build\app\outputs\flutter-apk"
$OUT_APK = Join-Path $OUT_DIR "app-release.apk"
if (-not (Test-Path $OUT_APK)) {
    Write-Error "Expected $OUT_APK not found"
    exit 1
}
Copy-Item $OUT_APK (Join-Path $OUT_DIR $FILE_NAME) -Force
Write-Host "Built: $OUT_DIR\$FILE_NAME"

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
