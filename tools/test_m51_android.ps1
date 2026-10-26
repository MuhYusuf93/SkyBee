param(
 [Parameter(Mandatory=$true)][ValidateSet('7f0edea0','192.168.0.102:5555','192.168.0.101:5555','0062112V2210F9B3')][string]$DeviceId,
 [Parameter(Mandatory=$true)][string]$TestFile,
 [string]$RunName='m51-native',
 [string]$NameFilter='',
 [string[]]$AdditionalDartDefines=@()
)
# M5.1 never downgrades a retained fixture to v6. Existing business files and
# wrapped secrets are fingerprinted; new tests must namespace their local keys.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Drain the current invocation through finally, then allow the owner to repair
# a failed case before the campaign starts another build. No device abort.
if($RunName -like 'realme-current-*' -and (Test-Path -LiteralPath (Join-Path $taskRoot 'build/realme-current-stop.flag'))){throw 'Campaign paused between suites for repair; no install attempted'}
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
if($RunName -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Invalid run name'}
$taskEvidence=Join-Path $taskRoot "build/$RunName-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
if(((& $taskAdb -s $DeviceId get-state)-join '').Trim() -ne 'device' -or $LASTEXITCODE -ne 0){throw 'Confirmed device unavailable'}
$taskExpected=switch($DeviceId){'7f0edea0' {'24069PC21G'} '192.168.0.102:5555' {'AX810'} '192.168.0.101:5555' {'AX810'} '0062112V2210F9B3' {'RMX3231'}}
if(((& $taskAdb -s $DeviceId shell getprop ro.product.model)-join '').Trim() -ne $taskExpected){throw 'Device mismatch'}
function Get-ProtectedHashes {
 $taskResult=[ordered]@{}
 foreach($taskPackage in @('com.example.kasir_app','com.example.kasir_app.integration','com.example.kasir_app.skybee')){
  $taskPackages=@(& $taskAdb -s $DeviceId shell pm list packages $taskPackage)
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect installed packages'}
  if("package:$taskPackage" -notin $taskPackages){$taskResult[$taskPackage]='ABSENT';continue}
  & $taskAdb -s $DeviceId shell am force-stop $taskPackage | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Cannot quiesce package'}
  # One read-only ADB operation avoids hundreds of host/device round trips.
  # All shell syntax is fixed; no discovered filename is interpolated as code.
  $taskFiles=@(& $taskAdb -s $DeviceId shell run-as $taskPackage find databases no_backup -type f -exec sha256sum '{}' '\;')
  if($LASTEXITCODE -ne 0){throw 'Cannot audit sandbox; no test install'}
  foreach($taskLine in $taskFiles){
   if($taskLine -notmatch '^([a-f0-9]{64})\s+(.+)$'){throw 'Invalid sandbox digest response'}
   $taskDigest=$Matches[1]; $taskFile=$Matches[2]
   # Retain every pre-existing app DB/archive/key. WorkManager's own database
   # can change on package-replaced and is not a business-data fingerprint.
   if($taskFile -match '^(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?$' -or $taskFile -match '^no_backup/(?:database|backup-work|printer-output)\.gate$'){continue}
   $taskResult["$taskPackage/$taskFile"]=$taskDigest
  }
 }
 return $taskResult
}
$taskBefore=Get-ProtectedHashes
$taskBefore | ConvertTo-Json -Depth 5 | Set-Content "$taskEvidence/before.json" -Encoding UTF8
$taskAwake=Join-Path $taskEvidence 'awake-original.json'
$taskResult=[ordered]@{device=$DeviceId;test=$TestFile;nameFilter=$NameFilter;automaticDeviceControlActive=$true;tests='RUNNING';isolation='NOT CHECKED';downgrade=$false;reset=$false}
$taskResult | ConvertTo-Json | Set-Content "$taskEvidence/result.json" -Encoding UTF8
try {
 if($DeviceId -in @('192.168.0.102:5555','192.168.0.101:5555')){& "$PSScriptRoot/dv8910_awake.ps1" -DeviceId $DeviceId -Action Enable -SnapshotPath $taskAwake}
 & "$PSScriptRoot/test_android.ps1" -DeviceId $DeviceId -AndroidSdkRoot $taskSdk -TestFiles @($TestFile) -AdditionalDartDefines $AdditionalDartDefines -PrepareOnly *> "$taskEvidence/prepare.log"
 if($LASTEXITCODE -ne 0){throw 'Isolated prepare failed'}
 & $taskAdb -s $DeviceId install -r "$taskRoot/build/app/outputs/flutter-apk/app-debug.apk" *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'In-place fixture install failed; no uninstall/downgrade fallback'}
 & "$PSScriptRoot/test_android.ps1" -DeviceId $DeviceId -AndroidSdkRoot $taskSdk -TestFiles @($TestFile) -TestTimeout 5m -NameFilter $NameFilter -AdditionalDartDefines $AdditionalDartDefines *> "$taskEvidence/runner.log"
 if($LASTEXITCODE -ne 0){throw 'Native suite failed'}
 $taskResult.tests=if((Get-Content "$taskEvidence/runner.log" -Raw) -match 'All tests skipped\.'){'SKIPPED'}else{'PASS'}
} catch {
 $taskResult.tests='FAILED_OR_BLOCKED'; throw
} finally {
 try {
  $taskAfter=Get-ProtectedHashes
  $taskAfter | ConvertTo-Json -Depth 5 | Set-Content "$taskEvidence/after.json" -Encoding UTF8
  foreach($taskKey in $taskBefore.Keys){if($taskAfter[$taskKey] -ne $taskBefore[$taskKey]){throw "Retained file mismatch: $taskKey"}}
  $taskResult.isolation='Every pre-existing protected file hash unchanged'
 } catch {
  # Passing test cases cannot turn an unverified data boundary into overall PASS.
  # Keep the original run/log intact; a later baseline is a separate interval.
  $taskResult.tests='FAILED_OR_BLOCKED'
  $taskResult.isolation='FAILED_OR_UNVERIFIED'
  throw
 } finally {
  if(Test-Path -LiteralPath $taskAwake){& "$PSScriptRoot/dv8910_awake.ps1" -DeviceId $DeviceId -Action Restore -SnapshotPath $taskAwake *> "$taskEvidence/awake-restored.log"}
  $taskResult.automaticDeviceControlActive=$false
  $taskResult | ConvertTo-Json | Set-Content "$taskEvidence/result.json" -Encoding UTF8
  Write-Output "M5.1 evidence: $taskEvidence"
 }
}
