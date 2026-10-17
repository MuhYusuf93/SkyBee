param([string[]]$TestFiles=@('integration_test/m5_encrypted_regression_test.dart','integration_test/m5_encryption_test.dart','integration_test/m5_backup_test.dart'),[string]$RunName='encrypted-regression')
$ErrorActionPreference='Stop'
if($RunName -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid run name.'}
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskTarget='0062112V2210F9B3';$taskPackage='com.example.kasir_app.integration'
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk';$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskStamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/realme-$RunName-$taskStamp"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
if(((& $taskAdb -s $taskTarget get-state)-join '').Trim() -ne 'device'){throw 'Confirmed Realme unavailable.'}
if(((& $taskAdb -s $taskTarget shell getprop ro.product.model)-join '').Trim() -ne 'RMX3231'){throw 'Device identity mismatch.'}
$taskOrdinary=@(& $taskAdb -s $taskTarget shell pm list packages com.example.kasir_app | Where-Object {$_ -eq 'package:com.example.kasir_app'})
if($LASTEXITCODE -ne 0 -or $taskOrdinary.Count){throw 'Operational package present/unavailable: explicit baseline required.'}
$taskInstalled=((& $taskAdb -s $taskTarget shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskInstalled -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Expected isolated fixture APK was not found.'}
$taskOriginal=Join-Path $taskEvidence 'original-fixture.apk'
& $taskAdb -s $taskTarget pull $Matches[1] $taskOriginal *> (Join-Path $taskEvidence 'original-apk-copy.log')
if($LASTEXITCODE -ne 0){throw 'Cannot preserve exact original fixture APK; no replacement attempted.'}
$taskAapt=Join-Path $taskSdk 'build-tools/36.0.0/aapt.exe'
if(-not ((& $taskAapt dump badging $taskOriginal)-match "^package: name='com.example.kasir_app.integration' ")){throw 'Original APK identity mismatch.'}
(Get-FileHash -LiteralPath $taskOriginal -Algorithm SHA256).Hash | Set-Content (Join-Path $taskEvidence 'original-apk-sha256.txt')
$taskInstalledNew=$false;$taskBefore=$null
function Get-FixtureDigest {
    # Only this known manual test DB and its exact sidecars. It is not opened,
    # migrated or removed. Capturing all sidecars avoids main-file-only claims.
    $taskLines=@()
    foreach($taskName in @('realme_restart_20261015.db','realme_restart_20261015.db-wal','realme_restart_20261015.db-shm','realme_restart_20261015.db-journal')){
        $taskLine=((& $taskAdb -s $taskTarget shell run-as $taskPackage sha256sum "databases/$taskName" 2>$null)-join '').Trim()
        if($LASTEXITCODE -eq 0){$taskLines+=$taskLine}else{$taskLines+="$taskName ABSENT"}
    }
    if($taskLines[0] -notmatch '^[a-f0-9]{64} '){throw 'Manual fixture baseline missing; no regression run.'}
    return $taskLines -join "`n"
}
try{
    & "$PSScriptRoot/test_android.ps1" -DeviceId $taskTarget -AndroidSdkRoot $taskSdk -PrepareOnly -TestFiles @($TestFiles[0]) *> (Join-Path $taskEvidence 'build.log')
    $taskApk=Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    & $taskAdb -s $taskTarget install -r $taskApk *> (Join-Path $taskEvidence 'install.log')
    if($LASTEXITCODE -ne 0){throw 'Test install failed; no uninstall fallback.'}
    $taskInstalledNew=$true
    & $taskAdb -s $taskTarget shell am force-stop $taskPackage
    if($LASTEXITCODE -ne 0){throw 'Cannot quiesce test package.'}
    $taskBefore=Get-FixtureDigest
    $taskBefore|Set-Content (Join-Path $taskEvidence 'manual-db-before.txt') -Encoding UTF8
    'Pre-install raw DB baseline unavailable because original fixture APK was release/non-debuggable. This baseline proves only the subsequent test interval.'|Set-Content (Join-Path $taskEvidence 'baseline-limits.txt') -Encoding UTF8
    & "$PSScriptRoot/test_android.ps1" -DeviceId $taskTarget -AndroidSdkRoot $taskSdk -TestFiles $TestFiles -TestTimeout 5m *> (Join-Path $taskEvidence 'runner.log')
    if($LASTEXITCODE -ne 0){throw 'Native suite failed.'}
}finally{
    if($taskInstalledNew){
      try{
        & $taskAdb -s $taskTarget shell am force-stop $taskPackage
        if($taskBefore){
            $taskAfter=Get-FixtureDigest
            $taskAfter|Set-Content (Join-Path $taskEvidence 'manual-db-after.txt') -Encoding UTF8
            if($taskAfter -ne $taskBefore){'MISMATCH - investigate; no preservation claim.'|Set-Content (Join-Path $taskEvidence 'manual-db-isolation.txt')}
            else{'Exact manual fixture DB and sidecar fingerprints unchanged across test interval.'|Set-Content (Join-Path $taskEvidence 'manual-db-isolation.txt')}
        }
      }finally{
        # M5 fixture versionCode 7 returns to the exact pre-test versionCode 6
        # sandbox APK. No operational package or migrated manual DB is involved.
        & $taskAdb -s $taskTarget install -r -d $taskOriginal *> (Join-Path $taskEvidence 'original-apk-restored.log')
        if($LASTEXITCODE -ne 0){Write-Error 'Original isolated APK reinstall failed; no uninstall fallback.'}
      }
    }
    Write-Output "Evidence: $taskEvidence"
}
