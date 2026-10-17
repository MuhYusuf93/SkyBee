# Kasir Flutter — M5

Source aktif **0.5.0+7 / schema8**: database Android SQLCipher wajib dengan key instalasi Keystore; printer Bluetooth Classic SPP/ESC-POS, preview/raster/queue; peringatan stok/batch; backup portable terenkripsi, SAF, safety restore; Google Drive opsional appDataFolder dan WorkManager best effort. Kasir tetap offline tanpa akun Google. Tidak ada rename applicationId/signing produksi atau sinkronisasi multi-device. **M6 belum dimulai.**

Hasil dan batas bukti: [M5_TEST_REPORT](docs/M5_TEST_REPORT.md), [implementasi](docs/M5_IMPLEMENTATION_REPORT.md), [temuan/perbaikan](docs/M5_FIXES_AND_VALIDATION.md), [STATUS](docs/STATUS.md), [requirement matrix](docs/REQUIREMENTS.md). Native Realme88 PASS/Windows219 PASS+2 benchmark opt-in SKIP tidak membuktikan Iware paper/OAuth Drive/ARM64 Poco/lintas perangkat; status tersebut tetap terpisah.

Panduan pemeliharaan: [SQLCipher/migration/key](docs/DATABASE_ENCRYPTION_AND_MIGRATION.md), [backup/restore](docs/BACKUP_RESTORE.md), [Google config](docs/GOOGLE_DRIVE_SETUP.md), [printer/kalibrasi](docs/PRINTER_SETUP_AND_CALIBRATION.md), [acceptance Poco](docs/M5_POCO_MANUAL_TEST.md). `pubspec.lock` mematok dependency; lisensi native pada assets/third_party dan halaman atribusi di Pengaturan.

Native integration wajib `tools/test_android.ps1 -DeviceId <confirmed-id> -AndroidSdkRoot <sdk> -TestFiles @('integration_test/<suite>.dart')`; skrip memverifikasi sandbox APK dan memakai --no-uninstall. Untuk artefak manual gunakan PrepareOnly, verifikasi hash/package sebelum direct install-r. Jangan menjalankan bare integration test pada package ordinary atau clear/uninstall untuk memperbaiki data. `flutter analyze`, `flutter test test`, `flutter gen-l10n`, `python tools/audit_localization.py` dan `python tools/audit_pin_crypto.py` merupakan pemeriksaan host. Build ordinary `flutter build apk --release` hanya menghasilkan APK; instalasi operasional bukan bagian tes fixture.

Checkpoint berikut dipertahankan sebagai histori tahap sebelum M5.

Tahap aktif M4, source **0.4.0+6 / schema7**: laporan seluruh periode (penjualan/HPP/laba kotor/pembayaran), filter riwayat lengkap, detail transaksi, koreksi penjualan/pembayaran terproteksi dan rekonsiliasi. State laporan/detail/form scoped; keuangan append-only dengan idempotency, batch asli dan snapshot HPP. [Keputusan M4](docs/M4-NOTES.md), [bukti aktual](docs/VALIDATION-M4.md), [status](docs/STATUS.md) serta [matriks persyaratan](docs/REQUIREMENTS.md) adalah acuan terkini. Paragraf checkpoint M1–M3.1 di bawah adalah histori, bukan status aktif. Pemeriksaan M4:165Windows+1benchmark terpisah,120functionalHP+1benchmark, format/analyze/doctor/l10n/debug+release build lulus. Actual ordinaryV6→V7/reopen/hash isolasi lulus tanpa reset; aplikasi0.4.0+6 terbuka pada HP. Release masih development signing; OEM/TalkBack/full release/restore unverified. M5 printer/Drive/backup/restore dan M6 rilis belum diimplementasikan.


Proyek Flutter Android dibuat langsung pada folder utama ini. M1–M2 dipertahankan. **M3 menambahkan kasir/search/scanner keyboard, keranjang persisten, checkout atomik, snapshot harga/HPP, FEFO, piutang/pelunasan, riwayat dasar dan recovery hasil commit.** Development0.3.1+5/schema6. Laporan penuh/pembatalan, printer, backup/Drive, legal/rilis tetap M4–M6. AGENTS.md, START-HERE.md dan SPEC dipertahankan. [Keputusan/file M3](docs/M3-NOTES.md), [hasil aktual/batas pengujian](docs/VALIDATION-M3.md), [status](docs/STATUS.md).

Tambahan sebelum M3: ID/EN langsung tanpa PIN; currency IDR0/USD-MYR-EUR2 terproteksi dan hanya sebelum data keuangan; Money/parser/formatter eksak dan migration V4. [Panduan pemeliharaan](docs/LOCALIZATION-MONEY.md), [kontrak backup](docs/BACKUP-CONTRACT.md), [bukti pemeriksaan](docs/VALIDATION-LOCALIZATION-MONEY.md). Jalankan `flutter gen-l10n` setelah mengubah ARB, jangan mengedit generated localization.

