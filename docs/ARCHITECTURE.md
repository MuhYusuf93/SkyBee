# Arsitektur aplikasi — M1–M4 + Localization/Money

Checkpoint M4: ReportsProvider, riwayat lengkap, detail dan form koreksi tersedia dengan scope route/dialog. ReportsService/SqliteReportsRepository menghitung seluruh rentang SQL; CorrectionService membalik fakta atomik melalui coordinator. DatabaseCoordinator memberi revision/commit stream untuk invalidation, tanpa menyimpan state fitur global. Receivables/history/reports membuang respons async usang serta cache maksimal tiga halaman. Lihat [M4-NOTES](M4-NOTES.md) dan hasil aktual [VALIDATION-M4](VALIDATION-M4.md). Catatan checkpoint M1–M3 di bawah adalah histori; laporan/koreksi/performa yang disebut pending di sana sudah menjadi lingkup M4. Printer/Drive/restore tetap M5, acceptance rilis M6.

Query rincian laporan menggabungkan dua indexed branches original/reversal, maksimal 51 kandidat per branch, ORDER BY waktu DESC/kind DESC/ID BINARY DESC. History service mengikat revision mutasi, sementara kontrak repository dasar upper-bound M1 tetap tersedia. Batas waktu efektif continuation adalah minimum akhir periode dan waktu cursor (+1 ms bila perlu menyertakan timestamp tie); memakai satu batas scalar menghindari pemindaian hingga anchor jauh pada planner. EXPLAIN memakai query production yang sama, dan benchmark terpisah mencatat biaya ranking/agregasi; index tidak membuat SUM/ranking konstan.

LocaleProvider hanya preferensi bahasa dan currency read-only; SettingsProvider tetap form toko. MaterialApp memakai generated AppLocalizations ID–EN; Navigator/controller/session tidak diganti ketika locale berubah. Pesan service berupa key, widget menerjemahkan saat render termasuk snackbar overlay. Money/MoneyCodec/MoneyTextInputFormatter terpisah dari Provider/SQL. Bahasa tanpa PIN, currency terproteksi/terblokir seluruh fakta keuangan. V4 menjaga nilai lama. Lihat LOCALIZATION-MONEY/BACKUP-CONTRACT; catatan M1–M2 di bawah tetap berlaku.

Checkpoint M3: kasir, draft, checkout, piutang dan riwayat dasar tersedia. Detail ownership/SQL/search/index/snapshot/recovery di [M3-NOTES](M3-NOTES.md); otorisasi/presisi gudang di [M2-NOTES](M2-NOTES.md). Reports/corrections/printing/backup/legal/rilis tetap M4–M6. Dependency shared terpisah dari state fitur.

## Aliran dan dependency

`main → KasirApp (composition root) → AppServices (satu coordinator + service) → layar/Provider fitur → service → dbTxn/sqflite`. FoundationController/Readiness tetap hanya startup shell. ManagementSessionProvider dipasang sepanjang lifecycle aplikasi untuk penguncian; state inventory/detail/settings/master/picker/history scoped ke route.

Default aplikasi memakai CashierScreen dengan CartProvider/ProductSearchProvider. CheckoutProvider tidak menyalin keranjang; ReceivablesProvider/SaleHistoryProvider scoped ke route. Kelola meminta PIN sebelum menu/HPP. Shell FoundationStatus lama hanya jalur test compatibility untuk readiness M1; tindakan disabled pada shell itu bukan UI produksi. SQL tidak tersedia dari controller. InventoryService/CheckoutService/ReceivablesService mengerjakan aturan/commit atomik; repository menghasilkan snapshot immutable. Kasir/storage bekerja tanpa koneksi/akun. State tidak disatukan pada AppServices.

Service/repository memakai coordinator yang sama dari composition root. Jangan membuka koneksi baru per fitur. PagedController dipakai pada katalog/master/riwayat stok-harga, sementara detail mempunyai page batch terbatas. Relasi gudang memakai dropdown async20 suggestion dan picker keyset; cashier suggestion16. Inventory/Detail/Settings serta Cart/Search/Checkout/Receivables/SaleHistory sudah tersedia; Reports tetap M4. Tidak ada interface dummy yang mengembalikan sukses.

