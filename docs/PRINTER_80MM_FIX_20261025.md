# Perbaikan printer 80 mm — 25 Oktober 2026

Target pengguna: Milestone MHT-P29L, Bluetooth, Poco F6. Skybee0.5.2+9.
DV8910 tidak tersambung; tidak menjalankan pengujian ulang di DV/Realme.

## Gejala dan scope

Pengguna melihat kalibrasi berhenti sekitar Feed=6, lalu ruler dan angka dari
job sebelumnya muncul pada job berikutnya. Angka terpotong dan karakter yang
tampak seperti huruf Cina kadang muncul. Cetakan lain berhenti di L/R/shift,
lalu Feed muncul sekitar2detik kemudian. Ini laporan fisik pengguna, bukan
hasil yang diklaim dari mock.

Source merender semua teks ke raster monokrom, bukan mengirim teks UTF8
langsung. Transport saat ini menerima potongan4096byte, tanpa pacing, dan
socket ditutup langsung sesudah write terakhir. Terdapat celah finalisasi;
penyebab semua gejala pada perangkat masih perlu bukti terarah/fisik.

Pertahankan fitur, profile/feed tersimpan dan seluruh data Skybee. Tidak
menambah retry otomatis atau mengubah invariant checkout/print queue.
Hasil pengujian dan handoff akan ditambahkan berdasarkan bukti aktual.

## Kontrak kompatibilitas

Pengguna menegaskan dukungan banyak printer thermal. Perbaikan produksi
berdasarkan protokol ESC/POS dan kemampuan/lebar, tanpa whitelist nama/model.
Screenshot OpenLabel menjadi referensi pemisahan protokol ESC/CPCL/TSPL;
label ESC1/ESC2 pada screenshot belum membuktikan format byte tertentu.
Pengguna belum mencoba target ini di OpenLabel. CPCL/TSPL/BLE tidak diklaim
didukung hanya karena tersedia di aplikasi referensi.

Referensi primer: [Android BluetoothSocket](https://developer.android.com/reference/android/bluetooth/BluetoothSocket)
menjelaskan close mengakhiri operasi socket; itu bukan acknowledgment kertas.
[Epson GS v 0](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/gs_lv_0.html)
menetapkan framing width-byte/height/payload dan raster melakukan feed sendiri.
Target fisik tersedia pada [halaman pabrikan MHT-P29L](https://www.milestoneiot.com/v1/products/80mm%20mobile%20printer_1799_21.html);
nama model hanya dipakai untuk identifikasi uji, tidak memilih cabang encoder.

## Implementasi dan bukti sementara

- Raster dibatasi24row sehingga perintah lengkap di bawah2KiB untuk semua
  lebar profil yang tervalidasi. Margin/font/feed tersimpan tidak diubah.
- Bluetooth menyalurkan256byte per40ms, dengan final delivery interval400ms.
  Ini kebijakan konservatif submission, bukan janji bahwa semua firmware
  mendukung ESC/POS atau acknowledgment hasil kertas.
- Finish eksplisit sebelum submitted/disconnect, termasuk output recovery;
  kegagalan drain tetap unknown, tidak mengulang atau mengubah fakta bisnis.
- Kalibrasi memisahkan IDR/USD/EUR dan menambahkan AKHIR UJI di baris terakhir.
- Host raster/queue/recovery:24PASS57s. Tambahan kasus recovery-drain1PASS4s
  dan native transport adapter1PASS4s. JVM Bluetooth6/USB8PASS22s.
- Analyzer pertama mencatat12error pada salinan source historis di build dan
  1lint source aktif. Arsip tetap dipertahankan; build dikecualikan dari
  analisis, lint diperbaiki. Analyze ulang: No issues6,3s; format2/0changed.
- Poco: framing raster384/576/639dot dan paired inventory4PASS. Seluruh445hash
  berkas lama terlindungi tetap sama; controlOff. Tidak mencetak pada run ini.
- Printer dinyalakan ulang oleh pengguna sebelum sampel. Tepat satu kalibrasi
  melalui probe terisolasi:1PASS7s, outcome submitted, tanpa retry. Seluruh445
  hash lama cocok/controlOff. Pengguna mengonfirmasi hasil tercetak utuh;
  ruang kosong akhir masih panjang. Sampel memakai feed6 dan hanya data
  sintetis;0sale/payment/stock-history. OpenLabel tetap belum diuji.

## Tambahan ruang kosong akhir struk

Sesudah hasil utuh, pengguna meminta kontrol manual ruang kosong dan default
3feed. Field manual yang sudah ada dipindahkan tepat di bawah ukuran kertas,
diberi label Ruang kosong akhir struk dan tombol−/+. Tetap0–8baris, tersimpan
per printer;0tidak menambah feed. Panjang fisik baris dan jarak kepala cetak
ke sobekan bergantung printer, sehingga tidak menjanjikan milimeter palsu.
Default profil baru/reset template menjadi3. Profil tersimpan tidak dimigrasi
diam-diam. Host form/persist/reopen1PASS2s tanpa output. Run awal fixture
tertahan karena IO/coordinator dibuat pada fake-async; dua run dihentikan
terarah dan raw tetap. Finder RawTooltip dan tap sesudah keyboard juga
diperbaiki tanpa menonaktifkan assertion/hit-test. Regresi default3 menemukan
ekspektasi lama6baris; diperbarui ke3 dan saved legacy6tetap diuji. APK awalv10
sebelum tambahan ini tidak dipasang; build akhir harus dibuat ulang.
Run regresi akhir default3:25PASS/1FAIL60s karena assertion lama mengharuskan
6LF; source memang mengirim3LF. Assertion diperbarui mengikuti permintaan
pengguna dan memastikan saved6tidak diubah. Focused retest1PASS4s. Seluruh26
kasus memiliki PASS lintas run, tidak diklaim26PASS dalam run gagal tadi.
Analyze akhir No issues101,9s; audit680keyID/EN/471reference/245ID PASS.
Native satu kasus form/save/reopen tanpa output1PASS5s/447hash lama cocok,
controlOff. Tambahan berikutnya top feed/protokol dicatat terpisah pada
[laporan lanjutan](PRINTER_PROTOCOLS_20261025.md).

## Handoff versi10 selesai

Patch0.5.2+10, schema tetap14. Sesudah hasil fisik dan build terverifikasi,
pasang-r ke package Skybee yang sama dengan sertifikat sama. Sebelum membuka
app, semua hash DB/no_backup/shared_prefs lama harus cocok. Startup kasir
diamati; key/preferensi/seed/proof dan package lain diperiksa lagi. Tidak
menyalin sandbox, reset/reseed/uninstall/downgrade atau menghapus fingerprint.
Runtime boleh memperbarui metadata alert/draft; tidak mengklaim whole-file DB
tetap identik sesudah startup. APK/data/log privat tetap di build lokal.

Aktual: build debug20,8s, signature/3ABI/13library/16KiB PASS. Install-r v9→v10
PASS;459hash DB/no_backup/shared_prefs lama cocok sebelum launch. Installed
APK cocok, startup kasir PASS, key/preferensi/seed/proof tetap sesudah startup,
package lain cocok/controlOff. Tidak reset/reseed/downgrade/ekspor sandbox atau
menghapus fingerprint. Setelah ini pengguna meminta top feed dan protokol
tambahan; keduanya belum terdapat pada v10, target lanjutanv11/schema14.
