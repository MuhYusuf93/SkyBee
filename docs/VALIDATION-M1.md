# Bukti validasi M1 — 12 Oktober 2026

Lingkup: fondasi saja. Perintah dijalankan nyata pada workspace utama. Hasil akhir di bawah menggantikan percobaan awal yang gagal dan telah diperbaiki; skenario negatif yang sengaja disuntikkan tetap bagian test.

## Lingkungan dan perintah

| Perintah | Hasil aktual / bukti |
| --- | --- |
| `flutter create --platforms=android --project-name kasir_app --org com.example .` | Berhasil bootstrap di root; dokumen awal dipertahankan |
| `flutter doctor -v` | Flutter 3.44.7 stable/Dart 3.12.2; Android SDK/JDK tersedia; lisensi sebagian belum diterima. [Log](evidence/m1-doctor.log) |
| `flutter devices`, `flutter emulators`, `flutter emulators --launch Pixel_7` | Awal hanya Chrome/Edge; AVD sudah tersedia lalu dijalankan, emulator-5554 Android 17 API 37 x64 terdeteksi |
| `flutter pub get` | Resolver berhasil; versi ada di pubspec.lock |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0; 24 file, 0 changed. [Log](evidence/m1-format.log) |
| `flutter analyze` | Exit 0, No issues found. [Log](evidence/m1-analyze.log) |
| `flutter test --reporter expanded` | Exit 0, **23 lulus**. [Log](evidence/m1-tests.log) |
| `flutter test integration_test/database_test.dart -d emulator-5554 --reporter expanded` | Exit 0, **11 lulus** pada sqflite Android. [Log](evidence/m1-android-tests.log) |
| `flutter build apk --debug` | Exit 0; build final **22,4 s** menurut output Gradle Flutter. [Log](evidence/m1-build-debug.log) |

APK aplikasi (bukan test APK) di `build/app/outputs/flutter-apk/app-debug.apk`. Build release/AAB tidak dijalankan karena checkpoint M1, konfigurasi signing/legal/produksi masih M6. Durasi build bukan latency query atau benchmark performa.

Windows 11 26H2, Flutter test Dart VM/debug; SQL nyata menggunakan sqflite_common_ffi 2.4.3 dan dependency native sqlite3 package 3.5.2 (bukan klaim nomor engine SQLite). Android integration merupakan APK debug/plugin sqflite pada emulator, bukan perangkat fisik atau release profiling. JDK Android Studio OpenJDK 21.0.10; SDK build-tools 36.0.0/platform 36.1. Warning doctor ditangani dengan membaca/menerima lisensi melalui `flutter doctor --android-licenses`; tidak diterima otomatis oleh agen.

## Test dan fixture

11 skenario SQL yang sama pada Windows disk database sementara dan Android database fixture ber-prefix m1_integration terpisah:

1. Fresh schema/user_version/FK, tabel penjualan konsisten, production products kosong, settings timezone/opt-in default dan credentials kosong.
2. Nonnegative integer money/stock, REAL ditolak, normalized_name non-NULL, value stok nol, FK invalid ditolak, SKU/barcode uniqueness termasuk arsip, barcode `00123`, category/supplier NULL.
3. Relasi sale/item/draft, FK parent invalid, hard delete/update fact ditolak, key/draft unique, snapshot detail tetap harga/nama lama setelah master berubah.
4. Fault operasi database membatalkan product/sale/draft sekaligus; operasi berikutnya masih berjalan. Ini bukan full fault injection checkout bisnis.
5. Data dan hubungan product/sale/item pada fixture v1 dibuka ulang v2; index ada, foreign_key_check bersih; downgrade ditolak dan data tetap terbaca.
6. Katalog: 11 produk awal dengan nama/case/whitespace duplikat, Unicode dan literal `%`/`_`; satu arsip. Traversal size 2 setara urutan SQL tetap, tanpa duplikasi/kehilangan; prefix/reset/filter salah, page kosong/final/exact-size, size invalid dan default 50. Tambahan 103 produk untuk memastikan halaman default 50+1, bukan benchmark besar.
7. Migration failure: index history duplikat disuntikkan pada v1 agar V2 gagal sesudah statement awal. user_version tetap 1, index V2 sebelumnya rollback, product tetap ada. Setelah fixture conflict diperbaiki, retry upgrade berhasil.
8. Startup service gagal membuka lalu retry, beberapa check berbagi coordinator yang sama, dispose menutup storage dan menolak operasi lanjutan.
9. Riwayat: tujuh transaksi dalam periode bertimestamp sama, dua di luar `[start,end)`, customer filter dan page size 2. Insert baru selama sesi tidak masuk halaman lanjutan karena upper tuple; refresh memasukkannya. Filter berbeda dengan cursor lama ditolak.
10. Query plan: fixture 8 produk + 8 sale_transactions; actual query first/continuation/prefix/customer memakai index dan tanpa temporary ORDER BY sort/OFFSET. Continuation katalog memerlukan seek komposit.
11. Coordinator exclusive/transaction diantrekan sesuai urutan; close menolak pembacaan lanjutan.

