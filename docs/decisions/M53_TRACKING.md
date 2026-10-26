# Penutupan dan pembukaan pelacakan stok M5.3

Schema18 mengarsipkan batas pengukuran fisik, bukan membuat opname0, kehilangan
barang atau biaya penjualan. Untuk saldo nonzero diperlukan pratinjau jumlah/
nilai, revisi stok yang sesuai, alasan dan konfirmasi. `stock_tracking_changes`
serta `stock_tracking_closed_batches` append-only mempertahankan saldo/batch
terakhir; batch aktif ditutup sebelum produk menjadi999+flag untracked. Ledger
quantity/value dinetralkan untuk scope tracked, dengan link operasi ke event
tersebut. **Laporan selisih opname/kerugian harus mengecualikan operasi yang
terhubung ke tracking change**, termasuk initial receipt saat pembukaan kembali.
Penjualan/HPP lama tidak diubah atau dihitung ulang.

Reference cost setelah penutupan dapat berupa input eksplisit, rata-rata historis
yang diketahui, atau unknown bila biaya disembunyikan. Rata-rata historis adalah
acuan, bukan klaim pembelian baru; hasil rounding0 per micro tidak menyatakan
barang diperoleh gratis. Input0 eksplisit tetap membutuhkan konfirmasi. Nilai
pool lama utuh tersimpan pada event, termasuk saat seluruh pool incomplete.

Tanggal paling awal dari batch yang ditutup dipertahankan secara konservatif
sebagai reference expiry untracked. Pembukaan kembali meminta jumlah fisik baru,
termasuk0; sentinel tidak pernah dianggap jumlah nyata. Reference expiry lama
dibawa ke batch baru, termasuk yang sudah lewat atau sedang dinonaktifkan,
melalui jalur internal khusus rekonsiliasi. Penerimaan pembelian baru tetap
memerlukan tanggal masa depan. Kasir memeriksa expiry untracked secara terpisah
dari batas quantity agar perubahan mode tidak membuat barang expired layak jual.

Mode seluruh/nonaktif yang masih konflik dapat dimulai dari mode parsial dengan
konfirmasi pemilik. Saldo tidak berubah massal. Pengguna meninjau setiap barang,
lalu memilih mode tujuan lagi; UI yang masih terbuka melanjutkan target semula.
Jika proses berhenti, mode parsial yang sudah disetujui tetap valid dan barang
tidak diubah otomatis. Pola tugas3 tetap menuntut mode seluruh; ubah pembagian
tugas melalui alur pemilik bila diperlukan.

API mengotorisasi inventory sebelum/sesudah transaksi, mengikat retry ke payload,
memeriksa saldo batch, dan menolak preview stok stale. Semua perubahan state
fisik/ledger/event/reference/audit memakai satu transaksi. Tab riwayat tracking
mempunyai keyset dan index sendiri. Restore memeriksa snapshot batch, relasi
opening, reference historis dan tanggal; tidak hanya mempercayai CHECK berkas.

Form yang sedang menyimpan menolak discard saat masih unlocked. Setelah locked,
Back tetap menampilkan warning dirty generik; keluar mencabut sesi sehingga
operasi protected yang tertunda tidak dapat menyimpan setelah discard.
