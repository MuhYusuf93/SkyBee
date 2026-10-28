# E — daftar gudang dan supplier master

Source0.5.2+12/schema26, setelah ons cf3e315 yang sudah push. Ini checkpoint
browse dan form master; seluruh sisa gudang/supplier E serta F–H masih aktif.
[Keputusan implementasi](decisions/M53_WAREHOUSE_BROWSE.md).

Daftar baru memfilter dan mengurutkan expiry bersaldo, tracked fisik0, lalu
produk terbaru di SQL sebelum halaman dibatasi. Cursor memuat konteks filter,
zona/hari, generation dan epoch. Pengayaan batch menggantikan detail per produk;
cache route maksimal3 halaman, debounce275ms dan refresh saat data berubah/resume.
Detail stok juga memakai MIN(fisik,batch layak) agar saldo tanpa batch tidak
otomatis dijual. Sentinel999 untracked tetap bukan stockout atau jumlah expired.

Supplier master opsional memakai FK baru, terpisah supplier penerimaan. Migrasi
tidak menebak relasi lama; arsip mempertahankan fakta. Tap kategori/supplier
membuka produk terfilter; edit terlihat dan long-press kategori tetap. Barcode
arsip tetap ditemukan. Backup menolak relasi rusak sebelum mengambil metadata.
Grosir mengikuti threshold currency yang sama dengan retail; IDR99 pada ambang
100 mengingatkan di Ubah, dengan label/nominal, hard error tetap lebih dahulu.
Dropdown ons dan dialog warning muat di320px/text2x/keyboard. Disclosure grosir
dimiliki form; edit dan revert menjadi bersih tanpa menyimpan.

Host acceptance32 PASS1:28 (gudang SQL5/UI2, ons6, barcode2, form lama17),
tambahan legacy inventory2 PASS10s. Analyzer bersih176,1s; format455/0changed;
l10n956keys/643refs/245RIDs dan PIN106upstream/license identik.
[Bukti host](evidence/m53-20261026/warehouse-host-validation.json).

Riwayat gagal dan perbaikan ada di bukti host: API fixture/created_at/reference
untracked/alias timezone diperbaiki tanpa melonggarkan constraint; UI lazy-load
dan label pencarian diikuti wait owner dan reveal. Acceptance awal13PASS2FAIL16s
menemukan overflow dropdown ons, focusedUI2PASS12s setelah bounded width.
Penambahan warning grosir menemukan dialog overflow dan lazy disclosure;
percobaan PageStorage bertabrakan bool state dengan double scroll offset,
diganti state lokal form. FocusedUI2PASS13s lalu acceptance32PASS. Tidak ada
data operasional yang dipakai sebagai fixture atau reset untuk membuat tes lulus.

Native DV7 PASS3:02/Poco7 PASS2:29; seluruh728/659hash berkas lama cocok.
Kedua wrapper exit0/controlOff; awakeDV dipulihkan tepat. Source551 identik
sebelum/sesudah kedua run. [DV](evidence/m53-20261026/warehouse-dv.json),
[Poco](evidence/m53-20261026/warehouse-poco.json),
[checksum source](evidence/m53-20261026/warehouse-source-sha256.json).
.skybee+12/schema14 belum diupdate/reset. Seluruh pengujian mutasi memakai
database numerik baru di package integration dengan background paused.
WidgetTester gesture bukan bukti sentuhan manual/ADB fisik. Benchmark percepatan
daftar ini tidak diukur; EXPLAIN memeriksa indeks batch yang dipakai.

Panduan ID: di Gudang pilih kondisi stok, lalu gabungkan pencarian dengan
kategori/rak/supplier master pada bagian filter. Ketuk master untuk membuka
produk terkait; pilih tombol edit atau tekan lama kategori untuk mengubah nama.
Supplier master hanya pengelompokan, supplier pembelian tetap dipilih terpisah.
Periksa warning harga grosir rendah; Periksa kembali mempertahankan draft.

English: choose a stock condition and combine search with category/shelf/master
supplier filters. Tap a master to browse linked products; use Edit or long-press
a category to rename it. The master supplier groups products; each purchase
keeps its own supplier. Review a low wholesale price warning without losing input.

Berikutnya: biaya pembelian terakhir dengan konversi tepat, field errors form
operasi stok, receipt multi-item/opname, retur/tagihan/pembayaran/jadwal supplier,
laporan/output F, keselamatan data G dan pemasangan/handoff H.
