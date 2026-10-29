# F1 — label QR barang (schema35)

Ralat langsung pengguna menggantikan barcode label baru dengan QR; acuan
[ralat](M53_QR_LABEL_AMENDMENT.md) dan [kontrak](M53_REQUEST.md) bagian8.
Barcode/SKU lama, leading zero dan snapshot penjualan tetap dipertahankan.

Payload label adalah `SBP1` diikuti UUID produk tersimpan secara persis,
40 karakter ASCII. Case/hyphen tidak dinormalisasi karena primary key lama
bisa mempunyai case berbeda. Ini identitas lokal SkyBee, bukan URL, perintah,
GS1 atau EAN resmi. Resolver exact bersama mencakup kasir, gudang, penerimaan
dan opname. Benturan dengan barcode/SKU produk lain ditolak sebagai ambigu,
termasuk ketika target QR sudah diarsipkan; jangan memilih barang lain diam-diam.

Encoder murni Dart `qr:4.0.0` dipin, level koreksi Q. Renderer memakai modul
integer4–12 titik printer, tanpa antialias, dengan quiet zone4modul. Nama maksimal
2baris, identitas lengkap2baris eksplisit, harga eceran opsional utuh. Media yang
tidak muat ditolak, modul tidak dikecilkan. [API paket](https://pub.dev/documentation/qr/latest/qr/QrCode-class.html)
dan [panduan pembuat QR](https://www.qrcode.com/en/howto/code.html/index.html)
menjadi acuan API/ruang putih, bukan bukti keterbacaan hardware pengguna.
Preview dan raster24baris memakai layout yang sama. Dimensi memakai8titik/mm
nominal untuk kelas203dpi; ukuran fisik mengikuti printer dan perlu uji kertas.

Pengaturan label berdiri sendiri dalam `product_label_profiles` (aditif35),
CAS revisi, bukan penulisan ulang profil struk. Continuous memakai protokol
yang dipilih operator sesuai kemampuan printer (ESC/POS raster/kolom, TSPL,
CPCL). Gap hanya TSPL setelah konfirmasi dukungan/ukuran/celah; CPCL gap ditolak.
Tidak ada pergantian firmware, probing empat protokol, factory reset atau
kalibrasi otomatis. Profil struk58/80mm, default feed3/manual0–8 tidak berubah.
Portable preferences tetap disimpan ketika binding hardware lokal dibersihkan
pada restore; penerapan/printing selalu memvalidasi hardware yang dipilih lagi.

Gudang dan pemilik boleh menyiapkan label lewat capability inventory. Kasir
tidak memperoleh akses label hanya karena pengaturan printer publik tersedia.
Service menangkap fakta publik barang/harga/locale/revisi dan hardware/media/
jumlah1–100 sebelum membuat job di antrean cetak lama. Retry operation key sama
harus intent yang sama; snapshot lama tetap meski master diedit. Job tanpa FK
penjualan, tidak memanggil checkout atau mutasi stok/HPP. Antrean memeriksa
capability/generation sebelum klaim, koneksi dan setiap write; penguncian saat
output menghentikan write berikutnya. Gagal koneksi=`failed`, output parsial=
`unknown`; tidak ada pengiriman ulang otomatis. `submitted` hanya data terkirim.
Pekerjaan baru memerlukan aksi eksplisit dengan peringatan duplikasi label.

Kembali dari pengaturan printer mempertahankan isian, flags dan CAS profil label
lama; metadata hardware dibaca ulang. Printer terpilih di luar halaman awal
ditampilkan sebagai pilihan tambahan, tanpa memindahkan cursor keyset. Preview
memvalidasi geometry hardware terbaru. Tidak ada pemuatan seluruh daftar printer.

Offset positif menggeser pusat seluruh isi tepat8dots/mm nominal ke kanan/bawah,
tanpa memperkecil modul. Karena isi terpusat, area teks perlu menghabiskan dua
kali inset horizontal agar perpindahan pusat tidak hanya setengah permintaan.
SemuaRGBA dan byte raster diuji terhadap translasi yang ditentukan, bukan hanya
membandingkan posisi terhadap bounding box renderer itu sendiri.

Bukti host/native serta kegagalan helper UI awal dan retestnya dicatat pada
[laporan F1](../M53_QR_LABELS_REPORT.md), bukan disimpulkan dari pilihan protokol.
Nama/SKU panjang hanya dibatasi pada snapshot label; master tetap utuh. Revisi0
produk kosong sah. Kasus post-review jadwal E3 disertakan pada native F.
Belum ada bukti kertas, scanner fisik atau kamera.

F2 kebijakan struk, F3 laporan, G dan H tetap pekerjaan berikutnya. `.skybee`
belum diupdate/reset/reseed. Reset100produk/50transaksi hanya pada H sesudah
semua M5.3 selesai dan cadangan terenkripsi/material pemulihan lama diverifikasi.
