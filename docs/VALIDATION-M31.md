# Validasi M3.1 — hasil aktual dan batas bukti

13 Oktober 2026. Windows, Flutter3.44.7/Dart3.12.2, sqflite_common_ffi untuk SQL Windows. Aplikasi0.3.1+5/schema6. Fixtures sementara/m31_* terpisah dari kasir_app.db; **klaim no-uninstall dikoreksi oleh insiden default cleanup Flutter**, lihat INCIDENT-M31-ANDROID-TEST. Kebutuhan §19, keputusan M31-NOTES.

## Otomatis Windows

- Gen localization: `flutter gen-l10n`, exit0, m31-gen.log. Audit307 bilingual keys,259 static references,244 original requirement IDs, exit0, m31-audit.log. Label quantity/prices/preview/warnings/error ID–EN.
- Formatter: `dart format lib test integration_test`, exit0;106 files/0 changed/0.29s, m31-format-final.log. Pass sebelumnya1 changed tetap di m31-format.log.
- Analyzer final: `flutter analyze --no-pub`, exit0/No issues/3.4s, m31-analyze-final.log. Pass sebelumnya exit0/64.9s bersamaan regression Windows di m31-analyze.log.
- Focused: `flutter test test/stock_input_test.dart test/wholesale_packaging_sql_test.dart --reporter expanded`, **16 pass**, exit0/00:27 pada m31-targeted-final.log (sebelum tambahan undo/fault injection).
- Regression: `flutter test --reporter expanded`, **123 pass**, exit0/01:02 pada m31-tests-windows.log, termasuk103 regresi M1–M3 +4 value/formatter +13 SQL M3.1 +3 widget/checkout lock. **Final124 pass**, exit0/01:02, m31-tests-windows-final.log:103 regresi +4 unit +14 SQL M3.1 +3 widget. DTO shared PricingMode/history repository membaca snapshot yang sama; fault injection receipt lulus.
- Debug build: `flutter build apk --debug --no-pub`, exit0/Gradle9.1s, m31-build-debug.log (sebelum DTO shared enum terakhir). **Final** setelah shared DTO:exit0/Gradle7.2s, m31-build-debug-final.log; APK build/app/outputs/flutter-apk/app-debug.apk. Belum dipasang pada HP selama M3.1. Debug bukan release/AAB/signing.

SQL suite memeriksa nullable/config defaults, typed wholesale history/undo, mode scan/quantity/reopen/undo/payment intent, berubah/hilangnya harga, exact200pcs/600000 receipt cost, snapshot override/master independen, USD/MYR micro-minor/residue, penjualan/opname/reversal serta ledger/batch/value reconciliation, proteksi/zero/overflow/idempotency, V5→V6 semua kolom lama/defaults, migration failure rollback, DB fixture tertutup→copy→reopen preserving facts. Tambahan fault injection memaksa kegagalan stock_history setelah update stok untuk membuktikan receipt/items/batch/stock/value/operation rollback; retry key yang sama boleh setelah rollback.

Widget tests ID/EN320×568/text2×/keyboard inset160 memeriksa preview serta invalid paste tidak diubah menjadi quantity lain. Provider test menahan checkout pada validated stage: add/quantity/pricing/remove ditolak selama saving, snapshot final wholesale tetap. M3 layout/cursor/SQL fault/recovery/payment tests merupakan regresi, bukan sertifikasi OEM.

## Kegagalan yang diperbaiki

- m31-analyze-initial.log exit1: const migration list tidak bisa memakai for serta lint blok. Diubah getter list dan blok eksplisit; perbaikan lint pertama CLI menolak dua direktori (m31-fix.log diulang dengan satu root).
- m31-targeted-initial.log: fixture management_credentials memakai created_at yang tidak ada; fixture diperbaiki.
- m31-targeted-retest.log: fixture legacy sale lupa draft_id NOT NULL; reference diperbaiki. Kegagalan fixture membuat cleanup terkunci pada run tersebut; successful retest menutup/menghapus fixture normal.
- m31-tests-windows-initial.log:121 pass/1 fail; assertion M3 membandingkan semua key map produk lama dengan schema terbaru. Tetap menguji setiap nilai lama, tambah assertion kolom V6 NULL/pcs; full retest123 pass.
- Log intentional duplicate column/currency/cashier_state adalah fault injection migration yang memang diharapkan; tidak mengklaim semua log kosong. Tidak menghapus hasil failure untuk menyamarkan exit code.

## HP fisik — hasil M3.1, regresi sedang berjalan

Pengguna menyatakan **HP siap, mulai pengujian** setelah checkpoint Windows. `flutter devices` exit0 memilih **24069PC21G / 7f0edea0 / Android16 API36 arm64** secara eksplisit, m31-devices.log. Tidak mengganti ke emulator. Seluruh fixture m31_integration_* / m31_ui_* terpisah dari kasir_app.db; DB fixtures terpisah, tetapi APK masih berbagi package operasional sehingga default-uninstall runner menyasar data pengguna.

`flutter test integration_test/wholesale_packaging_sql_test.dart integration_test/wholesale_packaging_ui_test.dart -d 7f0edea0 --reporter expanded`: **14 SQL pass,1 UI fail**, exit1/reporter01:57, m31-android-initial.log. SQL termasuk V5→V6 pelestarian/defaults/rollback dan snapshot-copy lulus Android. Duplicate column pack_size adalah intentional fault migration yang expected. UI gagal karena helper hanya menggulir ke bawah menuju Stok awal yang ada di atas.