| Pemilik state (Reports masih pending) | Lifecycle | Batas tanggung jawab |
| --- | --- | --- |
| CartProvider | Alur kasir/draft | Quantity, draft, total tampilan, undo; satu pemilik keranjang |
| ProductSearchProvider | Pencarian kasir | Debounce, suggestion terbatas, penolakan async usang |
| CheckoutProvider | Form checkout | Pembayaran/pelanggan/submit; tidak menyalin keranjang |
| InventoryProvider | Layar gudang | Filter/paging/operasi lewat service |
| ReceivablesProvider | Layar hutang | Daftar/detail/pelunasan lewat service |
| SaleHistoryProvider | Layar riwayat | Periode/filter/paging/detail |
| ReportsProvider | Layar laporan | Periode/agregat/halaman detail; bukan menghitung total dari cache UI |
| ManagementSessionProvider | Sesi pengelolaan | Akses/kedaluwarsa/lifecycle; verifikasi juga di service |
| SettingsProvider | Form pengaturan | State form/konfigurasi; tanpa hashing/transport/upload |

Tidak ada dependensi antar-Provider yang melingkar. Checkout merujuk satu CartProvider; Cart tidak merujuk Checkout. Commit menginvalidasi layar terkait secara terarah; database tetap sumber kebenaran stok/piutang. Snapshot immutable/comparable; query pencarian tidak menotifikasi Cart/Reports/Inventory. SQL, algoritma HPP, hashing, dan plugin berada pada service/repository/adaptor.

## Koordinator database

Satu koneksi lazy dengan `foreign_keys=ON`. Seluruh callback read/transaction/exclusive diantrekan untuk membuat batas pemeliharaan eksplisit. Write service memakai `transaction((dbTxn) ...)`; repository yang berpartisipasi dalam operasi tersebut perlu menerima executor dbTxn, jangan memanggil coordinator lagi dari dalam callback karena akan deadlock. Error membatalkan transaksi; antrean berikutnya tetap dapat berjalan. Jangan menunggu dialog, undo, Bluetooth, ataupun jaringan di dalam callback.

`exclusive` hanya pagar operasi biasa; belum membuat snapshot, checkpoint WAL, menutup/mengganti file, atau memulihkan restore. M5 harus menambahkan protokol maintenance melalui coordinator; jangan menyalin database live. `close` menguras antrean dan menolak operasi sesudahnya. Service startup berbagi future pembukaan, mengizinkan retry pembukaan gagal, dan menutup koneksi saat dispose. Error teknis tidak dipaparkan ke UI/log aplikasi.

## Pagination

Repository menyediakan `Page<T, C>` immutable, nextCursor nullable, dan hasMore. Default 50, maksimum 200 per permintaan untuk membatasi memori, bukan batas jumlah data toko. SQL mengambil 51 baris untuk halaman default tanpa COUNT/OFFSET. Cache state hanya tiga halaman; data yang dikeluarkan dari cache dapat dilihat lagi melalui refresh/sesi baru. UI daftar berikutnya perlu menawarkan refresh/berikutnya, atau menyimpan cursor sebelumnya secara terbatas jika menyediakan navigasi kembali.

- Katalog: `is_deleted = ?`, `normalized_name ASC, id ASC`. Nama dinormalisasi trim/lowercase/rapatkan whitespace dan NOT NULL; seluruh kolom/index/order/cursor memakai SQLite BINARY. Filter awalan memakai rentang Unicode scalar dengan parameter, `%`/`_` bersifat literal. Ini filter alfabetis M1, bukan pencarian berperingkat SPEC §6. Suggestion berperingkat/alias dan fallback term-index M3 berada di ProductSearchService, terpisah dari filter alfabetis gudang.
- Riwayat: `[start,end)` epoch UTC ms, optional customerId, `created_at DESC, id DESC`. Cursor memiliki tuple terakhir dan tuple batas atas sesi. Data baru yang lebih baru dari batas atas muncul saat refresh. Insert backdated tidak memperoleh jaminan snapshot; service mendatang wajib mempertahankan waktu/id fakta dan menginvalidasi untuk import/koreksi konteks.
- Cursor mengikat filter/periodenya dan ditolak bila dipakai pada konteks lain. Perubahan sort harus membuat tipe cursor/query baru. ID UUID bukan tanggal.
- Reset state menaikkan generation, membersihkan item/cursor/error dan memuat halaman pertama. Load-more paralel ditolak; respons/error usang dan sesudah dispose tidak menotifikasi. Edit nama/arsip/filter wajib reset sesudah commit. Batas cache tidak sama dengan total data laporan.

