# Opname fisik durable dan snapshot selisih

M5.3 E2 menggunakan migrasi aditif29 sesudah receipt27–28 `9c6c66a`.
Tidak mengubah tabel/kolom lama, tidak memulai ulang toko atau membuat receipt
baru dari barang temuan. F laporan konsolidasi selisih masih tahap berikutnya.

Satu sesi berstatus draft/posted/cancelled dan memiliki revision CAS, currency,
zona waktu, waktu, alasan dan capability aktor. Satu produk memiliki satu baris
per sesi; maksimal100produk, dapat dibagi ke sesi berikutnya. Baseline ditangkap
saat produk pertama dimasukkan, meliputi revisi master DAN revisi stok, jumlah,
nilai/coverage dan seluruh batch yang masih berisi. Sesi tidak menangkap seluruh
katalog. Batch dibaca/disimpan dalam keyset chunk100 dan ditampilkan50+1 dengan
position/id BINARY, generation dan baseline_epoch. Daftar sesi20+1 memakai
updated_at/id BINARY dengan status/generation/database revision. Tidak ada
batas200batch yang akan memotong stok SKU dengan banyak batch.

NULL berarti belum dihitung. Angka0 hanya ditulis melalui input/pilihan fisik0
yang eksplisit. Tambah barang tanpa count tetapNULL. Scan literal barcode/SKU
menambah1UNIT DASAR pada satu target yang tidak ambigu; bukan satu kemasan dan
bukan serial unik tiap pcs. Beberapa batch mengharuskan pilihan fisik; scan itu
menyimpan baseline tanpa menebak count/batch. Edit count menyimpan input unit,
count, pack size/label serta hasil base quantity. Minus, resetNULL dan Undo50
beroperasi atas input saja. Histori undo bounded; recount eksplisit menghapus
count/undo/nilai input barang itu dan menangkap baseline baru. Unknown product
menggunakan formulir barang nyata dengan stok awal0, lalu ditambahkan/dihitung.
Untracked999 ditolak; pengaktifan tracking tetap melalui alur resminya.

Capability inventory diperiksa sebelum dan sesudah transaksi. Draft/count tidak
mengirim inventoryChanged setelah setiap scan; finalisasi tetap satu writer
dengan satu notifikasi perubahan stok. Semua total memakai BigInt sebelum
penulisan agar SQLite SUM valid dan tidak overflow. Gudang boleh menyelesaikan
opname; actor_role menyatakan capability owner/warehouse, bukan identitas pegawai.

Finalisasi memerlukan count seluruh batch, ringkasan per produk dan alasan.
Semua revisi, saldo, coverage, currency, zona dan vector batch diperiksa sebelum
mutasi pertama. Konflik akibat sale/restock/perubahan master tidak menimpa stok;
input lama bertahan sampai pengguna memilih recount. Semua produk, batch,
operasi adjustment, stock_history, nilai dan snapshot final berada dalam satu
dbTxn. Kegagalan produk kedua me-rollback produk pertama. Retry posted hanya
menerima confirmed_revision dan alasan yang sama, tanpa adjustment baru.
Count yang tepat sama tetap bukti opname selesai, tanpa history mutasi palsu0.
Status final dan anak snapshot dilindungi trigger immutable.

Review read-only sebelum modal final menandai ID baris bermasalah lewat satu
query indexed dan aturan coverage/total. UI mengungkap baris pertama dengan
caption singkat; pesan panjang tetap di area penjelasan halaman. Ini bukan lease:
mutasi setelah review tetap ditolak finalisasi atomik. Batch choice memakai ID
observation stabil, bukan posisi child yang kebetulan sudah dibangun di viewport.

Biaya tetap pool moving average per PRODUK. Selisih bersih jumlah menentukan
selisih nilai; redistribusi antarbatch tidak mengganti HPP menjadi FIFO atau
memasukkan gross kerugian batch sebagai HPP penjualan. Penurunan memakai
removalCost dan menghabiskan residu tepat pada pengosongan terakhir. Penambahan
pada pool known memakai average yang sama dengan aturan adjustment proyek;
unknown tetapunknown. Coverage sebelum/hasil disimpan dan estimasi nilai tidak
ditampilkan sebagai known bila salah satunya incomplete. Snapshot tidak dihitung
ulang dari stok/harga hari ini.

Pool awal0 tidak mempunyai average. Total nilai barang temuan diisi untuk SELURUH
count saat ini, tepat pada minor currency, bukan per-pcs/pack yang dibulatkan.
Input optional unknown hanya dapat diposting bila biaya pembelian opsional;
known0 memerlukan persetujuan gratis. Total terikat valuation_quantity: count
berubah wajibReview nilai; Undo count yang mengembalikan basis dapat memulihkan
kecocokannya. Tidak menciptakan pembelian/utang supplier. Bila belum ada actual
purchase, pool known nonempty dapat menjadi hint berlabel REFERENCE dengan rasio
tepat; latest purchase unknown/legacy ambiguity tetap tidak diganti reference.

Batch tambahan ditemukan sebagai adjustment-only batch dengan receipt itemNULL,
bukan menaikkan fakta received_quantity pembelian lama. Tanggal nyata dapat lewat,
hari ini atau masa depan; batch baseline mempertahankan expiry-nya. Pemilih tanggal
physicalObservation mengizinkan tanggal lampau; aturan penerimaan biasa tetap
besok. Expired tetap fisik dan tidak menjadi stok layak jual. Clear tanggal batch
temuan eksplisit; tanggal baseline tidak dapat diganti melalui count.

Route daftar/dokumen/batch/editor memiliki ManagementGate sendiri. Editor count
dan total serta input kode/alasan memiliki FormExitGuard dengan capability
inventory. Back terkunci memakai warning generik; Stay tetap terkunci dan unlock
memulihkan input. Save menutup hanya route editor miliknya. First-invalid quantity/
pack/total/alasan diungkap dan difokuskan setelah field aktif kembali. Semua
penyimpanan menguji generation agar callback lama tidak menulis setelah restore.

BackupValidation schema29 memanggil StocktakeValidation: header/snapshot/link/
currency/zone/expiry/operation/undo diverifikasi lewat SQL dan stream100; total
BigInt per baris melintasi batas halaman dan JSON undo dibatasi/diwhitelist.
Validasi tidak menganggap snapshot lama harus sama dengan saldo stok saat ini.
Kata-kata UI menjelaskan salah hitung, mutasi belum dicatat, kerusakan dan sebab
lain; selisih bukan bukti pencurian.
