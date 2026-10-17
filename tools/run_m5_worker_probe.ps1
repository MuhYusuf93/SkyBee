param([string]$DeviceId='192.168.0.102:5555',[string]$AndroidSdkRoot='C:\Users\ACER\AppData\Local\Android\sdk')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/worker-$taskNonce"
New-Item -ItemType Directory -Path $taskEvidence | Out-Null
$taskAdb=Join-Path $AndroidSdkRoot 'platform-tools/adb.exe'
$taskPackage='com.example.kasir_app.integration'
$taskOrdinary=((& $taskAdb -s $DeviceId shell pm list packages com.example.kasir_app)-join "`n").Trim()
if($LASTEXITCODE -eq 0){$taskOrdinary=(@($taskOrdinary -split "`n" | Where-Object {$_ -eq 'package:com.example.kasir_app'})-join '').Trim()}
if($LASTEXITCODE -ne 0 -or $taskOrdinary){throw 'This probe requires verified operational-package absence; no user data will be touched.'}
$taskSnapshot=Join-Path $taskEvidence 'awake-original.json'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
function Read-Marker([string]$Suffix){
    $taskLines=& $taskAdb -s $DeviceId shell run-as $taskPackage cat "databases/m5_worker_$taskNonce.$Suffix.json" 2>$null
    if($LASTEXITCODE -ne 0){return $null}
    return (($taskLines -join "`n") | ConvertFrom-Json)
}
try{
    if($DeviceId -eq '192.168.0.102:5555'){& "$PSScriptRoot/dv8910_awake.ps1" -Action Enable -SnapshotPath $taskSnapshot}
    & "$PSScriptRoot/test_android.ps1" -DeviceId $DeviceId -AndroidSdkRoot $AndroidSdkRoot -PrepareOnly -TargetPlatform android-arm -AdditionalDartDefines @("M5_WORKER_NONCE=$taskNonce") -TestFiles @('integration_test/m5_worker_probe_app.dart') *> (Join-Path $taskEvidence 'build.log')
    $taskApk=Join-Path $taskRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    & 'C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' "$PSScriptRoot/verify_m5_apk.py" --apk $taskApk --kind fixture --abis armeabi-v7a --output (Join-Path $taskEvidence 'apk.json')
    if($LASTEXITCODE -ne 0){throw 'Native APK verification failed; no install.'}
    & $taskAdb -s $DeviceId install -r $taskApk *> (Join-Path $taskEvidence 'install.log')
    if($LASTEXITCODE -ne 0){throw 'Isolated installation failed; no uninstall fallback.'}
    & $taskAdb -s $DeviceId shell am start -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> (Join-Path $taskEvidence 'launch.log')
    if($LASTEXITCODE -ne 0){throw 'Fixture launch failed.'}
    $taskSetup=$null;$taskDeadline=(Get-Date).AddMinutes(2)
    do{$taskSetup=Read-Marker 'setup';if($taskSetup){break};Start-Sleep -Seconds 2}while((Get-Date)-lt $taskDeadline)
    if(-not $taskSetup){throw 'Setup marker unavailable within bound.'}
    $taskSetup | ConvertTo-Json | Set-Content (Join-Path $taskEvidence 'setup.json') -Encoding UTF8
    $taskDeadline=(Get-Date).AddSeconds(15);$taskExited=$false
    do{
        $taskAlive=(& $taskAdb -s $DeviceId shell pidof $taskPackage)-join ' '
        if(($taskAlive -split ' ') -notcontains "$($taskSetup.setupPid)"){$taskExited=$true;break}
        Start-Sleep -Seconds 1
    }while((Get-Date)-lt $taskDeadline)
    if(-not $taskExited){throw 'Original process did not exit; cannot claim a headless restart.'}
    $taskResult=$null;$taskDeadline=(Get-Date).AddMinutes(3)
    do{
        $taskResult=Read-Marker 'result';if($taskResult){break}
        $taskFailure=Read-Marker 'failure';if($taskFailure){$taskFailure|ConvertTo-Json|Set-Content (Join-Path $taskEvidence 'worker-failure.json');throw 'Worker failed; inspect sanitized marker.'}
        Start-Sleep -Seconds 3
    }while((Get-Date)-lt $taskDeadline)
    if(-not $taskResult){throw 'Worker result unavailable within bound; no success claim.'}
    $taskResult|ConvertTo-Json|Set-Content (Join-Path $taskEvidence 'result.json') -Encoding UTF8
    Start-Sleep -Seconds 2
    & "$PSScriptRoot/test_android.ps1" -DeviceId $DeviceId -AndroidSdkRoot $AndroidSdkRoot -AdditionalDartDefines @("M5_WORKER_NONCE=$taskNonce") -TestFiles @('integration_test/m5_worker_result_test.dart') -TestTimeout 5m *> (Join-Path $taskEvidence 'reader.log')
    if($LASTEXITCODE -ne 0){throw 'Worker reader test failed.'}
}finally{
    if($DeviceId -eq '192.168.0.102:5555' -and (Test-Path -LiteralPath $taskSnapshot)){& "$PSScriptRoot/dv8910_awake.ps1" -Action Restore -SnapshotPath $taskSnapshot *> (Join-Path $taskEvidence 'awake-restored.log')}
    $taskAfter=((& $taskAdb -s $DeviceId shell pm path com.example.kasir_app)-join '').Trim()
    @{ordinaryBefore=$taskOrdinary;ordinaryAfter=$taskAfter;nonce=$taskNonce}|ConvertTo-Json|Set-Content (Join-Path $taskEvidence 'isolation.json') -Encoding UTF8
    Write-Output "Evidence: $taskEvidence"
}
