# M3 — Kasir, checkout, piutang, dan recovery

Development 0.3.0+4/schema 5, Android dahulu. M4–M6 tidak diimplementasikan. Seluruh fitur tetap offline; tidak ada server, phonebook, kamera wajib, pengiriman data, printer, atau Drive baru.

## Kepemilikan state

- CashierScreen membuat CartProvider dan ProductSearchProvider sesuai lifetime alur kasir. CartProvider adalah satu pemilik snapshot draft/quantity/undo; ProductSearchProvider hanya query, debounce275 ms, suggestion/loading/error/generation.
- CheckoutScreen mempunyai CheckoutProvider untuk mode/form pembayaran/customer/submit guard. Ia merujuk CartProvider, tidak menyimpan keranjang kedua. MoneyEditingController mempertahankan canonical value/locale; preview sisa hutang menunda notifikasi render bila MoneyField mengganti codec ketika Localizations sedang build.
- ReceivablesProvider hanya aktif pada route Hutang untuk list dan status operasi payment; detail route memiliki satu local form State untuk controller/preview/page pendek (tidak diduplikasi di Provider lain), dan tetap memanggil service tanpa SQL/rumus bisnis. Pilihan ini mengikuti pola form/picker M2 supaya controller sementara tidak menjadi state global.  SaleHistoryProvider pada route riwayat pengelolaan. Cache daftar maksimal150 record/3 halaman; detail piutang menampilkan satu halaman50. Refresh sesudah payment/kelola memulai sesi cursor baru.
- AppServices hanya dependency composition. SQL/transaction/hash/FEFO/HPP/balance berada pada CartService, CheckoutService, ProductSearchService, ReceivablesService, SaleHistoryService dan CashierStore. Tidak ada SQL di widget/Provider. Public SaleReceipt/CashierProduct sengaja tidak membawa HPP/valuation; service riwayat HPP memeriksa sesi PIN sebelum dan sesudah pembacaan.

## Pencarian

Exact barcode/SKU diproses segera pada Enter, sebagai string trim tanpa menghapus nol. Jika barcode satu produk bertabrakan dengan SKU produk lain, scan ditolak sebagai ambigu; pilih hasil secara eksplisit. Ketikan nama tidak otomatis menambah hasil pertama. Scanner Enter beruntun merupakan beberapa intent penambahan, bukan request suggestion yang boleh dibuang oleh generation; CartProvider mengantrekan mutasi. Clear hasil scan/selection juga mengikat inputVersion; respons sukses lama tidak menghapus input/error scan yang lebih baru, termasuk barcode tidak ditemukan.

Peringkat: exact barcode/SKU, exact normalized name, prefix nama/token/compact, alias, kategori. Normalisasi trim/lowercase/whitespace; pecah token tanda baca, simpan compact tanpa spasi. Contoh Le Minerale/mineral/lemineral/le dan kategori/alias air/minum diuji. Suggestion maksimal16, bukan batas katalog. Prefix memakai prefixEnd Unicode scalar/BINARY, parameter SQL; `%`, `_`, quotes dan operator FTS menjadi teks literal.

Schema5 mempunyai cashier_search_terms dengan index `(term BINARY,priority,product_id BINARY)` dan antrean cashier_search_dirty. Trigger edit master/alias/category menandai produk; service memproses100 dirty products per chunk dan mengganti index secara atomik. Tidak memuat seluruh katalog ke Provider/Dart untuk contains. Proses membangun indeks pertama masih dapat membutuhkan waktu pada katalog besar; profil/perbaikan performa M4, tanpa klaim O(1).

