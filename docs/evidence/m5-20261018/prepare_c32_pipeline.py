"""Reuse guarded installers; close only the confirmed isolated campaign."""
from pathlib import Path
root=Path(__file__).resolve().parents[3]
ev=root/'docs/evidence/m5-20261018'
s=(ev/'c31_pipeline.ps1').read_text(encoding='utf-8-sig')
s=s.replace('c31','c32').replace('C31','C32')
s=s.replace('C30','C31').replace('prior-c30','prior-c31')
s=s.replace('928bb4515fec95f6453335c4dabf56812ae976b4a2832138fa7c548a424bb1d4','ab00a7e191f354707a5cf847c04de620ffc6576231cf19ef197b2e6f99620641')
s=s.replace('poco-silent-auth-update-', 'poco-worker-status-update-')
s=s.replace('integration_test/m5_drive_authorization_test.dart', 'integration_test/m5_settings_ui_test.dart')
assert s.count("-TestFiles @('integration_test/m5_settings_ui_test.dart')") == 2
s=s.replace("-TestFiles @('integration_test/m5_settings_ui_test.dart')", "-TestFiles @('integration_test/m5_settings_ui_test.dart') -NameFilter 'Drive persisted automatic failure'")
s=s.replace('integration_test/m5_account_b_audit_test.dart','integration_test/m5_closing_audit_test.dart')
s=s.replace("'M5_ACCOUNT_B_AUDIT=true','M5_ACCEPTANCE_AUDIT_ROLE=before',\"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce\"", "'M5_CLOSING_AUDIT=true','M5_CLOSING_ROLE=before',\"M5_CLOSING_NONCE=$taskNonce\",'M5_CLOSING_BASELINE_NONCE=1792333169315'")
s=s.replace("'M5_ACCOUNT_B_AUDIT=true','M5_ACCEPTANCE_AUDIT_ROLE=after',\"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce\"", "'M5_CLOSING_AUDIT=true','M5_CLOSING_ROLE=after',\"M5_CLOSING_NONCE=$taskNonce\",'M5_CLOSING_BASELINE_NONCE=1792333169315'")
assert 'M5_ACCEPTANCE_AUDIT_' not in s
s=s.replace('M5_ACCOUNT_B_AUDIT $($taskEntry[1]) integrity/FK/envelope/financial facts/all tables/13archives/policy PASS', 'M5_CLOSING_AUDIT $($taskEntry[1]) integrity/FK/envelope/business23/13archives/disconnected/policy/allTables PASS')
anchor="'poco-history-ui-update-1792331546910'))"
assert anchor in s
s=s.replace(anchor,"'poco-history-ui-update-1792331546910','poco-silent-auth-update-1792333169315'))")
s=s.replace('native SDK-null authorization completed','native persisted-worker-status UI completed')
ending="$taskLedger.state='C32 native regression/build/strict preservation/startup PASS; manual handover not finalized'\nSave-Ledger\nWrite-Output \"C32 complete: $taskEvidence\""
assert ending in s
closing=r'''
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
'''
s=s.replace(ending,closing)
assert 'M5_ACCOUNT_B_AUDIT' not in s and 'M5_CLOSING_ROLE=before' in s and 'M5_CLOSING_ROLE=after' in s
(ev/'c32_pipeline.ps1').write_text(s,encoding='utf-8')
print('C32 guarded native/build/closing pipeline prepared; no device action')
