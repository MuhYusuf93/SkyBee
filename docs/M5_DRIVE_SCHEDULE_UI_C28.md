# C28 — status target jadwal sesudah perubahan switch

Gejala host: saat aktivasi, backend telah menyimpan epoch target21:00 dan meminta satu job melalui WorkManager tiruan, tetapi BackupSettingsProvider.overview masih null. Sebelum patch1FAIL5s. D-MAN14 pada C27 justru PASS reported; label zona waktu toko memang benar. Tidak menyebut HP gagal, job tidak terdaftar, atau bug zona waktu dari bukti host ini.

Penyebab jalur host yang direpro: automatic memuat policy dan memanggil scheduler.refresh tetapi tidak memuat ulang overview yang dibaca label jadwal. Dampak: label dapat tertinggal sesudah switch berubah; bukan kehilangan data, perubahan target21:00, atau kegagalan upload yang terbukti.

Perbaikan aplikasi: backup_settings_provider.dart memuat overview melalui BackupService sesudah refresh, sebelum feedback sukses. Widget/Provider tetap tidak membuka SQL/transaksi. Policy/generation/consent, aturan21:00/best effort, business data serta scope akun tidak berubah.

Tes m5_settings_ui_test.dart memakai kebijakan/Keystore/WorkManager tiruan dan nilai publik. Periksa persisted target vs route/rendered status tanpa refresh; ON terdaftar sekali, OFF membatalkan dan membersihkan target, semua fingerprint tabel selain backup_schedule tetap, backup_runs kosong. Tidak mengunggah atau membuat job OS. After pertama melewati assertion state tetapi helper belum memount baris lazy (FAIL terpisah, bukan kegagalan patch aplikasi); scroll bounded ditambahkan tanpa mengurangi assertion. Hasil focused/full/analyze/native/build/preservation masih menunggu.

Perangkat saat ini C27, Google connected/autoON/5arsip setelah D-MAN14. Pembaruan native wajib mempertahankan semua tabel/arsip/policy digest dan ordinary hash, tanpa reset atau unggah tambahan. APK produksi hanya build/verify, bukan install. Histori comparator-fix restore Drive tetap terpisah.

## Checkpoint host dan analisis

Focused akhir1PASS5s, subset dari regresi6file48PASS133s. Before1FAIL5s actual overview=null dengan persisted1792332000000; after pertama gagal pada0widget target belum mounted, lalu helper scroll pertama mengenai notice scrollable sehingga StateError. Keduanya dipertahankan di c28-schedule-host-after.log dan after-reveal.log, terpisah dari product bug awal. Scoped form scroll (key backup-settings-form) membuat assert rendered target dan OFF/cancel/target-clear lulus tanpa refresh atau penghapusan assertion.

Analyzer pertama2info curly_braces pada helper baru (138,9s), bukan PASS. Brace ditambahkan tanpa perubahan perilaku; analyzer ulang --no-pub No issues7,2s sesudah dependency sudah selesai. Tidak ada proses dihentikan. Native/build/preservation pipeline baru dimulai, belum menjadi hasil PASS pada checkpoint ini.

**C28 siap retest manual, 18 Oktober 2026:** projection target dimuat ulang dari service setelah switch; host48PASS133s (focused1 subset), analyzer 7.2s No issues; Poco1PASS; DV 1PASS schedule UI mock; exact prior APK/default hashes and awake restored/read back. Native UI memakai plugin tiruan, bukan upload/job OS nyata. Build ordinary/fixture/bridge verified universal/min24/16KiB/icon/license/signature/negative guard; ordinary tidak dipasang. Strict before/after1+1PASS: seluruh tabel+5arsip+digestpolicy sama, real account connected/autoON dan target21 tersimpan, backup_runs kosong/tidak ada unggah tambahan. C28 installed hash cocok dan own cashier startup/0marker pada buffer diperiksa; kontrol otomatis Off. D-MAN14 pada C27 tetap PASS reported, bukan gagal karena label zona waktu toko. Retest fisik OFF/ON tanpa refresh berikutnya; actual21delivery/headlessGoogle/retensi/lintas akun/reboot/Doze dan closing belum selesai. OriginalAPK6 pending; M5 belum selesai/M6 tidak dimulai. [Laporan](M5_DRIVE_SCHEDULE_UI_C28.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-schedule-ui-update-1792317053346\update.json

**C28 retest fisik PASS dilaporkan pengguna, 18 Oktober 2026:** koreksi lokasi teks: OFF target belum terjadwal, ON target18/10/2026 21:00 tanpa refresh; static help21:00 bukan nilai target. Kondisi akhir otomatis On. Selama jeda pengguna melaporkan satu Off dan satu On saja; bukan bukti semua metadata tetap atau job tidak berjalan. Poco7f0edea0 dan DV192.168.0.102:5555 terdeteksi ulang; berikut baseline baru dan controlled headless Drive/retensi, bukan mengubah jam sistem atau klaim actual21delivery. Kontrol perangkat belum aktif saat persiapan host. M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/c28-man01r-user-report.json).**
