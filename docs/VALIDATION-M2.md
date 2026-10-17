# Bukti validasi M2 — 12 Oktober 2026

Lingkup: management/PIN, master, persediaan/batch/HPP primitive, koreksi stock, UI Gudang/settings. M3–M6 tidak diimplementasikan. Seluruh hasil berikut berasal dari perintah aktual; source dan fixture tersimpan, log final di docs/evidence.

## Lingkungan dan hasil

Windows 11 26H2, Flutter stable 3.44.7/Dart 3.12.2. Android JDK 21.0.10/SDK build-tools 36.0.0/platform 36.1, AVD Pixel_7 → emulator-5554 Android 17 API 37 x64. Windows SQL adalah sqflite_common_ffi 2.4.3/sqlite3 package 3.5.2 native, Android SQL plugin sqflite 2.4.4+1. App development 0.2.0+2/schema 3.

| Perintah | Exit / hasil / bukti |
| --- | --- |
| `flutter doctor -v` | 0; No issues found/All Android licenses accepted. [Log](evidence/m2-doctor.log) |
| `flutter pub get` | 0; dependencies resolved, cryptography 2.9.0/timezone 0.11.1 |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 0; 55 files/0 changed. [Log](evidence/m2-format.log) |
| `flutter analyze` | 0; No issues found. [Log](evidence/m2-analyze.log) |
| `flutter test --reporter expanded` | 0; **40 passed**. [Log](evidence/m2-tests.log) |
| `flutter test test/shell_test.dart test/management_ui_test.dart --reporter expanded` | 0; **8 layout passed ulang** setelah locale id_ID/delegates SDK/intl; bukan 8 skenario unik tambahan. [Log](evidence/m2-locale-layouts.log) |
| `flutter test integration_test/management_inventory_test.dart -d emulator-5554 --reporter expanded` | 0; **14 passed**, real SQLite + KDF. [Log](evidence/m2-android-sql.log) |
| `flutter test integration_test/management_ui_test.dart -d emulator-5554 --reporter expanded` | 0; **1 passed**, full UI flow. [Log](evidence/m2-android-ui.log) |
| `flutter build apk --debug` | 0; app-debug.apk aplikasi final, **22,0 s** Gradle (bukan latency query). [Log](evidence/m2-build-debug.log) |

APK di build/app/outputs/flutter-apk/app-debug.apk dibuat ulang sesudah test APK. Tidak menjalankan release/AAB/signing produksi atau publikasi. Doctor warning lama M1 tidak berlaku pada pemeriksaan akhir M2; hasil historis tetap tersimpan.

## Bukti yang diuji

Suite M2 sama pada Windows disk fixture dan Android fixture terpisah (tidak mengisi kasir produksi):

1. Service auth enforcement sebelum mutate; idle lima menit, queued write ditolak setelah lock.
2. Monotonic session deadline tidak berubah ketika wall clock maju 400 hari; batas 299.999/300.000 ms.
3. PIN `0001`, gagal berulang/progressive delay, reopen tetap diblokir, wall-clock rollback tidak menghapus rate limit, successful retry reset count.
4. Configure/confirmation/no default, salt random/verifier bukan plaintext, recovery 128-bit ditampilkan sekali, rotation dengan recovery dan PIN lama; secret/kode lama ditolak.
5. Master CRUD/category NULL/generated distinct SKU, archived barcode `000009` conflict, category in-use archive blocked, supplier contact `00123` teks; receipt dari dua supplier dan supplier arsip tetap direferensikan, supplier arsip tidak menerima receipt baru.
6. 10×8.000 + 10×10.000 → physical qty 20/value 180.000/average 9.000; removal primitive 3 unit → cost 27.000. Harga jual baru tidak mengubah value, retry receipt identik tidak menambah stock, payload berbeda dengan key sama ditolak.
7. Trigger fault stock_history membatalkan receipt/item/batch/inventory_operation/product value/history/audit seluruhnya; retry setelah fault dihapus berhasil.
8. Reversal receipt memulihkan exact prior value/quantity, idempotent, price/name edit diperbolehkan; movement berikutnya memblokir reversal. Ledger/batch/product direkonsiliasi.
9. Jakarta UTC 17:00 Oct 12 = calendar Oct 13; expired excluded mulai tanggalnya, masih physical, future + undated saleable/warning, upcoming window 5 hari, FEFO dated/undated ordering. Waste expired mengurangi physical/value; batch habis tidak masuk warning.
10. Count adjustment/waste/residual micro rounding; zero stock = zero value; gain empty stock requires cost. Ledger qty/value dan batch totals cocok.
11. Price/archive undo/restore, expected revision serta window; later edit tidak tertimpa, time expired ditolak, price history append-only.
12. Settings names/contact text/IANA zone validated, invalid zone/auth rejected, opt-in backup tetap mati.
13. Duplicate master names/literal prefix `%`, wrong cursor context rejected; 54 same-timestamp batch/history dipaginasi 50+4 tanpa duplicate/loss; ledger reconciliation.
14. Additive v2→v3 preserves UUID/barcode zeros/sale facts/draft relations; FK check clean/default stock_revision. Regresi M1 juga menguji v1→current dan migration rollback/data preservation.