4 test PagedController: async response/error usang, load-more paralel, retry, reset/invalidation, eviction cache, immutable items dan dispose. 3 test value: rupiah/overflow, fixed cost/half-up, UUID/UTC/calendar/normalisasi. 5 test widget/theme memakai readiness boundary stub untuk loading/ready/error/retry dan disabled action, ukuran 320×568/1024×768/568×320 skala teks 2x serta contrast text/surface dan primary/onPrimary >4,5:1. Stub UI tidak digunakan sebagai bukti SQL.

## Query plan aktual

Hasil yang sama pada Windows dan Android; SQL dieksekusi dari keyset_queries.dart lalu EXPLAIN oleh suite, bukan query contoh terpisah:

```text
Katalog awal:
SEARCH products USING INDEX products_catalog (is_deleted=?)
Katalog lanjutan:
SEARCH products USING INDEX products_catalog (is_deleted=? AND (normalized_name,id)>(?,?))
Katalog prefix:
SEARCH products USING INDEX products_catalog (is_deleted=? AND normalized_name>? AND normalized_name<?)
Riwayat awal/lanjutan:
SEARCH sale_transactions USING INDEX sale_transactions_history (created_at>? AND created_at<?)
Riwayat customer:
SEARCH sale_transactions USING INDEX sale_transactions_customer_history (customer_id=? AND created_at>? AND created_at<?)
```

Tidak ada `USE TEMP B-TREE` untuk query ini. Tidak ada klaim semua query O(1), semua filter/search murah, atau laporan sudah terukur. Runtime row-value didukung target Android yang diuji; kompatibilitas perangkat/versi OS lain belum dibuktikan. Query/benchmark FTS, ledger/detail laporan, agregasi/ranking dan fixture 10k/100k menjadi M3/M4. Tidak ada angka latency halaman jauh yang dibuat-buat.

## Kegagalan awal yang sudah ditangani

- Analyzer: import sqflite extension getVersion, test counter bawaan dihapus/diganti; prefer_initializing_formals memiliki suppression sempit untuk API constructor berlabel publik. Analyzer akhir bersih.
- Native IO fixture di widget test menunggu dalam fake async; test UI memakai interface readiness stub dan semua SQL tetap diuji nyata secara terpisah.
- Pesan loading Row overflow pada text 2x diperbaiki dengan Expanded; tiga ukuran shell kemudian lulus.
- `PRAGMA busy_timeout = 5000` via execute bekerja di FFI tetapi ditolak SQLiteDatabase Android karena menghasilkan result. Diganti rawQuery; integration kemudian lulus.
- COLLATE eksplisit dalam tuple katalog menyebabkan plan hanya menyaring is_deleted. Dihapus pada ekspresi tuple dengan mempertahankan BINARY deklarasi kolom/index/ORDER; plan seek komposit terbukti. Assertion diperbaiki agar hanya continuation, bukan prefix, diharuskan memiliki tuple seek.
- Log penolakan downgrade dan index migration conflict pada run terakhir memang diharapkan dari negative tests; assertions membuktikan preservasi dan pemulihan. Tidak memuat fixture PIN/token/data toko nyata.

## Batas verifikasi

M1 memenuhi kriteria PLAN pada lingkungan ini; warning lisensi tidak memblokir hasil aktual. Belum diuji HP fisik/TalkBack/UI bisnis, hardware printer, Drive/OAuth, notifikasi, backup/restore, signing rilis/AAB, iOS/web, database produksi eksternal ataupun benchmark besar. Storage constraint/snapshot/dbTxn tidak membuktikan algoritma checkout/HPP/pelunasan/FEFO; acceptance tersebut tetap pending pada REQUIREMENTS.
