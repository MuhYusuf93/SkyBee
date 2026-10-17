$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$env:PATH = 'C:\Users\ACER\dev\flutter\bin;' + $env:PATH
$taskSdk = 'C:\Users\ACER\AppData\Local\Android\sdk'
$taskDevice = '0062112V2210F9B3'
foreach ($taskSuite in @('realme_acceptance_test.dart', 'realme_value_input_test.dart', 'realme_performance_test.dart')) {
    $taskLog = Join-Path $PSScriptRoot ('native-' + $taskSuite.Replace('.dart','.log'))
    $taskFlags = @()
    if ($taskSuite -eq 'realme_performance_test.dart') { $taskFlags = @('-PerformanceFixture') }
    $taskSavedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test_android.ps1 `
      -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -TestFiles "integration_test/$taskSuite" `
      -TestTimeout 15m @taskFlags *> $taskLog
    $taskExit = $LASTEXITCODE
    $ErrorActionPreference = $taskSavedPreference
    Add-Content -Encoding UTF8 $taskLog "RunnerExit=$taskExit"
    Write-Output "END $taskSuite exit=$taskExit"
}
