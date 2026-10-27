# M5.3 E — ons dan locale metadata

Kontrak aktif: M53_REQUEST §7.2.9; menggantikan aturan M5.2 yang mengikat
desimal ukuran ke currency. Bahasa UI ID memakai koma, EN memakai titik,
tanpa grouping dan maksimal tiga desimal. Uang tetap minor integer dengan
codec sendiri; metadata ukuran tetap integer thousandths. `ons` berarti
100 gram, bukan ounce dan tidak mengonversi jumlah stok/kemasan/harga.

Schema25 menambahkan `size_ons_milli` pada products dan
`size_ons_milli_snapshot` pada sale_transaction_items. Nilai positif bounded;
pasangan size_milli/size_unit lama harus NULL jika kolom ons terisi. Tidak ada
rebuild produk/FK, rewrite data lama atau perubahan CHECK migrasi committed.
g/kg/ml/l tetap memakai pasangan lama. Domain menolak ons pada pasangan lama,
ons di dua representasi sekaligus dan penulisan ons ke schema<25.

Produk, DTO publik (whitelist biaya tetap), draft yang dibuka kembali dan
snapshot receipt membawa representasi yang sama. Edit/clear produk tidak
mengubah snapshot penjualan. Ekspor inventory memakai nilai thousandths ons
dan unit `ons (100 g)`; template cetak konsumen yang sebelumnya tidak mencetak
metadata ukuran tidak ditambah catatan internal. Preview metadata mengikuti
locale saat ditampilkan. Snapshot cetak uang/histori tetap immutable.

Form memindahkan tanda desimal memakai locale sebelumnya dan membandingkan
baseline kanonis. Mengubah bahasa saja tidak membuat form kotor; mengubah lalu
mengembalikan angka menjadi bersih lagi. MoneyField menunda notifikasi
pergantian codec/teks sampai selesai build, dengan revision/controller proof;
callback locale lama tidak menimpa input baru dan composing tetap ditunda.

Validator backup memeriksa tipe/bounds/exclusivity dengan SQL sebelum mengambil
metadata per100 baris, termasuk arsip dengan CHECK yang dipalsukan. Migrasi
teruji dengan membandingkan semua kolom lama pada fixture populated24. Tes
pemalsuan snapshot hanya menonaktifkan trigger pada fixture baru miliknya;
kode produksi tidak pernah menonaktifkan immutable trigger. Portable recovery
seluruh M5.3 tetap checkpoint G, bukan klaim dari validator ini.

Paket Eksplorasi Mandiri tidak dimigrasikan pada checkpoint ini. H baru
memperbarui paket tersebut in-place setelah seluruh implementasi M5.3 selesai.
