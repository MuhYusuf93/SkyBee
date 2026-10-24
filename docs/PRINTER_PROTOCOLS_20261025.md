# Dukungan beberapa protokol printer — 25 Oktober 2026

Permintaan langsung pengguna sesudah perbaikan80mm: pengaturan feed atas dan
bawah manual/default3, lalu dukungan berbagai printer memakai screenshot
OpenLabel sebagai referensi. Saat ini hanya Milestone Bluetooth tersedia;
Iware tidak dibawa. Pengguna mungkin menguji printer teman lain di kemudian
hari; pekerjaan tidak menunggu laporan uji mandiri tersebut.

## Kontrak dan implementasi aktif

- Pilihan perprinter: ESC/POS Raster (GS v0), ESC/POS Kolom (ESC*33), TSPL
  BITMAP dan CPCL CG. Nama ESC1/ESC2 OpenLabel tidak dipetakan tanpa bukti.
- Pemilihan eksplisit, tanpa deteksi merek, firmware switch, fallback/retry
  otomatis, cutter, flash download, atau pengiriman konfigurasi jaringan.
- Bluetooth Classic SPP/USB printer-class yang sudah ada tetap transport.
  BLE/protokol proprietary merek pada screenshot belum diimplementasikan.
- Semua teks/nominal/logo tetap raster dari layout bersama; data pengguna
  tidak disisipkan sebagai command text. Antrean/output lease tetap satu
  dokumen. Gagal sebagian tetap unknown, tidak menciptakan penjualan baru.
- TSPL/CPCL khusus struk kertas gulung203dpi,58/80mm. Tinggi halaman perprofil
  128–4096dot, default1024; halaman internal tidak membatasi panjang struk.
  Buffer paling besar320KiB, bukan bitmap seluruh struk. Feed di awal/akhir
  dokumen sekali, bukan di setiap halaman. Pada page mode satu baris=24dot.
- Feed atas/bawah0–8manual/−/+, default baru3keduanya, disimpan independen.
  Nilai bottom lama tetap. Profil lama tanpa topFeed memakai default baru3
  untuk job baru; snapshot job lama tanpa topFeed tetap0. Normalisasi snapshot
  saat prepare mempertahankan perilaku job lama dan mengunci pilihan protokol.
- Recovery memakai encoder yang sama, auth diperiksa perwrite/finish; buffer
  paket/strip/page sensitif dibersihkan saat resume/cancel/error.

## Referensi primer

[Epson ESC*](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/esc_asterisk.html)
untuk susunan kolom24bit/mode33 dan LF/spacing. [TSC TSPL/TSPL2 manual](https://fs.tscprinters.com/en/dl/1/2541)
untuk SIZE/GAP/BITMAP/PRINT; diagram halaman69 diperiksa visual. Pola contoh
menegaskan0hitam untuk TSPL BITMAP, berbeda dari1hitam ESC/POS/CPCL.
[Zebra CPCL manual](https://cpws.zebra.com/cpws/docs/comtec/PROMAN-CPCL_RevY.pdf)
untuk CG/PW/JOURNAL/PRINT; FORM sengaja tidak dipakai pada kertas kontinu.
Tidak mengirim perubahan permanen bahasa firmware atau media calibration.

## Bukti dan handoff

Host final42PASS65s; Poco17deltaPASS24s dengan seluruh448hash lama tetap sama,
controlOff. Mencakup14encoder/wipe, satu form protocol/page/feed dan dua kasus
queue/snapshot/partial output. Format23/0changed, analyze No issues5,7s,
audit690keyID/EN/471reference/245ID PASS. Analyzer pertama dua lint test saja
dirapikan; tidak mengurangi assertion. Hasil byte/software tidak
dianggap bukti kertas TSPL/CPCL/ESC*; perangkat fisik mode tersebut belum ada.
Milestone ESC/POS Raster sebelumnya tercetak utuh atas konfirmasi pengguna.
Skybee0.5.2+10 untuk perbaikan/bottom feed telah dipasang:459hash tertutup
cocok sebelum startup; kasir berhasil startup, key/preferensi/seed/proof tetap,
package lain cocok/controlOff. Tidak reset/reseed/downgrade/ekspor sandbox atau
penghilangan fingerprint. Tambahan top/protokol disiapkan untuk0.5.2+11;
schema tetap14. Jangan memakai APK v10 sebagai bukti fitur tambahan ini.

Aktualv11: build debug21s, signature/3ABI/13library/16KiB PASS. Installed APK
cocok artefak terverifikasi. Install-r10→11 PASS; seluruh462hash tertutup
DB/no_backup/shared_prefs lama cocok sebelum startup. Kasir startup PASS;
key/preferensi/seed/proof tetap sesudah startup, package lain cocok/controlOff.
Whole-file DB sesudah runtime tidak diklaim identik karena alert/draft metadata
dapat berubah. Tidak mereset data, menghapus fitur/fingerprint atau downgrade.
APK/raw/private tetap lokal di build/printer-protocols-20261025.

Penggunaan: Printer → pilih printer tersimpan → bahasa perintah → ruang kosong
sebelum header/akhir → Simpan. Pilih mode yang memang didukung firmware.
TSPL/CPCL memakai kertas kontinu dan pageRows sesuai kemampuan perangkat;
BLE, protokol proprietary merek,300dpi dan desain/die-cut label belum didukung.
Tidak ada retry/fallback atau perubahan firmware otomatis. Hardware tambahan
tetap UNVERIFIED dan tidak menahan penutupan pekerjaan yang tersedia.

Pengguna mengotorisasi commit-push setelah seluruh pekerjaan selesai. Source
fitur9a23775 dan harness checkpoint25c66a7 sudah dipush biasa ke origin/main;
remote source HEAD9a23775f0e06376d3fc0ce84f099c86ab06c30ef terverifikasi sama.
Catatan penutupan dokumentasi mengikuti source tersebut. APK/database/log
privat tetap lokal. Tidak ada pekerjaan menunggu hasil uji mandiri pengguna.
