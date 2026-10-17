# Skema dan migration — M1–M4 + Localization/Money

Versi aktif **7** (M4). V7 additive menambah `sale_transaction_reversals.payload_hash` dan `goods_returned` nullable (legacy attestation unknown), tabel immutable `checkout_payment_links`/`receivable_payment_links`, index period pembayaran/pembatalan dan guard provenance/reversal header/allocation. Backfill checkout hanya dengan exact checkout key, timestamp/currency/customer serta single allocation yang cocok; pelunasan hanya dari audit lama yang membuktikannya. Receipt lain tetap unknown. Tidak mengubah nominal/HPP/stok/snapshot lama. Runtime services menulis provenance setelah allocations dalam dbTxn yang sama. Pembalikan append-only tidak menghapus completed draft atau transaksi asli. Detail/test/upgrade aktual: [M4-NOTES](M4-NOTES.md), [VALIDATION-M4](VALIDATION-M4.md). Paragraf versi6 dan checkpoint di bawah bersifat historis.

Angka penjualan/pembayaran disimpan positif dengan event kind/reversal reference yang menentukan tanda saat agregasi. Gross profit bertanda memakai BigInt dalam micro-minor; SQLite SUM overflow ditolak secara eksplisit. Konversi kalender laporan ke UTC half-open dilakukan service, timestamp tetap indexed tanpa fungsi pembungkus. Reconciliation membaca seluruh dataset dan tidak memperbaiki fakta diam-diam.

Versi aktif **6**. V6 additive grosir/kemasan/pricing_mode/receipt-input/typed price snapshots; lihat M31-NOTES dan VALIDATION-M31. Default lama NULL/retail tanpa rewrite stok/value/HPP. V5 additive menambah form draft, payload_hash sale/payment, cashier_state/recovery pointer, indexes customer/draft/FEFO/search, search terms/dirty triggers dan completed draft/item guards. Tidak menulis ulang nominal/harga/stok/HPP/FK V4. Fixture V4→V5 dan failure rollback diuji nyata; detail di M3-NOTES/VALIDATION-M3. V4 ui_language/currency metadata/reason_key dan IDR0 tanpa x100 tetap. Nama storage *_rupiah tetap minor units sesuai metadata; *_micros10^6 per minor. V1–V4 dipertahankan. Catatan V3 di bawah adalah histori M2.

Sumber eksekusi: `lib/data/database/schema.dart`. Versi pada checkpoint M2 **3**. V1 membuat tabel/constraint/trigger/default settings; V2 menambah index; V3 additive menambah stock_revision, last_attempt_at, inventory_operations, referensi ledger dan index master/batch. V1/V2 tidak diubah. Fresh/upgrade memakai satu jalur. Fixture v1→current dan v2→v3 diuji nyata; tidak mengklaim migrasi database aplikasi eksternal.

## Identitas, angka, dan tanggal

- ID internal TEXT UUID v4, dihasilkan lapisan data, stabil dan bukan urutan waktu. Constraint SQL panjang 36, validasi UUID penuh di value type. SKU manual atau UUID-based otomatis, unique; konflik dijelaskan di service M2. Barcode TEXT nullable, nonempty bila terisi, unik termasuk arsip; empty input menjadi NULL.
- Nominal jual/bayar INTEGER rupiah. Inventory value, receipt cost dan snapshot HPP memakai INTEGER micro-rupiah, skala **1.000.000**. CHECK typeof integer/nonnegative mencegah REAL/angka negatif; delta ledger bertanda memakai INTEGER. BigInt intermediate pada API uang mendeteksi overflow signed 64-bit, bukan diam-diam menjadi double. Kapasitas nilai persediaan sekitar Rp9,22 triliun pada skala ini; operasi di luar rentang harus ditolak dengan pesan yang sesuai, bukan batas jumlah produk.
- Tidak ada average cost ganda. Nilai/quantity adalah sumber average; M2 mengimplementasikan weighted value, proportional half-up removal dan residu penuh pada pengurangan terakhir (lihat M2-NOTES). Stok nol mengharuskan nilai nol. Biaya sale/detail mempunyai kolom snapshot; checkout M3 belum ada.
- created_at/updated_at INTEGER UTC epoch ms. Zona IANA default Asia/Jakarta; M2 menghitung expiry/hari dan display history memakai timezone toko. Konversi periode laporan M4. expiry_date ISO yyyy-MM-dd nullable; SQL memeriksa bentuk dan service memakai CalendarDate valid. FEFO primitive M2 mengabaikan expired mulai tanggalnya, undated terakhir. Idle session menggunakan monotonic time di memori, tidak dipulihkan saat restart.

## Relasi dan sumber kebenaran

