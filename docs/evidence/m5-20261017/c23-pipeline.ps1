param([switch]$ResumeAfterBeforeAudit)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$taskContext=Get-Content "$PSScriptRoot/c23-update-context.json" -Raw | ConvertFrom-Json
$taskNonce=$taskContext.nonce
if($taskNonce -notmatch '^[0-9]{13}$'){throw 'Invalid campaign nonce.'}
if(-not (Select-String -LiteralPath "$PSScriptRoot/c23-host-after.log" -SimpleMatch -Pattern 'All tests passed!')){throw 'Host regression has not passed.'}
if(-not (Select-String -LiteralPath "$PSScriptRoot/c23-host-fixture-visibility.log" -SimpleMatch -Pattern 'All tests passed!')){throw 'Fixture visibility host test has not passed.'}
if(-not (Select-String -LiteralPath "$PSScriptRoot/c23-analyze-final.log" -SimpleMatch -Pattern 'No issues found!')){throw 'Analyzer has not passed.'}
if(-not (Select-String -LiteralPath "$PSScriptRoot/c23-export-controlled-host.log" -SimpleMatch -Pattern 'All tests passed!')){throw 'Controlled input host test has not passed.'}
if(-not $ResumeAfterBeforeAudit){
 & tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_acceptance_audit_test.dart') -RunName "c23-before-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCEPTANCE_AUDIT_PHASE=post_backup','M5_ACCEPTANCE_AUDIT_ROLE=before',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$PSScriptRoot/c23-audit-before-invocation.log"
 if($LASTEXITCODE -ne 0){throw 'Before preservation audit failed.'}
}else{
 $taskExistingBefore=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter "poco-c23-before-$taskNonce-*")
 if($taskExistingBefore.Count -ne 1 -or -not (Select-String -LiteralPath "$($taskExistingBefore[0].FullName)/runner.log" -SimpleMatch -Pattern 'M5_ACCEPTANCE_AUDIT post_backup before integrity/FK/legacy/facts PASS')){throw 'Matching before audit required for resume.'}
}
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_settings_ui_test.dart','integration_test/m5_backup_rejection_test.dart') -RunName "c23-regression-final-$taskNonce" *> "$PSScriptRoot/c23-poco-final-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Poco regression failed.'}
& tools/test_m5_dv.ps1 -TestFiles @('integration_test/m5_settings_ui_test.dart','integration_test/m5_backup_rejection_test.dart') -RunName "c23-regression-$taskNonce" *> "$PSScriptRoot/c23-dv-invocation.log"
if($LASTEXITCODE -ne 0){throw 'DV regression failed.'}
$taskBuildStart=Get-Date
& tools/build_m5_acceptance.ps1 -ConfirmedDeviceId '192.168.0.102:5555' *> "$PSScriptRoot/c23-release-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Release build/verification failed.'}
$taskArtifacts=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter 'release-artifacts-*' | Where-Object {$_.CreationTime -ge $taskBuildStart.AddSeconds(-1)})
if($taskArtifacts.Count -ne 1){throw 'Ambiguous new build ledger.'}
$taskBefore=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter "poco-c23-before-$taskNonce-*")
if($taskBefore.Count -ne 1){throw 'Ambiguous before audit.'}
# Derive a fixed campaign-specific deployment from the audited C22 routine.
$taskDeploy=Get-Content "$PSScriptRoot/deploy_c22_update.ps1" -Raw
$taskDeploy=$taskDeploy.Replace("'1792178476161'","'$taskNonce'").Replace('49fb5e293909bc98f7d2cef2714e0f05ef3fbc6d3759c49ee65b868a2f8b411a',$taskContext.priorSha256)
$taskDeploy=$taskDeploy.Replace('docs/evidence/m5-20261016/poco-c22-before-1792178476161-20261017-022116',"docs/evidence/m5-20261016/$($taskBefore[0].Name)")
$taskDeploy=$taskDeploy.Replace('poco-export-update-$taskNonce','poco-archive-update-$taskNonce').Replace('c22-after-','c23-after-').Replace('c22-public-export-before.txt','c23-public-export-before.txt').Replace('prior-c20-release.apk','prior-c22-release.apk').Replace('installed-c20-release.apk','installed-c23-release.apk').Replace('audited C20 release','audited C22 release').Replace('C21+C22','C23')
$taskDeploy=$taskDeploy.Replace('sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup','sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup')
# The original handles one hash line. Preserve native output line breaks for two.
$taskDeploy=$taskDeploy.Replace("/sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join '').Trim()","/sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join '+PUBLIC-LINE+').Trim()")
$taskDeploy=$taskDeploy.Replace("-join '+PUBLIC-LINE+'",'-join "`r`n"')
$taskDeployPath=Join-Path $PSScriptRoot 'deploy_c23_update.ps1'
$taskDeploy | Set-Content -LiteralPath $taskDeployPath -Encoding UTF8
$taskErrors=$null;$taskTokens=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($taskDeployPath,[ref]$taskTokens,[ref]$taskErrors)
if($taskErrors.Count){throw 'Deployment script parse failure.'}
& $taskDeployPath -ArtifactsJson (Join-Path $taskArtifacts[0].FullName 'artifacts.json') *> "$PSScriptRoot/c23-deploy-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Guarded deploy/preservation failed.'}
Write-Output 'C23 pipeline PASS; startup and human handover remain pending.'
