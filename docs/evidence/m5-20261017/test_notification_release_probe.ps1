param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$RunName,
 [ValidateSet('7f0edea0','192.168.0.102:5555')][string]$DeviceId='7f0edea0')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk';$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskDevice=$DeviceId;$taskPackage='com.example.kasir_app.integration'
$taskDv=$taskDevice -eq '192.168.0.102:5555'
$taskPrefix=if($taskDv){'dv'}else{'poco'}
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/$taskPrefix-$RunName-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskModel=if($taskDv){'AX810'}else{'24069PC21G'}
if(((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne $taskModel){throw 'Confirmed device unavailable.'}
function Get-Ordinary {
 if($taskDv){
  $taskPackages=@(& $taskAdb -s $taskDevice shell pm list packages com.example.kasir_app)
  if($LASTEXITCODE -ne 0 -or 'package:com.example.kasir_app' -in $taskPackages){throw 'DV operational package presence changed/unavailable.'}
  return 'Operational package absent; no existing DB preservation claim.'
 }
 $taskRows=@()
 foreach($taskName in @('kasir_app.db','kasir_app.db-wal','kasir_app.db-shm','kasir_app.db-journal')){
  & $taskAdb -s $taskDevice shell run-as com.example.kasir_app test -f "databases/$taskName"
  if($LASTEXITCODE -eq 1){$taskRows+="$taskName ABSENT";continue}
  if($LASTEXITCODE -ne 0){throw 'Ordinary sandbox unavailable.'}
  $taskRows+=((& $taskAdb -s $taskDevice shell run-as com.example.kasir_app sha256sum "databases/$taskName")-join '').Trim()
  if($LASTEXITCODE -ne 0){throw 'Ordinary digest failed.'}
 }
 if($taskRows[0] -notmatch '^[a-f0-9]{64} '){throw 'Missing ordinary DB; never initialize.'}
 return $taskRows -join "`n"
}
& $taskAdb -s $taskDevice shell am force-stop com.example.kasir_app
if($LASTEXITCODE -ne 0){throw 'Cannot quiesce own ordinary app.'}
$taskBefore=Get-Ordinary
$taskBefore | Set-Content "$taskEvidence/ordinary-before.txt" -Encoding UTF8
$taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Prior fixture APK missing.'}
& $taskAdb -s $taskDevice pull $Matches[1] "$taskEvidence/prior.apk" *> "$taskEvidence/prior-copy.log"
if($LASTEXITCODE -ne 0){throw 'Prior copy failed.'}
$taskExpected=(Get-FileHash "$taskEvidence/prior.apk" -Algorithm SHA256).Hash
& "$taskSdk/build-tools/36.0.0/aapt.exe" dump badging "$taskEvidence/prior.apk" | Set-Content "$taskEvidence/prior-identity.txt"
if(-not (Select-String -LiteralPath "$taskEvidence/prior-identity.txt" -Pattern "^package: name='com.example.kasir_app.integration' ")){throw 'Prior fixture identity mismatch.'}
$taskInstalled=$false
try {
 if($taskDv){& tools/dv8910_awake.ps1 -Action Enable -SnapshotPath "$taskEvidence/awake-original.json"}
 & tools/test_android.ps1 -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -PrepareOnly -BuildMode release -TestFiles @('integration_test/m5_notification_release_probe.dart') *> "$taskEvidence/build.log"
 if($LASTEXITCODE -ne 0){throw 'Release probe build failed.'}
 Copy-Item build/app/outputs/flutter-apk/app-release.apk "$taskEvidence/probe.apk"
 & "$taskSdk/build-tools/36.0.0/aapt.exe" dump resources "$taskEvidence/probe.apk" | Select-String 'ic_stock_notification' | Set-Content "$taskEvidence/icon-resource.txt"
 & $taskAdb -s $taskDevice install -r "$taskEvidence/probe.apk" *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'Install failed; no uninstall fallback.'}
 $taskInstalled=$true
 & $taskAdb -s $taskDevice shell am start -S -W -f 0x10008000 -n com.example.kasir_app.integration/com.example.kasir_app.IntegrationActivity *> "$taskEvidence/start.log"
 if($LASTEXITCODE -ne 0){throw 'Probe start failed.'}
 $taskDeadline=(Get-Date).AddSeconds(40);$taskFound=$false
 do {
  $taskPid=((& $taskAdb -s $taskDevice shell pidof $taskPackage)-join '').Trim()
  if($taskPid -match '^[0-9]+$'){
   $taskLines=@(& $taskAdb -s $taskDevice logcat -d "--pid=$taskPid" -v brief)
   $taskMarker=@($taskLines | Where-Object {$_ -match 'M5_NOTIFICATION_RELEASE_PROBE '})
   if($taskMarker.Count){$taskMarker[-1] | Set-Content "$taskEvidence/result-marker.txt" -Encoding UTF8;$taskFound=$true;break}
  }
  Start-Sleep -Seconds 1
 }while((Get-Date) -lt $taskDeadline)
 if(-not $taskFound){throw 'No probe result; no success claim.'}
}finally{
 try {
  $taskAfter=Get-Ordinary
  $taskAfter | Set-Content "$taskEvidence/ordinary-after.txt" -Encoding UTF8
  if($taskAfter -ne $taskBefore){throw 'Ordinary digest mismatch.'}
  $(if($taskDv){$taskBefore}else{'Ordinary DB and sidecar byte hashes unchanged.'}) | Set-Content "$taskEvidence/isolation.txt"
 }finally{
  try {
   if($taskInstalled){
    & $taskAdb -s $taskDevice install -r -d "$taskEvidence/prior.apk" *> "$taskEvidence/prior-restored.log"
    if($LASTEXITCODE -ne 0){throw 'Prior APK restore failed.'}
    $taskRestored=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
    if($LASTEXITCODE -ne 0 -or $taskRestored -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Restored APK unavailable.'}
    & $taskAdb -s $taskDevice pull $Matches[1] "$taskEvidence/restored.apk" *> "$taskEvidence/restored-copy.log"
    if($LASTEXITCODE -ne 0 -or (Get-FileHash "$taskEvidence/restored.apk" -Algorithm SHA256).Hash -ne $taskExpected){throw 'Restored APK hash differs.'}
   }
  }finally{
   if($taskDv -and (Test-Path "$taskEvidence/awake-original.json")){& tools/dv8910_awake.ps1 -Action Restore -SnapshotPath "$taskEvidence/awake-original.json" *> "$taskEvidence/awake-restored.log"}
  }
 }
}
Write-Output "Release notification probe: $taskEvidence"
