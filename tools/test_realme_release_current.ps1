param([Parameter(Mandatory=$true)][ValidatePattern('^[0-9]{10,20}$')][string]$Nonce)
# AOT validation of a fresh, namespaced fixture. Restore only the exact same
# version9 debug APK; never use -d, uninstall, reset or launch an old entrypoint.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskPython='C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$taskDevice='0062112V2210F9B3'; $taskPackage='com.example.kasir_app.integration'
$taskEvidence=Join-Path $taskRoot "build/realme-release-current-$Nonce"
if(Test-Path -LiteralPath $taskEvidence){throw 'Inspect previous release attempt; never overwrite'}
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
if(((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne 'RMX3231'){throw 'Confirmed Realme unavailable'}
function Get-ProtectedHashes {
 $taskMap=[ordered]@{}
 foreach($taskPkg in @('com.example.kasir_app','com.example.kasir_app.integration','com.example.kasir_app.skybee')){
  $taskPackages=@(& $taskAdb -s $taskDevice shell pm list packages $taskPkg)
  if($LASTEXITCODE -ne 0){throw 'Cannot inspect own package'}
  if("package:$taskPkg" -notin $taskPackages){$taskMap[$taskPkg]='ABSENT';continue}
  & $taskAdb -s $taskDevice shell am force-stop $taskPkg | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Cannot quiesce own package'}
  $taskRows=@(& $taskAdb -s $taskDevice shell run-as $taskPkg find databases no_backup -type f -exec sha256sum '{}' '\;')
  if($LASTEXITCODE -ne 0){throw 'Cannot audit closed data'}
  foreach($taskRow in $taskRows){
   if($taskRow -notmatch '^([a-f0-9]{64})\s+(.+)$'){throw 'Invalid hash metadata'}
   $taskDigest=$Matches[1];$taskFile=$Matches[2]
   if($taskFile -match '^(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?$' -or $taskFile -match '^no_backup/(?:database|backup-work|printer-output)\.gate$'){continue}
   $taskMap["$taskPkg/$taskFile"]=$taskDigest
  }
 }
 return $taskMap
}
$taskBefore=Get-ProtectedHashes
$taskBefore | ConvertTo-Json | Set-Content "$taskEvidence/before.json" -Encoding UTF8
$taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
if($LASTEXITCODE -ne 0 -or $taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Prior fixture missing'}
& $taskAdb -s $taskDevice pull $Matches[1] "$taskEvidence/prior-debug.apk" *> "$taskEvidence/prior-copy.log"
if($LASTEXITCODE -ne 0){throw 'Cannot retain exact same-version bridge'}
$taskPriorIdentity=(& "$taskSdk/build-tools/36.0.0/aapt.exe" dump badging "$taskEvidence/prior-debug.apk") -join "`n"
if($LASTEXITCODE -ne 0 -or $taskPriorIdentity -notmatch "package: name='com.example.kasir_app.integration' versionCode='9' versionName='0.5.2'" -or $taskPriorIdentity -notmatch 'application-debuggable'){throw 'Version9 debug bridge required; no downgrade allowed'}
$taskPriorHash=(Get-FileHash -LiteralPath "$taskEvidence/prior-debug.apk" -Algorithm SHA256).Hash
$taskResult=[ordered]@{device=$taskDevice;nonce=$Nonce;tests='RUNNING';version='0.5.2+9';isolation='NOT CHECKED';automaticDeviceControlActive=$true;downgrade=$false;reset=$false;uninstall=$false}
$taskInstalled=$false
try {
 & "$PSScriptRoot/test_android.ps1" -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -PrepareOnly -BuildMode release -TargetPlatform android-arm -TestFiles @('integration_test/realme_m52_release_probe.dart') -AdditionalDartDefines @("REALME_RELEASE_NONCE=$Nonce") *> "$taskEvidence/build.log"
 if($LASTEXITCODE -ne 0){throw 'Release fixture build failed; no install'}
 Copy-Item -LiteralPath "$taskRoot/build/app/outputs/flutter-apk/app-release.apk" -Destination "$taskEvidence/realme-m52-release.apk"
 & $taskPython "$PSScriptRoot/verify_m5_apk.py" --apk "$taskEvidence/realme-m52-release.apk" --kind fixture --abis armeabi-v7a --expected-version-name 0.5.2 --expected-version-code 9 --output "$taskEvidence/release-apk.json" *> "$taskEvidence/verification.log"
 if($LASTEXITCODE -ne 0){throw 'Release fixture verification failed; no install'}
 $taskSignature=(& "$taskSdk/build-tools/36.0.0/apksigner.bat" verify --print-certs "$taskEvidence/prior-debug.apk") -join "`n"
 $taskGate=Get-Content "$taskEvidence/release-apk.json" -Raw | ConvertFrom-Json
 if($LASTEXITCODE -ne 0 -or $taskSignature -notmatch [regex]::Escape($taskGate.signing_certificate_sha256)){throw 'Same signing certificate required'}
 & $taskAdb -s $taskDevice install -r "$taskEvidence/realme-m52-release.apk" *> "$taskEvidence/install.log"
 if($LASTEXITCODE -ne 0){throw 'In-place release install failed; no fallback'}
 $taskInstalled=$true
 & $taskAdb -s $taskDevice shell am start -W -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> "$taskEvidence/start.log"
 if($LASTEXITCODE -ne 0){throw 'Release fixture launch failed'}
 $taskDeadline=(Get-Date).AddMinutes(3);$taskProof=$null
 do {
  $taskPid=((& $taskAdb -s $taskDevice shell pidof $taskPackage)-join '').Trim()
  if($taskPid -match '^[0-9]+$'){
   $taskLines=@(& $taskAdb -s $taskDevice logcat -d "--pid=$taskPid" -v brief)
   if($LASTEXITCODE -ne 0){throw 'Own PID log unavailable'}
   $taskLines | Set-Content "$taskEvidence/private-release-log.txt" -Encoding UTF8
   $taskMarkers=@($taskLines | Where-Object {$_ -match 'REALME_M52_RELEASE '})
   if($taskMarkers.Count){
    $taskText=$taskMarkers[-1] -replace '^.*REALME_M52_RELEASE ',''
    $taskProof=$taskText | ConvertFrom-Json
    break
   }
  }
  Start-Sleep -Seconds 2
 }while((Get-Date) -lt $taskDeadline)
 if(-not $taskProof -or $taskProof.nonce -ne $Nonce -or $taskProof.status -ne 'PASS' -or -not $taskProof.release -or $taskProof.schema -ne 14){throw 'AOT facts not verified; inspect private marker'}
 $taskProof | ConvertTo-Json -Depth 8 | Set-Content "$taskEvidence/probe.json" -Encoding UTF8
 $taskResult.tests='PASS'
} catch {
 $taskResult.tests='FAILED_OR_BLOCKED';throw
} finally {
 try {
  if($taskInstalled){
   & $taskAdb -s $taskDevice shell am force-stop $taskPackage | Out-Null
   & $taskAdb -s $taskDevice install -r "$taskEvidence/prior-debug.apk" *> "$taskEvidence/debug-version9-restored.log"
   if($LASTEXITCODE -ne 0){throw 'Same-version debug restoration failed; no downgrade/reset fallback'}
   $taskRestored=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
   if($LASTEXITCODE -ne 0 -or $taskRestored -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Restored fixture unavailable'}
   & $taskAdb -s $taskDevice pull $Matches[1] "$taskEvidence/restored-debug.apk" *> "$taskEvidence/restored-copy.log"
   if($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath "$taskEvidence/restored-debug.apk" -Algorithm SHA256).Hash -ne $taskPriorHash){throw 'Restored APK hash differs'}
   $taskResult.exactSameVersionDebugApkRestored=$true
  }
  $taskAfter=Get-ProtectedHashes
  $taskAfter | ConvertTo-Json | Set-Content "$taskEvidence/after.json" -Encoding UTF8
  foreach($taskKey in $taskBefore.Keys){if($taskAfter[$taskKey] -ne $taskBefore[$taskKey]){throw "Retained file mismatch: $taskKey"}}
  $taskResult.isolation='Every pre-existing protected file hash unchanged'
 } catch {
  $taskResult.tests='FAILED_OR_BLOCKED';throw
 } finally {
  $taskResult.automaticDeviceControlActive=$false
  $taskResult | ConvertTo-Json -Depth 8 | Set-Content "$taskEvidence/result.json" -Encoding UTF8
  Write-Output "Realme AOT evidence: $taskEvidence"
 }
}
