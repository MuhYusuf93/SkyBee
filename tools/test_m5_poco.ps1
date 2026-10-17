param(
 [string[]]$TestFiles=@('integration_test/pin_native_backend_test.dart','integration_test/m5_encrypted_regression_test.dart','integration_test/m5_encryption_test.dart','integration_test/m5_backup_test.dart'),
 [string]$RunName='native', [string[]]$AdditionalDartDefines=@(), [string]$NameFilter='',
 [string]$CrossDeviceNonce='', [string]$CrossDeviceDirectory=''
)
$ErrorActionPreference='Stop'
if($RunName -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid run name.'}
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskTarget='7f0edea0'; $taskPackage='com.example.kasir_app.integration'
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-$RunName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
if(((& $taskAdb -s $taskTarget get-state)-join '').Trim() -ne 'device' -or $LASTEXITCODE -ne 0){throw 'Confirmed Poco unavailable.'}
if(((& $taskAdb -s $taskTarget shell getprop ro.product.model)-join '').Trim() -ne '24069PC21G'){throw 'Poco identity mismatch.'}
function Get-OrdinaryDigest {
 $taskRows=@()
 foreach($taskName in @('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')){
  $taskExists=((& $taskAdb -s $taskTarget shell run-as com.example.kasir_app test -f "databases/$taskName")-join '')
  if($LASTEXITCODE -eq 1){$taskRows+="$taskName ABSENT";continue}
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect ordinary database file.'}
  $taskHash=((& $taskAdb -s $taskTarget shell run-as com.example.kasir_app sha256sum "databases/$taskName")-join '').Trim()
  if($LASTEXITCODE -ne 0 -or $taskHash -notmatch '^[a-f0-9]{64} '){throw 'Ordinary hash unavailable.'}
  $taskRows+=$taskHash
 }
 if($taskRows[0] -notmatch '^[a-f0-9]{64} '){throw 'No existing ordinary DB baseline; do not initialize or claim preservation.'}
 return $taskRows -join "`n"
}
& $taskAdb -s $taskTarget shell am force-stop com.example.kasir_app
if($LASTEXITCODE -ne 0){throw 'Cannot quiesce operational app for read-only hash.'}
$taskBefore=Get-OrdinaryDigest
$taskBefore | Set-Content "$taskEvidence/ordinary-before.txt" -Encoding UTF8
$taskInstalled=((& $taskAdb -s $taskTarget shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskInstalled -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Existing fixture APK missing; refusing replacement without preservation.'}
$taskOriginal=Join-Path $taskEvidence 'original-fixture.apk'
& $taskAdb -s $taskTarget pull $Matches[1] $taskOriginal *> "$taskEvidence/original-copy.log"
if($LASTEXITCODE -ne 0){throw 'Original fixture copy failed.'}
$taskAapt=Join-Path $taskSdk 'build-tools/36.0.0/aapt.exe'
if(-not ((& $taskAapt dump badging $taskOriginal)-match "^package: name='com.example.kasir_app.integration' ")){throw 'Original fixture identity mismatch.'}
(Get-FileHash -LiteralPath $taskOriginal -Algorithm SHA256).Hash | Set-Content "$taskEvidence/original-sha256.txt"
$taskInstalledNew=$false
try{
 & "$PSScriptRoot/test_android.ps1" -DeviceId $taskTarget -AndroidSdkRoot $taskSdk -PrepareOnly -TestFiles @($TestFiles[0]) -AdditionalDartDefines $AdditionalDartDefines *> "$taskEvidence/build.log"
 if($LASTEXITCODE -ne 0){throw 'Prepare failed.'}
 & $taskAdb -s $taskTarget install -r (Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-debug.apk') *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'Fixture install failed; no uninstall.'}
 $taskInstalledNew=$true
 if($CrossDeviceDirectory){
  if($CrossDeviceNonce -notmatch '^[0-9]{10,20}$' -or $TestFiles.Count -ne 1 -or $TestFiles[0] -ne 'integration_test/m5_cross_device_test.dart' -or "M5_CROSS_DEVICE_ROLE=target" -notin $AdditionalDartDefines){throw 'Cross-device fixture scope mismatch.'}
  $taskInput=(Resolve-Path -LiteralPath $CrossDeviceDirectory).Path
  $taskEvidenceRoot=(Resolve-Path -LiteralPath "$taskRoot/docs/evidence/m5-20261016").Path+[IO.Path]::DirectorySeparatorChar
  if(-not $taskInput.StartsWith($taskEvidenceRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Cross-device input must be scoped evidence.'}
  $taskDestination="databases/m5_cross_$CrossDeviceNonce"
  & $taskAdb -s $taskTarget shell run-as $taskPackage mkdir $taskDestination
  if($LASTEXITCODE -ne 0){throw 'Transfer directory already exists or unavailable; no overwrite.'}
  foreach($taskFile in @('archive.kasirbackup','expected.json')){
   $taskTemp="/data/local/tmp/kasir_m5_cross_${CrossDeviceNonce}_$taskFile"
   & $taskAdb -s $taskTarget push (Join-Path $taskInput $taskFile) $taskTemp *> "$taskEvidence/push-$taskFile.log"
   if($LASTEXITCODE -ne 0){throw 'Transfer push failed.'}
   try{
    & $taskAdb -s $taskTarget shell chmod 644 $taskTemp
    if($LASTEXITCODE -ne 0){throw 'Cannot read owned transfer file.'}
    & $taskAdb -s $taskTarget shell run-as $taskPackage cp $taskTemp "$taskDestination/$taskFile"
    if($LASTEXITCODE -ne 0){throw 'Sandbox import copy failed.'}
   }finally{& $taskAdb -s $taskTarget shell rm $taskTemp}
  }
 }
 & "$PSScriptRoot/test_android.ps1" -DeviceId $taskTarget -AndroidSdkRoot $taskSdk -TestFiles $TestFiles -NameFilter $NameFilter -AdditionalDartDefines $AdditionalDartDefines -TestTimeout 5m *> "$taskEvidence/runner.log"
 if($LASTEXITCODE -ne 0){throw 'Poco native runner failed.'}
}finally{
 try{
  $taskAfter=Get-OrdinaryDigest
  $taskAfter | Set-Content "$taskEvidence/ordinary-after.txt" -Encoding UTF8
  if($taskAfter -ne $taskBefore){'MISMATCH - investigate' | Set-Content "$taskEvidence/isolation.txt";Write-Error 'Ordinary DB changed; no preservation claim.'}
  else{'Ordinary DB and sidecar byte hashes unchanged.' | Set-Content "$taskEvidence/isolation.txt"}
 }finally{
  if($taskInstalledNew){
   & $taskAdb -s $taskTarget install -r -d $taskOriginal *> "$taskEvidence/original-restored.log"
   if($LASTEXITCODE -ne 0){Write-Error 'Original fixture restore failed; no uninstall fallback.'}
  }
 }
 Write-Output "Evidence: $taskEvidence"
}
