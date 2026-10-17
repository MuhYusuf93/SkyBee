$ErrorActionPreference='Stop'
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$taskEvidence='docs\evidence\m1-m4-fixes-20261014'
$taskWatch=[Diagnostics.Stopwatch]::StartNew()
while (-not ((Get-Content "$taskEvidence\dv-locale-ui-retest.log" -Tail 3 -ErrorAction SilentlyContinue) -match '^RunnerExit=')) {
    if ($taskWatch.Elapsed.TotalMinutes -gt 20) { throw 'Previous native continuation has not ended.' }
    Start-Sleep -Seconds 10
}
foreach ($taskFile in @('management_ui_test','cashier_ui_test')) {
    $taskLog=Join-Path $taskEvidence ('emulator-bootstrap-' + $taskFile + '.log')
    try {
        & .\tools\test_android.ps1 -DeviceId 'emulator-5554' -AndroidSdkRoot 'C:\Users\ACER\AppData\Local\Android\sdk' -TestTimeout 5m -TestFiles @("integration_test/$taskFile.dart") *> $taskLog
        'RunnerExit=0' | Add-Content -LiteralPath $taskLog
    } catch {
        ($_ | Out-String) | Add-Content -LiteralPath $taskLog
        'RunnerExit=1' | Add-Content -LiteralPath $taskLog
    }
}
Write-Output 'Emulator bootstrap retests ended; inspect actual results.'
