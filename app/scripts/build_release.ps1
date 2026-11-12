# Validates the production configuration and builds the .aab for Google Play.
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1
$ErrorActionPreference = "Stop"

$appDir = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $appDir "config\release.json"
$propertiesPath = Join-Path $appDir "android\key.properties"
$googleTestPublisher = "ca-app-pub-3940256099942544"

if (-not (Test-Path $configPath)) {
    throw "config\release.json not found. Copy config\release.example.json and fill in the real values."
}
if (-not (Test-Path $propertiesPath)) {
    throw "android\key.properties not found. Run scripts\create_keystore.ps1 first."
}

$config = Get-Content -Raw -Encoding UTF8 $configPath | ConvertFrom-Json
$problems = @()

$apiUrl = [string]$config.API_BASE_URL
if ($apiUrl -notmatch '^https://[^/]+') {
    $problems += "API_BASE_URL must start with https://"
}
if ($apiUrl -match 'example|SEU_|localhost') {
    $problems += "API_BASE_URL still has a placeholder value"
}

$patterns = @{
    "ADMOB_APP_ID_ANDROID"      = '^ca-app-pub-\d{16}~\d{10}$'
    "ADMOB_BANNER_ANDROID_ID"   = '^ca-app-pub-\d{16}/\d{10}$'
    "ADMOB_REWARDED_ANDROID_ID" = '^ca-app-pub-\d{16}/\d{10}$'
}
foreach ($name in $patterns.Keys) {
    $value = [string]$config.$name
    if ($value -notmatch $patterns[$name]) {
        $problems += "$name has an invalid format"
    }
    elseif ($value -match '^ca-app-pub-0{16}') {
        $problems += "$name still has a placeholder value"
    }
    elseif ($value.StartsWith($googleTestPublisher)) {
        $problems += "$name is a Google test ID"
    }
}

if ($problems.Count -gt 0) {
    Write-Host "Fix config\release.json:" -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Push-Location $appDir
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze found problems." }

    & flutter test
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }

    & flutter build appbundle --release --dart-define-from-file=config/release.json
    if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed." }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Bundle ready: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
