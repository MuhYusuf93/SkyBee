# Kredit retur dan refund supplier M5.3

Schema33 menambahkan fakta persetujuan kredit, alokasi, refund aktual, reversal
masing-masing dan ledger ketersediaan kredit. Tidak mengubah nominal retur
fisik menjadi nominal kesepakatan secara otomatis. Seluruh aksi keuangan ini
milik owner; gudang tetap dapat membaca/mencatat dokumen operasional yang
diizinkan. Lihat kontrak §7.6–7.7 dan keputusan retur fisik32.

Persetujuan mengikat preview ke tagihan asal beserta revisinya, atau ketiadaan
tagihan aktif. Alokasi awal atomik = minimum kredit disepakati dan sisa tagihan
asal; bila sudah lunas/tidak ada tagihan, seluruh nilai belum dialokasikan.
Kelebihan tidak membayar tagihan lain diam-diam. Pemilik memilih satu tagihan
supplier/currency yang sama untuk setiap alokasi berikutnya, dengan CAS kedua
saldo. Uang/nominal minor integer dan replay agregat menggunakan BigInt.

Refund mencatat uang yang benar sudah diterima, maksimal kredit tersedia.
Transfer/dana pemilik tidak mengeksekusi pembayaran atau mengubah laci. Refund
dari laci yang dilacak mencatat pecahan masuk dan jurnal IN; reversal-nya
memerlukan pecahan OUT aktual. Semua menggunakan keluarga jurnal supplier
yang sudah ada dan provenance UUID otoritatif, bukan jurnal kedua. Tidak ada
perubahan stok/nilai persediaan/HPP penjualan ketika memposting kredit/refund.

Koreksi tidak menghapus fakta. Reversal alokasi memulihkan saldo tagihan dan
kredit; reversal refund memulihkan kredit; reversal header baru boleh setelah
seluruh dependensi efektif dibalik. Retur fisik baru dapat di-undo setelah
kredit finansial dibalik. Persetujuan pengganti boleh memakai ID baru sesudah
reversal, sementara bukti sebelumnya tetap ada. Retry operation key/payload
identik mengembalikan hasil lama; payload berbeda atau CAS usang ditolak.

Validator backup memeriksa source/FK/currency/role, jumlah alokasi awal pada
snapshot revisi tagihan saat persetujuan, typed ledger sequence dan before/after
setiap langkah. Saldo akhir yang benar tidak menutupi overspend di tengah
histori. Replay invoice menyatukan pembayaran, kredit, reversal, due amendment
dan void. Archive31/32 tetap divalidasi tanpa membaca tabel33 yang belum ada.
Daftar20 dan fakta20 memakai cursor berkonteks; ringkasan seluruh supplier
memakai halaman100 terpisah per currency, bukan subtotal halaman UI.

Pengujian clock yang bergerak juga menemukan producer retur32 mengambil
beberapa timestamp untuk satu posting. Schema32 mengharuskan timestamp header,
draft final dan sumber sama; fixture clock konstan sebelumnya menyembunyikannya.
Producer kini menangkap satu timestamp dan meneruskannya ke stock/history/
operation/source-ledger/header dalam posting dan undo. Reproduksi host memakai
source lama ditutup gagal sesuai harapan; siklus clock bergerak source baru
lulus. Source32 sebelumnya hanya checkpoint host, belum dipasang ke .skybee.

UI mendukung ID/EN, preview kredit dan sisa, alasan/date, dirty Back saat kunci,
konfirmasi sebelum posting, input nominal kosong wajib, dan koreksi beralasan.
Fixture widget memakai input sintetis; itu bukan bukti keyboard OEM atau aksi
fisik. Readiness diuji setelah pump stabil, dan klien teks difokuskan ulang
setelah busy/disable dan scroll lazy. Semua assertion saldo domain dipertahankan.

Native33 dan cross-key portable restore belum ditutup pada checkpoint host ini;
native E3 gabungan sesudah jadwal wajib sebelum F, portable restore mengikuti G.
Tidak ada reset/update/reseed package operasional atau .skybee pada checkpoint.
