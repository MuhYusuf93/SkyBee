# Harga pembelian terakhir dan editor penerimaan

Checkpoint E pada source0.5.2+12/schema26. Dokumen penerimaan multi-item,
opname dan keuangan supplier tetap bagian pekerjaan E berikutnya; editor ini
tidak menyatakan fitur tersebut selesai.

Harga usulan dibaca melalui InventoryService dalam snapshot berotorisasi.
Sumber actual adalah receipt efektif terakhir pada produk/currency dan supplier
transaksi yang dipilih, bukan supplier master atau average persediaan. Receipt
yang direversal dan pembukaan saldo transisi tracking tidak menjadi pembelian.
Pembelian terbaru dengan biaya unknown tetap unknown; jangan mencari harga
known yang lebih lama dan menyebutnya harga terakhir. Saldo awal/referensi
diberi label acuan, bukan fakta pembelian. Tidak ada penulisan ketika form dibuka.

Perhitungan mempertahankan total biaya fixed-point dibagi quantity asli dengan
BigInt. Usulan hanya ditampilkan jika tepat dalam minor currency. IDR10000 per
24pcs dapat diusulkan10000 per kemasan24; per pcs atau kemasan28 tetap kosong
jika tidak tepat, disertai penjelasan. Known0 berbeda unknown dan membutuhkan
persetujuan biaya gratis. Konversi tidak mengubah ukuran kemasan master.

Harga manual dimiliki route. Pergantian supplier tidak menimpanya. Pergantian
basis unit mengonversi tepat atau meminta pengisian ulang, menyimpan basis lama
untuk kembali. Decimal belum selesai dan composing IME disimpan pada basis
asal; tidak dilabel ulang sebagai harga kemasan baru. Pergantian locale menjaga
digit; currency tidak diubah oleh pergantian bahasa. Pengingat kuning membandingkan
nilai canonical dengan harga actual yang disarankan, sehingga hilang setelah
diubah dan muncul lagi jika dikembalikan, tanpa menulis transaksi.

ReceiptLineEditor memiliki controller, operation key, baseline dirty, privacy
gate dan FormExitGuard sendiri. Callback yang selesai hanya menghapus route
editornya; tidak menutup opaque lock. Error ditampilkan pada quantity/isi
kemasan/biaya/expiry terkait, field pertama diungkap dan difokuskan setelah
frame enabled. Expiry tetap kalender readonly. Fitur biaya tersembunyi tidak
mewajibkan input dan menyimpan unknown, bukan gratis0.

Save menunggu hint supplier selesai, menolak generation database yang berubah,
dan memakai expectedRevision master pada service. Pemeriksaan retry operation
yang sudah commit mendahului revision guard agar retry sah tidak menambah stok.
Hash panggilan lama tanpa expectedRevision tetap byte-identik. Semua penulisan
receipt/item/batch/nilai/history tetap satu transaksi service yang sudah ada.

Poco dipakai pribadi dan tidak diakses untuk delta ini. Pengujian native hanya
DV8910 melalui wrapper resmi, package integration dan fixture numerik baru.
Tidak ada update/reset Paket Eksplorasi Mandiri.

Saat dokumen multi-item diterapkan, operasi harus menunjuk receipt item secara
otoritatif. Join produk/receipt saat ini sah untuk writer satu item; jangan
memakainya memilih acak jika satu receipt kelak berisi beberapa batch produk
yang sama. Baseline stocktake dan perubahan supplier finance memerlukan aturan
tersendiri dalam E, bukan perluasan tersembunyi dari editor tunggal ini.
