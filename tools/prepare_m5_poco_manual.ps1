param([Parameter(Mandatory=$true)][string]$ArtifactsJson)
# Leaves the verified release fixture available for human acceptance. Never
# restores/replaces it while the human is testing; keep the exact original APK
# and hashes so the closing step can verify preservation and restore explicitly.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskAapt='C:\Users\ACER\AppData\Local\Android\sdk\build-tools\36.0.0\aapt.exe'
$taskTarget='7f0edea0';$taskPackage='com.example.kasir_app.integration'
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/poco-manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskArtifacts=Get-Content -LiteralPath $ArtifactsJson -Raw | ConvertFrom-Json
if($taskArtifacts.fixtureDatabase -ne 'm5_acceptance_1792150309449.db'){throw 'Unverified manual database selection; no install.'}
if(((& $taskAdb -s $taskTarget shell getprop ro.product.model)-join '').Trim() -ne '24069PC21G' -or $LASTEXITCODE -ne 0){throw 'Confirmed Poco unavailable.'}
function Get-DatabaseDigest([string]$Package){
 $taskRows=@()
 foreach($taskName in @('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')){
  & $taskAdb -s $taskTarget shell run-as $Package test -f "databases/$taskName"
  if($LASTEXITCODE -eq 1){$taskRows+="$taskName ABSENT";continue}
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect existing database; no preservation claim.'}
  $taskHash=((& $taskAdb -s $taskTarget shell run-as $Package sha256sum "databases/$taskName")-join '').Trim()
  if($LASTEXITCODE -ne 0 -or $taskHash -notmatch '^[a-f0-9]{64} '){throw 'Database digest unavailable.'}
  $taskRows+=$taskHash
 }
 return $taskRows -join "`n"
}
& $taskPython "$PSScriptRoot/verify_m5_apk.py" --apk $taskArtifacts.fixture --kind fixture --output "$taskEvidence/apk.json"
if($LASTEXITCODE -ne 0){throw 'APK gate failed; no install.'}
if(-not $taskArtifacts.restoreBridge){throw 'Closing debug audit bridge unavailable; no install.'}
& $taskPython "$PSScriptRoot/verify_m5_apk.py" --apk $taskArtifacts.restoreBridge --kind fixture --output "$taskEvidence/restore-bridge-apk.json"
if($LASTEXITCODE -ne 0){throw 'Debug audit bridge gate failed; no install.'}
foreach($taskApp in @('com.example.kasir_app',$taskPackage)){
 & $taskAdb -s $taskTarget shell am force-stop $taskApp
 if($LASTEXITCODE -ne 0){throw 'Cannot quiesce app.'}
}
$taskBefore=Get-DatabaseDigest 'com.example.kasir_app'
if($taskBefore -notmatch '^[a-f0-9]{64} '){throw 'Existing ordinary main DB baseline missing; no initialization.'}
$taskBefore | Set-Content "$taskEvidence/ordinary-before.txt" -Encoding UTF8
(Get-DatabaseDigest $taskPackage) | Set-Content "$taskEvidence/sandbox-default-before.txt" -Encoding UTF8
& $taskAdb -s $taskTarget shell run-as $taskPackage test -e "databases/$($taskArtifacts.fixtureDatabase)"
if($LASTEXITCODE -ne 1){throw 'Acceptance database already exists or cannot be checked. Do not reset/reseed.'}
$taskInstalled=((& $taskAdb -s $taskTarget shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskInstalled -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Original fixture unavailable.'}
$taskOriginal=Join-Path $taskEvidence 'original-fixture.apk'
& $taskAdb -s $taskTarget pull $Matches[1] $taskOriginal *> "$taskEvidence/original-copy.log"
if($LASTEXITCODE -ne 0){throw 'Cannot preserve original fixture APK.'}
if(-not ((& $taskAapt dump badging $taskOriginal)-match "^package: name='com.example.kasir_app.integration' ")){throw 'Original fixture identity mismatch.'}
(Get-FileHash -LiteralPath $taskOriginal -Algorithm SHA256).Hash | Set-Content "$taskEvidence/original-sha256.txt"
$taskInstalledNew=$false
try{
 & $taskAdb -s $taskTarget install -r $taskArtifacts.fixture *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'Isolated release installation failed; no uninstall fallback.'}
 $taskInstalledNew=$true
 & $taskAdb -s $taskTarget shell am start -W -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> "$taskEvidence/launch.log"
 if($LASTEXITCODE -ne 0){throw 'Release launcher failed.'}
 $taskAfter=Get-DatabaseDigest 'com.example.kasir_app'
 $taskAfter | Set-Content "$taskEvidence/ordinary-after-install.txt" -Encoding UTF8
 if($taskAfter -ne $taskBefore){throw 'Ordinary hashes changed; investigate, no preservation claim.'}
 [ordered]@{device=$taskTarget;package=$taskPackage;fixtureDatabase=$taskArtifacts.fixtureDatabase;fixtureApk=$taskArtifacts.fixture;restoreBridge=$taskArtifacts.restoreBridge;originalApk=$taskOriginal;ordinaryHashesUnchanged=$true;sandboxDefaultAfterRelease='UNVERIFIED until same-version debug bridge installed; run-as denied on release';manualResults='NOT TESTED';restoreOriginalPending=$true} | ConvertTo-Json | Set-Content "$taskEvidence/handover.json" -Encoding UTF8
 Write-Output "Prepared isolated release; verify own UI before human handover. Evidence: $taskEvidence"
}catch{
 if($taskInstalledNew){
  & $taskAdb -s $taskTarget install -r $taskArtifacts.restoreBridge *> "$taskEvidence/failure-debug-bridge.log"
  if($LASTEXITCODE -ne 0){Write-Warning 'Debug bridge restoration failed; no reset/uninstall.'}
  & $taskAdb -s $taskTarget install -r -d $taskOriginal *> "$taskEvidence/failure-original-restored.log"
  if($LASTEXITCODE -ne 0){Write-Warning 'Original APK restore failed; no uninstall fallback.'}
 }
 throw
}
