$ErrorActionPreference='Stop'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$taskEvidence='docs\evidence\m1-m4-fixes-20261014'
$taskWatch=[Diagnostics.Stopwatch]::StartNew()
while (-not ((Get-Content "$taskEvidence\emulator-independent-protected_reads_test.log" -Tail 3 -ErrorAction SilentlyContinue) -match '^RunnerExit=')) {
    if ($taskWatch.Elapsed.TotalMinutes -gt 20) { throw 'Emulator continuation not ended; refusing simultaneous APK builds.' }
    Start-Sleep -Seconds 10
}
try {
    & .\tools\test_android.ps1 -DeviceId '192.168.0.102:5555' -AndroidSdkRoot 'C:\Users\ACER\AppData\Local\Android\sdk' -TestTimeout 5m -TestFiles @('integration_test/localization_ui_test.dart') *> "$taskEvidence\dv-locale-ui-retest.log"
    'RunnerExit=0' | Add-Content "$taskEvidence\dv-locale-ui-retest.log"
} catch {
    ($_ | Out-String) | Add-Content "$taskEvidence\dv-locale-ui-retest.log"
    'RunnerExit=1' | Add-Content "$taskEvidence\dv-locale-ui-retest.log"
}
Write-Output 'DV localization retest ended; inspect actual result.'
