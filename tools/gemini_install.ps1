# Script instalasi mandiri aplikasi pengujian Gemini untuk Poco F6.
# Menggunakan package terisolasi com.example.kasir_app.gemini tanpa mengubah file proyek asli.

$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$adb = "C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe"
$aapt = "C:\Users\ACER\AppData\Local\Android\sdk\build-tools\36.0.0\aapt.exe"
$deviceId = '7f0edea0'
$package = 'com.example.kasir_app.gemini'

Write-Host "===> 1. Memeriksa koneksi perangkat Poco F6 ($deviceId)..."
$deviceState = ((& $adb -s $deviceId get-state) -join '').Trim()
if ($deviceState -ne 'device') {
    throw "Perangkat $deviceId tidak terdeteksi atau belum diizinkan!"
}
Write-Host "Perangkat Poco F6 terhubung."

Write-Host "===> 2. Memeriksa keberadaan APK Gemini..."
$apkPath = Join-Path $taskRoot "build\app\outputs\flutter-apk\app-debug.apk"
if (-not (Test-Path $apkPath)) {
    throw "APK tidak ditemukan di $apkPath! Jalankan build terlebih dahulu."
}

Write-Host "===> 3. Verifikasi AAPT Identity APK..."
$identity = & $aapt dump badging $apkPath
$pkgLine = $identity | Where-Object { $_ -match "^package: name='com\.example\.kasir_app\.gemini'" }
if (-not $pkgLine) {
    throw "Identitas APK bukan com.example.kasir_app.gemini! Menolak instalasi."
}
Write-Host "Identitas APK terverifikasi: $package"

Write-Host "===> 4. Menginstal APK Gemini ke Poco F6..."
& $adb -s $deviceId install -r $apkPath
if ($LASTEXITCODE -ne 0) {
    throw "Instalasi APK gagal!"
}
Write-Host "Instalasi sukses!"

Write-Host "===> 5. Memverifikasi paket terpasang di Poco F6..."
$installed = & $adb -s $deviceId shell pm list packages $package
if ($installed -notmatch "package:$package") {
    throw "Paket $package tidak ditemukan di daftar aplikasi terpasang!"
}
Write-Host "Paket $package terpasang dengan aman di sandbox Poco F6."

Write-Host "===> 6. Meluncurkan aplikasi Gemini di Poco F6..."
& $adb -s $deviceId shell am start -n "$package/com.example.kasir_app.MainActivity"
Write-Host "Aplikasi Kasir Gemini berhasil diluncurkan!"
