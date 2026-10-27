# Pencarian produk dan popularitas M5.3

Kontrak aktif: [permintaan §5.1](M53_REQUEST.md). Schema23 hanya menambah indeks
versi/cache turunan; tidak mengubah penjualan, kuantitas atau snapshot lama.

Urutan default adalah Paling sering terjual. Barcode/SKU persis mempunyai tier
pertama, termasuk hasil tidak layak yang tetap dinonaktifkan. Hasil biasa memakai
kelayakan jual dahulu, jumlah transaksi selesai yang memuat produk menurun,
quantity bersih menurun, relevansi, nama BINARY dan ID BINARY. Mode Paling sesuai
memakai tier kode/kelayakan yang sama kemudian relevansi/nama/ID. Popularitas
tidak pernah memperluas himpunan hasil di luar kode/nama/token/kategori/alias.
Satu transaksi dengan banyak unit tetap dihitung satu transaksi.

Window rolling30×24jam mencakup created_at mulai batas sampai waktu snapshot.
Reversal penjualan penuh mengecualikan penjualan aslinya, termasuk reversal yang
terjadi kemudian. Model koreksi saat ini tidak memiliki retur sebagian unit
penjualan pelanggan; reversal pembayaran sebagian/pelunasan tidak mengubah unit
terjual dan tidak menciptakan popularitas. Retur supplier pada tahap E berbeda
dari reversal penjualan pelanggan. Tidak menambahkan mesin refund di tahap C.

Tracked tanpa expiry memakai stok fisik; tracked dengan expiry memakai minimum
stok fisik dan jumlah batch layak (tanggal setelah hari toko atau tanpa tanggal).
Batch expired dan batch layak pada satu produk tidak memblokir seluruh produk.
Saldo fisik tanpa batch layak tidak menjadi bukti kelayakan alokasi checkout.
Perubahan ini fail-closed dan tidak memperbaiki/menghapus stok secara diam-diam.
Untracked memakai flag, bukan menebak dari sentinel999; reference expiry tetap
berlaku. Produk tracked fisik999 tetap tracked. DTO publik tetap whitelist tanpa
biaya atau nilai persediaan.

SQLite mengagregasi seluruh window memakai indeks waktu header dan parent item,
bukan mengurutkan histori di Dart. Cache memuat count dan quantity per produk,
metadata window/revision/sale_epoch. Cache direkonstruksi atomik ketika fakta
penjualan/reversal berubah, lewat60detik, atau jam mundur. Kegagalan rebuild
rollback ke cache lengkap sebelumnya. Metadata barang/batch/kategori/alias dan
zona/currency menaikkan catalogue_epoch. Cache/term-index writes tidak menaikkan
epoch mereka sendiri. Cost grouping/sorting sebanding kandidat/window; keyset
tidak menghilangkan seluruh biaya ranking dan bukan klaim O(1).

Cursor mengikat raw query trim (case dan nol di depan dipertahankan), sort,
DBgeneration, catalogue_epoch, hari/zona toko dan cache revision/window valid.
Cursor kedaluwarsa ditolak dan Provider memulai ulang halaman pertama. Pembacaan
dan publikasi DTO tetap dijaga proof kunci kasir. Lifecycle resume dan refresh
eksplisit memperbarui query; tidak memasang alarm waktu tepat di background.
Inventory events termasuk checkout/reversal memperbarui query yang sama.
Provider tidak mendengarkan semua commit agar rebuild cache tidak memicu loop.
Subscription cold dibatalkan ketika pemilik layar di-dispose.

Dirty index dibaca100 produk sekali dengan join kategori; alias memakai keyset
250 baris dan writes batch250. Ini membatasi objek serta panggilan platform,
termasuk pada rebuild pertama setelah migrasi. DTO halaman memakai tiga query
bounded dengan whitelist yang sama dengan baca satu produk. Batch tetap berada
di transaksi pemanggil; fault tidak meninggalkan index setengah jadi. Responsive
wide/narrow yang membuatulang panel mengambil teks Provider agar query tetap
terlihat. Helper native harus menerapkan resize lalu mengungkap field lazy pada
route aktif sebelum memperoleh text client; input ke subtree lama bukan bukti
bahwa query sudah dikirim.

SQL membatasi16+1 per halaman; Provider menyimpan maksimal tiga halaman/48 hasil
dan cursor maju. Tombol hasil berikutnya berada pada daftar lazy240px yang sama.
Debounce275ms, fokus pencarian M5.2, scan exact/ambiguity dan setiap intent Enter
berulang dipertahankan. Scan yang mulai saat paging membatalkan state paging;
hasil asinkron lama tidak menimpa query/order baru.

Backup memvalidasi tipe dan batas metadata/cache, TTL dan ukuran window. Cache
yang mengaku source_epoch mutakhir dibandingkan dua arah dengan agregat SQL
(termasuk baris hilang). Cache epoch lama diterima sebagai data turunan stale
dan harus direkonstruksi pada penggunaan berikutnya. Cache bukan fakta keuangan.
Tender JSON kini dibatasi sebelum perbandingan lintasbaris pada import.

[Laporan dan batas bukti](../M53_SEARCH_REPORT.md). Sisa D–H tetap aktif.
