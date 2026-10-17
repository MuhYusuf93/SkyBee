# Pemeliharaan M4

14 Oktober 2026. Kode development0.4.0+6/schema7 selesai pada lingkup M4; hasil aktual terakhir selalu STATUS/VALIDATION-M4. Dokumen ini menjelaskan keputusan, bukan klaim semua pemeriksaan sudah lulus.

## Kebijakan laporan dan koreksi

Penjualan/HPP/laba kotor dan pembayaran mengambil seluruh rentang SQL `[start,end)` dari kalender zona toko. UI memilih tanggal akhir inklusif; StoreClock.dayStart(nextDay:true) membuat tengah malam kalender berikutnya, termasuk DST. Default laporan adalah bulan berjalan sampai hari ini. Saldo piutang adalah snapshot saat ini untuk pelanggan terpilih; persediaan snapshot seluruh toko saat ini (termasuk stok arsip), terpisah dari periode/pelanggan laporan. Label membedakan ketiganya.

Pembalikan diperhitungkan pada tanggal koreksi. Original sale/payment tidak ditulis ulang, termasuk snapshot harga grosir/eceran, HPP, quantity dan batch. Periode lama tetap memuat kejadian asli; bulan pengembalian bisa mempunyai penjualan/HPP/laba negatif. Pelunasan tidak menjadi penjualan/laba baru. Signed aggregate DTO/BigInt menjaga profit mikro-minor; formatter membulatkan hanya tampilan dan tidak mengubah Money input menjadi signed. Overflow SUM integer SQLite menghasilkan pesan eksplisit; tidak memakai TOTAL/double untuk menyamarkannya.

CorrectionService memerlukan capability PIN pada awal dan sebelum commit, alasan, key/payload stabil, serta konfirmasi penanganan dana. Full sale juga memerlukan attestation seluruh barang kembali. Tidak memindahkan barang/cash secara otomatis. Active followup repayment menyebabkan penolakan full cancellation; jika pembayaran keliru, operator dapat membaliknya dahulu. Pembayaran anonim tidak dapat membuka piutang tanpa pemilik, sehingga dibalik dalam full sale return. Partial checkout dengan pelanggan boleh dibalik mandiri untuk membuka saldo pelanggan kembali.

Sale cancellation mengembalikan batch asli tanpa mengubah expiry, menambah quantity/nilai snapshot HPP ke saldo saat ini (bukan mengembalikan average lama), menaikkan stock_revision, menambah ledger pembalik yang merujuk original movement, membalik initial checkout receipt yang belum reversed, dan mencatat audit dalam satu dbTxn. Restock/sale lain tetap mempunyai snapshotnya. Barang arsip tetap arsip; pengembalian tidak diam-diam memulihkan metadata/harga, dan stok arsip termasuk ringkasan/reconciliation. Goods expired tetap tidak layak jual bila expiry aktif. Fakta yang tidak konsisten ditolak; reconciliation tidak mengeditnya.

Pembalikan pembayaran menyalin seluruh alokasi original dengan sign negatif pada derived balance; stream100 allocations/page. Original receipt dan allocations immutable. SQL guard memastikan jumlah/header currency/customer dan tiap reversal allocation sesuai original. Unique reversed target dan operation key + payload hash mencegah double correction. Completed draft tetap merujuk original sale; retry/recovery membaca receipt cancelled, tidak membuat sale kedua.

## Migration V7 dan asal pembayaran

Additive columns sale_transaction_reversals.payload_hash/goods_returned (legacy NULL attestation, tidak direkayasa); checkout_payment_links dan receivable_payment_links immutable, indeks period untuk payments/reversals, guards header/allocation/provenance. Nilai V1–V6 tidak dikalikan/dihapus/relabel.

Checkout provenance lama hanya dari exact checkout key, timestamp/currency/customer/header allocation tunggal yang cocok. Repayment lama hanya dari audit receivable_payment yang tercatat. Unknown tetap unknown dan ditampilkan terpisah; tidak semua receipt dianggap repayment. Current checkout/receivable services menulis link setelah allocations dalam dbTxn yang sama. Reversal origin mengikuti original payment link.

## Pembagian state dan pagination

