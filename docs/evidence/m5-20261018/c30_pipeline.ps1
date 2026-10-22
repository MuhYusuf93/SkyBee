$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
if(-not (Select-String -LiteralPath docs/evidence/m5-20261018/c30-host-regression.log -SimpleMatch -Pattern 'All tests passed!')){throw 'Host regression incomplete.'}
if(-not (Select-String -LiteralPath docs/evidence/m5-20261018/c30-analyze.log -SimpleMatch -Pattern 'No issues found!')){throw 'Analyzer incomplete.'}
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-history-ui-update-$taskNonce"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskDevice='7f0edea0';$taskPackage='com.example.kasir_app.integration'
$taskPriorSha='2f114edc869e4466aae6a9788e1b7bb6cda78c90b0528cce0e8a4981ab34cf6e'
$taskLedger=[ordered]@{nonce=$taskNonce;fixtureDatabase='m5_acceptance_1792150309449.db';state='Poco native regression';automaticDeviceControlActive=$true;originalV6Restoration='pending in original handover, never overwrite original pointer'}
function Save-Ledger {
 $taskLedger | ConvertTo-Json -Depth 8 | Set-Content "$taskEvidence/update.json" -Encoding UTF8
 foreach($taskFolder in @('poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346','poco-account-ui-update-1792328869099')){
  $taskFile="docs/evidence/m5-20261016/$taskFolder/handover.json"
  $taskH=Get-Content -LiteralPath $taskFile -Raw | ConvertFrom-Json
  $taskH.automaticDeviceControlActive=$taskLedger.automaticDeviceControlActive
  $taskH | Add-Member -NotePropertyName pendingC30Update -NotePropertyValue @{ledger="$taskEvidence/update.json";state=$taskLedger.state} -Force
  $taskH | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $taskFile -Encoding UTF8
 }
 @{stage=$taskLedger.state;ledger="$taskEvidence/update.json";automaticDeviceControlActive=$taskLedger.automaticDeviceControlActive;fixtureDatabase=$taskLedger.fixtureDatabase;originalV6RestorationPending=$true} | ConvertTo-Json | Set-Content "$taskRoot/docs/evidence/m5-20261018/c30-update-context.json" -Encoding UTF8
}
function Copy-Apk([string]$Device,[string]$Destination){
 $taskPath=((& $taskAdb -s $Device shell pm path $taskPackage)-join '').Trim()
 if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Fixture APK unavailable.'}
 & $taskAdb -s $Device pull $Matches[1] $Destination *> "$Destination-copy.log"
 if($LASTEXITCODE -ne 0){throw 'Fixture copy failed.'}
 return (Get-FileHash $Destination).Hash.ToLowerInvariant()
}
function Get-DvLegacy {
 $taskRows=@()
 foreach($taskName in @('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')){
  & $taskAdb -s '192.168.0.102:5555' shell run-as $taskPackage test -f "databases/$taskName"
  if($LASTEXITCODE -eq 1){$taskRows+="$taskName ABSENT";continue}
  if($LASTEXITCODE -ne 0){throw 'DV legacy file access unavailable; no preservation claim.'}
  $taskHash=((& $taskAdb -s '192.168.0.102:5555' shell run-as $taskPackage sha256sum "databases/$taskName")-join '').Trim()
  if($LASTEXITCODE -ne 0 -or $taskHash -notmatch '^[a-f0-9]{64} '){throw 'DV legacy digest unavailable.'}
  $taskRows+=$taskHash
 }
 return $taskRows -join "`n"
}
function Get-Public {
 $taskHash=((& $taskAdb -s $taskDevice shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`n").Trim()
 $taskBaseline=((Get-Content docs/evidence/m5-20261017/c23-public-export-before.txt)-join "`n").Trim()
 if($LASTEXITCODE -ne 0 -or $taskHash -ne $taskBaseline){throw 'Public backup digests changed/unavailable.'}
 return $taskHash
}
if(((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne '24069PC21G'){throw 'Confirmed Poco unavailable.'}
try {
Save-Ledger
if((Copy-Apk $taskDevice "$taskEvidence/prior-before-tests.apk") -ne $taskPriorSha){throw 'Installed fixture differs from C29; no tests or deploy.'}
Get-Public | Set-Content "$taskEvidence/public-before.txt" -Encoding UTF8
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_settings_ui_test.dart') -NameFilter 'Drive ' -RunName "c30-ui-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db') *> "$taskEvidence/poco-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Poco regression failed.'}
$taskLedger.state='DV native regression'
& $taskAdb connect '192.168.0.102:5555' *> "$taskEvidence/dv-connect.log"
Save-Ledger
if(((& $taskAdb -s '192.168.0.102:5555' get-state)-join '').Trim() -eq 'device'){
 if(((& $taskAdb -s '192.168.0.102:5555' shell getprop ro.product.model)-join '').Trim() -ne 'AX810'){throw 'DV identity mismatch.'}
 $taskDvBefore=Get-DvLegacy
 $taskDvBefore | Set-Content "$taskEvidence/dv-legacy-before.txt" -Encoding UTF8
 $taskDvSha=Copy-Apk '192.168.0.102:5555' "$taskEvidence/dv-prior.apk"
 try {
  & tools/test_m5_dv.ps1 -TestFiles @('integration_test/m5_settings_ui_test.dart') -NameFilter 'Drive ' -RunName "c30-ui-$taskNonce" -AdditionalDartDefines @("KASIR_FIXTURE_DATABASE=m5_worker_$taskNonce.db") *> "$taskEvidence/dv-invocation.log"
  if($LASTEXITCODE -ne 0){throw 'DV regression failed.'}
 }finally{
  & $taskAdb -s '192.168.0.102:5555' install -r -d "$taskEvidence/dv-prior.apk" *> "$taskEvidence/dv-prior-restored.log"
  if($LASTEXITCODE -ne 0){throw 'DV exact prior APK restoration failed.'}
  if((Copy-Apk '192.168.0.102:5555' "$taskEvidence/dv-restored.apk") -ne $taskDvSha){throw 'DV restored APK digest differs.'}
  $taskDvAfter=Get-DvLegacy
  $taskDvAfter | Set-Content "$taskEvidence/dv-legacy-after.txt" -Encoding UTF8
  if($taskDvAfter -ne $taskDvBefore){throw 'DV default sandbox byte hashes changed.'}
 }
 $taskLedger.dv='native UI completed; exact prior APK and default sandbox hashes restored/equal; awake proof in native wrapper'
}else{$taskLedger.dv='BLOCKED: device not available; no native result'}
$taskLedger.state='build final artifacts'
Save-Ledger
$taskBuildStart=Get-Date
& tools/build_m5_acceptance.ps1 -ConfirmedDeviceId $taskDevice *> "$taskEvidence/build-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Final build failed; no acceptance deploy.'}
$taskBuilt=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter 'release-artifacts-*' | Where-Object {$_.CreationTime -ge $taskBuildStart})
if($taskBuilt.Count -ne 1){throw 'Build artifacts ambiguous.'}
$taskArtifacts=Get-Content "$($taskBuilt[0].FullName)/artifacts.json" -Raw | ConvertFrom-Json
if($taskArtifacts.fixtureDatabase -ne $taskLedger.fixtureDatabase -or $taskArtifacts.installed -ne $false){throw 'Artifact scope mismatch.'}
$taskLedger.artifactsJson="$($taskBuilt[0].FullName)/artifacts.json"
$taskLedger.state='strict before audit'
Save-Ledger
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_account_b_audit_test.dart') -RunName "c30-before-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCOUNT_B_AUDIT=true','M5_ACCEPTANCE_AUDIT_ROLE=before',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskEvidence/before-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Before audit failed; no deploy.'}
if((Copy-Apk $taskDevice "$taskEvidence/prior-c29.apk") -ne $taskPriorSha){throw 'Installed APK differs from C29; no deploy.'}
& $taskPython tools/verify_m5_apk.py --apk $taskArtifacts.fixture --kind fixture --output "$taskEvidence/new-apk.json"
if($LASTEXITCODE -ne 0){throw 'Final fixture APK verification failed.'}
$taskLedger.priorApk="$taskEvidence/prior-c29.apk"
$taskLedger.newApk=$taskArtifacts.fixture
$taskLedger.restoreBridge=$taskArtifacts.restoreBridge
$taskLedger.fixtureSha256=(Get-FileHash $taskArtifacts.fixture).Hash.ToLowerInvariant()
$taskLedger.state='install verified C30 fixture only; no startup before strict after'
Save-Ledger
& $taskAdb -s $taskDevice install -r $taskArtifacts.fixture *> "$taskEvidence/install.log"
if($LASTEXITCODE -ne 0){throw 'C30 installation failed; no uninstall/reset fallback.'}
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_account_b_audit_test.dart') -RunName "c30-after-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCOUNT_B_AUDIT=true','M5_ACCEPTANCE_AUDIT_ROLE=after',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskEvidence/after-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Strict after audit failed; no handover.'}
$taskBefore=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c30-before-$taskNonce-*")
$taskAfter=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c30-after-$taskNonce-*")
if($taskBefore.Count -ne 1 -or $taskAfter.Count -ne 1){throw 'Strict audit evidence ambiguous.'}
foreach($taskEntry in @(@($taskBefore[0],'before'),@($taskAfter[0],'after'))){
 if(-not (Select-String -LiteralPath "$($taskEntry[0].FullName)/runner.log" -SimpleMatch -Pattern "M5_ACCOUNT_B_AUDIT $($taskEntry[1]) integrity/FK/envelope/financial facts/all tables/13archives/policy PASS")){throw 'Audit completion not proven.'}
 if(-not (Select-String -LiteralPath "$($taskEntry[0].FullName)/original-restored.log" -Pattern '^Success$')){throw 'Audit wrapper did not restore acceptance APK.'}
}
if((Get-Content "$($taskBefore[0].FullName)/ordinary-before.txt" -Raw) -ne (Get-Content "$($taskAfter[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary hashes changed across update.'}
Get-Public | Set-Content "$taskEvidence/public-after.txt" -Encoding UTF8
if((Copy-Apk $taskDevice "$taskEvidence/installed-c30.apk") -ne $taskLedger.fixtureSha256){throw 'Installed C30 digest mismatch.'}
$taskLedger.beforeEvidence=$taskBefore[0].FullName
$taskLedger.afterEvidence=$taskAfter[0].FullName
$taskLedger.state='strict all-table/13archive equality PASS; own startup next'
Save-Ledger
@{package=$taskPackage;automaticDeviceControlActive=$true;scope='own cashier only, no account/recovery UI'} | ConvertTo-Json | Set-Content "$taskEvidence/handover.json" -Encoding UTF8
& $taskAdb -s $taskDevice shell am start -S -W -f 0x10008000 -n com.example.kasir_app.integration/com.example.kasir_app.IntegrationActivity *> "$taskEvidence/start.log"
if($LASTEXITCODE -ne 0){throw 'C30 startup failed.'}
& $taskPython tools/probe_m5_poco_startup.py --evidence $taskEvidence *> "$taskEvidence/startup-invocation.log"
if($LASTEXITCODE -ne 0){throw 'C30 own startup not proven.'}
$taskLedger.state='C30 native regression/build/strict preservation/startup PASS; manual handover not finalized'
Save-Ledger
Write-Output "C30 complete: $taskEvidence"

} catch {
 $taskLedger.failure='Pipeline failed; retain logs and inspect installed APK/state before manual work. No reset/uninstall.'
 throw
} finally {
 $taskLedger.automaticDeviceControlActive=$false
 Save-Ledger
 if(Test-Path -LiteralPath "$taskEvidence/handover.json"){
  $taskH=Get-Content -LiteralPath "$taskEvidence/handover.json" -Raw | ConvertFrom-Json
  $taskH.automaticDeviceControlActive=$false
  $taskH | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath "$taskEvidence/handover.json" -Encoding UTF8
 }
}