M3.1 menambahkan harga grosir opsional per pcs/pilihan manual di kasir serta input Gudang dus/box dengan exact biaya total dan snapshot penerimaan. [Catatan pemeliharaan M3.1](docs/M31-NOTES.md), [validasi M3.1](docs/VALIDATION-M31.md).

Pemeriksaan ulang data dummy selesai pada lingkup otomatis tersedia:128Windows/84native pass, analyze/format/doctor/debug+release build, fresh DB schema6/FK/integrity, hash-isolation/reopen dan isolated release startup smoke lulus. APK biasa0.3.1+5 dipasang/dibuka pada DB baru. Signing development; full release/OEM/TalkBack/actual restore belum verified. [Bukti terkini](docs/VALIDATION-M31-RECHECK.md), [pembelajaran pengujian](docs/LESSONS-LEARNED.md). Tidak menganggap data dummy sebagai izin umum reset berikutnya.

## Membuka di Android Studio

1. Pasang plugin Flutter/Dart; buka folder yang berisi pubspec.yaml ini, bukan membuat proyek kasir_app lain di dalamnya.
2. Gunakan Flutter stable 3.44.7 dan Dart 3.12.2 (versi yang diperiksa pada mesin ini), Android SDK serta JDK Android Studio. SDK/JDK terdeteksi melalui `flutter doctor -v`.
3. `flutter doctor -v`. Doctor akhir M2 bersih dan seluruh lisensi Android terdeteksi diterima. Bila instalasi lain memperingatkan lisensi, jalankan `flutter doctor --android-licenses`, baca lalu terima yang diperlukan sendiri. Doctor M1 sebelumnya sempat memberi peringatan; bukti lama tetap tersimpan.
4. `flutter pub get`. Commit pubspec.lock untuk versi dependency aplikasi yang dapat direproduksi.
5. Jalankan emulator dari Device Manager atau `flutter emulators --launch Pixel_7` bila AVD tersebut tersedia; sambungkan HP Android jika diperlukan. `flutter devices`, lalu `flutter run -d <device-id>`.

Mode utama offline/lokal. Tidak ada akun/server yang harus disiapkan. M1 tidak mendukung run web; keberadaan Chrome pada doctor bukan bukti plugin sqflite Android berjalan di web. FFI Windows hanya dependency test, bukan distribusi desktop aplikasi.

## Dependency yang dipilih

