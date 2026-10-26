# Biaya tidak diketahui — kontrak persistensi M5.3

Biaya canonical nullable: saldo yang mencampur biaya diketahui dan tidak diketahui
tidak memiliki total/average yang dapat dilaporkan. Penerimaan diketahui tetap
menjadi fakta dokumen, tetapi tidak melengkapi seluruh pool. Saldo kosong kembali
complete0 untuk penerimaan berikutnya. Snapshot penjualan lama tetap immutable.

Migrasi17 menambahkan flag `cost_complete` (legacy default1) tanpa menulis ulang
kolom/row lama. Kolom micros non-null lama tetap menjadi proyeksi pembukuan untuk
rekonsiliasi ledger dan reversal exact, **bukan biaya canonical jika flag0**.
Pada pool incomplete, pelepasan parsial tidak mengasumsikan average: proyeksi
numerik dilepas0, dan residu proyeksi hanya dibersihkan saat pool habis, selalu
dengan snapshot incomplete. Tidak ada angka proyeksi tersebut pada UI/ekspor
sebagai HPP/nilai/laba. Reversal mengembalikan proyeksi dan status snapshot;
barang unknown yang kembali mencemari pool baru yang semula diketahui.

Rekonsiliasi biaya harus menyebut quantity/revision terkini, total seluruh pool,
konfirmasi biaya0 dan alasan. Event append-only menyimpan before/after status
serta nilai proyeksi, termasuk bila delta0; perubahan nilai nonzero juga menjadi
ledger adjustment quantity0. Tidak mengubah biaya penjualan lama.

Agregat periode unknown mengeluarkan total HPP/laba nullable dan jumlah dokumen
incomplete. Nilai persediaan nullable disertai jumlah produk tracked incomplete;
999+flag untracked tidak termasuk aset. Ekspor memakai field kosong + status,
bukan string null atau angka0. Backup/restore memeriksa flag dan relasinya.

Preferensi biaya tersembunyi tersedia mulai schema17 setelah propagasi tersebut
dihubungkan dan diperiksa pada host serta SQLCipher native. Schema15–16 tetap
menolaknya. Handoff pengguna dan backup portable seluruh M5.3 masih tahap H/G.
