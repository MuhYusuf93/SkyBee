# Skybee kasir — aplikasi debug terpisah untuk uji mandiri

21 Oktober2026. Pengguna meminta aplikasi terpisah bernama **skybee kasir**,
toko **toko skybee**, PIN dummy **1111**, dan100data dengan berbagai kondisi.
Interpretasi pengisian:100barang total beserta data pendukung dan transaksi.
Pengguna akan menguji sendiri, tidak perlu melaporkan hasil; perubahan/bug baru
akan diberikan melalui command terpisah. Tidak menunggu laporan manual atau
menjadwalkan pemantauan. M5.2/M6 tidak dimulai.

## Hasil pemasangan

**TERPASANG dan terbuka di Poco F6 `7f0edea0`**, package baru
`com.example.kasir_app.skybee`, launcher
`com.example.kasir_app.SkybeeDemoActivity`, debug0.5.1+8/schema13.
Ordinary `kasir_app` dan package integration tetap terpisah.393hash berkas
database/key/arsip yang sudah ada di kedua package lama cocok sebelum/sesudah
seluruh interval install/seed/reopen. Tidak reset, uninstall, downgrade,
mengganti identitas ordinary, atau menyentuh DV/Realme.

APK: `build/skybee-demo-20261021-002649/skybee-kasir-0.5.1-debug.apk`.
SHA256: `52b6a4819e07287821902e8e99c96f56cee261106d2d9be3f7379899d1971d6d`.
APK terpasang ditarik kembali dan hash sama. Tiga ABI lengkap,
engine/SQLCipher/KDF, signature debug, minSDK24, ELF/ZIP16KiB, resource notifikasi,
lisensi dan label diperiksa. Build debug23,7detik. Build ordinary regresi13,1detik
juga lolos verifier dan tidak memuat SkybeeDemoActivity, tanpa dipasang ulang.

Install pertama exit1; output installer belum tersimpan oleh helper awal,
sehingga alasan spesifik tidak diklaim. Audit sesudahnya393hash cocok/package
Skybee absent. Satu retry terarah pada APK sama menghasilkan Success.
Kelanjutan memeriksa exact installed hash dan kesamaan baseline lama sebelum
seed, tidak melakukan install/reset lagi. Failure awal, retry log, baseline dan
hasil resumed disimpan terpisah; helper kini menyimpan output saat ADB gagal.

## Isi dummy yang benar-benar dibuat

| Data | Jumlah / kondisi |
| --- | --- |
| Barang | **100total:95aktif,5arsip** |
| Kategori / supplier | 8kategori,4supplier dummy; beberapa penerimaan tanpa supplier |
| Stok dan batch | Kosong/rendah/normal; kedaluwarsa, jatuh tempo hari setup, hampir kedaluwarsa+7hari, campuran expired/future;110penerimaan termasuk dus dan HPP moving average |
| Harga dan identitas | Harga nol, retail/grosir, kemasan dus12pcs, barcode dengan nol awal, sebagian tanpa barcode, alias pencarian |
| Atribut | g/kg/ml/l, atribut null, letak rak, keterangan biasa/panjang/internal |
| Penjualan | 20penjualan dalam20hari terakhir; uang pas, lebih/kembalian, sebagian bayar, hutang penuh dan harga nol |
| Pembatalan | 2reversal penjualan melalui service, bukan hard delete |
| Pelanggan | 10pelanggan bernama Demo, tanpa nomor pribadi |
| Pembayaran | 14fakta pembayaran total termasuk4pelunasan lanjutan, campuran penuh/sebagian; tidak menambah sale baru |
| Awal penggunaan | Bahasa Indonesia, IDR, Asia/Jakarta; keranjang baru kosong, pengelolaan terkunci memakai PIN yang diminta |

Seed memakai service produksi untuk konfigurasi PIN, master, persediaan,
checkout, piutang dan reversal. Tidak menyisipkan fakta keuangan mentah atau
menonaktifkan enkripsi/constraint. Histori memakai clock service yang disuntikkan;
waktu Android tidak diubah. Tidak membuat printer job, menyambungkan Google,
mengunggah data atau menyalakan consent/jadwal backup saat seed.

## Isolasi dan seed sekali jalan

Entrypoint khusus `lib/main_skybee_demo.dart` memerlukan flag
`KASIR_SKYBEE_DEMO=true`. Gradle menolak kombinasi demo+integration, entrypoint/
flag tidak berpasangan, serta profile/release demo. Source set native demo hanya
ditambahkan pada build ini; runtime memeriksa package exact dan debuggable lewat
channel activity khusus **sebelum membuka database**. `lib/main.dart` tidak
mengimpor seed. Kredensial dummy ini bukan credential default produksi.

Marker privat `databases/skybee-demo-seed-v1.json` mencatat started/complete.
Marker complete membuat startup berikutnya melewati seed seluruhnya: edit,
tambah, arsip dan transaksi pengguna tidak ditimpa. Database terkonfigurasi
ditolak oleh seeder. Marker started/parsial menghentikan setup dengan data tetap
disimpan; tidak auto-reset atau menimpa data. Tidak menambahkan fitur reset baru.

## Pemeriksaan dan batas

- Host1PASS7detik:100produk/95aktif/20sale/2reversal/10customer, variasi stok/
  barcode/harga/tender, PIN yang diminta, integrity/FK/rekonsiliasi dan penolakan
  overwrite dengan seluruh fingerprint tetap.
- Analyzer final No issues7,1detik; formatter berkas baru lulus. Lint awal
  missing curly braces diperbaiki sebelum tes/build; log awal dipertahankan.
- Startup nyata Skybee menjalankan seed SQLCipher: integrity/FK dan rekonsiliasi
  stok/uang PASS, PIN dikonfigurasi dan diverifikasi service native. Ini operasi
  setup aplikasi demo, bukan native integration test melalui test framework.
- Dua startup memperlihatkan **toko skybee**, Daftar belanja, Bayar dan Kelola
  dalam package Skybee. Marker seed identik setelah reopen, tidak reseed.
- Buffer PID23027 tersedia:0penanda FATAL/Unhandled/ANR dan0E/flutter. Bukan
  pembuktian semua interaksi/hardware. Uji mandiri pengguna tidak diberi status
  PASS otomatis dan tidak dijadikan pekerjaan menunggu hasil.
- Kontrol otomatis **Off**, Skybee terakhir tetap terbuka. Semua APK/DB/key/
  hierarchy/log rinci privat berada di ignored build/. Ringkasan aman ada pada
  [evidence Skybee](evidence/skybee-20261021/handoff.json).

Untuk membangun/menjalankan debug ini lagi:

```powershell
flutter run -d 7f0edea0 -t lib/main_skybee_demo.dart --dart-define=KASIR_SKYBEE_DEMO=true
```

Run konfigurasi `main.dart` yang sudah ada tetap aplikasi ordinary. Fitur Drive
optional di package baru memerlukan konfigurasi OAuth untuk package/signature
yang sesuai; konfigurasi integration/ordinary bukan bukti Skybee sudah terhubung.
Tidak mengubah Cloud/OAuth pada handoff ini. Batas hardware M5.1 historis tetap
tercantum di [laporan akhir M5.1](M51_FINAL_REPORT_20261021.md).
