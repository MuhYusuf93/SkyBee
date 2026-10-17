param([ValidateSet('profile','release')][string]$BuildMode='profile')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskNonce=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds().ToString()
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/performance-$BuildMode-$taskNonce"
New-Item -ItemType Directory -Path $taskEvidence|Out-Null
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk';$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskTarget='192.168.0.102:5555';$taskPackage='com.example.kasir_app.integration'
$taskSnapshot=Join-Path $taskEvidence 'awake-original.json'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$taskOrdinary=@(& $taskAdb -s $taskTarget shell pm list packages com.example.kasir_app|Where-Object {$_ -eq 'package:com.example.kasir_app'})
if($LASTEXITCODE -ne 0 -or $taskOrdinary.Count){throw 'Operational package presence requires a separate baseline; no test attempted.'}
try{
  & "$PSScriptRoot/dv8910_awake.ps1" -Action Enable -SnapshotPath $taskSnapshot
  & "$PSScriptRoot/test_android.ps1" -DeviceId $taskTarget -AndroidSdkRoot $taskSdk -PrepareOnly -BuildMode $BuildMode -TargetPlatform android-arm -TestFiles @('integration_test/m5_performance_probe_app.dart') -AdditionalDartDefines @("M5_PERF_NONCE=$taskNonce") *> (Join-Path $taskEvidence 'build.log')
  $taskApk=Join-Path $taskRoot "build/app/outputs/flutter-apk/app-$BuildMode.apk"
  & 'C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' "$PSScriptRoot/verify_m5_apk.py" --apk $taskApk --kind fixture --abis armeabi-v7a --output (Join-Path $taskEvidence 'apk.json')
  if($LASTEXITCODE -ne 0){throw 'APK verification failed; no install.'}
  & $taskAdb -s $taskTarget install -r $taskApk *> (Join-Path $taskEvidence 'install.log')
  if($LASTEXITCODE -ne 0){throw 'Isolated install failed; no uninstall fallback.'}
  & $taskAdb -s $taskTarget shell am start -n "$taskPackage/com.example.kasir_app.IntegrationActivity" *> (Join-Path $taskEvidence 'launch.log')
  if($LASTEXITCODE -ne 0){throw 'Fixture launch failed.'}
  $taskDeadline=(Get-Date).AddMinutes(10);$taskResult=$null;$taskOwnPid=''
  do{
    $taskOwnPid=((& $taskAdb -s $taskTarget shell pidof $taskPackage)-join '').Trim()
    # Profile is debuggable on this toolchain. Prefer the flushed private file:
    # logcat can split a long JSON print into chunks at Android's message limit.
    $taskFileJson=((& $taskAdb -s $taskTarget shell run-as $taskPackage cat "databases/m5_perf_$taskNonce.result.json" 2>$null)-join '')
    if($LASTEXITCODE -eq 0 -and $taskFileJson){
      $taskResult=$taskFileJson|ConvertFrom-Json
      if($taskResult.nonce -ne $taskNonce -or $taskResult.mode -ne $BuildMode){throw 'Stale/different private performance result.'}
      $taskFileJson|Set-Content (Join-Path $taskEvidence 'result.json') -Encoding UTF8
      break
    }
    if($taskOwnPid -match '^\d+$'){
      $taskLines=@(& $taskAdb -s $taskTarget shell logcat -d --pid=$taskOwnPid -t 1000)
      $taskFailure=@($taskLines|Select-String 'M5_PERFORMANCE_FAILURE ')
      if($taskFailure.Count){$taskFailure|Set-Content (Join-Path $taskEvidence 'failure.log');throw 'Performance fixture failed; sanitized type recorded.'}
      $taskMatch=@($taskLines|Select-String 'M5_PERFORMANCE (\{.*\})'|Select-Object -Last 1)
      if($taskMatch.Count){
        $taskJson=$taskMatch[0].Matches[0].Groups[1].Value
        try{$taskResult=$taskJson|ConvertFrom-Json}catch{$taskResult=$null;continue}
        if($taskResult.nonce -ne $taskNonce -or $taskResult.mode -ne $BuildMode){throw 'Stale/different performance fixture result.'}
        $taskJson|Set-Content (Join-Path $taskEvidence 'result.json') -Encoding UTF8
        break
      }
    }
    Start-Sleep -Seconds 3
  }while((Get-Date)-lt $taskDeadline)
  if(-not $taskResult){throw 'No measured performance result within bound; not PASS.'}
}finally{
  if(Test-Path -LiteralPath $taskSnapshot){& "$PSScriptRoot/dv8910_awake.ps1" -Action Restore -SnapshotPath $taskSnapshot *> (Join-Path $taskEvidence 'awake-restored.log')}
  Write-Output "Evidence: $taskEvidence"
}
