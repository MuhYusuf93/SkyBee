param([string]$ConfirmedDeviceId='192.168.0.102:5555',
 [ValidatePattern('^m5_acceptance_[0-9]{1,20}\.db$')][string]$FixtureDatabase='m5_acceptance_1792150309449.db')
# Build-only artifacts. PrepareOnly probes the confirmed device but never deploys;
# all manual/native installation is a later explicit, package-verified step.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskStamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/release-artifacts-$taskStamp"
$taskArtifacts=Join-Path $taskRoot "build/m5-acceptance-$taskStamp"
New-Item -ItemType Directory -Path $taskEvidence,$taskArtifacts | Out-Null
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
Push-Location -LiteralPath $taskRoot
try {
    & flutter build apk --debug --no-pub --target integration_test/m5_acceptance_app.dart *> (Join-Path $taskEvidence 'negative-isolation-guard.log')
    if($LASTEXITCODE -eq 0 -or -not (Select-String -LiteralPath (Join-Path $taskEvidence 'negative-isolation-guard.log') -SimpleMatch 'Fixture entrypoints require KASIR_INTEGRATION_TEST=true.')) {
        throw 'Negative isolation guard did not produce the expected pre-install refusal.'
    }
    # Preserve a same-version debug bridge for the closing hash audit. Installing
    # it over release does not downgrade, clear data or launch a test listener;
    # run-as can then audit old sandbox files before the exact v6 APK is restored.
    & "$PSScriptRoot/test_android.ps1" -DeviceId $ConfirmedDeviceId -AndroidSdkRoot $taskSdk -PrepareOnly -BuildMode debug -TestFiles @('integration_test/m5_acceptance_app.dart') -AdditionalDartDefines @("KASIR_FIXTURE_DATABASE=$FixtureDatabase") *> (Join-Path $taskEvidence 'restore-bridge-build.log')
    if($LASTEXITCODE -ne 0){throw 'Debug restore bridge build failed; no install.'}
    $taskBridge=Join-Path $taskArtifacts 'kasir-app-0.5.0-m5-restore-bridge-debug.apk'
    Copy-Item -LiteralPath (Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-debug.apk') -Destination $taskBridge
    & $taskPython tools/verify_m5_apk.py --apk $taskBridge --kind fixture --output (Join-Path $taskEvidence 'restore-bridge-apk.json')
    if($LASTEXITCODE -ne 0){throw 'Debug restore bridge verification failed.'}
    & flutter build apk --release *> (Join-Path $taskEvidence 'ordinary-build.log')
    if($LASTEXITCODE -ne 0){throw 'Ordinary release build failed; no install.'}
    $taskOrdinary=Join-Path $taskArtifacts 'kasir-app-0.5.0-ordinary-release.apk'
    Copy-Item -LiteralPath (Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-release.apk') -Destination $taskOrdinary
    & $taskPython tools/verify_m5_apk.py --apk $taskOrdinary --kind ordinary --output (Join-Path $taskEvidence 'ordinary-apk.json')
    if($LASTEXITCODE -ne 0){throw 'Ordinary APK verification failed.'}
    & "$taskSdk/build-tools/36.0.0/apksigner.bat" verify --print-certs $taskOrdinary *> (Join-Path $taskEvidence 'ordinary-signature.log')
    if($LASTEXITCODE -ne 0){throw 'Ordinary signature verification failed.'}
    & "$PSScriptRoot/test_android.ps1" -DeviceId $ConfirmedDeviceId -AndroidSdkRoot $taskSdk -PrepareOnly -BuildMode release -TestFiles @('integration_test/m5_acceptance_app.dart') -AdditionalDartDefines @("KASIR_FIXTURE_DATABASE=$FixtureDatabase") *> (Join-Path $taskEvidence 'fixture-build.log')
    if($LASTEXITCODE -ne 0){throw 'Fixture acceptance build failed; no install.'}
    $taskFixture=Join-Path $taskArtifacts 'kasir-app-0.5.0-m5-isolated-release.apk'
    Copy-Item -LiteralPath (Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-release.apk') -Destination $taskFixture
    & $taskPython tools/verify_m5_apk.py --apk $taskFixture --kind fixture --output (Join-Path $taskEvidence 'fixture-apk.json')
    if($LASTEXITCODE -ne 0){throw 'Fixture APK verification failed.'}
    & "$taskSdk/build-tools/36.0.0/apksigner.bat" verify --print-certs $taskFixture *> (Join-Path $taskEvidence 'fixture-signature.log')
    if($LASTEXITCODE -ne 0){throw 'Fixture signature verification failed.'}
    [ordered]@{ordinary=$taskOrdinary;fixture=$taskFixture;restoreBridge=$taskBridge;fixtureDatabase=$FixtureDatabase;evidence=$taskEvidence;installed=$false;signing='existing development certificate, not M6 release signing'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskEvidence 'artifacts.json') -Encoding UTF8
    Write-Output "Verified build-only artifacts: $taskArtifacts"
    Write-Output "Evidence: $taskEvidence"
} finally {Pop-Location}
