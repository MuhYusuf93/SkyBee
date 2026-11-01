# Paket Eksplorasi Mandiri M5.3 — ID / EN

## Bahasa Indonesia

Paket `com.example.kasir_app.skybee` memakai source0.5.3+13/schema37. Handoff
hanya padaPoco F6 dengan update in-place dan signing yang sama. Ordinary dan
fixture lain tidak direset. Status pemasangan sebenarnya ada pada
[M53_EXPLORATION_HANDOFF_REPORT](M53_EXPLORATION_HANDOFF_REPORT.md).

Aplikasi ditinggalkan pada langkah pertama **Penyiapan toko**. Isi identitas,
pilih pola akses/stok/fitur, buat PIN4digit sendiri dan simpan recovery setup yang
ditampilkan. Printer boleh disiapkan atau dilewati. Tidak ada PIN demo yang
menjadi PIN Anda.

Pilih **Selesai dan buka Kasir** pada langkah7. Paket menyiapkan100 produk,
4 supplier,8 pelanggan terdaftar dan50 penjualan (termasuk2 reversal contoh),
dengan5 produk arsip. Ini sekali saja dan dapat memerlukan beberapa menit;
tunggu sampai selesai. Dataset aktif bersamaan dengan setup yang berhasil;
sebelum Finish database bisnis genuine masih kosong. Mode stok/biaya/currency
mengikuti konfigurasi yang dipilih; pilihan all/off membatasi variasi yang sah.

Nama diawali CONTOH dan kontak merupakan fixture sintetis. Tidak ada pesan,
backup Drive atau cetakan yang dikirim otomatis oleh proses seed. Label memakai
**QR code**; kode produk lama/leading zero tetap literal. Scanner fisik memerlukan
dukungan2D, dan hasil kertas/scanner fisik tetap berbeda dari uji encoder/transport.

Cadangan terenkripsi data sebelum reset dan file `RECOVERY.txt` disimpan di folder
pribadi `Documents/SkyBee-Backups/M53-H-...`. Kode tersebut untuk arsip lama,
bukan PIN baru atau recovery PIN setup. Simpan kedua file. Lokasi pasti dan bukti
salinan ada pada laporan akhir; jangan memasukkan file recovery/database ke Git.

Android Studio: buka root yang berisi pubspec.yaml; pilih konfigurasi tersimpan
**SkyBee Exploration (M5.3)** pada `.run/SkyBee_Exploration.run.xml`, mode debug,
Poco F6. Entrypoint `lib/main_skybee_demo.dart`, argumen
`--dart-define=KASIR_SKYBEE_DEMO=true`; ini applicationId dinamis, bukan flavor.
Entrypoint ordinary tetap `lib/main.dart`. Demo ditolak untuk release/profile.
Handoff memakai `tools/handoff_skybee_m53.py` dan APK yang sudah diverifikasi;
instalasi gagal tidak diperbaiki dengan uninstall, clear data atau downgrade.
Signing release masih sertifikat pengembangan, bukan penutupan M6/publikasi.

## English

The same `.skybee` package opens at genuine first-store setup. Choose your own
four-digit PIN and save the setup recovery code. Printer setup is optional.
On the final **Finish and open Cashier** action,100 varied products,4 suppliers,
8 registered customers and50 synthetic sales are activated atomically with your
chosen setup. Preparation runs once and may take several minutes. Before Finish,
the business database is intentionally empty. A later store reset does not grant
another automatic seed.

The pre-reset encrypted archive and `RECOVERY.txt` are preserved outside the
app in `Documents/SkyBee-Backups/M53-H-...`. That code belongs to the old backup,
not the new app PIN. No automatic cloud deletion, contact messages or printing.
Labels use QR codes; physical scanner/paper verification is reported separately.

Use Android Studio configuration **SkyBee Exploration (M5.3)**, debug mode,
`lib/main_skybee_demo.dart` and `--dart-define=KASIR_SKYBEE_DEMO=true`. The ordinary
entrypoint remains separate. This is a development-signed exploration handoff;
M6 production release/signing is outside the current milestone.
