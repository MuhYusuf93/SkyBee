# C26 — feedback konfigurasi Google Drive

17 Oktober 2026. M5 aktif; M6 tidak dimulai.

## Temuan dan batas bukti

D-MAN03 gagal saat mengonfirmasi akun tujuan setelah pemilihan akun berhasil. Pengguna melaporkan pesan “Operasi Drive belum selesai. Periksa jaringan, otorisasi, dan konfigurasi akun.” pada dua akun yang menurut pengguna terdaftar sebagai test user. Identitas akun tidak disalin ke laporan/log.

D-CONFIG01: pengguna kemudian memeriksa Console dan melaporkan Google Drive API belum Enabled. Ini kendala konfigurasi terkonfirmasi berdasarkan laporan pengguna. HTTP status/reason dari percobaan D-MAN03 tidak direkam; jangan mengklaim bahwa respons aktual pasti SERVICE_DISABLED atau bahwa tidak mungkin ada penyebab lain. Aktivasi API dan keberhasilan retry masih menunggu laporan.

Secara terpisah, kode menyatukan respons API-disabled dengan penolakan akses lain menjadi driveForbiddenOrNotConfigured, lalu UI menampilkan kegagalan Drive umum. Ini kelemahan feedback aplikasi yang dapat direproduksi tanpa akun nyata. Repro host menghasilkan **2 FAIL / 1 PASS**: dua format terstruktur API-disabled kehilangan kategori; kasus yang tidak terstruktur tetap ditolak sebagai penyebab spesifik. Bukti: `evidence/m5-20261017/c26-host-before.log`.

## Perubahan

- `lib/features/backup/application/drive_rest.dart`: kenali 403 terstruktur `usageLimits/accessNotConfigured` atau Google ErrorInfo `SERVICE_DISABLED` khusus service `drive.googleapis.com`. Pesan bebas/JSON rusak/service lain tidak dijadikan bukti API-disabled. Respons mentah tidak dipaparkan atau disimpan.
- `lib/features/backup/presentation/backup_settings_provider.dart`: tampilkan kategori API-disabled dan forbidden secara terpisah; penolakan umum tidak mengklaim penyebab pasti.
- ARB Indonesia/Inggris, hasil gen-l10n, dan `localization.dart`: petunjuk aktivasi API hanya untuk kategori terstruktur; tidak meminta perubahan client ID, perluasan scope atau penghapusan data.
- `test/m5_drive_failure_test.dart`: kategori terstruktur, payload rusak/menyesatkan/service lain, privasi pesan dan status non-403.
- `test/m5_settings_ui_test.dart`: status spesifik, pemuatan berakhir, kandidat tetap untuk retry, policy disconnected dan seluruh fingerprint DB tetap untuk kegagalan task yang disimulasikan. Ini bukan permintaan HTTP nyata atau bukti seluruh alur acceptAccount.

Tidak mengubah token, scope drive.appdata, identitas akun yang wajib cocok, PIN, consent, retry, enkripsi, migration, atau aturan uang/stok. API belum aktif memerlukan perbaikan Console oleh pemilik; patch feedback tidak mengaktifkan API.

## Pemeriksaan berjalan

Regresi host dan analyzer/build dicatat setelah selesai. Native/paket manual tetap C25 sampai ada deployment terverifikasi; perubahan source C26 belum menjadi bukti hasil perangkat. Selama pengguna menjalankan pemilih Google, kontrol otomatis Poco tetap nonaktif. Jangan menjalankan audit post_restore yang mengharuskan policy disconnected setelah akun berhasil dihubungkan.

## Referensi

- [about.get menerima scope drive.appdata](https://developers.google.com/workspace/drive/api/reference/rest/v3/about/get).
- [Penanganan error Google Drive](https://developers.google.com/workspace/drive/api/guides/handle-errors).
- [Aktivasi Google Drive API](https://developers.google.com/workspace/drive/api/guides/enable-sdk#enable_the_drive_api). Bagian konfigurasi Drive UI tidak diperlukan untuk backup appDataFolder ini.
- [Library API project yang digunakan](https://console.cloud.google.com/apis/library/drive.googleapis.com?project=skybee-cf8b9).

## Berikutnya

D-MAN03R pada APK C25 yang masih terpasang: setelah API Enabled, konfirmasi kandidat akun yang benar, periksa status tujuan disimpan dan automatic Off. Jangan mengunggah/mengaktifkan auto sebelum langkah manual berikutnya. D-MAN01R/02 tetap PASS terbatas laporan sebelumnya; identifikasi/unggah/list/download/restore Drive nyata belum dinyatakan lulus.


**Dilanjutkan 18 Oktober 2026 — D-MAN03R PASS manual dilaporkan pengguna:** setelah Google Drive API diaktifkan, APK C25 yang sama berhasil menyimpan akun tujuan yang benar dan switch otomatis tetap Off. Kegagalan sebelumnya konsisten dengan konfigurasi API belum aktif; exact HTTP lama tidak direkam. Ini hasil alur identifikasi/simpan dilaporkan, belum audit policy mandiri atau upload/list/download/restore/penjadwalan nyata. Pengguna melihat-lihat fitur selama jeda dan melaporkan tanpa perubahan DB/cetak/backup/restore; bukan bukti semua tabel identik, metadata/audit mungkin berubah. C26 host34PASS128s selesai sebelum limit; analyzer sebelumnya tidak dieksekusi karena automatic approval review gagal akibat limit, kini dicoba ulang. C26 belum dipasang, Poco terakhir C25. Kontrol otomatis perangkat masih Off; pemeriksaan independen berjalan. M5 belum selesai/M6 tidak dimulai. Bukti: [D-MAN03R](evidence/m5-20261018/d-man03r-user-report.json), [laporan jeda](evidence/m5-20261018/resume-user-report.json).**


**C26 siap lanjut manual, 18 Oktober 2026:** feedback API-disabled/forbidden dibedakan tanpa respons mentah. Host34PASS128s, analyzer finalNoissues6,6s; Poco20PASS; DV 20PASS; exact prior APK/default sandbox hashes and awake restored/read back. Build universal ordinary/fixture/bridge, ikon/min24/16KiB/licenses/signature/negative guard PASS; ordinary tidak dipasang. Audit post_drive_connected before/after masing-masing1PASS: seluruh tabel dan3arsip identik pada interval baseline baru, akun tetap connected/autoOff dan digest policy sama, fakta2sale/stok/HPP/integrity/FK serta rawlegacy/ordinary/public2exports sesuai. Tidak mengklaim semua tabel sama sepanjang pengguna melihat-lihat. C26 installed SHA cocok; own cashier startup/0error marker pada buffer diperiksa. Kontrol otomatis dihentikan. D-MAN03R accept setelah API aktif tetap PASS reported; belum upload/list/download/restore Drive nyata. Berikut D-MAN04 satu backup manual dengan switch auto tetap Off. OriginalAPK6/closing pending, M5 belum selesai/M6 tidak dimulai. Detail [C26](M5_DRIVE_CONFIGURATION_C26.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-drive-config-update-1792309347903\update.json


Ringkasan mesin: [c26-results.json](evidence/m5-20261018/c26-results.json). Host34 mencakup20kasus UI yang sama dijalankan lagi per perangkat, bukan74kasus unik. Poco20PASS122s; DV20PASS246s. DV ordinary package absent, bukan pelestarian DB yang tidak ada. Build memberi warning kompatibilitas KGP workmanager untuk versi Flutter mendatang, tetapi build saat ini berhasil; tidak ada upgrade dependency tanpa kebutuhan.
