param([switch]$ResumeAfterDv)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$taskNonce=if($ResumeAfterDv){'1792195919961'}else{[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()}
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-notification-update-$taskNonce"
if(-not $ResumeAfterDv){New-Item -ItemType Directory -Path $taskEvidence | Out-Null}
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskDevice='7f0edea0';$taskPackage='com.example.kasir_app.integration'
$taskExpected='fba00b55a3a0fc0345722a78ac9ce6c028944d09a541b761fe6fdd1510fc56b0'
$taskStart=Get-Date
$taskLedger=if($ResumeAfterDv){Get-Content "$taskEvidence/update.json" -Raw | ConvertFrom-Json -AsHashtable}else{[ordered]@{nonce=$taskNonce;state='serial build active';automaticDeviceControlActive=$true;originalV6Restoration='still pending in original handover'}}
if($ResumeAfterDv -and $taskLedger.state -ne 'verified final artifacts; DV release probe'){throw 'Unexpected checkpoint; inspect before resuming.'}
function Save-Ledger { $taskLedger | ConvertTo-Json -Depth 8 | Set-Content "$taskEvidence/update.json" -Encoding UTF8 }
function Get-PublicHash {
 $taskHash=((& $taskAdb -s $taskDevice shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`n").Trim()
 if($LASTEXITCODE -ne 0){throw 'Public archive hash unavailable.'}
 $taskBaseline=((Get-Content docs/evidence/m5-20261017/c23-public-export-before.txt)-join "`n").Trim()
 if($taskHash -ne $taskBaseline){throw 'Public archives differ; no overwrite.'}
 return $taskHash
}
function Get-InstalledApk([string]$Destination) {
 $taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
 if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Installed fixture APK unavailable.'}
 & $taskAdb -s $taskDevice pull $Matches[1] $Destination *> "$Destination-copy.log"
 if($LASTEXITCODE -ne 0){throw 'APK copy failed.'}
 return (Get-FileHash $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
}
if(-not $ResumeAfterDv){
Save-Ledger
& tools/build_m5_acceptance.ps1 -ConfirmedDeviceId $taskDevice *> "$taskEvidence/build-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Final serial build failed; no deploy.'}
$taskBuilt=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter 'release-artifacts-*' | Where-Object {$_.CreationTime -ge $taskStart})
if($taskBuilt.Count -ne 1){throw 'Ambiguous build artifacts.'}
$taskArtifacts=Get-Content "$($taskBuilt[0].FullName)/artifacts.json" -Raw | ConvertFrom-Json
if($taskArtifacts.fixtureDatabase -ne 'm5_acceptance_1792150309449.db' -or $taskArtifacts.installed -ne $false){throw 'Wrong artifact scope.'}
$taskLedger.artifactsJson="$($taskBuilt[0].FullName)/artifacts.json"
$taskLedger.state='verified final artifacts; DV release probe'
Save-Ledger
& docs/evidence/m5-20261017/test_notification_release_probe.ps1 -RunName c24-release-after -DeviceId '192.168.0.102:5555' *> "$taskEvidence/dv-probe-invocation.log"
if($LASTEXITCODE -ne 0){throw 'DV release probe incomplete; inspect restore/awake evidence.'}
}else{
 $taskArtifacts=Get-Content $taskLedger.artifactsJson -Raw | ConvertFrom-Json
}
$taskDv=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter 'dv-c24-release-after-*')
if($taskDv.Count -ne 1 -or -not (Select-String -LiteralPath "$($taskDv[0].FullName)/result-marker.txt" -SimpleMatch -Pattern '"initialized":true,"errorCode":null,"databaseFilesUnchanged":true,"release":true')){throw 'DV release initialization not proven.'}
if((Get-Content "$($taskDv[0].FullName)/awake-original.json" -Raw | ConvertFrom-Json).Restored -ne $true){throw 'DV awake restoration not proven.'}
if((Get-FileHash "$($taskDv[0].FullName)/prior.apk").Hash -ne (Get-FileHash "$($taskDv[0].FullName)/restored.apk").Hash){throw 'DV APK restoration differs.'}
$taskLedger.dvProbe=$taskDv[0].FullName
$taskLedger.state='Poco strict before audit'
Save-Ledger
Get-PublicHash | Set-Content "$taskEvidence/public-before.txt" -Encoding UTF8
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_acceptance_audit_test.dart') -RunName "c24-before-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCEPTANCE_AUDIT_PHASE=post_restore','M5_ACCEPTANCE_AUDIT_ROLE=before',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskEvidence/before-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Before audit failed; no deploy.'}
$taskPrior=Join-Path $taskEvidence 'prior-c23-release.apk'
if((Get-InstalledApk $taskPrior) -ne $taskExpected){throw 'Current APK differs from C23; no deploy.'}
$taskLedger.priorApk=$taskPrior
$taskLedger.newApk=$taskArtifacts.fixture
$taskLedger.restoreBridge=$taskArtifacts.restoreBridge
$taskLedger.fixtureDatabase=$taskArtifacts.fixtureDatabase
& $taskPython tools/verify_m5_apk.py --apk $taskArtifacts.fixture --kind fixture --output "$taskEvidence/new-apk.json"
if($LASTEXITCODE -ne 0){throw 'Final APK gate failed.'}
$taskLedger.state='verified before install; no startup until strict after passes'
Save-Ledger
& $taskAdb -s $taskDevice install -r $taskArtifacts.fixture *> "$taskEvidence/install.log"
if($LASTEXITCODE -ne 0){throw 'Install failed; no uninstall/reset fallback.'}
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_acceptance_audit_test.dart') -RunName "c24-after-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCEPTANCE_AUDIT_PHASE=post_restore','M5_ACCEPTANCE_AUDIT_ROLE=after',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskEvidence/after-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Strict after audit failed; do not launch/handover.'}
$taskBefore=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c24-before-$taskNonce-*")
$taskAfter=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c24-after-$taskNonce-*")
if($taskBefore.Count -ne 1 -or $taskAfter.Count -ne 1){throw 'Audit evidence ambiguous.'}
foreach($taskPair in @(@($taskBefore[0],'before'),@($taskAfter[0],'after'))){
 if(-not (Select-String -LiteralPath "$($taskPair[0].FullName)/runner.log" -SimpleMatch -Pattern "M5_ACCEPTANCE_AUDIT post_restore $($taskPair[1]) integrity/FK/legacy/facts PASS")){throw 'Audit marker missing.'}
 if(-not (Select-String -LiteralPath "$($taskPair[0].FullName)/original-restored.log" -Pattern '^Success$')){throw 'Audit wrapper APK restore missing.'}
}
if((Get-Content "$($taskBefore[0].FullName)/ordinary-before.txt" -Raw) -ne (Get-Content "$($taskAfter[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary hashes differ across update.'}
$taskNewHash=(Get-FileHash $taskArtifacts.fixture -Algorithm SHA256).Hash.ToLowerInvariant()
if((Get-InstalledApk "$taskEvidence/installed-c24-release.apk") -ne $taskNewHash){throw 'Installed C24 APK hash mismatch.'}
$taskLedger.fixtureSha256=$taskNewHash
$taskLedger.beforeEvidence=$taskBefore[0].FullName
$taskLedger.afterEvidence=$taskAfter[0].FullName
$taskLedger.state='strict install-only all-table/3archive equality PASS; runtime startup next'
Save-Ledger
# Own campaign already verified present above. This is the production M5 startup,
# not a direct SQL edit to clear the error and not another restore/reseed.
& $taskAdb -s $taskDevice shell am start -S -W -f 0x10008000 -n com.example.kasir_app.integration/com.example.kasir_app.IntegrationActivity *> "$taskEvidence/start.log"
if($LASTEXITCODE -ne 0){throw 'C24 startup failed.'}
@{package=$taskPackage;automaticDeviceControlActive=$true;scope='own cashier startup only; no recovery/account UI'} | ConvertTo-Json | Set-Content "$taskEvidence/handover.json" -Encoding UTF8
& $taskPython tools/probe_m5_poco_startup.py --evidence $taskEvidence *> "$taskEvidence/startup-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Own cashier startup not verified.'}
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_post_restore_audit_test.dart') -RunName "c24-post-restore-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db') *> "$taskEvidence/post-restore-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Post-restore safety audit failed; preserve evidence, no rerestore.'}
$taskPost=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-c24-post-restore-$taskNonce-*")
if($taskPost.Count -ne 1 -or -not (Select-String -LiteralPath "$($taskPost[0].FullName)/runner.log" -SimpleMatch -Pattern 'M5_POST_RESTORE_AUDIT integrity/FK/cipher/reconcile/business23/receipts/threeArchivesAuthenticated/safetyBeforeSwap/logo/deviceDefaults/driveDisconnected/legacy PASS count=3')){throw 'Safety audit marker missing.'}
if((Get-Content "$($taskBefore[0].FullName)/ordinary-before.txt" -Raw) -ne (Get-Content "$($taskPost[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary endpoint differs.'}
Get-PublicHash | Set-Content "$taskEvidence/public-after.txt" -Encoding UTF8
if((Get-InstalledApk "$taskEvidence/final-installed.apk") -ne $taskNewHash){throw 'Final installed APK differs.'}
$taskLedger.postRestoreEvidence=$taskPost[0].FullName
$taskLedger.state='C24 strict install preservation + production startup + actual restore safety audit PASS; manual handover not yet prepared'
Save-Ledger
Write-Output "C24 pipeline complete: $taskEvidence"
