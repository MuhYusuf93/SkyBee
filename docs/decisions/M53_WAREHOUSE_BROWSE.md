# M5.3 E — daftar gudang dan supplier master

Kontrak M53_REQUEST §7.2.1–2,6,8 dan §7.4. Source schema26 menambahkan
supplier master opsional pada produk; migrasi25 sebelumnya tetap immutable.
Tidak ada relasi supplier produk pada baseline25, hanya supplier penerimaan.
Kolom `master_supplier_id` nullable/FK dan indeks ditambahkan tanpa inferensi
dari penerimaan lama. Penerimaan tidak memindahkan supplier master. Arsip
supplier mempertahankan relasi yang sudah ada, tetapi pilihan baru harus aktif.

WarehouseFilter/Cursor terpisah dari kontrak CatalogFilter alfabetis. Query
merangking di SQL: expiry bersaldo terlebih dahulu (atau tanggal acuan untracked),
tracked fisik0, lalu created_at DESC/id BINARY DESC. Batch bersaldo0 tidak
memengaruhi expired. Sentinel999 tidak menjadi stockout atau jumlah expired.
Untracked memakai label tanggal acuan dan jumlah fisik tidak diketahui.

Pencarian awalan literal, kategori/rak/supplier master, kondisi stok dan arsip
digabung sebelum LIMIT. Cursor terikat filter, tanggal/zona toko, generation
database dan catalogue_epoch; perubahan memerlukan refresh, bukan append.
ORDER BY dan predicate continuation sama. Ranking berbasis tanggal memerlukan
sort SQL; tidak ada klaim semua query bebas TEMP B-TREE.

Satu transaksi baca menghasilkan metadata, halaman50+1 dan aggregate batch
untuk produk pada halaman. Provider scoped route menahan maksimal3 halaman,
debounce275ms, membatalkan hasil lama dan refresh saat resume/perubahan stok.
Adapter alfabetis yang masih dipakai promo juga memakai pengayaan batch,
menggantikan panggilan detail per produk. Detail dan browse memakai aturan
saleable sama: MIN(fisik, jumlah batch layak) bila expiry aktif, bukan fisik
dikurangi expired yang bisa menjual saldo legacy tanpa batch layak.

Ketuk master membuka route produk terfilter dengan capability inventory dan
Provider sendiri. Picker tetap memilih relasi. Edit terlihat melalui tombol,
long-press kategori dan petunjuk tetap tersedia. Lookup kode mencakup arsip:
kode yang sudah ada tidak dianggap unknown lalu ditawari produk duplikat.

Form produk mempertahankan supplier master saat dibuka. Satuan ons pada layar
kecil memakai dropdown bounded. Peringatan harga rendah menggunakan threshold
currency toko untuk retail maupun grosir, dengan nominal/label yang jelas;
hard error biaya/grosir di atas retail tetap lebih dahulu. Dialog warning dapat
digulir. Disclosure grosir dimiliki state form saat lazy row dibuang; tidak
memakai PageStorage bersama yang bertabrakan dengan scroll offset textfield.

Backup memeriksa tipe/batas/FK supplier master sebelum menerima arsip, termasuk
arsip yang tidak menegakkan FK. Data lama, barcode, ons, stock/value dan supplier
transaksi tidak diubah oleh migrasi. Portable recovery menyeluruh tetap G.

Harga beli terakhir, validasi form operasi stok, multi-item receipt/opname,
tagihan/retur/pembayaran/jadwal supplier serta F–H tetap berikutnya. Tidak ada
klaim modul gudang/supplier M5.3 sudah lengkap dari checkpoint browse ini.