| Tabel | Tanggung jawab/relasi |
| --- | --- |
| categories, suppliers, customers | Master terpisah, is_deleted; nama pelanggan tidak unique; HP/contact teks |
| products, product_aliases | category_id nullable, stock_quantity/value/revision/default min_stock 5; alias terpisah |
| stock_receipts, stock_receipt_items | Supplier nullable pada penerimaan, operation_key unique, biaya aktual/snapshot |
| stock_batches | Product + receipt item nullable untuk initial/adjustment; qty received/remaining dan tanggal nullable |
| cart_drafts, cart_draft_items | Active/completed/abandoned; qty/accepted price/revision; satu baris per product |
| sale_transactions | checkout_key dan draft_id unique; customer nullable, total/HPP/name/phone snapshot |
| sale_transaction_items | FK **sale_transaction_id**, product dan snapshot nama/SKU/barcode/harga/qty/HPP |
| sale_batch_allocations | Detail penjualan ↔ batch + quantity |
| payments, payment_allocations | Receipt/reversal append-only, reversal reference unique; allocations ↔ sale_transactions |
| sale_transaction_reversals | Pembatalan penuh terpisah + alasan/waktu/idempotensi; fakta asli tidak diedit |
| stock_history | Delta jumlah/nilai bertanda, FK sumber product/batch/receipt/sale/reversal/history pembalik |
| price_history | Nilai harga sebelum/sesudah + waktu/alasan |
| inventory_operations (V3) | Key/payload hash/idempotensi, before quantity/value, stock_revision_after, receipt/ref reversal; append-only |
| store_settings | Singleton, konfigurasi toko, zona waktu; backup/notifikasi default mati |
| management_credentials | Singleton verifier/salt/KDF/recovery verifier/rate-limit; tidak ada PIN plaintext/default |
| installation_metadata, legal_acceptances | Identitas instalasi dan consent version/time; tanpa consent otomatis |
| audit_log | Mode/instalasi/action/reference/time, tidak mengklaim identitas orang |

Semua relasi memakai FK dengan RESTRICT untuk master/keuangan; hanya item draft boleh CASCADE ketika draft dihapus. Tabel fakta mempunyai trigger penolak UPDATE/DELETE. Reversal menambah record. M6 anonimisasi sah membutuhkan API terproteksi dengan scope snapshot jelas; jangan mematikan trigger dari widget. Tidak ada saldo piutang ganda: kelak dihitung dari sale/payment/reversal. Payments menyimpan nominal positif dan kind membedakan tanda. Audit tidak menyediakan payload bebas untuk PIN/token/data pribadi.

Circular FK sale/draft sengaja disiapkan untuk satu commit: draft aktif sudah ada, insert sale yang menunjuk draft, lalu tandai draft completed dengan sale ID. CHECK state menjaga referensi completed tidak NULL. Kesetaraan kedua arah, total header/detail, total alokasi pembayaran, kesesuaian product/batch, ledger/valuasi, otorisasi PIN, dan idempotensi operasional harus diperiksa service M2–M4 dalam dbTxn; constraint saja belum memenuhi checkout bisnis. Test M1 membuktikan hubungan/constraint dasar dan rollback SQL, bukan checkout yang sudah bekerja.

## Index

Katalog `(is_deleted, normalized_name BINARY, id BINARY)`; sale history waktu/id DESC dan customer-prefix. V3 menambah master catalog/batch/operasi/ledger indexes. V5 menambah cashier terms prefix dan customers name/id BINARY, draft recent, FEFO expression COALESCE(expiry_date,'9999-99-99')/received_at/id yang konsisten dengan cursor100-batch streaming. Checkout M3 kini memakai conditional stock_revision, allocation dan immutable ledger. SQLite memakai autoindex key unique. Plans M1 dan pagination M2 tercatat pada VALIDATION-M1/M2; profiling suggestion/receivables aggregates/large fixtures M4 pending.

## Menambah migration

1. Baca database produksi/STATUS dan kontrak yang terdampak; naikkan version.
2. Tambahkan langkah versi tersendiri pada loop migrate. Jangan mengubah V1/V2 yang sudah dipakai pengguna. Tidak menggunakan drop-recreate data produksi atau onDowngradeDelete.
3. sqflite membungkus onCreate/onUpgrade atomik. Gunakan executor callback yang sama; jangan membuka db lain/transaction bersarang.
4. Untuk perubahan constraint, lakukan copy terkontrol dengan kolom eksplisit, mempertahankan UUID/snapshot/relasi/index/trigger. Periksa foreign_key_check/integrity_check dan jumlah/nilai rekonsiliasi, plus rollback kegagalan migration.
5. Tambahkan fixture versi sebelumnya berisi data dan relasi, buka versi baru tanpa uninstall, verifikasi isi, lalu regresi SQLite FFI dan Android. Jangan hanya menguji database kosong.

Downgrade ditolak sebelum data diubah. Restore/integritas/checksum/backup WAL tidak tersedia di M1 dan harus diselesaikan di M5.


Migration fixtures lulus bukan bukti preservation package pada Flutter runner. INCIDENT-M31-ANDROID-TEST mengoreksi default-uninstall; native hanya melalui script package fixture dan --no-uninstall.
