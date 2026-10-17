# Validasi Localization/Money — 12 Oktober 2026

Versi development 0.2.1+3, schema V4, Flutter 3.44.7/Dart 3.12.2. Windows SQLite FFI dan emulator Android Pixel_7/emulator-5554 API37 diuji terpisah. Setiap fixture terisolasi; tidak membuka/menghapus database pengguna atau membuat ulang proyek. Driver sqflite tetap, bukan SQLCipher.

## Pemeriksaan dan bukti

| Perintah | Hasil aktual | Bukti |
| --- | --- | --- |
| `flutter gen-l10n` | Exit 0; ARB ID/EN, generator SDK, tanpa edit generated manual | [gen](evidence/locale-gen.log) |
| `flutter doctor -v` | Exit 0; No issues found, lisensi Android diterima | [doctor](evidence/locale-doctor.log) |
| `flutter analyze` | Exit 0; No issues found | [analyze](evidence/locale-analyze.log) |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 73 files/0 changed | [format](evidence/locale-format.log) |
| `flutter test --reporter expanded` | 64 lulus: 40 regresi M1/M2 + 12 Money + 6 locale/UI + 6 SQL | [tests](evidence/locale-tests.log) |
| `flutter test integration_test/locale_currency_test.dart -d emulator-5554 --reporter expanded` | Exit 0; 6 skenario SQL nyata | [SQL baru](evidence/locale-android-sql.log) |
| `flutter test integration_test/management_inventory_test.dart -d emulator-5554 --reporter expanded` | Exit 0; 14 regresi SQL/KDF M2 nyata | [SQL M2](evidence/locale-m2-android-sql.log) |
| `flutter test integration_test/localization_ui_test.dart integration_test/management_ui_test.dart -d emulator-5554 --reporter expanded` | 2 alur UI Android lulus | [UI final](evidence/locale-android-ui-final.log) |
| `python tools/audit_localization.py` | Exit 0; 213 key bilingual, metadata/placeholder cocok, 184 referensi static valid, 244 ID lama tetap unik | [audit](evidence/locale-audit.log) |
| `flutter build apk --debug` | Exit 0; APK aplikasi final sesudah test APK, Gradle **17,9 s** | [build](evidence/locale-build-debug.log) |

SDK/plugin dependency di pubspec.lock; intl 0.20.2 menjadi direct dependency, provider/sqflite/cryptography/timezone tetap. SDK memberitahu versi paket lebih baru tersedia; tidak melakukan upgrade dependency di luar kebutuhan ini.

## Skenario

- 8 kombinasi locale×currency round-trip angka tanpa simbol: 0, 1 minor, 15, 1550, IDR12000, nominal besar, ceiling dan ceiling-1. USD0.01/15/15.50 dan id15,50 tepat. Simbol/kode tidak diparse sebagai nominal. Legacy signed64 ditampilkan tanpa kehilangan digit; input/arithmetic baru menjaga ceiling dan quantity/total overflow.
- Money tambah/kurang/cost-round menolak metadata mismatch, negatif, scale tidak sesuai katalog dan overflow. Cost micro per minor tidak tercampur dengan currency_scale; moving average/removal/residu M2 tetap lulus. USD receipt 3×0.01 menyimpan value 3.000.000 micro dan price15.50 =1550 minor.
- Grouping/desimal valid, grouping lintas locale ambigu, eksponen, whitespace/simbol, negatif, desimal berlebih, kosong dan overflow diuji. Formatter mengetik major units, tidak cents shifting; insertion/cursor/selection, backspace/Delete separator, paste dengan net length sama dan composing diuji.
- Resolver id/en/unsupported fallback en/saved priority; public language persistence/reopen/no-PIN; currency default/scale/persistence/auth. English tidak memilih USD. Form locale switch menjaga navigator/controller, fraction/trailing decimal/kosong/selection, composing, canonical value, unmount/remount dan submit normalization. Snackbar yang masih tampil mengubah copy/Undo dan tetap single-use.
- Guard financial fixtures: produk termasuk arsip, inventory value, receipt nol, sale, payment, draft berharga, price/stock history. Service dan SQL trigger menolak retag. Harga nol juga memblokir karena sudah merupakan Money terikat; kategori/supplier tanpa harga tidak memblokir. Header receipt/ledger/operation metadata, foreign key, incompatible cost/service input dan repository Money diuji.
- V3→V4 mempertahankan nilai setiap kolom produk lama, stok/HPP/value/ID, sale36000/IDR0, receipt/draft/header, footer/alamat pengguna; tanpa x100. reason_key hanya pesan sistem. Conflict kolom buatan memaksa kegagalan V4 setelah sebagian ALTER; rollback mempertahankan user_version3, kolom settings lama dan nominal12000. Error SQL yang terlihat di log pada kasus itu **sengaja dipicu dan ditangani**, bukan kegagalan suite.
- PIN ID/EN pada 320×568, text2x/keyboard160; currency selector Inggris dan form stock pada kondisi yang sama, scroll sampai target hit-testable dan warning dibuka. Regresi M1 mencakup shell sempit/lebar/landscape2x, M2 PIN layout tetap lulus. Ini tidak membuktikan seluruh kombinasi UI/TalkBack.
- UI Android baru: language public tanpa membuka session, PIN unlock, USD dropdown/scale, live nominal15.50→15,50/nama asli/session, stock awal0.01, language setelah ada fakta, EUR ditolak dan dropdown tetap USD. UI M2: setup/leading-zero PIN, category/picker, product/receipt/average, price undo, soft-IME activity dan simulated lifecycle lock.

## Kegagalan awal yang diperbaiki dan batas bukti

Generator awal menolak key keyword `continue`; diganti continueAction di ARB lalu generate ulang. Test lama tanpa locale eksplisit mengharapkan Indonesia padahal fallback baru Inggris; locale fixture dibuat eksplisit. Label ID lama mengandung Rp sehingga dobel suffix currency; Rp tetap dihapus dari ARB label. Dropdown penolakan tidak boleh mengandalkan busy frame; version reset dan committed snapshot menghilangkan stale selection/race. Money controller memegang codec ketika field offscreen/unmounted. Fixture SQL/KDF layout disiapkan di luar fake widget clock; target lazy/keyboard digulir hingga hit-testable. Seluruh kegagalan yang bisa diperbaiki diselesaikan sebelum checkpoint.

Pada checkpoint 12 Oktober, belum diuji HP fisik, clipboard/IME keyboard OEM/manual seluruh UI, TalkBack, seluruh versi Android/iOS/web, release/profile/AAB/signing produksi, printer/Drive/restore arsip nyata. Pembaruan laporan manual pengguna dan otomatis HP 13 Oktober dicatat terpisah di [VALIDATION-PHYSICAL](VALIDATION-PHYSICAL.md). Widget composing/cursor memakai event sintetis; integration enterText memakai Flutter test input, bukan klaim kompatibilitas setiap keyboard OS. Lifecycle M2 merupakan urutan event valid, bukan uji Home/force-stop semua OEM. KDF/latency rilis bukan benchmark tahap ini. Backup/restore hanya kontrak M5, bukan fitur terverifikasi. M3–M6 tetap pending.
