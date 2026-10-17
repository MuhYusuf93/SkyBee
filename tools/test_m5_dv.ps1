param(
    [string[]]$TestFiles = @('integration_test/m5_encryption_test.dart'),
    [string]$RunName = 'native',
    [string]$NameFilter = '',
    [string[]]$AdditionalDartDefines = @()
)
$ErrorActionPreference='Stop'
if ($RunName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid evidence name.' }
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskStamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$taskEvidence=Join-Path $taskRoot "docs/evidence/m5-20261016/$RunName-$taskStamp"
New-Item -ItemType Directory -Force -Path $taskEvidence | Out-Null
$taskSnapshot=Join-Path $taskEvidence 'awake-original.json'
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskAdb=Join-Path $taskSdk 'platform-tools/adb.exe'
$taskTarget='192.168.0.102:5555'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$taskPackages=@(& $taskAdb -s $taskTarget shell pm list packages com.example.kasir_app)
if($LASTEXITCODE -ne 0){throw 'Cannot inspect packages; no absence or preservation claim.'}
$taskPackage=($taskPackages|Where-Object {$_ -eq 'package:com.example.kasir_app'}) -join ''
if($taskPackage.Trim()) { throw 'Operational package is present: establish an explicit quiescent hash baseline before this wrapper can run.' }
'Operational package absent before run; no existing database preservation claim.' | Set-Content (Join-Path $taskEvidence 'isolation.txt') -Encoding UTF8
try {
    & "$PSScriptRoot/dv8910_awake.ps1" -Action Enable -SnapshotPath $taskSnapshot
    & "$PSScriptRoot/test_android.ps1" -DeviceId $taskTarget -AndroidSdkRoot $taskSdk -TestFiles $TestFiles -NameFilter $NameFilter -AdditionalDartDefines $AdditionalDartDefines -TestTimeout 5m *> (Join-Path $taskEvidence 'runner.log')
    if($LASTEXITCODE -ne 0) {throw 'Native runner returned failure.'}
} finally {
    # Even a terminating runner exception must restore the exact initial values.
    & "$PSScriptRoot/dv8910_awake.ps1" -Action Restore -SnapshotPath $taskSnapshot *> (Join-Path $taskEvidence 'awake-restored.log')
    $taskAfterPackages=@(& $taskAdb -s $taskTarget shell pm list packages com.example.kasir_app)
    $taskAfterExit=$LASTEXITCODE
    $taskAfter=($taskAfterPackages|Where-Object {$_ -eq 'package:com.example.kasir_app'}) -join ''
    "Operational package after run: $(if($taskAfterExit -ne 0){'UNKNOWN - package query failed'}elseif($taskAfter.Trim()){'PRESENT - investigate'}else{'absent'})" | Add-Content (Join-Path $taskEvidence 'isolation.txt') -Encoding UTF8
    Write-Output "Evidence: $taskEvidence"
}
