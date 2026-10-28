# Izin tempo supplier — prasyarat E3

Schema30 menambahkan supplier_terms dan supplier_terms_events. Tidak mengubah
kolom/tabel lama atau membuat tagihan dari receipt lama. Izin tempo defaultfalse
melalui ketiadaan profil, berlaku bagi supplier baru maupun lama. Supplier tetap
ID stabil yang terpisah dari pelanggan serta supplier transaksi/penerimaan.

Warehouse dapat membaca kesepakatan supplier sebagai fakta operasional; hanya
pemilik yang dapat menulis, diperiksa sebelum dan sesudah dbTxn. Save memakai
revision CAS, perubahan nilai menambah revision dan immutable before/after event
dengan actor_role owner serta audit. Nilai sama tidak membuat event palsu. Form
stale ditolak tanpa menimpa pengaturan yang lebih baru; mematikan izin tidak
menghapus data. Arsip supplier tetap mempertahankan profil/histori.

Layar pengaturan dari editor supplier memiliki gate sendiri, scope state lokal,
dirty Back (termasuk warning generik saat terkunci), generation guard, save busy
dan role-listener. Gudang melihat nilai tersimpan dengan switch disabled tanpa
tombol Save; service tetap menolak pemanggilan langsung. Pilihan checkbox tidak
diubah karena focus hilang. Data belum dimuat tidak ditampilkan sebagai off.
Reload pada konflik mengambil revisi baru untuk ditinjau sebelum Save berikut.

BackupValidation schema>=30 memverifikasi profil/current revision terhadap
riwayat append-only serta chain before/after. Migrasi aditif tidak menghasilkan
payment, utang, stock_history atau menerima ulang barang. Uji migrasi menanam
receipt dan sesi opname posted29 lalu membandingkan semua kolom/tabel lama.

Ini prasyarat, bukan implementasi invoice/payment. Writer tagihan berikutnya
WAJIB membaca termsOn pada dbTxn yang sama saat posting, bukan mempercayai flag
UI lama. Off menghentikan credit invoice baru; tagihan/payment yang sudah ada
nantinya tetap rekonsiliasi append-only. Penerimaan lama tetap payment-unreconciled
sampai pemilik melengkapi fakta tanpa menerima stok lagi. E3 invoice/payment,
retur/approved credit/jadwal supplier serta F/G/H tetap aktif.
