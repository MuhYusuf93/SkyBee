# M5.4 tahap 2 · arsip, navigasi, dan kamera

## Arsip dan navigasi

Tes sebelum perbaikan menemukan checkout dari draft lama melaporkan stok
kurang saat produk sudah diarsipkan. Dua tes ID/EN juga membuktikan bahwa
reload menghapus pesan Undo yang kedaluwarsa. Kasus navigasi pertama memakai
target sentuh yang tertutup. Driver diperbaiki untuk mengetuk judul baris,
mengembalikan scroll header sebelum mengganti tab, dan menunggu menu bahasa.

Checkout memberi pesan pemulihan arsip dan mempertahankan draft. Undo gagal
mempertahankan status dan menampilkan alasan. Gudang memperbarui daftar aktif
dan arsip pada semua scope yang diperiksa setelah commit dan reopen. Akses
kategori, supplier, dan rak membuka daftar sesuai filter. Edit memakai tombol
tersendiri. Tab promo memakai kontrol bahasa Gudang dan formulir promo
mempertahankan draft saat bahasa berubah.

Regresi juga menutup celah kesetaraan harga beli dan jual pada edit produk
tanpa tracking serta transisi tracking. Fixture checkout lama sekarang
menggunakan nomor sintetis wajib dan mengulang payload yang benar-benar
dikirim. Fixture restock memakai biaya di bawah harga jual dan tetap memeriksa
HPP asli setelah retur penuh dan perubahan biaya rata-rata.

## Kamera

Adapter ZXing memakai frame dan crop decoder untuk menerjemahkan ketukan
preview ke koordinat sensor kamera belakang. Perangkat dengan area fokus
memakai area yang dipilih pada siklus autofocus yang sudah berjalan. Ring
singkat menandai permintaan. Kamera fixed-focus dan perangkat dengan kamera
depan saja tetap dapat memindai menggunakan perilaku asal. Pembacaan ini
mengikuti [kontrak koordinat sensor Camera1](https://developer.android.com/reference/android/hardware/Camera.Parameters#getFocusAreas()).

## Bukti dan batas

- Regresi terakhir host lulus **75/75 dalam 1:11**. Cakupan meliputi arsip,
  navigasi/promo, form, validasi, checkout, layout kasir, dan koreksi/laporan.
- Analyzer bersih dalam 160,1 detik. Pemeriksaan lokalisasi mencatat 1.553
  kunci, 947 rujukan statis dan 245 persyaratan. Audit 106 file PIN cocok.
- Build fixture `0.5.4+14` berhasil dikompilasi. Pemeriksaan package, ABI ARM32,
  ARM64 dan x86_64, 13 library, ZIP 16 KiB dan alignment ELF lulus. Build
  dipersiapkan sebelum koreksi jalur harga referensi terakhir dan belum
  dipasang. Bukti lokal ada di `build/m54/archive-camera-fixture-check.json`.
- Entry `integration_test/m54_archive_test.dart` sudah memakai guard isolasi.
  Tes native arsip, fokus optik, dan scanner fisik tercatat untuk acceptance.
  Favorit baru bisa diperiksa setelah implementasi tahap 4.
- Runner Android menyimpan status terminal saat pemulihan awake gagal. Uji
  fault injection host memverifikasi hasil gagal ditulis dan exception tetap
  dipropagasikan. Log asli dari putus ADB tetap disimpan.
