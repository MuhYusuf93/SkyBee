$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$env:PATH = 'C:\Users\ACER\dev\flutter\bin;' + $env:PATH
$taskSdk = 'C:\Users\ACER\AppData\Local\Android\sdk'
$taskDevice = '0062112V2210F9B3'
$taskAdb = Join-Path $taskSdk 'platform-tools/adb.exe'
$taskSuites = @(
    'database_test.dart', 'management_inventory_test.dart', 'cashier_sql_test.dart',
    'wholesale_packaging_sql_test.dart', 'reports_corrections_sql_test.dart',
    'm4_storage_test.dart', 'locale_currency_test.dart', 'protected_reads_test.dart',
    'bugfix_regression_test.dart', 'management_ui_test.dart', 'cashier_ui_test.dart',
    'localization_ui_test.dart', 'wholesale_packaging_ui_test.dart',
    'm31_ui_gaps_test.dart', 'm4_ui_test.dart'
)
$taskResults = @()
$taskLedger = Join-Path $PSScriptRoot 'functional-run-results.json'
if (Test-Path -LiteralPath $taskLedger) {
    $taskDecodedResults = Get-Content -LiteralPath $taskLedger -Raw | ConvertFrom-Json
    foreach ($taskRecord in $taskDecodedResults) {
        if ($taskRecord.value) {
            foreach ($taskNestedRecord in $taskRecord.value) { $taskResults += $taskNestedRecord }
        } else { $taskResults += $taskRecord }
    }
}
foreach ($taskSuite in $taskSuites) {
    if (@($taskResults | Where-Object { $_.suite -eq $taskSuite -and $_.exit -eq 0 }).Count -gt 0) {
        Write-Output "SKIP completed suite $taskSuite (existing evidence retained)"
        continue
    }
    $taskState = ((& $taskAdb -s $taskDevice get-state 2>&1) -join '').Trim()
    if ($taskState -ne 'device') {
        $taskResults += [pscustomobject]@{ suite=$taskSuite; result='BLOCKED_ENVIRONMENT'; detail=$taskState }
        $taskResults | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'functional-run-results.json')
        continue
    }
    $taskLog = Join-Path $PSScriptRoot ('native-' + $taskSuite.Replace('.dart', '.log'))
    $taskAttempt = 1
    while (Test-Path -LiteralPath $taskLog) {
        $taskAttempt++
        $taskLog = Join-Path $PSScriptRoot ('native-' + $taskSuite.Replace('.dart', "-attempt$taskAttempt.log"))
    }
    $taskStarted = Get-Date
    Write-Output "START $taskSuite $($taskStarted.ToString('o'))"
    # Windows PowerShell turns child stderr into NativeCommandError. Preserve
    # the child failure/log/exit but let this outer queue run independent suites.
    $taskSavedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test_android.ps1 `
        -DeviceId $taskDevice -AndroidSdkRoot $taskSdk `
        -TestFiles "integration_test/$taskSuite" -TestTimeout 15m *> $taskLog
    $taskExit = $LASTEXITCODE
    $ErrorActionPreference = $taskSavedPreference
    Add-Content -Encoding UTF8 $taskLog "RunnerExit=$taskExit"
    $taskEnded = Get-Date
    $taskResults += [pscustomobject]@{ suite=$taskSuite; attempt=$taskAttempt; log=[IO.Path]::GetFileName($taskLog); exit=$taskExit; start=$taskStarted.ToString('o'); end=$taskEnded.ToString('o'); seconds=($taskEnded-$taskStarted).TotalSeconds }
    $taskResults | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'functional-run-results.json')
    $taskPidValue = ((& $taskAdb -s $taskDevice shell pidof com.example.kasir_app.integration 2>$null) -join '').Trim()
    $taskSnapshot = Join-Path $PSScriptRoot ('pid-' + $taskSuite.Replace('.dart', '.log'))
    if ($taskPidValue -match '^\d+$') {
        "package=com.example.kasir_app.integration pid=$taskPidValue" | Set-Content -Encoding UTF8 $taskSnapshot
        & $taskAdb -s $taskDevice logcat -d "--pid=$taskPidValue" -v threadtime | Add-Content -Encoding UTF8 $taskSnapshot
        & $taskAdb -s $taskDevice shell dumpsys meminfo $taskPidValue *> (Join-Path $PSScriptRoot ('memory-' + $taskSuite.Replace('.dart', '.log')))
    } else { 'Own test PID absent; no global log collected' | Set-Content -Encoding UTF8 $taskSnapshot }
    & $taskAdb -s $taskDevice shell dumpsys battery *> (Join-Path $PSScriptRoot ('battery-' + $taskSuite.Replace('.dart', '.log')))
    Write-Output "END $taskSuite exit=$taskExit"
}
Write-Output 'Functional queue completed. Failures require diagnosis/retest; no PASS inference from queue completion.'
