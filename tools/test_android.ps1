param(
    [Parameter(Mandatory = $true)][string]$DeviceId,
    [Parameter(Mandatory = $true)][string]$AndroidSdkRoot,
    [string[]]$TestFiles = @('integration_test/wholesale_packaging_sql_test.dart', 'integration_test/wholesale_packaging_ui_test.dart'),
    [switch]$VerifyOperationalDatabase,
    [switch]$PerformanceFixture,
    [string]$NameFilter = '',
    [ValidatePattern('^[1-9][0-9]*[sm]$')][string]$TestTimeout = '30s',
    [switch]$PrepareOnly,
    [ValidateSet('debug','profile','release')][string]$BuildMode='debug',
    [ValidateSet('android-arm','android-arm64','android-x64','android-arm,android-arm64,android-x64')][string]$TargetPlatform='android-arm,android-arm64,android-x64',
    [string[]]$AdditionalDartDefines=@()
)

# Build/verify a disposable package before letting Flutter install anything.
# --no-uninstall disables default test cleanup; the separate applicationId also
# confines install-failure fallback to fixtures instead of operational data.
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$taskPreviousLocation = Get-Location
function Get-OperationalDatabaseHash {
    # Optional development proof, after the user makes the device idle/available.
    # Only a closed/quiescent DB is fingerprinted; no data is printed or copied.
    $taskAdb = Join-Path $AndroidSdkRoot 'platform-tools/adb.exe'
    $taskPackage = 'com.example.kasir_app'
    $taskAppRoot = ((& $taskAdb -s $DeviceId shell run-as $taskPackage pwd) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $taskAppRoot -notin @('/data/user/0/com.example.kasir_app', '/data/data/com.example.kasir_app')) {
        throw 'Cannot verify the operational debug-app sandbox; no fingerprint claim.'
    }
    & $taskAdb -s $DeviceId shell am force-stop $taskPackage
    if ($LASTEXITCODE -ne 0) { throw 'Cannot quiesce the operational app.' }
    $taskDigest = ((& $taskAdb -s $DeviceId shell run-as $taskPackage sha256sum "$taskAppRoot/databases/kasir_app.db") -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $taskDigest -notmatch '^([0-9a-fA-F]{64})\s+') {
        throw 'Operational database fingerprint is unavailable; refusing a preservation claim.'
    }
    return $Matches[1].ToLowerInvariant()
}
try {
    Set-Location -LiteralPath $taskRoot
    $taskAdb = Join-Path $AndroidSdkRoot 'platform-tools/adb.exe'
    $taskDeviceState = ((& $taskAdb -s $DeviceId get-state) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $taskDeviceState -ne 'device') {
        throw 'Selected Android device is not connected/authorized; no build or install attempted.'
    }
    if ($TestFiles.Count -eq 0) { throw 'At least one integration suite is required.' }
    if (@($TestFiles | Where-Object { (Split-Path -Leaf $_) -like 'm53_*' }).Count -gt 0 -and
        'KASIR_FIXTURE_BACKGROUND_PAUSED=true' -notin $AdditionalDartDefines) {
        throw 'M5.3 retained-package tests require KASIR_FIXTURE_BACKGROUND_PAUSED=true before build/install.'
    }
    if($BuildMode -ne 'debug' -and -not $PrepareOnly){throw 'Profile/release fixtures use PrepareOnly; Flutter integration runner remains debug.'}
    if($PrepareOnly -and $TestFiles.Count -ne 1){throw 'PrepareOnly requires exactly one isolated entrypoint.'}
    $taskNameFilterArgs = @()
    if ($NameFilter) {
        if ($TestFiles.Count -ne 1) { throw 'A focused name filter requires exactly one suite.' }
        $taskNameFilterArgs = @("--plain-name=$NameFilter")
    }
    $taskExtraDefines = @()
    if ($PerformanceFixture) { $taskExtraDefines = @('--dart-define=KASIR_PERFORMANCE_FIXTURE=true') }
    foreach($taskDefine in $AdditionalDartDefines){
        if($taskDefine -notmatch '^[A-Z][A-Z0-9_]*=[A-Za-z0-9._:-]+$'){throw 'Only explicit non-secret fixture/build definitions are supported.'}
        $taskExtraDefines+=@("--dart-define=$taskDefine")
    }
    foreach ($taskFile in $TestFiles) {
        $taskResolved = (Resolve-Path -LiteralPath $taskFile).Path
        $taskFixtureRoot = (Resolve-Path -LiteralPath 'integration_test').Path + [IO.Path]::DirectorySeparatorChar
        if (-not $taskResolved.StartsWith($taskFixtureRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing a test entrypoint outside integration_test.'
        }
    }
    $taskBuildTools = Join-Path $AndroidSdkRoot 'build-tools'
    $taskAapt = Get-ChildItem -LiteralPath $taskBuildTools -Directory |
        Sort-Object { [Version]$_.Name } -Descending |
        ForEach-Object { Join-Path $_.FullName 'aapt.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $taskAapt) { throw 'aapt.exe was not found; no install attempted.' }
    # Regenerate plugin metadata when switching release/debug; --no-pub can
    # retain a registrant from the previous mode and break native plugins.
    & flutter build apk "--$BuildMode" "--target-platform=$TargetPlatform" --target $TestFiles[0] --dart-define=KASIR_INTEGRATION_TEST=true @taskExtraDefines
    if ($LASTEXITCODE -ne 0) { throw 'Fixture APK build failed; no install attempted.' }
    $taskApk = Join-Path $taskRoot "build/app/outputs/flutter-apk/app-$BuildMode.apk"
    $taskIdentity = & $taskAapt dump badging $taskApk
    $taskPackageMatch = @($taskIdentity | Where-Object { $_.StartsWith("package: name='com.example.kasir_app.integration' ") })
    if ($LASTEXITCODE -ne 0 -or $taskPackageMatch.Count -ne 1) {
        throw 'APK identity is not the disposable fixture package; no install attempted.'
    }
    $taskIdentity | Select-String '^package:|^application-label:|^launchable-activity:'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $taskZip=[System.IO.Compression.ZipFile]::OpenRead($taskApk)
    try{
        $taskNative=@($taskZip.Entries | Where-Object {$_.FullName -match '^lib/[^/]+/[^/]+\.so$'} | ForEach-Object {$_.FullName})
        $taskAbis=@($taskNative | ForEach-Object {($_ -split '/')[1]} | Sort-Object -Unique)
        foreach($taskAbi in $taskAbis){
            foreach($taskRequired in @('libflutter.so','libkasir_pin_kdf.so','libsqlcipher.so')){
                if("lib/$taskAbi/$taskRequired" -notin $taskNative){throw "Incomplete native ABI $taskAbi ($taskRequired absent); refusing install."}
            }
        }
        if($taskAbis.Count -eq 0){throw 'No verified native ABI; refusing install.'}
    }finally{$taskZip.Dispose()}
    if($PrepareOnly){Write-Output "Prepared verified isolated $BuildMode APK; no installation was performed.";return}
    if ($VerifyOperationalDatabase) {
        $taskBeforeHash = Get-OperationalDatabaseHash
        Write-Output "Operational DB SHA256 before: $taskBeforeHash"
    }
    foreach ($taskFile in $TestFiles) {
        # Slow ARM test targets may need a longer bounded harness timeout;
        # this does not alter PIN KDF parameters or remove business assertions.
        & flutter test $taskFile -d $DeviceId --no-uninstall --dart-define=KASIR_INTEGRATION_TEST=true @taskExtraDefines @taskNameFilterArgs --timeout=$TestTimeout --reporter expanded
        if ($LASTEXITCODE -ne 0) { throw "Fixture suite failed: $taskFile. Stopping before any further install." }
    }
    if ($VerifyOperationalDatabase) {
        $taskAfterHash = Get-OperationalDatabaseHash
        Write-Output "Operational DB SHA256 after: $taskAfterHash"
        if ($taskBeforeHash -ne $taskAfterHash) { throw 'Operational database changed across fixture testing.' }
        Write-Output 'Operational DB fingerprint preserved across all requested suites.'
    }
} finally {
    Set-Location -LiteralPath $taskPreviousLocation.Path
}
