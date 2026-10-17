# Status proyek

**12 Oktober 2026 — M2 selesai, siap review pengguna.** M1 telah diterima pengguna. Tulisan `M@` dikonfirmasi sebagai M2; hanya M2 dilanjutkan. Versi aplikasi development **0.2.0+2**, skema **3**. Pekerjaan berhenti setelah checkpoint ini.

| Milestone | Status |
| --- | --- |
| M1 — Fondasi/arsitektur/skema/pagination | Diterima pengguna; regresi tetap lulus |
| M2 — PIN/persediaan/HPP/pengelolaan | Implemented dan verified pada Windows SQLite FFI + emulator Android, siap review |
| M3 — Kasir/checkout/piutang/recovery | Pending, belum mulai |
| M4 — Laporan/koreksi/performa | Pending, belum mulai |
| M5 — Printer/notifikasi/backup/restore | Pending, belum mulai |
| M6 — Penyiapan/legal/rilis | Pending, belum mulai |

## Lingkup hasil

M2 sudah menyediakan Kelola/PIN, Gudang (Barang/Kategori/Supplier), tambah/ubah/arsip/pulihkan, kategori/alias/peringatan, dropdown relasi/tambah cepat, stok awal/receipt dengan supplier opsional, batch, stok opname/pengeluaran, reversal receipt, undo harga/arsip, riwayat stok/harga dan settings toko/zona waktu. Kasir tetap shell: pencarian, keranjang, Bayar/Hutang belum operasional. Belum dapat dipakai untuk menjual barang.

FEFO/removal cost adalah primitive domain yang diuji untuk digunakan M3, bukan checkout yang diam-diam sudah dikerjakan. Total value/quantity moving average, periodisasi/cost snapshots dan aturan append-only disiapkan; laporan penjualan/profit/piutang belum tersedia.

## File penting dan keputusan

- `lib/app/app_services.dart`, `kasir_app.dart`: satu DatabaseCoordinator shared, dependency service; state fitur scoped. FoundationController hanya readiness, ManagementSessionProvider hanya auth/lifecycle; InventoryProvider/ProductDetailProvider/SettingsProvider masing-masing punya state layar sendiri.
- `lib/features/management/application/`: PBKDF2-HMAC-SHA256 600.000 putaran/256 bit, salt CSPRNG 32 byte, recovery random 128 bit/verifier domain-separated, empat digit String, konfirmasi, rotasi lewat PIN lama/recovery, tanpa default/plaintext. Rate-limit persisted dimulai gagal ke-3 dengan jeda 5 detik lalu progresif. Session idle default lima menit memakai monotonic clock; pointer/key/soft IME activity memperpanjang; background mengunci, service memeriksa izin sebelum operasi/commit.
- `lib/features/inventory/application/inventory_service.dart`: SQL/aturan master dan stock di service, dbTxn atomik. SKU manual/UUID otomatis, barcode unique termasuk arsip/nullable, supplier nullable pada receipt. Key+payload hash idempotensi. Stock revision tersendiri menjaga dependency reversal; revision umum menjaga edit/undo.
- `lib/features/inventory/domain/stock_rules.dart`: biaya micro-rupiah 10^6, moving average dari total value/physical quantity. Removal proporsional half-up, pengurangan terakhir mengambil seluruh residu. FEFO dated dahulu/undated terakhir; expired excluded mulai tanggalnya. Receipt baru/harga tidak menghitung ulang fakta sale lama.
- `lib/core/time/store_clock.dart`: waktu data UTC, kalender expiry/display memakai IANA toko default Asia/Jakarta; clock monotonic terpisah untuk idle session.
- `lib/features/inventory/presentation/` dan `settings/presentation/`: form/progress/error/list/detail/history/dropdown, refresh setelah commit, keyset/bounded cache. Dialog memiliki auth gate dan controller tetap hidup sampai overlay selesai ditutup. Undo harga diperbarui langsung pada detail.
- `lib/data/database/schema.dart`: V3 additive, tidak mengubah V1/V2; stock_revision/last_attempt_at/inventory_operations/referensi ledger/price revision dan index. FK, schema snapshots dan SaleTransaction/sale_transactions + SaleTransactionItem/sale_transaction_items tetap konsisten.
- `android/.../AndroidManifest.xml`, `res/xml/*`: opt-out system backup/extraction minimal sebelum menyimpan data sensitif. Ini prasyarat keamanan M2, bukan backup/restore/legal final M5/M6.
- README, ARCHITECTURE, SCHEMA, PLAN, REQUIREMENTS, [M2-NOTES](M2-NOTES.md), [VALIDATION-M2](VALIDATION-M2.md), docs/evidence diperbarui. Matriks mempertahankan **244 ID klausul SPEC**, 13 bukti M1 dan 10 bukti M2; kebutuhan akhir yang belum seluruhnya terpenuhi tetap partial/pending.

