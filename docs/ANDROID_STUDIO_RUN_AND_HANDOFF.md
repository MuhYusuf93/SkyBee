# Menjalankan source dan handoff Android

Pembaruan21 Oktober2026. Buka root `codex-kasir-kit` yang berisi `pubspec.yaml` di Android
Studio, bukan hanya subfolder `android`. Gunakan plugin Flutter/Dart dan Flutter
SDK `C:\Users\ACER\dev\flutter`. Android SDK lokal berada di
`C:\Users\ACER\AppData\Local\Android\sdk`.

## Aplikasi utama

Run → Edit Configurations → Flutter, entrypoint `lib/main.dart`, working directory
root proyek. Konfigurasi lokal `.idea/runConfigurations/main_dart.xml` sudah
menunjuk entrypoint itu. Tidak ada flavor wajib; jangan menambahkan
`KASIR_INTEGRATION_TEST`, `KASIR_FIXTURE_DATABASE` atau entrypoint test/bridge.
Pilih Poco F6 `7f0edea0` secara eksplisit, lalu Run/Debug. Pastikan nama aplikasi
`kasir_app`, package `com.example.kasir_app`, launcher `MainActivity`.

Debug mendukung breakpoint/hot reload, lebih lambat dan debuggable. Profile
digunakan untuk pemeriksaan performa; release untuk mencoba perilaku distribusi
tanpa debugger. Android Studio membangun source saat itu; APK M5 arsip tidak
identik dengan debug/source M5.1 yang selanjutnya diedit.

CLI setara dari root: `flutter run -d 7f0edea0 -t lib/main.dart` (debug), tambahkan
`--profile` atau `--release` sesuai kebutuhan. Jangan menjalankannya bersamaan
dengan build/test/deploy lain. Hentikan kontrol otomatis sebelum uji pengguna.

## Integrasi terisolasi

Semua native integration test melalui `tools/test_android.ps1` dengan DeviceId
dan AndroidSdkRoot eksplisit. Runner memverifikasi `.integration`, tiga library
native sesuai ABI, flag isolasi dan `--no-uninstall`. Jangan memakai bare
`flutter test integration_test/...` untuk aplikasi utama, jangan melemahkan
Gradle guard. Fixture `kasir_app tests` bukan hasil handoff aplikasi utama.

## Konflik versi/sertifikat dan data

In-place update hanya setelah perlindungan data/key dan kecocokan package,
sertifikat serta versionCode terbukti. Jangan uninstall/clear data, mengganti
applicationId, membuat keystore lain atau downgrade paksa untuk melewati error.
Simpan pesan error dan laporkan blocker. Database terenkripsi membutuhkan key
yang benar; salinan mainfile aktif tanpa WAL/key bukan backup yang sah. Backup
portable tervalidasi beserta recovery pribadi menyediakan jalur pemulihan yang
berbeda dari key instalasi; jangan kirim recovery/PIN di chat/Git.

Signing saat ini development, bukan signing rilis M6. OAuth Android untuk package
utama dan sertifikat yang benar harus disiapkan pemilik project bila hendak
mencoba Drive; konfigurasi integration tidak otomatis berlaku bagi ordinary.

## Handoff M5.1 aktual

Ordinary **debug0.5.1+8** sudah dipasang in-place pada Poco `7f0edea0` dan dua
startup kasir lulus. Nama/applicationId tetap `kasir_app`/`com.example.kasir_app`,
launcher `MainActivity`, target schema13. Snapshot sandbox tertutup disimpan
privat sebelum install; database dan wrapped key cocok selama install sebelum
startup, installed APK ditarik/hash cocok. Wrapped key tetap setelah startup;
reopen menjalani bootstrap integrity/FK/HMAC/cipher. Tidak reset/uninstall/
downgrade. Kontrol otomatis Off; PIN Gudang/Pengaturan tetap diuji pengguna
sendiri, bukan dibagikan melalui chat.

Folder artefak: `build/m51-final-handoff-20261021-000031/`.

- Debug terpasang: `kasir-app-0.5.1-ordinary-debug.apk`, SHA256
  `fdb5de9397d66bb0ffb972cbdabf4936adfbbe28b880f92279a242cd1c8ef7f5`.
- Release tersedia: `kasir-app-0.5.1-ordinary-release.apk`, SHA256
  `3240de00de558e8e5279065143de466d83474a26c4d042d3d89dbdb599fe091e`.

Keduanya terverifikasi3ABI/16KiB/signature/resource/lisensi. Release memakai
sertifikat development yang sama, belum runtime-tested pada handoff terbaru;
bukan signing M6. `.idea/runConfigurations/main_dart.xml` telah diperiksa:
entrypoint `lib/main.dart`, tanpa flag integration. Run/Debug membangun source
terkini; jangan memakai APK fixture sebagai aplikasi utama.
[Laporan lengkap dan batas](M51_FINAL_REPORT_20261021.md).

## Skybee kasir — demo terpisah

Tambahan21 Oktober2026: **skybee kasir** tersedia sebagai aplikasi debug
terpisah `com.example.kasir_app.skybee`, bukan perubahan konfigurasi ordinary
`main.dart`. Entrypoint `lib/main_skybee_demo.dart` dengan
`--dart-define=KASIR_SKYBEE_DEMO=true`, debug saja. Seed100barang/toko/PIN dummy
yang diminta hanya berjalan sekali. [APK/hash dan handoff Skybee](SKYBEE_DEMO_HANDOFF_20261021.md).
Pengguna menguji mandiri; tidak menunggu laporan hasil.

## Handoff M5 historis sebelum fitur M5.1

Artefak M5 dibangun ulang sebelum fitur baru di
`build/m51-handoff-20261019-015916/kasir-app-0.5.0-m5-ordinary-release.apk`.
Release tersebut tersedia sebagai artefak terpisah. Untuk handoff pengembangan,
`kasir-app-0.5.0-m5-ordinary-debug.apk` di folder sama sudah dipasang in-place
dan dibuka pada Poco, setelah snapshot tertutup dan izin dummy terbaru pengguna.
Paket tetap ordinary, bukan fixture. SHA256 debug:
`1b7598740607c3cb15ee673b6eb91f69507c0793f6fd413c884aabb24eec0b43`.
Database/key wrapped sama selama install sebelum startup; tidak reset/uninstall.
Kontrol otomatis Off. Pemeriksaan Gudang/Pengaturan memakai PIN pribadi menunggu
laporan pengguna. Lihat [checkpoint aktual](M51_IMPLEMENTATION_REPORT.md).
