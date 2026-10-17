param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [Parameter(Mandatory = $true)][string]$AndroidSdkRoot,
    [switch]$ConfirmDummyData
)

# Explicit one-time developer action, not app behavior or test-run cleanup.
# Only the named operational SQLite file and its sidecars may be removed.
$ErrorActionPreference = 'Stop'
if (-not $ConfirmDummyData) { throw 'Reset requires explicit confirmation that data is dummy.' }
$taskAdb = Join-Path $AndroidSdkRoot 'platform-tools/adb.exe'
$taskPackage = 'com.example.kasir_app'
$taskState = (& $taskAdb -s $DeviceId get-state) -join ''
if ($LASTEXITCODE -ne 0 -or $taskState.Trim() -ne 'device') { throw 'Confirmed Android device is not available; no reset attempted.' }
$taskAppRoot = ((& $taskAdb -s $DeviceId shell run-as $taskPackage pwd) -join '').Trim()
if ($LASTEXITCODE -ne 0 -or $taskAppRoot -notin @('/data/user/0/com.example.kasir_app', '/data/data/com.example.kasir_app')) {
    throw 'Operational app sandbox could not be verified; no reset attempted.'
}
& $taskAdb -s $DeviceId shell am force-stop $taskPackage
if ($LASTEXITCODE -ne 0) { throw 'Could not stop the app; no reset attempted.' }
foreach ($taskName in @('kasir_app.db', 'kasir_app.db-wal', 'kasir_app.db-shm', 'kasir_app.db-journal')) {
    $taskTarget = "$taskAppRoot/databases/$taskName"
    if (-not $taskTarget.StartsWith("$taskAppRoot/databases/kasir_app.db", [StringComparison]::Ordinal)) {
        throw 'Reset target escaped the verified database path.'
    }
    & $taskAdb -s $DeviceId shell run-as $taskPackage test -f $taskTarget
    $taskExisted = $LASTEXITCODE -eq 0
    & $taskAdb -s $DeviceId shell run-as $taskPackage rm -f $taskTarget
    if ($LASTEXITCODE -ne 0) { throw "Could not remove authorized dummy file: $taskName" }
    & $taskAdb -s $DeviceId shell run-as $taskPackage test -e $taskTarget
    if ($LASTEXITCODE -eq 0) { throw "Dummy database file is still present: $taskName" }
    Write-Output "$taskName : existed=$taskExisted; absent-after-reset=true"
}
Write-Output 'Dummy SQLite reset completed. Other app files/packages were not reset.'
