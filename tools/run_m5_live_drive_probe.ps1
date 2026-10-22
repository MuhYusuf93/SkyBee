param(
 [Parameter(Mandatory=$true)][ValidateSet('7f0edea0')][string]$DeviceId,
 [Parameter(Mandatory=$true)][string]$AndroidSdkRoot,
 [switch]$TriggerReadyProbe
)
# Existing campaign only. No uninstall, reset, seeding, clock edits, account
# selection or ordinary APK installation. Restore the exact incoming fixture.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $taskRoot
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261018/live-drive-$taskNonce"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskAdb=Join-Path $AndroidSdkRoot 'platform-tools/adb.exe'
$taskPackage='com.example.kasir_app.integration'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskBridge=Join-Path $taskRoot 'build/m5-acceptance-20261018-165445/kasir-app-0.5.0-m5-restore-bridge-debug.apk'
$taskPriorSha='2c64c2ff8819602be01c6315000bbf876f56eeb9951c375ad2b3d7c4da09de14'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$taskLedger=[ordered]@{nonce=$taskNonce;state='preflight';device=$DeviceId;package=$taskPackage;campaign='m5_acceptance_1792150309449.db';automaticDeviceControlActive=$true;originalV6RestorationPending=$true;calendar21DeliveryProven=$false}
$taskFolders=@('poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346')
function Save-Ledger {
 $taskLedger | ConvertTo-Json -Depth 12 | Set-Content "$taskEvidence/ledger.json" -Encoding UTF8
 foreach($taskFolder in $taskFolders){
  $taskFile="docs/evidence/m5-20261016/$taskFolder/handover.json"
  $taskH=Get-Content -LiteralPath $taskFile -Raw | ConvertFrom-Json
  $taskH.automaticDeviceControlActive=$taskLedger.automaticDeviceControlActive
  $taskH | Add-Member -NotePropertyName liveDriveProbe -NotePropertyValue @{ledger="$taskEvidence/ledger.json";state=$taskLedger.state} -Force
  $taskH | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $taskFile -Encoding UTF8
 }
 @{ledger="$taskEvidence/ledger.json";nonce=$taskNonce;stage=$taskLedger.state;automaticDeviceControlActive=$taskLedger.automaticDeviceControlActive} | ConvertTo-Json | Set-Content docs/evidence/m5-20261018/live-drive-context.json -Encoding UTF8
}
function Read-Marker([string]$Kind){
 $taskOldPreference=$ErrorActionPreference
 $ErrorActionPreference='Continue'
 try {
  $taskLines=& $taskAdb -s $DeviceId shell run-as $taskPackage cat "databases/m5_live_drive_$taskNonce.$Kind.json" 2>$null
  if($LASTEXITCODE -ne 0){return $null}
  return (($taskLines -join "`n") | ConvertFrom-Json)
 }finally{$ErrorActionPreference=$taskOldPreference}
}
function Get-Digests([string]$Package){
 $taskRows=@()
 foreach($taskName in @('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')){
  & $taskAdb -s $DeviceId shell run-as $Package test -f "databases/$taskName"
  if($LASTEXITCODE -eq 1){$taskRows+="$taskName ABSENT";continue}
  if($LASTEXITCODE -ne 0){throw 'Database hash access unavailable.'}
  $taskHash=((& $taskAdb -s $DeviceId shell run-as $Package sha256sum "databases/$taskName")-join '').Trim()
  if($LASTEXITCODE -ne 0 -or $taskHash -notmatch '^[a-f0-9]{64} '){throw 'Database hash unavailable.'}
  $taskRows+=$taskHash
 }
 if($taskRows[0] -notmatch '^[a-f0-9]{64} '){throw 'Existing default DB missing; no initialize.'}
 return $taskRows -join "`n"
}
function Public-Digests {
 $taskValue=((& $taskAdb -s $DeviceId shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`n").Trim()
 if($LASTEXITCODE -ne 0){throw 'Public backup hash unavailable.'}
 return $taskValue
}
function Copy-Apk([string]$Path){
 $taskInstalled=((& $taskAdb -s $DeviceId shell pm path $taskPackage)-join '').Trim()
 if($LASTEXITCODE -ne 0 -or $taskInstalled -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Fixture APK unavailable.'}
 & $taskAdb -s $DeviceId pull $Matches[1] $Path *> "$Path-copy.log"
 if($LASTEXITCODE -ne 0){throw 'Fixture APK copy failed.'}
 return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
$taskReplaced=$false;$taskLegacy=$null;$taskOrdinary=$null;$taskPublic=$null
try {
 if(((& $taskAdb -s $DeviceId get-state)-join '').Trim() -ne 'device' -or ((& $taskAdb -s $DeviceId shell getprop ro.product.model)-join '').Trim() -ne '24069PC21G'){throw 'Confirmed Poco unavailable.'}
 Save-Ledger
 if((Copy-Apk "$taskEvidence/prior-c28.apk") -ne $taskPriorSha){throw 'Expected C28 not installed; do not replace.'}
 & $taskAdb -s $DeviceId shell am force-stop com.example.kasir_app
 if($LASTEXITCODE -ne 0){throw 'Cannot quiesce ordinary for hashes.'}
 $taskOrdinary=Get-Digests 'com.example.kasir_app'
 $taskOrdinary | Set-Content "$taskEvidence/ordinary-before.txt" -Encoding UTF8
 $taskPublic=Public-Digests
 $taskPublic | Set-Content "$taskEvidence/public-before.txt" -Encoding UTF8
 $taskLedger.state='build controlled worker'
 Save-Ledger
 & tools/test_android.ps1 -DeviceId $DeviceId -AndroidSdkRoot $AndroidSdkRoot -PrepareOnly -TargetPlatform android-arm64 -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db',"M5_LIVE_DRIVE_NONCE=$taskNonce") -TestFiles @('integration_test/m5_live_drive_probe_app.dart') *> "$taskEvidence/build.log"
 if($LASTEXITCODE -ne 0){throw 'Probe prepare failed; no install.'}
 $taskProbe=Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-debug.apk'
 & $taskPython tools/verify_m5_apk.py --apk $taskProbe --kind fixture --abis arm64-v8a --output "$taskEvidence/probe-apk.json" *> "$taskEvidence/verify.log"
 if($LASTEXITCODE -ne 0){throw 'Probe APK verification failed.'}
 & $taskPython tools/verify_m5_apk.py --apk $taskBridge --kind fixture --output "$taskEvidence/bridge-apk.json" *> "$taskEvidence/bridge-verify.log"
 if($LASTEXITCODE -ne 0){throw 'Bridge verification failed.'}
 & $taskAdb -s $DeviceId install -r $taskBridge *> "$taskEvidence/bridge-install.log"
 if($LASTEXITCODE -ne 0){throw 'Bridge install failed; no uninstall fallback.'}
 $taskReplaced=$true
 $taskLegacy=Get-Digests $taskPackage
 $taskLegacy | Set-Content "$taskEvidence/legacy-before.txt" -Encoding UTF8
 & $taskAdb -s $DeviceId install -r $taskProbe *> "$taskEvidence/probe-install.log"
 if($LASTEXITCODE -ne 0){throw 'Probe install failed; no uninstall fallback.'}
 $taskLedger.state='setup read-only fresh baseline and schedule controlled worker'
 Save-Ledger
 & $taskAdb -s $DeviceId shell am start -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> "$taskEvidence/start.log"
 if($LASTEXITCODE -ne 0){throw 'Probe start failed.'}
 $taskSetup=$null;$taskDeadline=(Get-Date).AddMinutes(3)
 do {
  $taskFailure=Read-Marker 'failure'
  if($taskFailure){$taskFailure|ConvertTo-Json|Set-Content "$taskEvidence/failure.json" -Encoding UTF8;throw 'Probe setup failure; sanitized marker retained.'}
  $taskSetup=Read-Marker 'setup'
  if($taskSetup){break}
  Start-Sleep -Seconds 3
 } while((Get-Date)-lt $taskDeadline)
 if(-not $taskSetup){throw 'Setup timed out; no success claim.'}
 $taskSetup|ConvertTo-Json|Set-Content "$taskEvidence/setup.json" -Encoding UTF8
 if($taskSetup.state -ne 'scheduled'){throw 'Controlled work not scheduled.'}
 $taskDeadline=(Get-Date).AddSeconds(20);$taskExited=$false
 do {
  $taskAlive=((& $taskAdb -s $DeviceId shell pidof $taskPackage)-join ' ')
  if(($taskAlive -split ' ') -notcontains "$($taskSetup.setupPid)"){$taskExited=$true;break}
  Start-Sleep -Seconds 1
 } while((Get-Date)-lt $taskDeadline)
 if(-not $taskExited){throw 'Setup process did not exit; restart not proven.'}
 $taskLedger.state='awaiting headless worker; bounded eight real uploads and scoped retention'
 $taskLedger.setupProcessExited=$true
 Save-Ledger
 if($TriggerReadyProbe){
  # Optional controlled dispatch, never a natural calendar-delivery claim.
  Start-Sleep -Seconds 35
  $taskAlive=((& $taskAdb -s $DeviceId shell pidof $taskPackage)-join '').Trim()
  if(-not $taskAlive){
   & $taskPython tools/inspect_m5_live_work_id.py --evidence $taskEvidence --adb $taskAdb *> "$taskEvidence/job-map-read.log"
   if($LASTEXITCODE -ne 0){throw 'Cannot map nonce job safely; no force fallback.'}
   $taskMapping=Get-Content "$taskEvidence/nonce-job-id.json" -Raw | ConvertFrom-Json
   if($taskMapping.nonce -ne $taskNonce -or $taskMapping.taskName -ne "kasir-m5-live-drive-$taskNonce" -or "$($taskMapping.systemJobId)" -notmatch '^[0-9]{1,8}$'){throw 'Nonce job mapping differs.'}
   & $taskAdb -s $DeviceId shell cmd jobscheduler run -s -n androidx.work.systemjobscheduler $taskPackage $taskMapping.systemJobId *> "$taskEvidence/controlled-job-dispatch.txt"
   if($LASTEXITCODE -ne 0){throw 'Controlled job constraints not met; do not bypass them.'}
   $taskLedger.controlledDispatch=$true
   Save-Ledger
  }
 }
 $taskResult=$null;$taskDeadline=(Get-Date).AddMinutes(12)
 do {
  $taskFailure=Read-Marker 'failure'
  if($taskFailure){$taskFailure|ConvertTo-Json|Set-Content "$taskEvidence/failure.json" -Encoding UTF8;throw 'Worker failure; inspect sanitized marker.'}
  $taskResult=Read-Marker 'result'
  if($taskResult){break}
  $taskProgress=Read-Marker 'progress'
  if($taskProgress){$taskProgress|ConvertTo-Json -Depth 8|Set-Content "$taskEvidence/progress.json" -Encoding UTF8}
  Start-Sleep -Seconds 3
 } while((Get-Date)-lt $taskDeadline)
 if(-not $taskResult){throw 'Worker result timed out; no success claim.'}
 $taskResult|ConvertTo-Json -Depth 12|Set-Content "$taskEvidence/result.json" -Encoding UTF8
 if($taskResult.workerPid -eq $taskSetup.setupPid){throw 'Worker reused setup process.'}
 $taskLedger.state='native independent result and financial invariants reader'
 Save-Ledger
 & tools/test_android.ps1 -DeviceId $DeviceId -AndroidSdkRoot $AndroidSdkRoot -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db',"M5_LIVE_DRIVE_NONCE=$taskNonce") -TestFiles @('integration_test/m5_live_drive_result_test.dart') -TestTimeout 5m *> "$taskEvidence/reader.log"
 if($LASTEXITCODE -ne 0){throw 'Independent reader failed.'}
 $taskLedger.state='controlled headless Drive and retention PASS; closure pending'
} catch {
 $taskLedger.failure='Probe incomplete/failed; retain raw logs, no reset/retry of eight uploads automatically.'
 throw
} finally {
 try {
  if($taskOrdinary){
   $taskAfter=Get-Digests 'com.example.kasir_app'
   $taskAfter|Set-Content "$taskEvidence/ordinary-after.txt" -Encoding UTF8
   if($taskAfter -ne $taskOrdinary){throw 'Ordinary byte hashes changed.'}
   $taskLedger.ordinaryHashesEqual=$true
  }
  if($taskLegacy){
   $taskAfter=Get-Digests $taskPackage
   $taskAfter|Set-Content "$taskEvidence/legacy-after.txt" -Encoding UTF8
   if($taskAfter -ne $taskLegacy){throw 'Default fixture byte hashes changed.'}
   $taskLedger.legacyHashesEqual=$true
  }
  if($taskPublic){
   $taskAfter=Public-Digests
   $taskAfter|Set-Content "$taskEvidence/public-after.txt" -Encoding UTF8
   if($taskAfter -ne $taskPublic){throw 'Public backup bytes changed.'}
   $taskLedger.publicBackupHashesEqual=$true
  }
 } finally {
  try {
   if($taskReplaced){
    # Production daily/alerts are left intact. Restored C28 startup registers
    # the normal dispatcher; this custom nonce task is unknown there and cannot
    # run its eight-upload probe again after the test binary has been replaced.
    & $taskAdb -s $DeviceId install -r -d "$taskEvidence/prior-c28.apk" *> "$taskEvidence/c28-restored.log"
    if($LASTEXITCODE -ne 0){throw 'Exact C28 restoration failed; no uninstall.'}
    if((Copy-Apk "$taskEvidence/restored-c28.apk") -ne $taskPriorSha){throw 'Restored C28 digest mismatch.'}
    $taskLedger.exactC28Restored=$true
    & $taskAdb -s $DeviceId shell am start -S -W -f 0x10008000 -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> "$taskEvidence/c28-start.log"
    if($LASTEXITCODE -ne 0){throw 'C28 startup failed.'}
    $taskLedger.productionStartupRequested=$true
   }
  } finally {
   $taskLedger.automaticDeviceControlActive=$false
   Save-Ledger
   Write-Output "Evidence: $taskEvidence"
  }
 }
}
