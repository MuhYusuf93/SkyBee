$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$taskProbe=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter 'poco-c23-metadata-explanation-timing-*')
if($taskProbe.Count -ne 1 -or -not (Select-String -LiteralPath "$($taskProbe[0].FullName)/runner.log" -Pattern 'M5_METADATA_PROBE .*credentialSecretsUnchanged.*true')){throw 'Metadata explanation must pass first.'}
if(-not (Select-String -LiteralPath "$($taskProbe[0].FullName)/runner.log" -SimpleMatch -Pattern 'All tests passed!')){throw 'Probe not completed.'}
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-c23-quiescent-$taskNonce"
if(Test-Path -LiteralPath $taskEvidence){throw 'Do not overwrite evidence.'}
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPackage='com.example.kasir_app.integration';$taskDevice='7f0edea0'
$taskArtifacts=Get-Content docs/evidence/m5-20261016/release-artifacts-20261017-054951/artifacts.json -Raw | ConvertFrom-Json
$taskExpected='fba00b55a3a0fc0345722a78ac9ce6c028944d09a541b761fe6fdd1510fc56b0'
if((Get-FileHash -LiteralPath $taskArtifacts.fixture -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskExpected){throw 'New release artifact mismatch.'}
$taskBaseline=((Get-Content -LiteralPath docs/evidence/m5-20261017/c23-public-export-before.txt)-join "`n").Trim()
function Get-PublicHash {
 $taskValue=((& $taskAdb -s $taskDevice shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`n").Trim()
 if($LASTEXITCODE -ne 0 -or $taskValue -ne $taskBaseline){throw 'Public archives changed.'}
 return $taskValue
}
Get-PublicHash | Set-Content "$taskEvidence/public-before.txt" -Encoding UTF8
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_acceptance_audit_test.dart') -RunName "c23-quiescent-before-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCEPTANCE_AUDIT_PHASE=post_backup','M5_ACCEPTANCE_AUDIT_ROLE=before',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskEvidence/before-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Fresh before audit failed.'}
$taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Current APK not available.'}
& $taskAdb -s $taskDevice pull $Matches[1] "$taskEvidence/prior-installed.apk" *> "$taskEvidence/prior-copy.log"
if($LASTEXITCODE -ne 0 -or (Get-FileHash "$taskEvidence/prior-installed.apk" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskExpected){throw 'Current release mismatch.'}
# Same C23 release, after documented human activity; preserve that activity.
& $taskAdb -s $taskDevice install -r $taskArtifacts.fixture *> "$taskEvidence/install.log"
if($LASTEXITCODE -ne 0){throw 'Install failed; no uninstall/reset fallback.'}
& tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_acceptance_audit_test.dart') -RunName "c23-quiescent-after-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCEPTANCE_AUDIT_PHASE=post_backup','M5_ACCEPTANCE_AUDIT_ROLE=after',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskEvidence/after-invocation.log"
if($LASTEXITCODE -ne 0){throw 'Strict fresh after audit failed.'}
$taskBefore=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter "poco-c23-quiescent-before-$taskNonce-*")
$taskAfter=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter "poco-c23-quiescent-after-$taskNonce-*")
if($taskBefore.Count -ne 1 -or $taskAfter.Count -ne 1){throw 'Ambiguous new audit evidence.'}
foreach($taskDir in @($taskBefore[0],$taskAfter[0])){
 if((Get-Content "$($taskDir.FullName)/isolation.txt" -Raw).Trim() -ne 'Ordinary DB and sidecar byte hashes unchanged.'){throw 'Ordinary isolation failed.'}
 if(-not (Select-String -LiteralPath "$($taskDir.FullName)/original-restored.log" -Pattern '^Success$')){throw 'Release not restored.'}
}
if((Get-Content docs/evidence/m5-20261016/poco-c23-before-1792181574653-20261017-031614/ordinary-before.txt -Raw) -ne (Get-Content "$($taskAfter[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary endpoint differs across original interval.'}
Get-PublicHash | Set-Content "$taskEvidence/public-after.txt" -Encoding UTF8
$taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Installed release unavailable.'}
& $taskAdb -s $taskDevice pull $Matches[1] "$taskEvidence/installed.apk" *> "$taskEvidence/installed-copy.log"
if($LASTEXITCODE -ne 0 -or (Get-FileHash "$taskEvidence/installed.apk" -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskExpected){throw 'Installed hash differs.'}
[ordered]@{nonce=$taskNonce;fixtureDatabase=$taskArtifacts.fixtureDatabase;newApk=$taskArtifacts.fixture;restoreBridge=$taskArtifacts.restoreBridge;fixtureSha256=$taskExpected;strictFreshBeforeAfter='PASS; all tables and two private archive hashes equal';originalInterval='Historical strict FAIL retained; metadata probe explains all four changed tables, no data rollback';ordinaryAndPublicExports='unchanged';startupConfirmed=$false;automaticDeviceControlActive=$true;beforeEvidence=$taskBefore[0].FullName;afterEvidence=$taskAfter[0].FullName} | ConvertTo-Json | Set-Content "$taskEvidence/update.json" -Encoding UTF8
Write-Output "Quiescent audit complete: $taskEvidence"
