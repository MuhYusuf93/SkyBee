$ErrorActionPreference='Stop'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$taskEvidence='docs\evidence\m1-m4-fixes-20261014'
$taskWatch=[Diagnostics.Stopwatch]::StartNew()
while (-not ((Get-Content "$taskEvidence\emulator-bootstrap-cashier_ui_test.log" -Tail 3 -ErrorAction SilentlyContinue) -match '^RunnerExit=')) {
    if ($taskWatch.Elapsed.TotalMinutes -gt 20) { throw 'Previous native retest not ended; no concurrent build.' }
    Start-Sleep -Seconds 10
}
try {
    & .\tools\test_android.ps1 -DeviceId 'emulator-5554' -AndroidSdkRoot 'C:\Users\ACER\AppData\Local\Android\sdk' -TestTimeout 5m -TestFiles @('integration_test/wholesale_packaging_ui_test.dart') *> "$taskEvidence\emulator-bootstrap-wholesale_packaging_ui_test.log"
    'RunnerExit=0' | Add-Content "$taskEvidence\emulator-bootstrap-wholesale_packaging_ui_test.log"
} catch {
    ($_ | Out-String) | Add-Content "$taskEvidence\emulator-bootstrap-wholesale_packaging_ui_test.log"
    'RunnerExit=1' | Add-Content "$taskEvidence\emulator-bootstrap-wholesale_packaging_ui_test.log"
}
Write-Output 'Wholesale fixture retest ended; inspect result.'
