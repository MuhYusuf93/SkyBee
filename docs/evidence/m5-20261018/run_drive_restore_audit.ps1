$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskAudit=Join-Path $taskRoot "docs/evidence/m5-20261018/drive-restore-audit-$taskNonce"
New-Item -ItemType Directory -Path $taskAudit | Out-Null
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskDevice='7f0edea0';$taskPackage='com.example.kasir_app.integration'
$taskExpected='0ec0734a306d177ecd329d74274ed3938bef7debcdfa4bd7d05fd017d3a6e3e1'
$taskFolders=@('poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867')
$taskLedger=[ordered]@{state='preflight';automaticDeviceControlActive=$false;fixtureDatabase='m5_acceptance_1792150309449.db';expectedArchives=5;source='actual Drive restore';originalV6RestorationPending=$true}
Copy-Item -LiteralPath integration_test/m5_post_restore_audit_test.dart -Destination "$taskAudit/audit-source.dart.txt"
$taskLedger.auditSourceSha256=(Get-FileHash -LiteralPath "$taskAudit/audit-source.dart.txt").Hash.ToLowerInvariant()
function Save-Audit([bool]$Active){
 $taskLedger.automaticDeviceControlActive=$Active
 $taskLedger | ConvertTo-Json -Depth 8 | Set-Content "$taskAudit/ledger.json" -Encoding UTF8
 @{ledger="$taskAudit/ledger.json";stage=$taskLedger.state;automaticDeviceControlActive=$Active;originalV6RestorationPending=$true} | ConvertTo-Json | Set-Content docs/evidence/m5-20261018/drive-restore-audit-context.json -Encoding UTF8
 foreach($taskFolder in $taskFolders){
  $taskFile="docs/evidence/m5-20261016/$taskFolder/handover.json"
  $taskH=Get-Content -LiteralPath $taskFile -Raw | ConvertFrom-Json
  $taskH.automaticDeviceControlActive=$Active
  $taskH | Add-Member -NotePropertyName postDriveRestoreNativeAudit -NotePropertyValue @{ledger="$taskAudit/ledger.json";state=$taskLedger.state;originalV6StillPending=$true} -Force
  $taskH | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $taskFile -Encoding UTF8
 }
}
function Get-Apk([string]$Name){
 $taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
 if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Fixture APK unavailable.'}
 & $taskAdb -s $taskDevice pull $Matches[1] "$taskAudit/$Name.apk" *> "$taskAudit/$Name-copy.log"
 if($LASTEXITCODE -ne 0){throw 'APK preservation copy failed.'}
 return (Get-FileHash -LiteralPath "$taskAudit/$Name.apk").Hash.ToLowerInvariant()
}
function Get-Public {
 $taskValue=((& $taskAdb -s $taskDevice shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`n").Trim()
 if($LASTEXITCODE -ne 0){throw 'Public exports unavailable.'}
 $taskReference=((Get-Content docs/evidence/m5-20261017/c23-public-export-before.txt)-join "`n").Trim()
 if($taskValue -ne $taskReference){throw 'Public archive baseline mismatch.'}
 return $taskValue
}
if(-not (Select-String -LiteralPath docs/evidence/m5-20261018/drive-restore-audit-provenance-analyze.log -SimpleMatch 'No issues found!')){throw 'Provenance analyze not complete.'}
if(((& $taskAdb -s $taskDevice get-state)-join '').Trim() -ne 'device' -or ((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne '24069PC21G'){throw 'Confirmed Poco unavailable; no native audit.'}
if((Get-Apk 'before') -ne $taskExpected){throw 'Installed fixture not C27; no native audit.'}
Get-Public | Set-Content "$taskAudit/public-before.txt" -Encoding UTF8
$taskLedger.state='native five-archive Drive restore audit running'
Save-Audit $true
$taskFailure=$null
try{
 & tools/test_m5_poco.ps1 -RunName "drive-restore-$taskNonce" -TestFiles @('integration_test/m5_post_restore_audit_test.dart') -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_POST_RESTORE_SOURCE=drive') *> "$taskAudit/runner-invocation.log"
 if($LASTEXITCODE -ne 0){throw 'Native audit runner failed.'}
 $taskRuns=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-drive-restore-$taskNonce-*")
 if($taskRuns.Count -ne 1){throw 'Audit run evidence ambiguous.'}
 $taskRun=$taskRuns[0].FullName
 $taskLedger.nativeEvidence=$taskRun
 if(-not (Select-String -LiteralPath "$taskRun/runner.log" -SimpleMatch 'M5_POST_DRIVE_RESTORE_AUDIT integrity/FK/cipher/reconcile/business23/receipts/fiveArchivesAuthenticated/selectedDriveSnapshot/safetyBeforeSwapAndSuccessfulRun/logo/deviceDefaults/driveDisconnected/legacy PASS count=5')){throw 'Full audit completion marker missing.'}
 if(-not (Select-String -LiteralPath "$taskRun/runner.log" -Pattern '\+1: All tests passed!')){throw 'Native test success not proven.'}
 if(-not (Select-String -LiteralPath "$taskRun/isolation.txt" -SimpleMatch 'Ordinary DB and sidecar byte hashes unchanged.')){throw 'Ordinary isolation not proven.'}
 $taskLedger.state='PASS: five archives authenticated, business23/cipher/FK/reconcile/safety pre-swap/Drive snapshot/device defaults verified'
}catch{
 $taskFailure=$_
 $taskLedger.state='FAIL or BLOCKED: inspect retained runner evidence; do not weaken checks or reset database'
}finally{
 try{
  Get-Public | Set-Content "$taskAudit/public-after.txt" -Encoding UTF8
  if((Get-Apk 'restored') -ne $taskExpected){throw 'C27 exact APK restoration NOT proven; no uninstall/reset.'}
  $taskLedger.exactC27Restored=$true
 }finally{Save-Audit $false}
}
if($taskFailure){throw $taskFailure}
Write-Output "Post-Drive-restore native audit complete: $taskAudit"
