# Laporan stok dan supplier / Inventory and supplier reports

Pemilik: Laporan → Laporan stok dan supplier. Pilih jenis laporan, supplier/
kategori bila tersedia, lalu Terapkan / muat ulang. Pencarian adalah teks literal
yang mengandung input; nomor0 di depan tetap bagian identitas. Pilihan tanggal
hanya muncul untuk opname dan pembayaran/refund periode. “Dasar, cakupan dan
batas perhitungan” membuka asumsi lengkap.

Owner: Reports → Inventory and supplier reports. Choose the report and available
supplier/category filters, then Apply / reload. Search uses literal contained
text; leading zeros remain part of identifiers. Date filters appear only for
stocktakes and payment/refund periods. Open “Basis, coverage and calculation
limits” for the full assumptions.

- Potensi nilai jual stok: produk/kategori/supplier/seluruh toko. Harga eceran
  saat ini dan biaya moving average yang dialokasikan ke stok layak. Perhatikan
  subtotal biaya/laba diketahui dan cakupan unknown/untracked/arsip/nonjual.
  Supplier berdasarkan data barang, bukan bukti asal setiap batch.
- Selisih stok: opname posted, dengan baseline/fisik/delta, alasan, waktu dan
  dokumen mutasi. Tidak ada opname berarti belum ada pembanding. Kekurangan
  bukan bukti pencurian; nilai penyesuaian bukan HPP penjualan.
- Utang supplier: saldo **saat ini**, per tagihan/supplier. Open termasuk overdue;
  jangan menjumlahkan keduanya lagi. Bucket memakai sisa saldo, bukan nilai awal
  tagihan. Tanpa due date tampil terpisah dan tidak otomatis overdue.
- Pembayaran periode: tanggal operator untuk original, tanggal pencatatan toko
  untuk reversal. Refund memakai tanggal kejadian operator. Dana pemilik, bank
  dan laci terpisah. Periode ini tidak menghitung saldo utang historis.
- Kredit tersedia, penerimaan belum direkonsiliasi, dan retur fisik belum disetujui
  memiliki laporan terpisah. Retur belum disetujui tidak mengurangi utang.
- Histori/audit kas dan kebijakan audit wajib membuka fitur kas yang sudah ada.

Potential stock retail value offers product/category/master supplier/whole-store
levels. It uses current retail prices and average carrying costs for saleable
tracked stock. Read the known cost/profit subtotal and excluded/incomplete
coverage. This is not a sales forecast or net profit. Stock variance uses posted
snapshots, not current stock or theft assumptions. Supplier balances are
**current**; overdue balances are part of open debt. Payments/refunds are separate
period reports with the date bases described above. Available credit,
unreconciled purchases and unapproved physical returns are separate facts.

Ringkasan dan ekspor mencakup seluruh scope filter; halaman UI20 baris tidak
membatasi total. Ekspor mengambil snapshot baru dengan waktu/timezone/scope-nya
sendiri. CSV/XLSX → Buat → pilih tujuan → Tulis. Memilih tujuan belum menulis
data. Setelah akses terkunci/berganti, buat ekspor baru. Currency tidak dicampur.

Summary and export cover the entire filtered scope, not only the20 visible rows.
Export captures a new consistent snapshot with its own time, timezone and scope.
CSV/XLSX → Create → choose destination → Write. Choosing a destination writes no
report bytes. Regenerate after the owner session changes. Currencies stay separate.

Kolom ekspor field/value/unit adalah data eksak: minor=unit uang terkecil,
millionth_minor=sepersejuta minor, base_units=unit dasar produk. XLSX menyimpan
uang/ID sebagai teks, tanpa rumus. Untuk CSV, impor kolom ID/uang sebagai teks
agar0 di depan tidak hilang; awalan berisiko formula dinetralkan dengan apostrof.
Ekspor tidak memuat PIN/kunci. Batalkan untuk menghapus artifact sementara milik
ekspor; file tujuan yang sudah ditulis tetap menjadi dokumen pengguna.

Export field/value/unit columns are exact: minor means the smallest currency
unit; millionth_minor means one millionth of a minor unit; base_units means
product base units. XLSX stores money/identifiers as text without formulas.
Import CSV identifier/money columns as text to preserve zeros. Formula-like
prefixes are neutralized with an apostrophe. No PIN/key is exported. Cancellation
removes the owned staging artifact; an already written destination remains the
user's document.
