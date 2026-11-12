# Creates the Google Play upload key and android/key.properties.
# Run once:  powershell -ExecutionPolicy Bypass -File scripts\create_keystore.ps1
# Back up the .jks and the password. Losing them blocks future app updates.
param(
    [string]$Alias = "metafeita"
)

$ErrorActionPreference = "Stop"

$appDir = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $appDir "android"
$keystorePath = Join-Path $androidDir "meta-feita-release.jks"
$propertiesPath = Join-Path $androidDir "key.properties"

if ((Test-Path $keystorePath) -or (Test-Path $propertiesPath)) {
    throw "Keystore or key.properties already exists in android/. Nothing was changed."
}

$candidates = @(
    $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\keytool.exe" }),
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
) | Where-Object { $_ -and (Test-Path $_) }

$keytool = $candidates | Select-Object -First 1
if (-not $keytool) {
    throw "keytool.exe not found. Install Android Studio or set JAVA_HOME."
}

$secure = Read-Host "Choose the keystore password (minimum 8 characters)" -AsSecureString
$confirm = Read-Host "Type the password again" -AsSecureString

function ConvertTo-PlainText([System.Security.SecureString]$value) {
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$password = ConvertTo-PlainText $secure
if ($password -ne (ConvertTo-PlainText $confirm)) {
    throw "The passwords do not match."
}
if ($password.Length -lt 8) {
    throw "The password must have at least 8 characters."
}

$distinguishedName = "CN=Feito Labs, O=Feito Labs, C=BR"

# Passed through the environment so the password never appears in the process list.
$env:META_FEITA_KEYSTORE_PASSWORD = $password
try {
    & $keytool -genkeypair -v `
        -keystore $keystorePath `
        -storetype PKCS12 `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -alias $Alias `
        -dname $distinguishedName `
        -storepass:env META_FEITA_KEYSTORE_PASSWORD `
        -keypass:env META_FEITA_KEYSTORE_PASSWORD
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE."
    }
}
finally {
    Remove-Item Env:\META_FEITA_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
}

# Backslash is an escape character in .properties files.
$escaped = $password.Replace("\", "\\")
$lines = @(
    "storePassword=$escaped",
    "keyPassword=$escaped",
    "keyAlias=$Alias",
    "storeFile=../meta-feita-release.jks"
)
[System.IO.File]::WriteAllLines($propertiesPath, $lines, (New-Object System.Text.ASCIIEncoding))

Write-Host ""
Write-Host "Done:"
Write-Host "  $keystorePath"
Write-Host "  $propertiesPath"
Write-Host ""
Write-Host "IMPORTANT: copy the .jks and the password to a safe place outside this computer."
