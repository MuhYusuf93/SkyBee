# Actual cross-PID WorkManager probe, private evidence and whole-workflow hashes.
# Never use the legacy worker wrapper on a retained manual-test sandbox.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(Test-Path -LiteralPath (Join-Path $taskRoot 'build/realme-current-stop.flag')){throw 'Realme paused for personal use; no device operation attempted'}
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskDevice='0062112V2210F9B3';$taskPackage='com.example.kasir_app.integration'
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "build/realme-current-worker-$taskNonce"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
if(((& $taskAdb -s $taskDevice get-state)-join '').Trim() -ne 'device'){throw 'Confirmed Realme unavailable'}
if(((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne 'RMX3231'){throw 'Device mismatch'}
function Get-ProtectedHashes {
 $taskPackages=@(& $taskAdb -s $taskDevice shell pm list packages com.example.kasir_app)
 if($LASTEXITCODE -ne 0 -or 'package:com.example.kasir_app' -in $taskPackages){throw 'Ordinary absence required; no data touched'}
 & $taskAdb -s $taskDevice shell am force-stop $taskPackage | Out-Null
 if($LASTEXITCODE -ne 0){throw 'Cannot quiesce fixture'}
 $taskFiles=@(& $taskAdb -s $taskDevice shell run-as $taskPackage find databases no_backup -type f -exec sha256sum '{}' '\;')
 if($LASTEXITCODE -ne 0){throw 'Cannot audit fixture; no install'}
 $taskMap=[ordered]@{ordinary='ABSENT'}
 foreach($taskLine in $taskFiles){
  if($taskLine -notmatch '^([a-f0-9]{64})\s+(.+)$'){throw 'Invalid digest response'}
  $taskHash=$Matches[1];$taskFile=$Matches[2]
  if($taskFile -match '^(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?$' -or $taskFile -match '^no_backup/(?:database|backup-work|printer-output)\.gate$'){continue}
  $taskMap[$taskFile]=$taskHash
 }
 return $taskMap
}
function Read-Marker([string]$Suffix){
 $taskOldPreference=$ErrorActionPreference
 try {
  $ErrorActionPreference='Continue'
  $taskLines=@(& $taskAdb -s $taskDevice shell run-as $taskPackage cat "databases/m5_worker_$taskNonce.$Suffix.json" 2>&1)
  if($LASTEXITCODE -ne 0){return $null}
  return (($taskLines -join "`n") | ConvertFrom-Json)
 } finally {$ErrorActionPreference=$taskOldPreference}
}
$taskBefore=Get-ProtectedHashes
$taskBefore | ConvertTo-Json | Set-Content "$taskEvidence/before.json" -Encoding UTF8
& 'C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' -X utf8 "$PSScriptRoot/inspect_realme_work_idle.py" *> "$taskEvidence/work-idle-before.log"
if($LASTEXITCODE -ne 0){throw 'Existing work idle proof unavailable; no callback change/build/install'}
$taskReport=[ordered]@{device=$taskDevice;nonce=$taskNonce;tests='RUNNING';isolation='NOT CHECKED';automaticDeviceControlActive=$true;reset=$false;downgrade=$false}
$taskLaunched=$false;$taskVerified=$false;$taskReaderCompleted=$false
try {
 & "$PSScriptRoot/test_android.ps1" -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -PrepareOnly -TargetPlatform android-arm -AdditionalDartDefines @("M5_WORKER_NONCE=$taskNonce") -TestFiles @('integration_test/m5_worker_probe_app.dart') *> "$taskEvidence/prepare.log"
 if($LASTEXITCODE -ne 0){throw 'Worker prepare failed'}
 & $taskAdb -s $taskDevice install -r "$taskRoot/build/app/outputs/flutter-apk/app-debug.apk" *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'In-place install failed; no uninstall/downgrade fallback'}
 $taskLaunched=$true
 & $taskAdb -s $taskDevice shell am start -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> "$taskEvidence/launch.log"
 if($LASTEXITCODE -ne 0){throw 'Launch failed'}
 $taskSetup=$null;$taskDeadline=(Get-Date).AddMinutes(2)
 do {$taskSetup=Read-Marker 'setup';if($taskSetup){break};Start-Sleep -Seconds 2}while((Get-Date)-lt $taskDeadline)
 if(-not $taskSetup){throw 'Setup unavailable within bound'}
 $taskSetup | ConvertTo-Json | Set-Content "$taskEvidence/setup.json" -Encoding UTF8
 $taskExited=$false;$taskDeadline=(Get-Date).AddSeconds(15)
 do {
  $taskAlive=(& $taskAdb -s $taskDevice shell pidof $taskPackage)-join ' '
  if(($taskAlive -split ' ') -notcontains "$($taskSetup.setupPid)"){$taskExited=$true;break}
  Start-Sleep -Seconds 1
 }while((Get-Date)-lt $taskDeadline)
 if(-not $taskExited){throw 'Setup PID did not exit naturally'}
 $taskWorker=$null;$taskDeadline=(Get-Date).AddMinutes(3)
 do {
  $taskWorker=Read-Marker 'result';if($taskWorker){break}
  $taskFailure=Read-Marker 'failure'
  if($taskFailure){$taskFailure | ConvertTo-Json | Set-Content "$taskEvidence/worker-failure.json";throw 'Worker reported failure; no automatic retry'}
  Start-Sleep -Seconds 3
 }while((Get-Date)-lt $taskDeadline)
 if(-not $taskWorker){throw 'Worker result unavailable; OS execution not verified'}
 $taskWorker | ConvertTo-Json | Set-Content "$taskEvidence/worker.json" -Encoding UTF8
 Start-Sleep -Seconds 2
 & "$PSScriptRoot/test_android.ps1" -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -TestFiles @('integration_test/m5_worker_result_test.dart') -AdditionalDartDefines @("M5_WORKER_NONCE=$taskNonce") -TestTimeout 5m *> "$taskEvidence/reader.log"
 if($LASTEXITCODE -ne 0){throw 'Reader failed'}
 $taskReaderCompleted=$true;$taskVerified=$true;$taskReport.tests='PASS'
} catch {
 $taskReport.tests='FAILED_OR_BLOCKED'
 throw
} finally {
 try {
  if($taskLaunched -and -not $taskReaderCompleted){
   # Cleanup only this unique task even if setup/OS execution was blocked.
   & "$PSScriptRoot/test_android.ps1" -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -TestFiles @('integration_test/m5_worker_result_test.dart') -AdditionalDartDefines @("M5_WORKER_NONCE=$taskNonce",'M5_WORKER_CLEANUP_ONLY=true') -TestTimeout 5m *> "$taskEvidence/cleanup.log"
   if($LASTEXITCODE -ne 0){throw 'Own worker cleanup not verified'}
  }
 } finally {
  try {
   $taskAfter=Get-ProtectedHashes
   $taskAfter | ConvertTo-Json | Set-Content "$taskEvidence/after.json" -Encoding UTF8
   foreach($taskKey in $taskBefore.Keys){if($taskAfter[$taskKey] -ne $taskBefore[$taskKey]){throw "Retained file mismatch: $taskKey"}}
   $taskReport.isolation='Every pre-existing protected file hash unchanged'
  } finally {
   $taskReport.automaticDeviceControlActive=$false
   $taskReport | ConvertTo-Json | Set-Content "$taskEvidence/result.json" -Encoding UTF8
   Write-Output "Realme worker evidence: $taskEvidence"
  }
 }
}
