# F1 — label QR barang, laporan aktif

Implementasi aditif35 mengikuti [keputusan](decisions/M53_QR_LABELS.md).
Host final46PASS61s meliputi lookup5, raster8, antrean13, UI ID/EN2,
jadwal E3 review11/UI2 dan runtime5. Regresi printer lama33PASS69s terpisah.
Analyzer12s bersih, format282/2, lokalisasi1296/877/245, PIN106match.
[Bukti host](evidence/m53-20261026/qr-labels-host-checks.json).

Temuan dan perbaikan: fixture piutang printer lama wajib nomor telepon; bahasa
legacy null diberi fallback headless eksplisit/UI memasok locale teresolusi;
UUID dipenggal teksnya pada20karakter agar word-wrap tidak menghasilkan3baris;
revisi produk0 sah; nama/SKU panjang dibatasi pada snapshot label saja, master
utuh. UI320px/text2 memeriksa invalidmedia, dirty Back saat terkunci, data tetap
sesudah unlock, preview tanpa filter dan CAS profil. Helper awal menunggu child
lazy yang ter-evict; log gagal tetap tersedia, tes menunggu gambar yang nyata.

Antrean memakai transport sintetis pada host. Tidak ada klaim kertas tercetak,
scanner fisik, kamera atau sentuhan OEM. Poco native42PASS8:19 pada SQLCipher,
termasuk decode piksel raster Dart dengan ZXing Java independen dan delta E3.
Seluruh776protected entries sebelum run hashsama sesudahnya, kontrolOff dan
trueexit0. Lisensi QR ada di APK.
[Bukti Poco](evidence/m53-20261026/qr-labels-poco.json). DV awal selesai
41PASS1UI-helperFAIL12:17: caption preview sudah tampil namun helper menunggu
child gambar yang belum dibangun di viewport. Decoder independen lulus.
Seluruh852protected entries hashsama/controlOff/awakeexact/trueexit1.
[Bukti DV awal](evidence/m53-20261026/qr-labels-dv-initial.json).

Review berikutnya memperbaiki form yang reset saat kembali dari pengaturan
printer: controllers/flags/CAS label lama tetap, hardware diperbarui; pilihan
di luar halaman awal tidak mengubah cursor keyset. Preview memvalidasi hardware
terbaru. Helper kini reveal gambar sebelum memeriksanya; ID/EN juga menguji
width43 bertahan setelah childprinterBack. Host2PASS21s/analyze129,9s bersih,
format2/0, l10n/PIN tetap. [Bukti delta](evidence/m53-20261026/qr-labels-review-checks.json).
Source672-review hanya berbeda2file UI/fixture dari source native awal672.
Native focused2 lulus: Poco1:00/815hashsama, DV1:44/891hashsama/awakeexact;
keduanya trueexit0/controlOff. [Poco review](evidence/m53-20261026/qr-labels-review-poco.json),
[DV review](evidence/m53-20261026/qr-labels-review-dv.json).
Jangan mengklaim source awal672 sudah menjalankan perubahan review tersebut.

Pemeriksaan geometri independen berikutnya mereproduksi offset3mm hanya12dots,
seharusnya24 pada8dots/mm nominal. Inset satu sisi menggeser pusat setengahnya.
Renderer diperbaiki dengan area pusat yang tepat; uji seluruhRGBA dan raster
memastikan translasi24/16dots (3mm/2mm), tanpa scaling/clipping. Hostrenderer9PASS
<1s/analyze62,8s bersih; format2/1. [Bukti offset](evidence/m53-20261026/qr-labels-offset-checks.json).
Source672-offset hanya berbeda layout/fixture renderer dari672-review, yang
offset0/SQL/semuaUI/business-nya tetap. Nativefocusedraster9 lulus: Poco<1s/
817protectedhashsama dan DV2s/893hashsama/awakeexact; keduanya controlOff/trueexit0.
[Poco offset](evidence/m53-20261026/qr-labels-offset-poco.json),
[DV offset](evidence/m53-20261026/qr-labels-offset-dv.json).
Ini ukuran nominal, bukan kalibrasi kertas. Semua temuan software F1 di atas
ditutup berdasarkan source/interval masing-masing; tidak menjumlahkan rerun yang
overlap seolah kasus unik atau mengklaim satu fullrun pada source baru.

F2 struk wajib/konfirmasi/pengecualian, F3 laporan, G backup/retensi/reset dan H
handoff masih aktif. `.skybee` belum diupdate/reset/reseed. H100produk/50transaksi
memerlukan seluruh M5.3 selesai dan cadangan terenkripsi beserta material
pemulihan lama terverifikasi; checkpoint ini bukan penutupan M5.3.