| Dependency | Versi resolved M1/M2 | Alasan |
| --- | --- | --- |
| Flutter / Dart | 3.44.7 / 3.12.2 stable | SDK terpasang, proyek/build/analyze/test diperiksa dengan versi ini |
| [provider](https://pub.dev/packages/provider) | 6.1.5+1 | DI dan lifecycle state layar, Selector untuk subscription sempit |
| [sqflite](https://pub.dev/packages/sqflite) | 2.4.4+1 | SQLite Android, transaksi dan migration; uji plugin Android terpisah |
| [path](https://pub.dev/packages/path) | 1.9.1 | Path database sesuai platform |
| [uuid](https://pub.dev/packages/uuid) | 4.6.0 | UUID v4 internal, tidak mengandalkan timestamp untuk identitas |
| [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) | 2.4.3 dev | SQL nyata Windows, bukan fake map; native sqlite3 resolved 3.5.2 |
| flutter_test / integration_test / flutter_lints | SDK / SDK / 6.0.0 | Value/controller/widget tests dan sqflite Android regression |
| [cryptography](https://pub.dev/documentation/cryptography/latest/) | 2.9.0 | KDF PIN PBKDF2-HMAC-SHA256 di isolate dan hash idempotensi |
| [timezone](https://pub.dev/packages/timezone) | 0.11.1 | Kalender expiry memakai zona IANA toko, terpisah dari UTC timestamp |
| flutter_localizations / intl | SDK / 0.20.2 | Locale id_ID, termasuk label/tooltip/kontrol bawaan berbahasa Indonesia |

Versi tersebut diterima resolver dan diperiksa pada toolchain saat ini. Paket/SDK yang lebih baru mungkin tersedia; perbarui secara sadar dengan regresi migration, bukan upgrade serentak tanpa bukti.

## Struktur

```text
lib/app/                       composition root dan tema
lib/core/domain/               uang, biaya, quantity, ID, waktu/tanggal
lib/core/pagination/           Page dan helper state paging terbatas
lib/data/database/             koneksi/koordinator, migration v1→v7
lib/data/repositories/         implementasi SQLite dan query parameterized
lib/features/catalog/domain/  Product + repository/filter/cursor
lib/features/sale_history/domain/ SaleTransaction/Item + kontrak riwayat
lib/features/foundation/      startup service/controller dan shell kasir
lib/features/management/      KDF, akses/rate limit, lifecycle dan route/dialog gate
lib/features/inventory/       master/receipt/valuasi/FEFO, gudang/detail/history
lib/features/settings/        pengaturan toko dengan service terproteksi
lib/features/reports/         ringkasan SQL/filter/rincian/reconciliation
lib/features/corrections/     reversal atomik, form PIN/alasan/attestation
test/                         unit/widget dan SQLite FFI nyata
integration_test/             kontrak SQL yang sama pada sqflite Android
docs/                         SPEC, PLAN, STATUS, REQUIREMENTS, arsitektur/skema/bukti
```

## Pemeriksaan

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test --reporter expanded
./tools/test_android.ps1 -DeviceId <ID-HP-dikonfirmasi> -AndroidSdkRoot <SDK> -VerifyOperationalDatabase -TestFiles @('integration_test/database_test.dart','integration_test/management_inventory_test.dart','integration_test/management_ui_test.dart')
flutter build apk --debug
```

Ganti device-id sesuai `flutter devices`. SQL/UI integration memakai database fixture terpisah dan menghapusnya sesudah test; tidak menyuntikkan data contoh pada database kasir. Pesan penolakan downgrade/kegagalan index yang sengaja disuntikkan pada test adalah skenario negatif. Bukti aktual ada pada [VALIDATION-M2](docs/VALIDATION-M2.md) dan checkpoint lama [VALIDATION-M1](docs/VALIDATION-M1.md).

Gunakan **Kelola** untuk membuat nama toko/PIN jika belum ada, catat recovery code di luar perangkat, lalu masuk PIN untuk Gudang/Pengaturan. PIN dikunci ulang saat background atau lima menit tidak aktif. Belum ada consent/legal final pada build review ini. Detail batas PIN, presisi, FEFO, reversal dan scope: [M2-NOTES](docs/M2-NOTES.md).

## Panduan perubahan

- [Arsitektur/lifecycle Provider dan pagination](docs/ARCHITECTURE.md). Tambah state sesuai layar/alur, aturan bisnis di service, SQL di repository; jangan membuat AppProvider serba guna.
- [Skema, presisi dan migration](docs/SCHEMA.md). Kolom baru lewat migration versi, fixture upgrade dengan relasi, dan pemeriksaan non-destructive.
- Warna/font di lib/app/theme.dart; format rupiah dan skala biaya di lib/core/domain/value_types.dart. Jangan mengubah skala database yang sudah dipakai tanpa migration.
- Ambang stok default 5, dapat diubah/dinonaktifkan di form barang; warning memakai stok layak jual. Ledger tidak ditimpa ketika master/harga diubah.
- Integrasi printer/Drive akan dipisahkan dari format struk/backup coordinator pada M5. Konfigurasi credential, Bluetooth, dan hardware belum tersedia; jangan memasang token dalam widget.
- Isi/legal offline, identitas pengembang/kontak/URL, signing release, OAuth/Play Store guide dan regresi rilis masih M6. Opt-out Auto Backup/extraction minimal dipasang M2 sebelum menyimpan verifier PIN; uji transfer OEM/rilis masih pending. Package ID `com.example.kasir_app` dan signing debug adalah development. Belum ada artifact rilis/publikasi ataupun panduan legal final.

Mulai review dari [STATUS](docs/STATUS.md) dan [REQUIREMENTS](docs/REQUIREMENTS.md). Setelah review M4, tahap berikutnya M5 hanya atas instruksi pengguna; jangan melanjutkannya otomatis.


## Pengujian HP yang memisahkan data pengguna

Gunakan `./tools/test_android.ps1 -DeviceId <ID-HP> -AndroidSdkRoot <path-SDK>` setelah pengguna siap. Script memverifikasi package APK fixture, memberi flag isolasi dan --no-uninstall. **Jangan gunakan bare flutter test integration_test pada package operasional:** Flutter default-uninstall. Lihat [insiden M3.1](docs/INCIDENT-M31-ANDROID-TEST.md); data dummy lama tidak ditemukan dan tidak dipulihkan. Pengguna kemudian mengotorisasi fresh DB pada tindak lanjut M3.1; M4 mempertahankan baseline tersebut tanpa reset. Izin reset lama bukan izin umum reset berikutnya.


[Referensi pembelajaran dan runbook](docs/LESSONS-LEARNED.md) harus dibaca sebelum pengujian Android. Pengguna mengizinkan reset DB dummy pada tindak lanjut M3.1, belum data penting sampai M6 selesai. Reset explicit via tools/reset_dummy_android_db.ps1 -ConfirmDummyData, tidak merupakan cleanup rutin. TestAndroid -VerifyOperationalDatabase memeriksa hash DB ordinary quiescent sebelum/sesudah suite; membutuhkan debug app dan perangkat idle yang diizinkan.
