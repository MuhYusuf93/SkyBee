# One-time in-place upgrade of the confirmed legacy release TEST package only.
# No launch/SQL/reset/uninstall/downgrade; a newer debuggable fixture enables
# closed-file baselines before subsequent integration tests. The old release
# cannot be fingerprinted with run-as: never claim a pre-update DB comparison.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskDevice='0062112V2210F9B3';$taskPackage='com.example.kasir_app.integration'
$taskEvidence=Join-Path $taskRoot "build/m51-realme-audit-bootstrap-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
if(((& $taskAdb -s $taskDevice get-state)-join '').Trim() -ne 'device'){throw 'Confirmed Realme unavailable'}
if(((& $taskAdb -s $taskDevice shell getprop ro.product.model)-join '').Trim() -ne 'RMX3231'){throw 'Device mismatch'}
$taskPackages=@(& $taskAdb -s $taskDevice shell pm list packages com.example.kasir_app)
if($LASTEXITCODE -ne 0 -or 'package:com.example.kasir_app' -in $taskPackages){throw 'Unexpected ordinary package; separate protection required'}
$taskAccess=@(& $taskAdb -s $taskDevice shell run-as $taskPackage pwd 2>&1)
if($LASTEXITCODE -eq 0){throw 'Fixture already auditable; use normal safe runner'}
if(($taskAccess -join '') -notlike '*package not debuggable*'){throw 'Unexpected sandbox access failure; no replacement'}
& $taskAdb -s $taskDevice shell am force-stop $taskPackage | Out-Null
if($LASTEXITCODE -ne 0){throw 'Cannot quiesce fixture'}
$taskPath=((& $taskAdb -s $taskDevice shell pm path $taskPackage)-join '').Trim()
if($taskPath -notmatch '^package:(/data/app/[^\r\n]+/base.apk)$'){throw 'Unexpected APK path'}
$taskOriginal=Join-Path $taskEvidence 'original-release-fixture.apk'
& $taskAdb -s $taskDevice pull $Matches[1] $taskOriginal *> "$taskEvidence/original-copy.log"
if($LASTEXITCODE -ne 0){throw 'Cannot preserve original test APK'}
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$taskAapt=Join-Path $taskSdk 'build-tools/36.0.0/aapt.exe'
$taskSigner=Join-Path $taskSdk 'build-tools/36.0.0/apksigner.bat'
function Read-Identity([string]$Path){
 $taskLines=@(& $taskAapt dump badging $Path)
 if($LASTEXITCODE -ne 0){throw 'Cannot inspect APK'}
 $taskIdentity=$taskLines | Where-Object {$_ -match "^package: name='com.example.kasir_app.integration' versionCode='([0-9]+)'"}
 if(@($taskIdentity).Count -ne 1 -or $taskIdentity -notmatch "versionCode='([0-9]+)'"){throw 'APK is not isolated test package'}
 $taskVersion=[int]$Matches[1]
 $taskCert=@(& $taskSigner verify --print-certs $Path)
 if($LASTEXITCODE -ne 0){throw 'APK signature verification failed'}
 $taskDigest=@($taskCert | Where-Object {$_ -match '^Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]{64})$'})
 if($taskDigest.Count -ne 1 -or $taskDigest[0] -notmatch 'digest: ([a-fA-F0-9]{64})$'){throw 'Unsupported signing identity'}
 return @{version=$taskVersion;cert=$Matches[1].ToLowerInvariant();debuggable=('application-debuggable' -in $taskLines)}
}
$taskOld=Read-Identity $taskOriginal
if($taskOld.version -ne 6 -or $taskOld.debuggable){throw 'Unexpected legacy baseline; no update'}
& "$PSScriptRoot/test_android.ps1" -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -TestFiles @('integration_test/m51_usb_test.dart') -PrepareOnly *> "$taskEvidence/prepare.log"
if($LASTEXITCODE -ne 0){throw 'Safe isolated preparation failed'}
$taskNewApk=Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-debug.apk'
$taskNew=Read-Identity $taskNewApk
if($taskNew.cert -ne $taskOld.cert -or $taskNew.version -lt $taskOld.version -or -not $taskNew.debuggable){throw 'Incompatible update; no uninstall/downgrade fallback'}
& $taskAdb -s $taskDevice install -r $taskNewApk *> "$taskEvidence/install.log"
if($LASTEXITCODE -ne 0){throw 'In-place fixture update failed; no fallback'}
& $taskAdb -s $taskDevice shell am force-stop $taskPackage | Out-Null
if($LASTEXITCODE -ne 0){throw 'Cannot quiesce updated fixture'}
$taskHashes=@(& $taskAdb -s $taskDevice shell run-as $taskPackage find databases no_backup -type f -exec sha256sum '{}' '\;')
if($LASTEXITCODE -ne 0){throw 'Updated fixture cannot be audited'}
$taskHashes | Set-Content "$taskEvidence/post-update-before-tests.txt" -Encoding UTF8
@{device=$taskDevice;package=$taskPackage;oldVersion=$taskOld.version;newVersion=$taskNew.version;certificate=$taskNew.cert;oldApkSha256=(Get-FileHash -LiteralPath $taskOriginal -Algorithm SHA256).Hash.ToLowerInvariant();newApkSha256=(Get-FileHash -LiteralPath $taskNewApk -Algorithm SHA256).Hash.ToLowerInvariant();launch=$false;reset=$false;downgrade=$false;limit='Old release run-as unavailable. No pre-update DB byte comparison. Closed post-update baseline captured before any integration run.'} | ConvertTo-Json | Set-Content "$taskEvidence/result.json" -Encoding UTF8
Write-Output "Realme fixture audit bootstrap evidence: $taskEvidence"