40 unit/widget/SQL Windows terdiri dari 23 regresi M1, 14 M2 di atas, dan 3 PIN layout pada 320×568, 1024×768, 568×320 dengan teks 2x/keyboard inset. PIN string zero, masking default/toggle dan no overflow diperiksa; ini bukan uji seluruh TalkBack/UI akhir.

Android UI menggunakan database temporary sendiri: buat PIN/name/recovery acknowledgement, unlock, create category lewat form, pilih kategori dari dropdown, create product/initial stock 10×8.000, receipt 10×10.000 supplier kosong, lihat average 9.000, edit price 15.000 dan undo ke 12.000. Fake clock maju 4 menit setelah form dibuka lalu soft-keyboard edit memperpanjang idle melewati total 6 menit; back membuang edit yang belum disimpan. Flutter lifecycle urutan inactive→hidden→paused lalu hidden→inactive→resumed mengunci dan tidak auto-unlock. Mengirim event pada emulator tidak diklaim sebagai pengujian tombol Home/force-stop OEM fisik.

## KDF dan batas hasil

PBKDF2-HMAC-SHA256 600.000 rounds/256 bit benar-benar dijalankan, termasuk unlock/rotation; tidak memakai fake crypto atau parameter murah demi test. Verifier fixture synthetic dicache hanya untuk setup suite, setiap unlock tetap KDF produksi. Satu derive yang dicatat: **2.469 ms Windows**, **5.705 ms Android emulator**, mode test/debug, lingkungan beban tidak terkontrol. Ini satu sampel, bukan release profiling/benchmark HP atau janji latency. Work di isolate menjaga main UI responsif; sesi tidak memakai wall clock. Param dipilih berdasarkan [OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html); profil perangkat pengguna/rilis tetap pending.

## Kegagalan yang diperbaiki

- Braces/import/static info diperbaiki; analyzer final bersih.
- Null pada whereArgs dibuang dengan predicate barcode kondisional; storage barcode NULL tetap sah.
- Protected async load mengembalikan error melalui Future sehingga controller/test dapat menanganinya konsisten.
- Test scroll memakai scrollable vertikal; EditableText mempunyai scrollable horizontal tersendiri. Finder menunggu route transition dan memakai target ListTile agar tidak salah mengambil EditableText dari route yang sedang ditutup.
- Dialog controller sempat disposed saat closing animation; DialogRoute.completed kini memastikan overlay selesai sebelum controller dilepas. Quick-add menyimpan text input sebelum await. Salah satu bug ini ditemukan hanya pada Android UI nyata, bukan SQL unit test.
- Dropdown LayoutBuilder tidak dapat dipakai sebagai child intrinsic AlertDialog; dihapus, option view dibatasi lebar/tinggi tanpa intrinsic conflict.
- Price undo sebelumnya tidak refresh detail setelah route form ditutup; UndoToken sekarang ditangani oleh pemilik detail dan error ditampilkan pada route yang masih mounted.
- Lifecycle fixture memakai urutan Flutter valid, bukan langsung resumed↔paused.
- Idle deadline memakai monotonic clock; soft IME edits tidak selalu menimbulkan KeyEvent sehingga ManagedTextField mencatat activity tanpa menyimpan teks.

## Unverified/pending

HP fisik, profile/release KDF, TalkBack/manual semua layar/orientasi, kompatibilitas seluruh OS/SQLite target, transfer system backup OEM, stress/benchmark 10k/100k, data produksi eksternal, scanner/checkout/receivables, laporan, printer/notifikasi/Drive/backup/restore, legal/onboarding dan release/AAB masih pending sesuai milestone. XML backup opt-out dikompilasi; bukan bukti seluruh transfer sistem sudah diuji. Tidak ada requirement akhir ditandai selesai hanya berdasarkan scaffolding/schema.

