$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$taskEvidence=Join-Path $taskRoot 'docs/evidence/m5-20261016/poco-notification-update-1792195919961'
$taskLedger=Get-Content "$taskEvidence/update.json" -Raw | ConvertFrom-Json -AsHashtable
if($taskLedger.state -ne 'strict install-only all-table/3archive equality PASS; runtime startup next'){throw 'Unexpected checkpoint; inspect evidence.'}
if(-not (Test-Path "$taskEvidence/startup.json")){throw 'Prior startup not verified.'}
$taskStartup=Get-Content "$taskEvidence/startup.json" -Raw | ConvertFrom-Json
if(-not $taskStartup.synthetic_screen_visible -or $taskStartup.startup_error_markers -ne 0){throw 'Prior startup not clean.'}
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPath=((& $taskAdb -s 7f0edea0 shell pm path com.example.kasir_app.integration)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Installed APK unavailable.'}
& $taskAdb -s 7f0edea0 pull $Matches[1] "$taskEvidence/before-safety-retry.apk" *> "$taskEvidence/before-safety-retry-copy.log"
if($LASTEXITCODE -ne 0 -or (Get-FileHash "$taskEvidence/before-safety-retry.apk").Hash.ToLowerInvariant() -ne $taskLedger.fixtureSha256){throw 'Prior C24 APK not restored; no retry.'}
$taskRun='c24-post-restore-final-1792195919961'
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_post_restore_audit_test.dart') -RunName $taskRun -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db') *> "$taskEvidence/post-restore-final-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Final audit failed; no rerestore/reset.'}
$taskPost=@(Get-ChildItem docs/evidence/m5-20261016 -Directory -Filter "poco-$taskRun-*")
if($taskPost.Count -ne 1 -or -not (Select-String -LiteralPath "$($taskPost[0].FullName)/runner.log" -SimpleMatch -Pattern 'M5_POST_RESTORE_AUDIT integrity/FK/cipher/reconcile/business23/receipts/threeArchivesAuthenticated/safetyBeforeSwap/logo/deviceDefaults/driveDisconnected/legacy PASS count=3')){throw 'Final audit marker missing.'}
if((Get-Content "$($taskLedger.beforeEvidence)/ordinary-before.txt" -Raw) -ne (Get-Content "$($taskPost[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary endpoint differs.'}
$taskBaseline=((Get-Content docs/evidence/m5-20261017/c23-public-export-before.txt)-join "`n").Trim()
$taskPublic=((& $taskAdb -s 7f0edea0 shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`n").Trim()
if($LASTEXITCODE -ne 0 -or $taskPublic -ne $taskBaseline){throw 'Public export hashes differ.'}
$taskPublic | Set-Content "$taskEvidence/public-after.txt" -Encoding UTF8
$taskPath=((& $taskAdb -s 7f0edea0 shell pm path com.example.kasir_app.integration)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Final APK unavailable.'}
& $taskAdb -s 7f0edea0 pull $Matches[1] "$taskEvidence/final-installed.apk" *> "$taskEvidence/final-installed-copy.log"
if($LASTEXITCODE -ne 0 -or (Get-FileHash "$taskEvidence/final-installed.apk").Hash.ToLowerInvariant() -ne $taskLedger.fixtureSha256){throw 'Final APK hash differs.'}
$taskLedger.postRestoreEvidence=$taskPost[0].FullName
$taskLedger.state='C24 strict install preservation + production startup + actual restore safety audit PASS; manual handover not yet prepared'
$taskLedger | ConvertTo-Json -Depth 8 | Set-Content "$taskEvidence/update.json" -Encoding UTF8
Write-Output "C24 safety audit complete: $($taskPost[0].FullName)"
