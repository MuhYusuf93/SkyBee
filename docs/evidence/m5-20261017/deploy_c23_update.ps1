param([Parameter(Mandatory)][string]$ArtifactsJson)
# Campaign-specific replacement only after the existing two-sale DB and two archive files were audited.
# Never launches the acceptance app until the matching after-audit has passed.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskDevice='7f0edea0'
$taskPackage='com.example.kasir_app.integration'
$taskNonce='1792181574653'
$taskPriorSha='592e089427a05dcf1ea3d5cd77914b5169eef9f012fb491bab316baa138d4869'
$taskBefore=Join-Path $taskRoot 'docs/evidence/m5-20261016/poco-c23-before-1792181574653-20261017-031614'
$taskUpdate=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-archive-update-$taskNonce"
Push-Location -LiteralPath $taskRoot
try {
    if(-not (Select-String -LiteralPath "$taskBefore/runner.log" -SimpleMatch 'M5_ACCEPTANCE_AUDIT post_backup before integrity/FK/legacy/facts PASS')){throw 'Matching before audit unavailable.'}
    if((Get-Content -LiteralPath "$taskBefore/isolation.txt" -Raw).Trim() -ne 'Ordinary DB and sidecar byte hashes unchanged.'){throw 'Before isolation not proven.'}
    if(-not (Select-String -LiteralPath "$taskBefore/original-restored.log" -Pattern '^Success$')){throw 'Before wrapper did not restore prior APK.'}
    $taskInput=(Resolve-Path -LiteralPath $ArtifactsJson).Path
    $taskEvidenceRoot=(Resolve-Path 'docs/evidence/m5-20261016').Path+[IO.Path]::DirectorySeparatorChar
    if(-not $taskInput.StartsWith($taskEvidenceRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unscoped artifact ledger.'}
    $taskArtifacts=Get-Content -LiteralPath $taskInput -Raw | ConvertFrom-Json
    if($taskArtifacts.fixtureDatabase -ne 'm5_acceptance_1792150309449.db' -or $taskArtifacts.installed -ne $false){throw 'Wrong acceptance artifact scope.'}
    $taskNew=(Resolve-Path -LiteralPath $taskArtifacts.fixture).Path
    $taskBuildRoot=(Resolve-Path build).Path+[IO.Path]::DirectorySeparatorChar
    if(-not $taskNew.StartsWith($taskBuildRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'APK outside owned build directory.'}
    if(((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne '24069PC21G' -or $LASTEXITCODE -ne 0){throw 'Confirmed Poco unavailable.'}
    if(Test-Path -LiteralPath $taskUpdate){throw 'Update evidence already exists; inspect before resuming, no overwrite.'}
    New-Item -ItemType Directory -Path $taskUpdate | Out-Null
    & $taskPython tools/verify_m5_apk.py --apk $taskNew --kind fixture --output "$taskUpdate/apk-verification.json"
    if($LASTEXITCODE -ne 0){throw 'New fixture APK verification failed; no install.'}
    $taskPublicBaseline=(Get-Content -LiteralPath 'docs/evidence/m5-20261017/c23-public-export-before.txt' -Raw).Trim()
    $taskPublicHash=((& $taskAdb -s $taskDevice shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`r`n").Trim()
    if($LASTEXITCODE -ne 0 -or $taskPublicHash -ne $taskPublicBaseline){throw 'Public exported backup differs before update; no install.'}
    $taskPublicHash | Set-Content -LiteralPath "$taskUpdate/public-export-before.txt" -Encoding UTF8
    $taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
    if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Current APK unavailable.'}
    $taskPrior=Join-Path $taskUpdate 'prior-c22-release.apk'
    & $taskAdb -s $taskDevice pull $Matches[1] $taskPrior *> "$taskUpdate/prior-copy.log"
    if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $taskPrior -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskPriorSha){throw 'Current APK differs from audited C22 release.'}
    [ordered]@{device=$taskDevice;package=$taskPackage;fixtureDatabase=$taskArtifacts.fixtureDatabase;priorApk=$taskPrior;priorSha256=$taskPriorSha;newApk=$taskNew;restoreBridge=$taskArtifacts.restoreBridge;originalV6Restoration='still pending in original handover';state='verified before install';automaticDeviceControlActive=$true} | ConvertTo-Json | Set-Content "$taskUpdate/update.json" -Encoding UTF8
    & $taskAdb -s $taskDevice install -r $taskNew *> "$taskUpdate/install.log"
    if($LASTEXITCODE -ne 0){throw 'Replacement failed; no uninstall/reset fallback.'}
    & tools/test_m5_poco.ps1 -TestFiles @('integration_test/m5_acceptance_audit_test.dart') -RunName "c23-after-$taskNonce" -AdditionalDartDefines @('KASIR_FIXTURE_DATABASE=m5_acceptance_1792150309449.db','M5_ACCEPTANCE_AUDIT_PHASE=post_backup','M5_ACCEPTANCE_AUDIT_ROLE=after',"M5_ACCEPTANCE_AUDIT_NONCE=$taskNonce") *> "$taskUpdate/after-invocation.log"
    if($LASTEXITCODE -ne 0){throw 'After audit failed; do not launch or hand over. Inspect safe-runner finally evidence.'}
    $taskAfter=@(Get-ChildItem -Directory docs/evidence/m5-20261016 -Filter "poco-c23-after-$taskNonce-*")
    if($taskAfter.Count -ne 1){throw 'After audit evidence ambiguous.'}
    if(-not (Select-String -LiteralPath "$($taskAfter[0].FullName)/runner.log" -SimpleMatch 'M5_ACCEPTANCE_AUDIT post_backup after integrity/FK/legacy/facts PASS')){throw 'After audit completion not proven.'}
    if((Get-Content -LiteralPath "$($taskAfter[0].FullName)/isolation.txt" -Raw).Trim() -ne 'Ordinary DB and sidecar byte hashes unchanged.'){throw 'After isolation failed.'}
    if((Get-Content -LiteralPath "$taskBefore/ordinary-before.txt" -Raw) -ne (Get-Content -LiteralPath "$($taskAfter[0].FullName)/ordinary-after.txt" -Raw)){throw 'Ordinary hashes differ across update interval.'}
    if(-not (Select-String -LiteralPath "$($taskAfter[0].FullName)/original-restored.log" -Pattern '^Success$')){throw 'After wrapper did not restore new APK.'}
    $taskActual=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
    if($LASTEXITCODE -ne 0 -or $taskActual -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Updated APK unavailable.'}
    $taskInstalled=Join-Path $taskUpdate 'installed-c23-release.apk'
    & $taskAdb -s $taskDevice pull $Matches[1] $taskInstalled *> "$taskUpdate/installed-copy.log"
    if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $taskInstalled -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $taskNew -Algorithm SHA256).Hash){throw 'Installed updated APK hash mismatch.'}
    $taskPublicHash=((& $taskAdb -s $taskDevice shell sha256sum /sdcard/Download/M5_poco_uji_20261017_01.kasirbackup /sdcard/Download/M5_poco_keyboard_20261017_02.kasirbackup)-join "`r`n").Trim()
    if($LASTEXITCODE -ne 0 -or $taskPublicHash -ne $taskPublicBaseline){throw 'Public exported backup differs after update.'}
    $taskPublicHash | Set-Content -LiteralPath "$taskUpdate/public-export-after.txt" -Encoding UTF8
    $taskLedger=Get-Content -LiteralPath "$taskUpdate/update.json" -Raw | ConvertFrom-Json
    $taskLedger.state='before+after integrity/facts/all-table fingerprints/two local archive hashes/public export/default+ordinary hashes PASS; installed APK hash matches; startup not yet run'
    $taskLedger | ConvertTo-Json | Set-Content "$taskUpdate/update.json" -Encoding UTF8
    Write-Output "C23 update verified without launch: $taskUpdate"
} finally { Pop-Location }

