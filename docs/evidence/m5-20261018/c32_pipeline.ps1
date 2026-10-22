$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
if(-not (Select-String -LiteralPath docs/evidence/m5-20261018/c32-host-regression.log -SimpleMatch -Pattern 'All tests passed!')){throw 'Host regression incomplete.'}
if(-not (Select-String -LiteralPath docs/evidence/m5-20261018/c32-analyze.log -SimpleMatch -Pattern 'No issues found!')){throw 'Analyzer incomplete.'}
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-worker-status-update-$taskNonce"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskDevice='7f0edea0';$taskPackage='com.example.kasir_app.integration'
$taskPriorSha='ab00a7e191f354707a5cf847c04de620ffc6576231cf19ef197b2e6f99620641'
$taskLedger=[ordered]@{nonce=$taskNonce;fixtureDatabase='m5_acceptance_1792150309449.db';state='Poco native regression';automaticDeviceControlActive=$true;originalV6Restoration='pending in original handover, never overwrite original pointer'}
function Save-Ledger {
 $taskLedger | ConvertTo-Json -Depth 8 | Set-Content "$taskEvidence/update.json" -Encoding UTF8
 foreach($taskFolder in @('poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346','poco-account-ui-update-1792328869099','poco-history-ui-update-1792331546910','poco-silent-auth-update-1792333169315')){
  $taskFile="docs/evidence/m5-20261016/$taskFolder/handover.json"
  $taskH=Get-Content -LiteralPath $taskFile -Raw | ConvertFrom-Json
  $taskH.automaticDeviceControlActive=$taskLedger.automaticDeviceControlActive
  $taskH | Add-Member -NotePropertyName pendingC32Update -NotePropertyValue @{ledger="$taskEvidence/update.json";state=$taskLedger.state} -Force
  $taskH | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $taskFile -Encoding UTF8
 }
 @{stage=$taskLedger.state;ledger="$taskEvidence/update.json";automaticDeviceControlActive=$taskLedger.automaticDeviceControlActive;fixtureDatabase=$taskLedger.fixtureDatabase;originalV6RestorationPending=$true} | ConvertTo-Json | Set-Content "$taskRoot/docs/evidence/m5-20261018/c32-update-context.json" -Encoding UTF8
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
if((Copy-Apk $taskDevice "$taskEvidence/prior-before-tests.apk") -ne $taskPriorSha){throw 'Installed fixture differs from C31; no tests or deploy.'}
Get-Public | Set-Content "$taskEvidence/public-before.txt" -Encoding UTF8
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_settings_ui_test.dart') -NameFilter 'Drive persisted automatic failure' -RunName "c32-ui-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db') *> "$taskEvidence/poco-invocation.log"
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
  & tools/test_m5_dv.ps1 -TestFiles @('integration_test/m5_settings_ui_test.dart') -NameFilter 'Drive persisted automatic failure' -RunName "c32-ui-$taskNonce" -AdditionalDartDefines @("KASIR_FIXTURE_DATABASE=m5_worker_$taskNonce.db") *> "$taskEvidence/dv-invocation.log"
  if($LASTEXITCODE -ne 0){throw 'DV regression failed.'}
 }finally{
  & $taskAdb -s '192.168.0.102:5555' install -r -d "$taskEvidence/dv-prior.apk" *> "$taskEvidence/dv-prior-restored.log"
  if($LASTEXITCODE -ne 0){throw 'DV exact prior APK restoration failed.'}
  if((Copy-Apk '192.168.0.102:5555' "$taskEvidence/dv-restored.apk") -ne $taskDvSha){throw 'DV restored APK digest differs.'}
  $taskDvAfter=Get-DvLegacy
  $taskDvAfter | Set-Content "$taskEvidence/dv-legacy-after.txt" -Encoding UTF8
  if($taskDvAfter -ne $taskDvBefore){throw 'DV default sandbox byte hashes changed.'}
 }
 $taskLedger.dv='native persisted-worker-status UI completed; exact prior APK and default sandbox hashes restored/equal; awake proof in native wrapper'
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
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_closing_audit_test.dart') -RunName "c32-before-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_CLOSING_AUDIT=true','M5_CLOSING_ROLE=before',"M5_CLOSING_NONCE=$taskNonce",'M5_CLOSING_BASELINE_NONCE=1792333169315') *> "$taskEvidence/before-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Before audit failed; no deploy.'}
if((Copy-Apk $taskDevice "$taskEvidence/prior-c31.apk") -ne $taskPriorSha){throw 'Installed APK differs from C31; no deploy.'}
& $taskPython tools/verify_m5_apk.py --apk $taskArtifacts.fixture --kind fixture --output "$taskEvidence/new-apk.json"
if($LASTEXITCODE -ne 0){throw 'Final fixture APK verification failed.'}
$taskLedger.priorApk="$taskEvidence/prior-c31.apk"
$taskLedger.newApk=$taskArtifacts.fixture
$taskLedger.restoreBridge=$taskArtifacts.restoreBridge
$taskLedger.fixtureSha256=(Get-FileHash $taskArtifacts.fixture).Hash.ToLowerInvariant()
$taskLedger.state='install verified C32 fixture only; no startup before strict after'
Save-Ledger
& $taskAdb -s $taskDevice install -r $taskArtifacts.fixture *> "$taskEvidence/install.log"
if($LASTEXITCODE -ne 0){throw 'C32 installation failed; no uninstall/reset fallback.'}
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_closing_audit_test.dart') -RunName "c32-after-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_CLOSING_AUDIT=true','M5_CLOSING_ROLE=after',"M5_CLOSING_NONCE=$taskNonce",'M5_CLOSING_BASELINE_NONCE=1792333169315') *> "$taskEvidence/after-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Strict after audit failed; no handover.'}
$taskBefore=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c32-before-$taskNonce-*")
$taskAfter=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c32-after-$taskNonce-*")
if($taskBefore.Count -ne 1 -or $taskAfter.Count -ne 1){throw 'Strict audit evidence ambiguous.'}
foreach($taskEntry in @(@($taskBefore[0],'before'),@($taskAfter[0],'after'))){
 if(-not (Select-String -LiteralPath "$($taskEntry[0].FullName)/runner.log" -SimpleMatch -Pattern "M5_CLOSING_AUDIT $($taskEntry[1]) integrity/FK/envelope/business23/13archives/disconnected/policy/allTables PASS")){throw 'Audit completion not proven.'}
 if(-not (Select-String -LiteralPath "$($taskEntry[0].FullName)/original-restored.log" -Pattern '^Success$')){throw 'Audit wrapper did not restore acceptance APK.'}
}
if((Get-Content "$($taskBefore[0].FullName)/ordinary-before.txt" -Raw) -ne (Get-Content "$($taskAfter[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary hashes changed across update.'}
Get-Public | Set-Content "$taskEvidence/public-after.txt" -Encoding UTF8
if((Copy-Apk $taskDevice "$taskEvidence/installed-c32.apk") -ne $taskLedger.fixtureSha256){throw 'Installed C32 digest mismatch.'}
$taskLedger.beforeEvidence=$taskBefore[0].FullName
$taskLedger.afterEvidence=$taskAfter[0].FullName
$taskLedger.state='strict all-table/13archive equality PASS; own startup next'
Save-Ledger
@{package=$taskPackage;automaticDeviceControlActive=$true;scope='own cashier only, no account/recovery UI'} | ConvertTo-Json | Set-Content "$taskEvidence/handover.json" -Encoding UTF8
& $taskAdb -s $taskDevice shell am start -S -W -f 0x10008000 -n com.example.kasir_app.integration/com.example.kasir_app.IntegrationActivity *> "$taskEvidence/start.log"
if($LASTEXITCODE -ne 0){throw 'C32 startup failed.'}
& $taskPython tools/probe_m5_poco_startup.py --evidence $taskEvidence *> "$taskEvidence/startup-invocation.log"
if($LASTEXITCODE -ne 0){throw 'C32 own startup not proven.'}

$taskLedger.state='final post-startup audit and own fixture work cleanup'
Save-Ledger
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_closing_audit_test.dart') -RunName "c32-final-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_CLOSING_AUDIT=true','M5_CLOSING_ROLE=final',"M5_CLOSING_NONCE=$taskNonce",'M5_CLOSING_BASELINE_NONCE=1792333169315') *> "$taskEvidence/final-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Final closing audit failed; preserve artifacts, do not claim closure.'}
$taskFinal=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c32-final-$taskNonce-*")
if($taskFinal.Count -ne 1 -or -not (Select-String -LiteralPath "$($taskFinal[0].FullName)/runner.log" -SimpleMatch 'M5_CLOSING_CLOSED_DIGESTS final stored=true')){throw 'Final closing marker unavailable.'}
$taskLedger.finalEvidence=$taskFinal[0].FullName
$taskLedger.state='verified debug bridge for closed-file inspection, no launch'
Save-Ledger
& $taskAdb -s $taskDevice install -r $taskArtifacts.restoreBridge *> "$taskEvidence/closing-bridge-install.log"
if($LASTEXITCODE -ne 0){throw 'Closing bridge installation failed; no uninstall fallback.'}
function Get-PocoHashes([string]$Package,[string[]]$Names) {
 $taskResult=[ordered]@{}
 foreach($taskName in $Names){
  if($taskName -notmatch '^(kasir_app|m5_acceptance_1792150309449)\.db(-wal|-shm|-journal)?$'){throw 'Closed-file hash scope rejected.'}
  & $taskAdb -s $taskDevice shell run-as $Package test -f "databases/$taskName"
  if($LASTEXITCODE -eq 1){$taskResult[$taskName]='ABSENT';continue}
  if($LASTEXITCODE -ne 0){throw 'Closed-file access failed; do not infer absence.'}
  $taskHash=((& $taskAdb -s $taskDevice shell run-as $Package sha256sum "databases/$taskName")-join '').Trim()
  if($LASTEXITCODE -ne 0 -or $taskHash -notmatch '^([a-f0-9]{64}) '){throw 'Closed-file digest unavailable.'}
  $taskResult[$taskName]=$Matches[1]
 }
 return $taskResult
}
function Assert-Hashes($Actual,$Expected,[string]$Role) {
 foreach($taskName in $Expected.Keys){if($Actual[$taskName] -ne $Expected[$taskName]){throw "$Role closed-file hash differs; no preservation claim."}}
}
$taskOrdinaryNames=@('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')
$taskCampaignNames=@('m5_acceptance_1792150309449.db','m5_acceptance_1792150309449.db-wal','m5_acceptance_1792150309449.db-shm','m5_acceptance_1792150309449.db-journal')
$taskClosedText=((& $taskAdb -s $taskDevice exec-out run-as $taskPackage cat "databases/m5_closing_closed_$taskNonce.json")-join "`n")
if($LASTEXITCODE -ne 0){throw 'Closed audit digests unavailable.'}
$taskClosed=$taskClosedText | ConvertFrom-Json -AsHashtable
if($taskClosed.Count -ne 4 -or @($taskClosed.Keys|Where-Object {$_ -notin $taskCampaignNames}).Count -ne 0){throw 'Closed audit scope mismatch.'}
$taskClosed | ConvertTo-Json | Set-Content "$taskEvidence/campaign-closed-audit.json" -Encoding UTF8
$taskLegacyExpected=[ordered]@{'kasir_app.db'='556c6a5c472bf4c77edf80919eda1a58f76c415b2cb4c2bd5badfd442dfd103e';'kasir_app.db-wal'='ABSENT';'kasir_app.db-shm'='ABSENT';'kasir_app.db-journal'='076a27c79e5ace2a3d47f9dd2e83e4ff6ea8872b3c2218f66c92b89b55f36560'}
Assert-Hashes (Get-PocoHashes $taskPackage $taskOrdinaryNames) $taskLegacyExpected 'Legacy fixture'
Assert-Hashes (Get-PocoHashes $taskPackage $taskCampaignNames) $taskClosed 'Campaign before original restore'
$taskOrdinaryBefore=Get-PocoHashes 'com.example.kasir_app' $taskOrdinaryNames
$taskOrdinaryBefore | ConvertTo-Json | Set-Content "$taskEvidence/ordinary-closing-before.json" -Encoding UTF8
$taskOriginal=Join-Path $taskRoot 'docs/evidence/m5-20261016/poco-manual-20261016-191759/original-fixture.apk'
$taskOriginalHash=((Get-Content docs/evidence/m5-20261016/poco-manual-20261016-191759/original-sha256.txt)-join '').Trim().ToLowerInvariant()
if((Get-FileHash $taskOriginal).Hash.ToLowerInvariant() -ne $taskOriginalHash){throw 'Original v6 artifact does not match initial preservation baseline.'}
$taskOriginalIdentity=(& 'C:\Users\ACER\AppData\Local\Android\sdk\build-tools\36.0.0\aapt.exe' dump badging $taskOriginal | Where-Object {$_ -match '^package:'}) -join ''
if($taskOriginalIdentity -notmatch "name='com.example.kasir_app.integration' versionCode='6'"){throw 'Exact original package/version not verified.'}
$taskOriginalIdentity | Set-Content "$taskEvidence/original-v6-identity.txt" -Encoding UTF8
$taskLedger.state='restore exact original v6 fixture without launch'
Save-Ledger
& $taskAdb -s $taskDevice install -r -d $taskOriginal *> "$taskEvidence/exact-original-restored.log"
if($LASTEXITCODE -ne 0){throw 'Exact original v6 restoration failed; no uninstall/reset.'}
if((Copy-Apk $taskDevice "$taskEvidence/restored-original-v6.apk") -ne $taskOriginalHash){throw 'Restored APK differs from exact initial v6.'}
Assert-Hashes (Get-PocoHashes $taskPackage $taskOrdinaryNames) $taskLegacyExpected 'Legacy after v6 restore'
Assert-Hashes (Get-PocoHashes $taskPackage $taskCampaignNames) $taskClosed 'Campaign after v6 restore'
Assert-Hashes (Get-PocoHashes 'com.example.kasir_app' $taskOrdinaryNames) $taskOrdinaryBefore 'Ordinary after v6 restore'
Get-Public | Set-Content "$taskEvidence/public-closing-after.txt" -Encoding UTF8
if((Get-Content "$taskEvidence/public-before.txt" -Raw) -ne (Get-Content "$taskEvidence/public-closing-after.txt" -Raw)){throw 'Public exports changed.'}
$taskLedger.state='exact original v6 and closed files preserved; own WorkManager read-only inspection'
$taskLedger.originalV6Restored=$true
$taskLedger.originalV6Sha256=$taskOriginalHash
Save-Ledger
& $taskPython tools/inspect_m5_closing_work.py --evidence $taskEvidence --nonce $taskNonce *> "$taskEvidence/work-inspection.log"
if($LASTEXITCODE -ne 0){throw 'Own M5 pending-work cleanup not verified; original v6 restored, investigate retained work.'}
@{originalV6Restored=$true;originalSha256=$taskOriginalHash;legacyHashesSame=$true;campaignClosedHashesSame=$true;ordinaryHashesSame=$true;publicExportsSame=$true;finalNativeEvidence=$taskFinal[0].FullName;originalNotLaunched=$true} | ConvertTo-Json | Set-Content "$taskEvidence/closing-results.json" -Encoding UTF8
$taskLedger.state='C32 native/build/strict preservation/startup/final audit/exact original v6 restoration/own M5 work cleanup PASS; docs finalization pending'
Save-Ledger
Write-Output "C32 closing complete: $taskEvidence"


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
