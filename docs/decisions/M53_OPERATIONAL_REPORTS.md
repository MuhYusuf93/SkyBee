# F3 — laporan stok, supplier, dan ekspor

30 Oktober 2026. Acuan permintaan §9; melanjutkan F2 `b0cfc60` yang sudah
dipush. Implementasi masih diperiksa; belum handoff dan belum native F3.

Pemilik saja membuka laporan konsolidasi maupun ekspor. Service membaca satu
snapshot SQL, memeriksa grant/epoch dan generation, mengambil paling banyak100
baris per panggilan platform, lalu menjumlahkan dengan BigInt. UI menyimpan
satu halaman20 baris. Cursor mengikat scope, revision, generation dan hari toko;
perubahan membuat cursor lama ditolak. Ringkasan selalu seluruh scope filter.
Schema37 menambah lima indeks expression/compound, tanpa menulis baris bisnis.
Planner36 memakai temp sort untuk grouping;37 memakai range seek untuk group
berikutnya dan equality-group/ID-range untuk sisa group, tanpa temp sort.
Perbatasan group membutuhkan maksimum dua source read terbatas100 baris, bukan
satu panggilan per produk. Migrasi36→37 membandingkan semua hash tabel lama.

Potensi memakai harga eceran master saat snapshot × jumlah tracked layak jual.
Alokasi carrying value memakai removalCost moving average yang sama dengan
checkout, termasuk pembulatan dan residu penuh saat habis. Sisa carrying cost
adalah pool dikurangi bagian layak, bukan pengurangan seluruh pool dari omzet
parsial. CostAmount.scale adalah satu juta **per minor unit**, termasuk USD2.
Produk untracked tidak dikalikan999; tracked999 sah. Arsip dan jumlah nonjual
dikecualikan, expired ditampilkan. Biaya unknown tidak menjadi0: subtotal biaya/
laba diketahui disertai jumlah produk/unit belum lengkap dan dikecualikan.
Agregasi produk/kategori/supplier/toko tidak join riwayat penerimaan; supplier
adalah supplier pada data barang, bukan asal batch. Jumlah lintas satuan bukan
jumlah pcs yang dapat dibandingkan tanpa melihat satuan tiap produk. Ini bukan
ramalan, penjualan terealisasi, laba bersih atau simulasi promo/grosir.

Selisih stok hanya dari stocktake_drafts posted dan snapshot stocktake_lines:
baseline/final, tanggal, alasan, aktor dan operation_id asli. NULL tidak menjadi
0; tidak ada opname menghasilkan “Belum ada data pembanding”. Nilai penyesuaian
bukan HPP penjualan atau bukti pencurian. Saldo produk hari ini tidak dipakai
untuk menghitung ulang hasil lama.

Utang versi ini adalah **saldo saat ini**, tanpa picker saldo historis. Tagihan
posted memakai proyeksi yang sama dengan SupplierService, termasuk pembayaran/
kredit yang belum direversal dan due amendment terakhir. Sisa saldo dijumlahkan
per currency; bucket overdue1–7/8–30/>30 memakai beda tanggal kalender UTC untuk
tanggal lokal toko, bukan selisih jam DST. Tanpa due date tidak overdue. Filter
all/open/future/today/overdue/paid/noDue dan level supplier/tagihan memakai scope
yang sama untuk summary, halaman dan ekspor. Arsip supplier tidak menghapus utang.

Pembayaran periode berdiri sendiri: original memakai paid_date operator,
reversal memakai created_at diproyeksikan ke hari/timezone toko (tabel reversal
tidak punya tanggal efektif). Original tidak hilang dari periode lamanya karena
reversal/void kemudian. Laci/bank/dana pemilik terpisah. Refund memakai event_date
operator untuk original dan reversal. Kredit available/net refund, penerimaan
pembelian belum direkonsiliasi, dan retur fisik belum disetujui ditampilkan
terpisah; carrying retur bukan nilai kredit yang disetujui atau pengurang utang.

Ekspor CSV/XLSX memakai ReportFileWriter dan ReportDestinationService yang sudah
ada. Kolom khusus opsional menjaga format ekspor lama. Nilai uang/ID adalah teks
eksak, CSV menetralkan formula; XLSX inlineString bukan formula/float. Artifact
sementara hanya direktori milik ekspor m51_report_UUID, dibersihkan saat batal/
gagal/akses berubah. Semua detail dan summary seluruh scope, metadata scope/
capture/timezone/satuan ikut diekspor. Pemilihan tujuan/SAF terjadi setelah lease
database dilepas. XML illegal control diganti U+FFFD, memperbaiki mojibake lama.

Audit kas D tetap memakai histori sesi/pecahan/transaksi dan kebijakan audit
wajib yang ada, ditautkan dari laporan; tidak ada ledger kas duplikat.

Syarat penutupan: uji domain/regresi ekspor, ID/EN320/text2, format/analyze/l10n,
native fixture di Poco dan DV melalui wrapper dengan hash data lama/finally/
awake exact, lalu bukti/laporan dan commit. G/H tetap tahap aktif sesudah F3.
Data .skybee belum diupdate/reset/reseed;100 produk/50 transaksi hanya H setelah
backup terenkripsi dan material pemulihan data lama diverifikasi.

Cursor UNION pembayaran/refund menggunakan (jenis kejadian, ID tabel), bukan
asumsi UUID unik lintas tabel. Group kursor mentah berbeda dari agregasi: dua
kejadian dengan ID sama tetap dua baris, tidak digabung. Ledger legacy valid
52 pembayaran/51 reversal dengan UUID lintas tabel sama membuktikan bug lama
103→102 di batas100; perbaikan mempertahankan103/net1000, seluruh halaman20
dan CSV. Tidak ada perubahan ledger atau schema untuk perbaikan cursor ini.
