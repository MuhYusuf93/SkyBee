# Pemeliharaan M3.1 — grosir dan input kemasan

Kebutuhan aktif SPEC §19; dependency M1–M3. Aplikasi 0.3.1+5, Schema.version 6. Tidak ada tahap M4 otomatis. Driver/enkripsi tidak berubah: sqflite biasa; PIN adalah kontrol aplikasi/KDF, bukan enkripsi DB.

## Pemilik state dan operasi

CartProvider tetap satu pemilik keranjang. PricingMode retail/wholesale ada pada CartLine/draft, tidak diduplikasi dalam CheckoutProvider. Toggle merupakan tindakan eksplisit yang menerima harga mode terpilih dan menaikkan revision draft. Scan/quantity berikutnya mempertahankan mode serta accepted price. Reopen membandingkan dengan harga mode terkini; harga berubah meminta acceptance, wholesale NULL meminta pilih retail/hapus. Checkbox hanya tampil jika harga grosir tersedia; draft wholesale lama yang hilang harganya tetap mempunyai penjelasan/tombol koreksi.

CheckoutProvider mengunci CartProvider sebelum menguras antrean perubahan yang sudah diterima. Selama submit seluruh mutasi baru ditolak; refresh read-only diperbolehkan. Hash checkout tetap draft ID/revision/input; revision naik pada mode/price/quantity, sehingga mode berbeda tidak dapat menjadi retry upaya lama. Completed draft/item guards tetap mencegah perubahan setelah commit. SaleTransactionItem menyimpan pricing_mode dan accepted unit price; HPP memakai nilai stok, bukan harga grosir. ReceiptView membaca snapshot, tidak mengakses harga terbaru untuk cetak ulang kelak. Pembatalan penjualan penuh dan printer tetap M4/M5, tanpa implementasi palsu.

StockInputController adalah state formulir lokal (jumlah/unit/isi), bukan Provider global/saldo stok. StockInput/StockPurchase pada domain mengonversi integer dan total biaya dengan BigInt; WholeQuantityFormatter pada presentation menolak seluruh edit invalid. Service menerima nilai typed, tidak teks. Tidak ada SQL/rumus valuasi di widget. Preview menggunakan helper yang sama.

## Satu saldo dan biaya eksak

Produk tetap satu SKU/barcode/saldo dalam pcs. Produk lama default base_unit_label pcs; label ini tidak mengubah makna quantity lama. pack_label/pack_size harus keduanya NULL atau label nonkosong/integer positif. Mengubah konfigurasi hanya revision master, tidak stock_revision/value/batch/history. Harga grosir nullable, >0 jika terisi dan mempunyai currency/scale produk. Warnings membandingkan dengan retail serta rasio nilai/quantity HPP memakai perkalian BigInt (tanpa pembulatan display). Peringatan tidak mengubah harga; Gudang juga menampilkan peringatan ketika biaya stok terbaru berubah.

Penerimaan 5×40 pcs, harga120000/dus: quantityBase200; total600000 minor/600000000000 micros; unit cost3000000000 micros. StockPurchase menghitung count×costPerInput terlebih dahulu. Nilai stok bertambah exact total; unit_cost_micros dibagi/half-up untuk informasi, tidak dikalikan ulang menjadi total. USD/MYR0.01 per box3pcs menyimpan total1000000 micro-minor, informasi perpcs333333; residue tetap pada nilai total dan konsumsi terakhir mengambil seluruh sisa. CostAmount10^6 per minor terpisah dari currency scale. Semua penyesuaian/opname tetap memakai aturan M2 dan bukan pembelian baru. Harga beli saat opname stok kosong tetap beracuan pcs, meskipun quantity input dus.

API kompatibilitas create(initialQuantity/unitCost)/receive tetap tersedia. API typed create(initialPurchase)/receivePurchase menyimpan snapshot unit input; jangan memasok dua representasi awal sekaligus. adjustInput hanya mengonversi count ke base lalu memakai adjustment lama. Restock harus >0; initial/count0 sah; pack size tetap >0. Reversal memakai exact before totals dan stock_revision dependency, sehingga edit konfigurasi tidak memblokir reversal tetapi penjualan/adjustment selanjutnya memblokirnya.

## Migration dan fakta

V6 ALTER additive; old retail mode, wholesale/config NULL, quantity/value/snapshot lama tidak ditulis ulang. Receipt input lama seluruh kolom konversi NULL: tidak menebak bahwa inputnya dus maupun pcs; quantity dasar dan biaya lama tetap terbaca. Receipt baru membawa input_unit(base/pack), input_quantity, pack_size_snapshot/label, base_unit_snapshot, input_unit_cost_micros dan currency_code/scale; total_cost_micros otoritatif. Header currency tetap immutable; insert guard memeriksa total/quantity/unit/metadata tanpa multiplication overflow SQL. Batch dan stock_history merujuk receipt sumber dan quantity delta base; seluruh writes satu dbTxn. History page dibatasi51 dan diperkaya detail sumber satu produk, tetap cursor time/id; tidak memuat seluruh receipt/catalog.

price_history.price_kind membedakan retail/wholesale. before_price_minor/after_price_minor adalah snapshot nullable (NULL=tidak tersedia). Kolom legacy before_rupiah/after_rupiah tetap NOT NULL untuk kompatibilitas, sehingga NULL grosir memakai placeholder0 di kolom legacy; **reader wholesale wajib memakai snapshot nullable, jangan menginterpretasikan placeholder sebagai harga0**. Reader retail lama tetap memakai kolom legacy; semua row baru juga menyimpan typed snapshots. UndoToken membawa wholesaleChanged agar nilai NULL dapat dipulihkan secara eksplisit, dengan revision/time guard dan history append-only. Undo harga tidak mengembalikan perubahan konfigurasi master.

Backup contract V6 mencakup semua kolom baru; snapshot fixture menutup DB sebelum copy dan reopen/compare facts. Tidak menyalin DB produksi aktif/WAL, tidak mengganti DB pengguna. Package archive/manifest/logo/checksum/safety rollback/Drive dan restore nyata tetap M5 belum tersedia. Lihat BACKUP-CONTRACT dan VALIDATION-M31.

## Perubahan berikutnya

ARB ID/EN/generator resmi; purchasePricePerUnit sekarang eksplisit per pcs (finder dua regression native diperbarui sesuai label baru). Tambah label ke kedua ARB dan localization switch lalu gen-l10n/audit, jangan edit generated files. Harga/kemasan/purchase diubah melalui service; jangan merekonstruksi receipt/sale lama dari master. M4 laporan membaca harga/HPP snapshot dan agregat seluruh periode, M4 reversal mengembalikan biaya snapshot serta base qty, M5 printer/restore mempertahankan mode/input/metadata.


## Koreksi keamanan native runner

INCIDENT-M31-ANDROID-TEST menjelaskan kesalahan workflow yang menyebabkan package operasional di-uninstall/install ulang dan database lama tidak ditemukan. Fixtures DB saja tidak memisahkan sandbox. Gunakan tools/test_android.ps1: APKidentity integration diverifikasi dahulu, flag KASIR_INTEGRATION_TEST=true dan --no-uninstall wajib. Gradle guard memblokir direct/generated test entrypoint tanpa flag; launcher fully-qualified mendukung package fixture berbeda. Ordinary APK tanpa flag tetap com.example.kasir_app. Pengguna tidak punya backup; tidak ada pemulihan yang diklaim. Catatan sebelumnya mengenai tidak uninstall dikoreksi oleh insiden ini.
