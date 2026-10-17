param(
    [ValidateSet('Probe','Enable','Restore')][string]$Action = 'Probe',
    [string]$AndroidSdkRoot = 'C:\Users\ACER\AppData\Local\Android\sdk',
    [string]$SnapshotPath = "$PSScriptRoot/../docs/evidence/m5-20261016/dv-awake-original.json"
)
# Narrow, user-authorized temporary settings only; never overwrite the baseline
# on resume. This is independent of the integration runner and survives its exit.
$ErrorActionPreference = 'Stop'
$taskAdb = Join-Path $AndroidSdkRoot 'platform-tools/adb.exe'
$taskTarget = '192.168.0.102:5555'
function Invoke-Dv([string[]]$Arguments) {
    $taskResult = & $taskAdb -s $taskTarget @Arguments
    if ($LASTEXITCODE -ne 0) { throw "ADB operation failed for confirmed DV target ($Action)." }
    return (($taskResult -join "`n").Trim())
}
if ((Invoke-Dv @('get-state')) -ne 'device') { throw 'DV unavailable; no setting changed.' }
$taskModel = Invoke-Dv @('shell','getprop','ro.product.model')
$taskFingerprint = Invoke-Dv @('shell','getprop','ro.build.fingerprint')
# Prior DV reports record ADB model AX810 despite the accepted firmware label.
if ($taskModel -notin @('DV8947-KIX','DV8910','AX810') -or
    ($taskModel -eq 'AX810' -and -not $taskFingerprint.StartsWith('Skyworth/HP4609-Skyworth/YYT:11/'))) {
    throw "Unexpected device identity: $taskModel"
}
$taskEntries = @(
    @{ Namespace='secure'; Name='screensaver_enabled'; Temporary='0' },
    @{ Namespace='system'; Name='screen_off_timeout'; Temporary='2147483647' },
    @{ Namespace='global'; Name='stay_on_while_plugged_in'; Temporary='7' }
)
if ($Action -eq 'Probe') {
    foreach ($taskEntry in $taskEntries) {
        [PSCustomObject]@{Namespace=$taskEntry.Namespace;Name=$taskEntry.Name;Value=(Invoke-Dv @('shell','settings','get',$taskEntry.Namespace,$taskEntry.Name))}
    }
    exit 0
}
if ($Action -eq 'Enable') {
    if (Test-Path -LiteralPath $SnapshotPath) {
        $taskSnapshot = Get-Content -LiteralPath $SnapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($taskSnapshot.Restored -eq $true) { throw 'Previous session restored; choose a new snapshot file for a new session.' }
    } else {
        $taskSaved = foreach ($taskEntry in $taskEntries) {
            @{Namespace=$taskEntry.Namespace;Name=$taskEntry.Name;Value=(Invoke-Dv @('shell','settings','get',$taskEntry.Namespace,$taskEntry.Name));Temporary=$taskEntry.Temporary}
        }
        $taskSnapshot = @{Device=$taskTarget;Model=$taskModel;SavedAt=(Get-Date -Format o);Restored=$false;Entries=@($taskSaved)}
        $taskParent = Split-Path -Parent $SnapshotPath
        New-Item -ItemType Directory -Force -Path $taskParent | Out-Null
        $taskSnapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $SnapshotPath -Encoding UTF8
    }
    foreach ($taskEntry in $taskSnapshot.Entries) {
        Invoke-Dv @('shell','settings','put',$taskEntry.Namespace,$taskEntry.Name,$taskEntry.Temporary) | Out-Null
        if ((Invoke-Dv @('shell','settings','get',$taskEntry.Namespace,$taskEntry.Name)) -ne $taskEntry.Temporary) { throw 'Awake setting readback mismatch; restore snapshot.' }
    }
    # Disabling a future screensaver does not wake an already sleeping display.
    # KEYCODE_WAKEUP is the narrowly authorized screen action; it enters no app
    # data and does not disable/force-stop any system service.
    Invoke-Dv @('shell','timeout','5','input','keyevent','224') | Out-Null
    Write-Output "Temporary awake applied; original values retained at $SnapshotPath"
} else {
    if (-not (Test-Path -LiteralPath $SnapshotPath)) { throw 'No snapshot; refuse guessed restoration.' }
    $taskSnapshot = Get-Content -LiteralPath $SnapshotPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($taskSnapshot.Device -ne $taskTarget -or $taskSnapshot.Model -ne $taskModel) { throw 'Snapshot identity mismatch.' }
    foreach ($taskEntry in $taskSnapshot.Entries) {
        if ($taskEntry.Value -eq 'null') { Invoke-Dv @('shell','settings','delete',$taskEntry.Namespace,$taskEntry.Name) | Out-Null }
        else { Invoke-Dv @('shell','settings','put',$taskEntry.Namespace,$taskEntry.Name,$taskEntry.Value) | Out-Null }
        if ((Invoke-Dv @('shell','settings','get',$taskEntry.Namespace,$taskEntry.Name)) -ne $taskEntry.Value) { throw 'Original setting restoration readback mismatch.' }
    }
    $taskSnapshot.Restored = $true
    $taskSnapshot | Add-Member -NotePropertyName RestoredAt -NotePropertyValue (Get-Date -Format o) -Force
    $taskSnapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $SnapshotPath -Encoding UTF8
    Write-Output 'Original DV settings restored and read back exactly.'
}