Ulang UI setelah reset scroll ke awal: m31-android-ui-retest.log exit1/reporter00:43; seluruh stok awal/restock/opname dan valuasi melewati assertion, lalu helper pageBack mencari tooltip Inggris saat UI Indonesia. Diganti finder BackButton. Ulang berikutnya m31-android-ui-final.log exit1/reporter01:02; mode/scan/qty/draft/live ID→EN/45000 debt-preview melewati assertion, helper kehilangan tombol submit ketika caret masih fokus. Ditambahkan keyboard Done sebelum scroll submit. Assertion bisnis tidak dikurangi, tidak mengubah kode aplikasi untuk menyesuaikan fixture.

**Ulang final UI: exit0/1 pass/reporter01:04**, m31-android-ui-success.log. Alur stok awal5dus×40=200pcs/600000cost → restock240 → opname200/600000valuation → scan3/toggle/scan4/qty5/draft reopen → live Inggris/partialpaid5000 → sale50000/HPP15000/snapshot wholesale10000perpcs lulus; takeException(null), FK check kosong. Ini native input sintetis, bukan keyboard/scanner OEM atau laporan manual pengguna.

**15 kasus unik M3.1 lulus melalui SQL run utama dan retest UI**, bukan mengklaim run awal exit0. Regresi native tercatat33 pass/1 load fail pada m31-android-regression.log lalu interrupted; m31-android-isolated.log30SQL+2UI melewati assertions lalu interrupted. Total65 kasus regresi unik melewati assertions, tetapi package lama/default uninstall menyebabkan insiden; ini bukan bukti data operasional dipertahankan.

## Manual dan pemeriksaan belum dilakukan

MAN-USER-01: pengguna sebelumnya melaporkan alur yang dicoba di emulator dan HP berjalan baik, tanpa rincian; laporan mendahului M3.1 dan tidak memverifikasi fitur baru. Tidak ada pengujian manual M3.1 yang dilaporkan.

OEM keyboard/clipboard/scanner, TalkBack, lifecycle/power-loss semua OEM, release/profile/AAB/performance/signing, printer hardware, arsip restore/manifest/logo/WAL/safety recovery/Drive tetap unverified/pending. Migration dan copy fixture tertutup bukan restore produksi. Data tidak dikirim keluar aplikasi. M4–M6 belum dikerjakan.


## Insiden runner dan koreksi penting

Regresi7 suite semula memakai package operasional/default --uninstall=true. Run mencatat33 pass/1 load failure (INSTALL_FAILED_USER_RESTRICTED untuk cashier_sql), lalu dihentikan saat mengetahui uninstall otomatis. Data kasir_app.db tidak ditemukan, metadata package firstInstallTime=lastUpdateTime2026-10-13 03:46:28. User tidak memiliki backup; tidak ada pemulihan berhasil yang diklaim.

Usaha deteksi target-path pertama salah karena generated listener; m31-android-isolated.log masih package operasional dan dihentikan. 30 SQL M3+2 UI melewati assertions pada run itu, tetapi nama isolated tidak membuktikan pemisahan.

Koreksi: explicit --dart-define=KASIR_INTEGRATION_TEST=true, applicationId.integration, --no-uninstall, aapt APKidentity sebelum install, Gradle fail-closed test-entrypoint tanpa flag, tools/test_android.ps1. m31-isolated-apk-identity.log membuktikan package fixture; m31-safe-installed-identity.log dataDir=/data/user/0/com.example.kasir_app.integration. Uji aman M3.1 **exit0**,14 SQL01:36 dan1UI01:03, m31-android-safe.log. Script memakai flag fixture + --no-uninstall, verified aapt dan installed dataDir.integration. Klaim data pengguna dipertahankan tidak boleh dipakai; fixture migration/copy bukan pemulihan database operasional.


## Pemeriksaan akhir sesudah koreksi workflow

- Guard negatif lokal: build integration target tanpa flag ditolak dengan pesan Native tests require..., expected exit1, m31-isolation-guard-negative.log. Tidak ada install untuk probe ini.
- Package fixture verified aapt/application label kasir_app tests/activity fully qualified; ordinary APK verified com.example.kasir_app/0.3.1+5/label kasir_app. Detektor target-path tidak menjadi safety control.
- Format106 files/0 changed/0.33s dan analyze No issues/4.6s/exit0, m31-format-physical-final.log/m31-analyze-physical-final.log. Windows124 pass masih bukti kode bisnis; perubahan akhir pada test helper/Android workflow sudah native verified.
- Ordinary debug APK build16.2s/exit0, m31-build-normal-after-isolation.log; direct adb install-r Success, m31-install-normal-no-launch.log. Metadata version0.3.1/code5 diperiksa. **Tidak am start/launch**, tidak menginisialisasi DB baru; pencarian kasir_app.db sesudah install tetap kosong. Normal startup/production migration/data integrity tidak dapat diklaim.
- Log historis native UI: exit-info mengidentifikasi PID7624 milik fixture integration, force-stop oleh runner setelah completion. Snapshot1602 lines/174314bytes dari akhir UI,0 fatal/unhandled/Flutter framework errors,0 DB errors; terdapat23 InputConnection warnings/60 Spannable errors, dicatat tanpa menganggap keyboard OEM lulus. File m31-logcat-safe-ui.log/m31-fixture-exit-info.log. Upaya pidof live gagal karena runner sudah menghentikan process; tidak mengambil log global tanpa scope.
- Semua manual/OEM/TalkBack/release/actual restore tetap unverified. User no backup; data lama missing/unrecovered. Tidak ada otomatisasi/restore/normal-startup yang mengesahkan preservation.
