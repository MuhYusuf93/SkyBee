param([string[]]$SuiteNames=@())
# Serial native campaign, no human interaction, production DB or real Google.
# A failing case does not stop independent suites if strict isolation still
# holds. An isolation failure or lost device stops all dependent operations.
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskDevice='0062112V2210F9B3'
$taskCampaign=Join-Path $taskRoot "build/realme-m5-current-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Path $taskCampaign | Out-Null
$taskSuites=@(
 @('usb-migration','integration_test/m51_usb_test.dart','10 to 11 migration'),
 @('encryption','integration_test/m5_encryption_test.dart',''),
 @('migration-fault','integration_test/m5_migration_fault_test.dart',''),
 @('backup','integration_test/m5_backup_test.dart',''),
 @('restore-fault','integration_test/m5_restore_fault_test.dart',''),
 @('rejection','integration_test/m5_backup_rejection_test.dart',''),
 @('checkout','integration_test/m5_checkout_test.dart',''),
 @('drive-auth','integration_test/m5_drive_authorization_test.dart',''),
 @('settings-ui','integration_test/m5_settings_ui_test.dart',''),
 @('security','integration_test/m51_security_test.dart',''),
 @('recovery-output','integration_test/m51_recovery_print_test.dart',''),
 @('operational','integration_test/m5_device_operational_test.dart','')
)
$taskResults=@()
foreach($taskRequested in $SuiteNames){if($taskRequested -notin @($taskSuites | ForEach-Object {$_[0]})){throw 'Unknown requested suite'}}
foreach($taskSuite in $taskSuites){
 if($SuiteNames.Count -gt 0 -and $taskSuite[0] -notin $SuiteNames){continue}
 $taskName='realme-current-'+$taskSuite[0]
 $taskError=$false
 try {
  & "$PSScriptRoot/test_m51_android.ps1" -DeviceId $taskDevice -TestFile $taskSuite[1] -NameFilter $taskSuite[2] -RunName $taskName
 } catch { $taskError=$true; Write-Warning "Suite $($taskSuite[0]) failed/blocked. Inspect private evidence; independent suites continue only with isolation verified." }
 $taskEvidence=Get-ChildItem (Join-Path $taskRoot 'build') -Directory -Filter "$taskName-*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 if(-not $taskEvidence -or -not (Test-Path (Join-Path $taskEvidence.FullName 'result.json'))){throw 'No completed safety evidence; stopping campaign'}
 $taskResult=Get-Content (Join-Path $taskEvidence.FullName 'result.json') -Raw | ConvertFrom-Json
 $taskResults+=@{suite=$taskSuite[0];result=$taskResult;evidence=$taskEvidence.Name;exception=$taskError}
 $taskResults | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $taskCampaign 'results.json') -Encoding UTF8
 if($taskResult.isolation -ne 'Every pre-existing protected file hash unchanged' -or $taskResult.automaticDeviceControlActive){throw 'Isolation/control proof failed; no further installs'}
}
Write-Output "Realme current M5 campaign: $taskCampaign"
