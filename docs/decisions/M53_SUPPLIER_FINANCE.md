# Keputusan E3 — tagihan dan pembayaran supplier

Schema31 bersifat aditif. Penerimaan historis tidak otomatis dibuatkan utang,
ditandai lunas, atau diberi biaya tebakan. Satu penerimaan hanya mempunyai satu
tagihan aktif; pembatalan mempertahankan bukti dan memungkinkan tagihan koreksi.
Izin tempo dibaca ulang di transaksi yang sama. Gudang boleh membuat tagihan
operasional; pembayaran nyata, rekonsiliasi biaya historis, perubahan due date
final dan pembatalan tetap memerlukan Pemilik.

Total tagihan normal mengikuti jumlah biaya sumber tepat dalam minor unit.
Unknown atau pecahan lebih halus tidak dibulatkan diam-diam. Rekonsiliasi owner
boleh menyimpan total keuangan historis dengan alasan dan cakupan biaya sumber,
tanpa mengubah stok, nilai lama atau HPP. Snapshot supplier/terms/currency,
rolling source hash per100baris, operation ID/hash dan actor disimpan immutable.

Nominal pembayaran yang dilaporkan Gudang adalah catatan, bukan pembayaran
aktual. Syarat tunai tidak memberi bukti lunas. Setiap pembayaran nyata merekam
tanggal/nominal/sumber/referensi/catatan, satu tagihan per pembayaran, owner,
revision dan operation ID/hash. Tidak ada transfer bank otomatis. Nominal baru
positif dan tidak melebihi saldo; 0 pada input awal tidak membuat payment row.

Penerimaan draft + tagihan opsional + pembayaran awal owner yang dipilih
diposting atomik. Retry seluruh instruksi tidak boleh berubah. Rekonsiliasi
penerimaan lama + pembayaran awal juga atomik; fingerprint pembayaran masuk
hash instruksi tagihan. Pembayaran berikutnya tidak memanggil writer stok/HPP.
Header revision/status adalah projection dari fakta append-only, dengan guard
satu kejadian per revisi. Reversal pembayaran, due amendment beralasan, dan void
tidak mengedit atau menghapus bukti lama. Tagihan aktif menghalangi pembalikan
penerimaan sampai ketergantungannya diselesaikan secara sah.

Kas fisik memakai jurnal D yang sama. Family `supplier_payment` merujuk tepat
satu payment atau reversal authoritative; arah dan pecahan sesuai sumber.
Tidak mengubah CHECK tabel kas lama atau rebuild tabel populated. Pembayaran
bank/dana pemilik tidak mengubah laci. Pembalikan pembayaran dengan kas terlacak
memerlukan uang yang benar-benar dikembalikan dan sesi aktif. Posting manual
dengan source ID palsu ditolak.

Daftar supplier wajib scoped, cursor terikat supplier/filter/generation/revision,
20baris mengganti halaman sebelumnya. Source items50 dan payments20 terpisah.
Ringkasan seluruh tagihan aktif mengakumulasi BigInt dalam halaman100, terpisah
per currency; bukan subtotal halaman UI. Filter open/paid/overdue mengikuti sisa
dan tanggal toko. Laporan konsolidasi/cutoff/export adalah tahap F berikutnya.

UI ID/EN menyimpan isian selama lock; Back dirty memakai guard yang sama.
Kalender due date menerima hari ini dan historis sesuai tagihan, tidak memakai
batas besok dari expiry. Alur tagihan memunculkan biaya yang dibutuhkan pada
editor penerimaan walau preferensi harga beli tersembunyi. Source generation dan
grant dicek ulang sebelum serta sesudah I/O/commit, termasuk antrean transaksi.

Validator backup membaca seluruh model baru, FK, hubungan sumber/terms/cash,
snapshot biaya/hash, canonical input confirmation, dan replay revisi gabungan
dalam halaman terbatas. Pembayaran berlebih di tengah riwayat tidak boleh
disembunyikan reversal kemudian. Ini tidak menggantikan uji portable lintas key
dan keselamatan restore tahap G.

Retur fisik, kredit/refund supplier, jadwal/pengingat masih tahap E3 selanjutnya;
nilai kredit tagihan saat checkpoint31 ini 0. Tidak mengklaim seluruh E3 selesai.
