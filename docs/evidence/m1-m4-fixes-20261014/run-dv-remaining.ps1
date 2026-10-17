# Scoped continuation: wait for the existing emulator runner so APK output is
# never shared by simultaneous native builds. Each DV suite remains independent.
$ErrorActionPreference = 'Stop'
$env:PATH = 'C:\Users\ACER\dev\flutter\bin;' + $env:PATH
$taskEvidence = 'docs\evidence\m1-m4-fixes-20261014'
$taskWatch = [Diagnostics.Stopwatch]::StartNew()
while (-not ((Get-Content "$taskEvidence\emulator-native-final.log" -Tail 4 -ErrorAction SilentlyContinue) -match '^RunnerExit=')) {
    if ($taskWatch.Elapsed.TotalMinutes -gt 25) { throw 'Emulator runner has not ended; refusing concurrent native APK builds.' }
    Start-Sleep -Seconds 10
}
$taskCases = @(
    @{ Name='dv-pagination-retry'; File='integration_test/management_inventory_test.dart'; Filter='master, batch and ledger pagination' },
    @{ Name='dv-migration-retry'; File='integration_test/management_inventory_test.dart'; Filter='v2 to v3 preserves' },
    @{ Name='dv-cashier-final'; File='integration_test/cashier_sql_test.dart' },
    @{ Name='dv-database-final'; File='integration_test/database_test.dart' },
    @{ Name='dv-locale-ui-final'; File='integration_test/localization_ui_test.dart' },
    @{ Name='dv-wholesale-ui-final'; File='integration_test/wholesale_packaging_ui_test.dart' },
    @{ Name='dv-gaps-ui-final'; File='integration_test/m31_ui_gaps_test.dart' },
    @{ Name='dv-m4-ui-final'; File='integration_test/m4_ui_test.dart' },
    @{ Name='dv-benchmark-final'; File='integration_test/dv8910_performance_test.dart'; Performance=$true }
)
foreach ($taskCase in $taskCases) {
    $taskLog = Join-Path $taskEvidence ($taskCase.Name + '.log')
    $taskArgs = @{ DeviceId='192.168.0.102:5555'; AndroidSdkRoot='C:\Users\ACER\AppData\Local\Android\sdk'; TestTimeout='15m'; TestFiles=@($taskCase.File) }
    if ($taskCase.Filter) { $taskArgs.NameFilter=$taskCase.Filter }
    if ($taskCase.Performance) { $taskArgs.PerformanceFixture=$true }
    try {
        & .\tools\test_android.ps1 @taskArgs *> $taskLog
        'RunnerExit=0' | Add-Content -LiteralPath $taskLog
    } catch {
        ($_ | Out-String) | Add-Content -LiteralPath $taskLog
        'RunnerExit=1' | Add-Content -LiteralPath $taskLog
    }
}
foreach ($taskMode in @('debug','release')) {
    $taskLog = Join-Path $taskEvidence ('ordinary-' + $taskMode + '-build.log')
    & flutter build apk "--$taskMode" --target lib/main.dart *> $taskLog
    $taskCode=$LASTEXITCODE
    "BuildExit=$taskCode" | Add-Content -LiteralPath $taskLog
    if ($taskCode -ne 0) { throw "Ordinary $taskMode build failed; evidence retained." }
    Copy-Item -LiteralPath "build\app\outputs\flutter-apk\app-$taskMode.apk" -Destination "build\bugfix-20261014\ordinary-$taskMode.apk"
}
Write-Output 'Continuation and ordinary builds completed; inspect per-suite logs.'