`EXPLAIN QUERY PLAN` diuji memakai SQL yang sama dengan repository. Komparasi tuple menggunakan collation BINARY bawaan kolom; menambahkan COLLATE pada setiap ekspresi tuple membuat SQLite FFI memilih pemindaian seluruh rentang arsip, sehingga ekspresi itu dihapus tanpa mengubah semantik. Uji continuation katalog mengharuskan seek komposit. Query plan bukan benchmark. M4 sudah menyediakan laporan full-period, signed reversals, invalidasi cursor dan benchmark10.000produk/100.000penjualan; bukti/EXPLAIN/sampel ada pada VALIDATION-M4 dan M1_M4_BUGFIX_REPORT. Latency debug bukan acceptance release/SLA.

## Konfigurasi dan batas tahap

Tema: lib/app/theme.dart; localization ID/EN/delegates melalui LocaleProvider dan language preference publik; value types/schema/keyset di core/data. PIN/security dan stock algorithms sudah M2 (lihat M2-NOTES). Printer/backup/identitas pengembang/legal/signing produksi tetap pending. Package ID com.example.kasir_app masih development. Tidak ada integrasi pengiriman data.


M3.1: StockInput/StockPurchase helper typed tanpa dependency Flutter/SQL; StockInputController dimiliki form Gudang, WholeQuantityFormatter presentation. CartProvider memiliki pricing_mode dan lock checkout, CheckoutProvider hanya form. Service lama diperluas tanpa Provider global; lihat M31-NOTES.


Native test environment memisahkan applicationId/sandbox (com.example.kasir_app.integration) melalui explicit Dart define, no-uninstall dan APKidentity guard. Pemisahan file DB saja tidak melindungi data terhadap package cleanup runner. INCIDENT-M31-ANDROID-TEST mencatat kegagalan workflow awal; data operasional lama belum pulih.

## Batas layanan setelah audit M1–M4/M3.1

Perbaikan performa Realme15Oktober: `PinHasher` memilih MethodChannel Android yang menjalankan PBKDF2-HMAC-SHA256 Mbed TLS3.6.7 pada serial background task queue. Hanya empat implementation units crypto dikompilasi, tanpa TLS/network/PSA; sumber/lisensi/checksum terpin di `android/app/src/main/cpp`. JNI menerima UTF8 bytes dengan parameter tervalidasi dan membersihkan buffer. Backend tidak tersedia memakai algoritma Dart asli di isolate, tetap600k/256; kesalahan derivasi tidak menghasilkan nilai dummy. Salt, verifier, domain separation, format DB/schema7, CAS/lockout dan aturan keuangan tetap. Lihat laporan Realme untuk bukti kompatibilitas dan batas pengukuran; tidak menyebut PIN sebagai enkripsi database.

ManagementService mengganti credential dengan compare-and-swap salt yang benar-benar diverifikasi; mutex instance hanya guard submit UI. KDF600k dan progressive lockout tetap. Read pengelolaan diperiksa sebelum queue, saat callback DB mulai, dan sebelum hasil dilepas; mengunci layar saja tidak mengesahkan request service yang sudah mengantre. Public cashier/preferences tetap terpisah dari protected reads.

Hasil operasi keuangan yang sudah commit tetap sukses ketika Provider route disposed. Disposal menghentikan notifikasi/refresh UI, bukan mengubah hasil persistensi; idempotency dan rollback berada di service/SQL. ReceivablesProvider tetap hanya memiliki state route, tanpa memindahkan transaksi ke widget.

Inventory/master memakai lazy slivers dan tab NestedScrollView supaya safe area, keyboard serta text scale berbagi viewport yang dapat digulir. Preview pembayaran memakai scroll untuk seluruh content dan viewport finite untuk daftar alokasi; actions tetap terpisah. Cursor/index/order/cache3halaman/150items dan full-range report aggregation tidak berubah. Tidak ada migration/aturan uang/HPP baru pada audit ini; tujuh file aplikasi diubah secara terbatas.