ReportsService/SqliteReportsRepository menangani aturan/perhitungan/query, CorrectionService menangani atomic correction, SaleHistoryService/repository menyajikan fakta. AppServices hanya DI. ReportsProvider, SaleHistoryProvider, SaleDetailProvider dan CorrectionFormProvider sesuai lifecycle route/dialog; tidak ada state laporan global atau SQL dalam widget.

DatabaseCoordinator memberi revision/stream setelah successful dbTxn, rollback tidak mengemit. Reader route-scoped menginvalidasi cursor/cache dan generasi async; receipts/customer balances juga direfresh setelah koreksi. Signal ini konservatif (termasuk transaction read/noop), bukan snapshot database permanen. Repository history dasar tetap kontrak upper bound M1, sedangkan protected service mengaktifkan mutation revision; report cursor selalu memiliki revision. Filter equality mencakup periode/customer/status/section. Data mutable tidak diklaim sebagai snapshot sempurna.

History memakai `(created_at DESC,id BINARY DESC)`; report menggabungkan original/reversal dengan `(created_at DESC,kind DESC,id BINARY DESC)`. Each branch melakukan indexed seek sesuai constant kind, mengambil50+1 kandidat; outer merge paling banyak102kandidat, bukan OFFSET. Cache PagedController3pages, maksimal150items. Rincian UI tidak menjadi sumber ringkasan agregat; ranking search dan SUM tetap memiliki biaya terhadap kandidat/rentang.

## Pemeriksaan/performa

Shared SQL/window/native suites: reports_corrections_suite (rollback/idempotency/valuation/report), m4_storage_suite (migration/cursor/generation/cache), m4_ui_suite (synthetic narrow/wide2x/protection/locale). Lifecycle cleanup SQL harus selesai saat fake binding widget masih aktif; Finder terlihat bukan bukti semua pending reads selesai. Widget fixtures hanya nonce/inMemory, tidak kasir_app.db.

Benchmark opt-in KASIR_PERFORMANCE_FIXTURE=true:10000produk/100000sales +100000items/batch allocations/sale-ledger,600payments, fixture konsisten. Batch250invoices membatasi temporary allocations; bukan klaim peak RAM terukur. Seeding/search-index build/anchor lookup di luar query samples;1warmup+5timed, median/max aktual. Far anchor lookup via exact PK, bukan OFFSET. Production query builders sama dengan EXPLAIN, bukan SQL benchmark yang disederhanakan. WindowsFFI dan physical Android debug dibedakan; release/profile performance tetap M6.

Planner Windows memilih period index range untuk history/report. Batas akhir continuation dipersempit menjadi satu effective end=min(period end,cursor timestamp+tie allowance); tuple tetap memutus tie ID. Batas redundan terpisah sempat tetap memilih broad range dan median jauh ~9ms, sehingga benchmark benar-benar memengaruhi query. Pada report plan, SCAN subquery dan TEMP B-TREE adalah merge/sort kandidat branch yang sudah LIMIT51, maksimal102, bukan pemindaian seluruh sale. Pada summary, SCAN events memang mengagregasi seluruh rentang; pada ranked search, GROUP BY/ORDER BY dan join kandidat aktif tetap mempunyai biaya. Perbandingan latency akhir/plan platform berada di VALIDATION-M4, bukan jaminan O(1) atau SLA untuk dataset lain.

Native selalu tools/test_android.ps1 dengan explicit DeviceId/AndroidSdkRoot/VerifyOperationalDatabase; PerformanceFixture untuk benchmark. Package integration/identity gate/no-uninstall dipertahankan. Ordinary APK direct install-r setelah aapt. V6→V7 ordinary upgrade memerlukan table-value fingerprints sebelum/sesudah (whole-file hash wajar berubah karena migration); tidak reset dummy lagi. Baseline hash sebelum/sesudah fixture run tetap harus cocok.

Google Cloud dan Bluetooth thermal printer yang sedang disiapkan pengguna adalah prasyarat M5. Tidak ada OAuth/printer/Drive/notifikasi/restore baru pada M4; tidak publish. OEM/TalkBack/full release/actual restore tidak disahkan oleh synthetic UI/benchmark.
