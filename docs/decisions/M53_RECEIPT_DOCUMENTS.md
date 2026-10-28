# Dokumen draft penerimaan banyak barang

E2 M5.3 memakai migrasi aditif27–28. Receipt/item/batch/history yang sudah ada tetap
menjadi sumber fakta pembelian dan nilai persediaan; tabel receipt_drafts/lines
hanya menyimpan input dan jejak finalisasi. Tidak menebak pembayaran/utang dari
receipt lama. Keuangan supplier E3 serta opname adalah pekerjaan tersendiri.

Draft bertahan setelah route/proses ditutup. Maksimal100baris per dokumen;
daftar memakai satu halaman20+1 dengan keyset updated_at/id BINARY, status,
generation dan revision database pada cursor. Tidak memuat seluruh katalog atau
seluruh halaman ke Provider. Setiap mutasi draft memakai revision CAS dan
capability inventory di dalam transaksi yang diperiksa lagi sebelum commit.

Scan literal barcode/SKU menambah1 unit dasar. Baris kemasan tidak dianggap satu
dus per scan: buat baris dasar terpisah. Beberapa calon baris/batch memerlukan
pilihan target eksplisit atau baris baru; barcode produk bukan bukti batch fisik.
Kode unknown tidak membuat placeholder. Form barang sebenarnya dibuka dengan
stok awal0 yang tidak dapat diubah pada alur ini; kembali ke draft tanpa posting
quantity penerimaan. Supplier dokumen adalah supplier transaksi, tidak mengubah
supplier master. Edit biaya manual tidak ditimpa ketika supplier berubah.

Editor bersama menyimpan quantity/unit/isi kemasan/biaya/expiry ke draft,
bukan stok. Biaya yang sudah diisi pada draft tetap ditampilkan walau preferensi
biaya kini tersembunyi, agar edit satuan tidak membuang harga. Input biaya baru
per unit mengikuti minor currency tepat, tanpa pembulatan untuk mengisi angka.
Known0 membutuhkan persetujuan gratis; unknown tetap berbeda. Expiry kalender,
field error/focus, privacy gate dan dirty Back mengikuti editor sebelumnya.

Konfirmasi memvalidasi seluruh baseline product revision/currency/zone/supplier
sebelum penulisan pertama. Master/stok yang berubah menolak seluruh dokumen;
Tinjau ulang menyegarkan baseline secara eksplisit, mempertahankan input untuk
ditinjau sebelum konfirmasi lagi. Satu header receipt dan semua item/batch/
operation/history/nilai/audit dicatat dalam satu transaksi, memakai writer
_receive yang sama. Retry document ID+confirmed revision mengembalikan receipt
yang sudah tercatat; tidak menambah stok lagi. Final draft dan baris immutable.
Panggilan receive lama tanpa context/revision tambahan mempertahankan hash retry.

Baseline stok terpisah dari master revision: checkout dapat mengubah hanya
stock_revision. Migrasi28 menambah stock_revision nullable pada baris draft;
NULL pada draft27 berarti belum tercatat, wajib review eksplisit, bukan diisi
dengan stok saat migrasi. Add/review capture kedua revision; confirm28 menolak
mismatch/NULL sebelum menulis header. Editor tunggal juga meneruskan optional
expectedStockRevision, dengan marker hash hanya jika diberikan. Posted receipt
legacy tetap merupakan fakta; migrasi tidak mengulang atau membatalkannya.

Penerimaan untracked mencatat actual receipt/item dan reference history dengan
provenance item. Sentinel tetap999 dengan flag untracked dan aset0; tidak ada
batch/history quantity999. Unknown actual receipt mengubah acuan menjadi unknown,
bukan memakai biaya known lama sebagai fakta pembelian baru. Reversal memulihkan
acuan sebelum operasi beserta flag pengetahuannya, dengan dependency check.

Inventory operations kini menunjuk receipt item secara langsung. Saran harga
memakai urutan stock_revision_after, bukan ID acak ketika waktu sama, dan tidak
bergantung jam dinding untuk urutan mutasi produk. Index baru mendukung urutan
ini. Data legacy tanpa link diterima hanya jika satu item cocok pada receipt/
produk; tidak memilih acak dari beberapa batch. Reversal/transisi tracking tetap
dikecualikan dari pembelian actual, sedangkan saldo awal diberi label acuan.

Reversal dokumen harus menyatakan entireDocument dan ditawarkan pada layar yang
menampilkan seluruh item, dengan alasan dan konfirmasi. Tombol detail satu
produk menolak dokumen ini agar tidak membalik produk lain tanpa tinjauan.
Semua produk diperiksa dependency/reversal sebelum penulisan pertama, lalu
diurungkan dalam urutan baris terbalik secara atomik. Mutasi berikutnya menghalangi
reversal; tidak menimpa snapshot HPP penjualan. E3 wajib menambah dependency
tagihan/pembayaran/kredit sebelum dokumen yang ditagihkan dapat direversal.

Backup menjalankan preflight metadata bounded dan relasi document/item/operation/
reference history selain integritas/FK/enkripsi. Constraint dari arsip impor
tidak dianggap bukti validasi. Native memakai fixture terisolasi dan baseline
protected baru. Poco tersedia kembali sejak28Oktober18:40; jangan mengembalikan
data pribadi ke checkpoint lama. Hasil pengujian dicatat pada laporan terpisah.