## Pemeriksaan aktual akhir

| Perintah | Hasil |
| --- | --- |
| `flutter doctor -v` | **No issues found**, seluruh lisensi Android kini terdeteksi diterima; [log](evidence/m2-doctor.log) |
| `flutter pub get` | Berhasil; Provider/sqflite tetap versi M1, cryptography 2.9.0 dan timezone 0.11.1 ditambahkan |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0, **55 files, 0 changed**; [log](evidence/m2-format.log) |
| `flutter analyze` | Exit 0, **No issues found**; [log](evidence/m2-analyze.log) |
| `flutter test --reporter expanded` | Exit 0, **40 test lulus**: 23 regresi M1 + 14 SQL/KDF M2 + 3 PIN layout; [log](evidence/m2-tests.log) |
| `flutter test test/shell_test.dart test/management_ui_test.dart --reporter expanded` | Exit 0, **8 layout test lulus ulang** setelah locale Indonesia; [log](evidence/m2-locale-layouts.log) |
| `flutter test integration_test/management_inventory_test.dart -d emulator-5554 --reporter expanded` | Exit 0, **14 skenario SQL/KDF M2 lulus**; [log](evidence/m2-android-sql.log) |
| `flutter test integration_test/management_ui_test.dart -d emulator-5554 --reporter expanded` | Exit 0, **1 alur UI Android lulus**: PIN/setup, category/dropdown, product/receipt/average, edit/undo, soft IME idle renewal, lifecycle lock; [log](evidence/m2-android-ui.log) |
| `flutter build apk --debug` | Exit 0, APK aplikasi final setelah test APK, **22,0 s** Gradle menurut output; [log](evidence/m2-build-debug.log) |

Flutter stable 3.44.7/Dart 3.12.2, Windows 11 26H2, JDK Android Studio 21.0.10, Android SDK build-tools 36.0.0/platform 36.1. Emulator Pixel_7 sebagai emulator-5554, Android 17/API 37/x64. M1 pernah mencatat warning lisensi; doctor M2 kini bersih. Bukti M1 historis tetap pada VALIDATION-M1 dan log m1-*.

## Batas bukti, hambatan, dan berikutnya

Tidak ada hambatan implementasi/pemeriksaan M2 yang tersisa pada target yang diuji. Belum ada HP fisik, release/profile KDF, TalkBack/manual seluruh UI, compatibility semua versi Android/iOS/web, transfer backup semua OEM, benchmark besar, atau build release/AAB/signing produksi. PIN empat digit tidak mengenkripsi database; dokumentasi batas dan recovery ada di M2-NOTES. KDF debug nyata dapat memakan beberapa detik (lihat latency aktual log), sehingga profil HP/rilis tetap perlu sebelum distribusi.

UI lifecycle test mengirim urutan event Flutter yang valid pada emulator; tidak diklaim sebagai uji Home/force-stop semua OEM. SQL/Migration menggunakan SQLite nyata, bukan fake. Clock/fixture sengaja injectable agar batas kalender/idle terukur. Data test selalu terpisah dari database aplikasi produksi.

Milestone selanjutnya **M3 hanya setelah instruksi pengguna**: search/scanner/debounce, cart/draft/undo, checkout atomik/idempotent/snapshot harga-HPP/batch/ledger, pembayaran/piutang/alokasi/recovery. Reuse satu coordinator dan cost/FEFO primitives; checkout wajib mengubah revision/stock_revision supaya reversal M2 tetap aman. Kasir tidak memerlukan management PIN untuk penjualan sah. Jalankan regresi M1/M2, tambah migration bila perlu, dan pertahankan ketepatan Snapshot/ledger. M4–M6 tidak dimulai otomatis.

