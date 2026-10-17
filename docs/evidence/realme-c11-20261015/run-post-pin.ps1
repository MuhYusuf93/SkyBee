param([ValidateSet('realme','dv')][string]$Target='realme')
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location -LiteralPath $taskRoot
$env:PATH='C:\Users\ACER\dev\flutter\bin;'+$env:PATH
$taskSdk='C:\Users\ACER\AppData\Local\Android\sdk'
$taskDevice='0062112V2210F9B3'
$taskSuites=@('database_test.dart','management_inventory_test.dart','cashier_sql_test.dart',
 'wholesale_packaging_sql_test.dart','reports_corrections_sql_test.dart','m4_storage_test.dart',
 'locale_currency_test.dart','protected_reads_test.dart','bugfix_regression_test.dart',
 'management_ui_test.dart','cashier_ui_test.dart','localization_ui_test.dart',
 'wholesale_packaging_ui_test.dart','m31_ui_gaps_test.dart','m4_ui_test.dart',
 'realme_acceptance_test.dart','realme_value_input_test.dart')
if($Target -eq 'dv') {
 $taskDevice='192.168.0.102:5555'
 $taskSuites=@('pin_native_backend_test.dart','management_inventory_test.dart',
  'protected_reads_test.dart','bugfix_regression_test.dart')
}
$taskOut=Join-Path $PSScriptRoot "post-pin-$Target"
New-Item -ItemType Directory -Force -Path $taskOut | Out-Null
$taskResults=@()
foreach($taskSuite in $taskSuites) {
 $taskLog=Join-Path $taskOut ($taskSuite.Replace('.dart','.log'))
 if(Test-Path -LiteralPath $taskLog) { throw 'Preserve prior evidence: choose a new output folder before retry.' }
 $taskFilter=@()
 if($Target -eq 'dv' -and $taskSuite -eq 'pin_native_backend_test.dart') {
  # This case checks all independent vectors, native availability, worker queue
  # and legacy Dart parity; the Realme-specific populated DB is never opened DV.
  $taskFilter=@('-NameFilter','native PBKDF2 matches')
 }
 if($Target -eq 'dv' -and $taskSuite -eq 'bugfix_regression_test.dart') {
  # The shared change is PIN derivation, so focus the cross-device regression
  # on credential CAS. Realme runs all seven cases including the layout cases.
  $taskFilter=@('-NameFilter','competing PIN rotations')
 }
 $taskStart=Get-Date
 Write-Output "START $Target $taskSuite $($taskStart.ToString('o'))"
 $taskPreference=$ErrorActionPreference
 $ErrorActionPreference='Continue'
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/test_android.ps1 `
  -DeviceId $taskDevice -AndroidSdkRoot $taskSdk -TestFiles "integration_test/$taskSuite" `
  -TestTimeout 15m @taskFilter *> $taskLog
 $taskExit=$LASTEXITCODE
 $ErrorActionPreference=$taskPreference
 Add-Content -Encoding UTF8 $taskLog "RunnerExit=$taskExit"
 $taskResults += [pscustomobject]@{suite=$taskSuite;device=$taskDevice;exit=$taskExit;
  start=$taskStart.ToString('o');end=(Get-Date).ToString('o')}
 ConvertTo-Json -InputObject @($taskResults) -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $taskOut 'results.json')
 Write-Output "END $Target $taskSuite exit=$taskExit"
}
