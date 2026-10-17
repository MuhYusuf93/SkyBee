param([Parameter(Mandatory=$true)][string]$ApkPath)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/dv-release-smoke-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskSnapshot=Join-Path $taskEvidence 'awake-original.json'
$taskAdb='C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskTarget='192.168.0.102:5555';$taskPackage='com.example.kasir_app.integration'
& $taskPython "$PSScriptRoot/verify_m5_apk.py" --apk $ApkPath --kind fixture --output "$taskEvidence/apk.json"
if($LASTEXITCODE -ne 0){throw 'APK gate failed before install.'}
function Get-DefaultFixtureDigest {
 $taskRows=@()
 foreach($taskFile in @('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')){
  & $taskAdb -s $taskTarget shell run-as $taskPackage test -f "databases/$taskFile"
  if($LASTEXITCODE -eq 1){$taskRows+="$taskFile ABSENT";continue}
  if($LASTEXITCODE -ne 0){throw 'Default fixture hash unavailable; no preservation claim.'}
  $taskDigest=((& $taskAdb -s $taskTarget shell run-as $taskPackage sha256sum "databases/$taskFile")-join '').Trim()
  if($LASTEXITCODE -ne 0 -or $taskDigest -notmatch '^[a-f0-9]{64} '){throw 'Invalid fixture digest.'}
  $taskRows+=$taskDigest
 }
 return $taskRows -join "`n"
}
& $taskAdb -s $taskTarget shell am force-stop $taskPackage
if($LASTEXITCODE -ne 0){throw 'Cannot quiesce fixture.'}
$taskBefore=Get-DefaultFixtureDigest
$taskBefore | Set-Content "$taskEvidence/default-before.txt" -Encoding UTF8
$taskOriginalPath=((& $taskAdb -s $taskTarget shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskOriginalPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Original fixture APK unavailable.'}
$taskOriginal=Join-Path $taskEvidence 'original-fixture.apk'
& $taskAdb -s $taskTarget pull $Matches[1] $taskOriginal *> "$taskEvidence/original-copy.log"
if($LASTEXITCODE -ne 0){throw 'Original fixture preservation failed.'}
& $taskPython "$PSScriptRoot/verify_m5_apk.py" --apk $taskOriginal --kind fixture --abis armeabi-v7a --output "$taskEvidence/original-apk.json"
if($LASTEXITCODE -ne 0){throw 'Original fixture identity/ABI gate failed.'}
try{
 & "$PSScriptRoot/dv8910_awake.ps1" -Action Enable -SnapshotPath $taskSnapshot
 & $taskAdb -s $taskTarget install -r $ApkPath *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'Fixture release install failed, no uninstall.'}
 & $taskPython "$PSScriptRoot/dv8910_device_probe.py" --action restart *> "$taskEvidence/launch.log"
 if($LASTEXITCODE -ne 0){throw 'Fixture launcher failed.'}
 $taskDeadline=[DateTime]::UtcNow.AddSeconds(90);$taskVisible=$false;$taskProbe=0
 do{
  $taskProbe++
  & $taskPython "$PSScriptRoot/dv8910_device_probe.py" --action inspect --output "$taskEvidence/ui-$taskProbe.json" *> "$taskEvidence/ui-probe-$taskProbe.log"
  if($LASTEXITCODE -eq 0 -and (Select-String -LiteralPath "$taskEvidence/ui-$taskProbe.json" -SimpleMatch 'UJI COBA M5')){$taskVisible=$true;break}
  Start-Sleep -Seconds 3
 }while([DateTime]::UtcNow -lt $taskDeadline)
 if(-not $taskVisible){throw 'Synthetic M5 fixture screen not confirmed within 90s; keep logs, no cause assumed.'}
 & $taskPython "$PSScriptRoot/dv8910_device_probe.py" --action log --output "$taskEvidence/own-pid.log" *> "$taskEvidence/log-probe.log"
 if($LASTEXITCODE -ne 0){throw 'Own release PID log unavailable.'}
 'PASS startup/own fixture UI on ARM32 release; not full release acceptance, OAuth, Bluetooth or paper.' | Set-Content "$taskEvidence/result.txt" -Encoding UTF8
}finally{
 try{
  & $taskPython "$PSScriptRoot/dv8910_device_probe.py" --action log --output "$taskEvidence/final-own-pid.log" *> "$taskEvidence/final-log-probe.log"
  & $taskAdb -s $taskTarget shell am force-stop $taskPackage
  & $taskAdb -s $taskTarget install -r -d $taskOriginal *> "$taskEvidence/original-restored.log"
  if($LASTEXITCODE -ne 0){throw 'Original fixture restore failed; no uninstall fallback.'}
  $taskAfter=Get-DefaultFixtureDigest
  $taskAfter | Set-Content "$taskEvidence/default-after.txt" -Encoding UTF8
  if($taskBefore -ne $taskAfter){throw 'Default fixture hashes changed; investigate.'}
  'Existing default DB+sidecar hashes unchanged; original fixture APK restored.' | Set-Content "$taskEvidence/isolation.txt"
 }finally{
  & "$PSScriptRoot/dv8910_awake.ps1" -Action Restore -SnapshotPath $taskSnapshot *> "$taskEvidence/awake-restored.log"
  Write-Output "Evidence: $taskEvidence"
 }
}