FTS5 diperiksa melalui temporary virtual-table probe, karena dukungannya tergantung build SQLite ([dokumentasi SQLite](https://www.sqlite.org/fts5.html)). Implementasi memakai backend token prefix B-tree yang sama pada kedua kemampuan; Windows FFI mendukung FTS5, HP Android 16 yang diperiksa tidak. Tidak mengandalkan MATCH/LIKE substring atau memperkenalkan perbedaan hasil antar perangkat. Benchmark dataset besar/query plan suggestion lengkap tetap M4.

## Draft dan checkout

cashier_state singleton menunjuk draft aktif **atau** draft completed yang belum diakui. Draft/item menyimpan minor units, currency_code/scale, accepted price/product revision; tidak mengurangi atau mereservasi stok. Setiap mutasi menaikkan draft revision, mempertahankan payment intent tersimpan; total baru tetap diperiksa dan tidak mengubah mode hutang menjadi Lunas otomatis. Clear/remove meminta konfirmasi sesuai tindakan dan menghasilkan undo5 detik monotonic dengan expected revision; snackbar memegang token tindakan itu, sehingga undo lama tidak memakai token tindakan berikutnya.

Open memvalidasi produk/stok/harga terbaru sebagai warning, tanpa mengubah harga diterima. Checkout menolak produk arsip/stok kurang/price change/draft revision berubah. Pengguna menerima harga terbaru secara eksplisit; tidak ada total diam-diam. Uang baru/cost arithmetic memakai batas Money dan BigInt/signed64 yang telah didokumentasikan, tanpa double bisnis.

Input pembayaran valid disimpan sebelum transaksi checkout; teks sementara/invalid tetap milik form. Lunas tidak meminta pelanggan/cash tender/kembalian dan mencatat total. Sebagian membutuhkan0<paid<total; hutang semua paid0. Total0 hanya lunas, tidak membuat row payment0. Nama wajib untuk hutang, HP text opsional. Existing customer harus dipilih menurut ID; nama sama tidak digabung. Pilihan pelanggan baru dapat memakai nama sama. Mengubah nama/HP setelah memilih existing customer melepaskan pilihan ID, tanpa mengedit master lama secara tersembunyi.

Checkout memakai draft UUID sebagai durable checkout_key, revision dan hash payload kanonik. Same-key/same-payload retry membaca fakta lama sebelum stok/harga terbaru; payload berbeda ditolak. Di satu dbTxn: validasi → customer bila perlu → sale header → conditional stock/value/stock_revision → item snapshots → FEFO batch allocation → ledger delta → payment/allocation → draft completed → cashier audit. Error pada tahapan mana pun rollback seluruhnya. History satu delta per produk menunjuk sale; alokasi batch detail mengidentifikasi batch fisiknya.

FEFO streaming100 batch/halaman: tanggal terdekat dahulu, tanggal kosong terakhir, tie received_at/id BINARY. Stok tidak layak jual mulai expiry day pada zona toko; expiry disabled menggunakan FIFO. Index expression COALESCE(expiry_date,'9999-99-99') konsisten dengan order/cursor. HPP memakai moving value pada seluruh stok fisik, bukan biaya batch yang dipilih. removalCost mengalokasikan bagian proporsional; pengeluaran final menghabiskan seluruh residu. Snapshot header/item dan metadata immutable tidak dihitung ulang saat restock/edit harga/pelunasan.

Commit menyelesaikan draft dalam transaksi yang sama. Restart sebelum commit memulihkan draft/input; restart setelah commit menampilkan receipt tersimpan, bukan checkout baru. Tombol Belanja berikutnya mengakui hasil lalu membuat/persist pointer baru. Tidak menunggu dialog/undo/device transport di dalam SQL. Recovery test adalah reopen database/recreate UI yang deterministik, bukan seluruh skenario OS kill/power-loss/OEM.

## Piutang dan riwayat dasar

Saldo berasal dari seluruh sale/payment allocations/reversal, bukan kolom balance editable atau jumlah satu halaman. List customer prefix `(normalized_name,id) ASC BINARY` dengan cursor terikat query/filter hutang aktif. Detail/transaksi dan preview oldest-first memakai `(created_at,id) ASC BINARY`; preview membaca chunks100 sampai nominal dialokasikan. Customer aggregate bisa memerlukan scan/agregat besar; profil M4, tidak mengklaim semua query seek O(1).

Pratinjau menunjukkan rincian alokasi sebelum konfirmasi. Record memeriksa currency, semua outstandingBefore, jumlah alokasi positif/unik, total tepat, lalu menyimpan payment+allocations+audit secara atomik. Same-key/same-plan retry mengembalikan paymentID; perubahan saldo menolak plan dan meminta pratinjau baru. UI mempertahankan plan/key setelah kegagalan yang belum pasti; edit nominal memulai plan baru. Loader SQL berhenti saat menunggu dialog manusia, sementara submit guard tetap aktif.

Pelunasan tidak menulis sale/items/stok/HPP. Hutang lunas hilang dari list aktif, tetap tersimpan di riwayat. Riwayat dasar pengelolaan memakai repository keyset M1, snapshot total/HPP, UTC storage dan zona toko untuk tampilan. Filter laporan penuh/agregat, pembatalan sale/payment, rekonsiliasi UI, dan benchmark M4 tetap pending. Struk saat ini tampilan receipt saja; transport/cetak ulang M5 pending.

## Schema5 dan bukti

Migration additive: kolom form draft, payload_hash sale/payment, cashier_state, customer/draft/FEFO/search indexes, search terms/dirty triggers, guard completed draft/items. Default paid/null pada draft lama; fakta/nominal/FK/harga/stok/currency V4 tidak ditulis ulang. CHECK/foreign_key_check/quick_check dan rollback upgrade diuji pada fixture terpisah.

Hasil aktual/perintah/kegagalan yang diperbaiki ada di VALIDATION-M3. Laporan manual pengguna sebelumnya di STATUS-LOCALIZATION/VALIDATION-PHYSICAL mendahului M3 dan tidak menjadi bukti manual M3. Keyboard/scanner hardware/OEM/TalkBack/release/restore/printing/Drive belum dibuktikan oleh test sintetis ini.
