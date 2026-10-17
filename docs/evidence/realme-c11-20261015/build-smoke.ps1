param([ValidateSet('profile','release')][string]$Mode = 'profile', [switch]$ActualCashier, [switch]$CheckoutProbe)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$env:PATH = 'C:\Users\ACER\dev\flutter\bin;' + $env:PATH
$taskSdk = 'C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb = Join-Path $taskSdk 'platform-tools/adb.exe'
$taskDevice = '0062112V2210F9B3'
$taskAapt = Join-Path $taskSdk 'build-tools/36.0.0/aapt.exe'
if (((& $taskAdb -s $taskDevice get-state) -join '').Trim() -ne 'device') { throw 'Explicit Realme unavailable; no build/install' }
$taskTarget = 'tools/realme_smoke.dart'
$taskArtifact = "smoke-$Mode"
if ($ActualCashier) { $taskTarget = 'tools/realme_cashier.dart'; $taskArtifact = "cashier-$Mode" }
if ($CheckoutProbe) {
    if ($ActualCashier) { throw 'Select only one fixture entrypoint' }
    $taskTarget = 'tools/realme_checkout_probe.dart'; $taskArtifact = "checkout-$Mode"
}
$taskLog = Join-Path $PSScriptRoot "build-$taskArtifact.log"
& flutter build apk "--$Mode" --target $taskTarget --target-platform android-arm --dart-define=KASIR_INTEGRATION_TEST=true *> $taskLog
$taskExit = $LASTEXITCODE
Add-Content -Encoding UTF8 $taskLog "FlutterExit=$taskExit"
if ($taskExit -ne 0) { throw 'Smoke build failed; no install' }
$taskApk = Join-Path $taskRoot "build/app/outputs/flutter-apk/app-$Mode.apk"
$taskIdentity = & $taskAapt dump badging $taskApk
if ($LASTEXITCODE -ne 0 -or @($taskIdentity | Where-Object { $_.StartsWith("package: name='com.example.kasir_app.integration' ") }).Count -ne 1) { throw 'Not isolated APK; no install' }
if (@($taskIdentity | Where-Object { $_ -eq "native-code: 'armeabi-v7a'" }).Count -ne 1) { throw 'Unexpected ABI; no install' }
$taskIdentity | Select-String '^package:|^sdkVersion:|^targetSdkVersion:|^native-code:|^application-label:|^launchable-activity:' | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot "apk-$taskArtifact-identity.log")
& $taskAapt dump permissions $taskApk *> (Join-Path $PSScriptRoot "apk-$taskArtifact-permissions.log")
$taskCopies = Join-Path $taskRoot 'build/realme-c11-20261015'
New-Item -ItemType Directory -Path $taskCopies -Force | Out-Null
Copy-Item -LiteralPath $taskApk -Destination (Join-Path $taskCopies "realme-$taskArtifact.apk")
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $taskCopies "realme-$taskArtifact.apk") | Select-Object Path,Hash | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot "apk-$taskArtifact-hash.json")
# Direct install-r of a verified disposable package, no automatic uninstall fallback.
& $taskAdb -s $taskDevice install -r $taskApk *> (Join-Path $PSScriptRoot "install-$taskArtifact.log")
if ($LASTEXITCODE -ne 0) { throw 'Isolated APK install failed; no reset/uninstall fallback' }
& $taskAdb -s $taskDevice shell cmd package resolve-activity --brief com.example.kasir_app.integration
Write-Output "Verified isolated $Mode build/install complete; ordinary untouched."
