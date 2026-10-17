$ErrorActionPreference = 'Stop'
$env:PATH = 'C:\Users\ACER\dev\flutter\bin;' + $env:PATH
$taskEvidence = 'docs\evidence\m1-m4-fixes-20261014'
$taskWatch = [Diagnostics.Stopwatch]::StartNew()
while (-not ((Get-Content "$taskEvidence\ordinary-release-build.log" -Tail 2 -ErrorAction SilentlyContinue) -match '^BuildExit=0')) {
    if ($taskWatch.Elapsed.TotalMinutes -gt 35) { throw 'DV continuation/build has not finished; refusing simultaneous APK builds.' }
    Start-Sleep -Seconds 10
}
$taskFiles = @('database_test','management_ui_test','cashier_ui_test','localization_ui_test','wholesale_packaging_ui_test','m31_ui_gaps_test','m4_ui_test','protected_reads_test')
foreach ($taskFile in $taskFiles) {
    $taskLog = Join-Path $taskEvidence ('emulator-independent-' + $taskFile + '.log')
    try {
        & .\tools\test_android.ps1 -DeviceId 'emulator-5554' -AndroidSdkRoot 'C:\Users\ACER\AppData\Local\Android\sdk' -TestTimeout 5m -TestFiles @("integration_test/$taskFile.dart") *> $taskLog
        'RunnerExit=0' | Add-Content -LiteralPath $taskLog
    } catch {
        ($_ | Out-String) | Add-Content -LiteralPath $taskLog
        'RunnerExit=1' | Add-Content -LiteralPath $taskLog
    }
}
Write-Output 'Independent emulator continuation completed; inspect per-suite logs.'
