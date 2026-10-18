# Konfigurasi Google Drive M5

Status16Oktober: backend dan tes protokol palsu tersedia; belum ada klaim consent/upload/download/restore Google nyata. Web client ID terbaru diterima pengguna dan digunakan sebagai build configuration default. Jangan menyalin JSON rahasia ke assets atau membagikan token.

Project **SkyBee / skybee-cf8b9**, External/Testing, scope `https://www.googleapis.com/auth/drive.appdata`. Pengguna telah menyampaikan penggantian Androidclient yusuf2; screenshot lama yang berbeda bukan bukti client saat ini salah. Kasir merupakan aplikasi biasa, bukan AI-powered agent. Firebase, backend/serviceaccount dan fullDrive/People/Contacts tidak diperlukan.

Web serverClientId:
`223840564378-1l1bqc7c31fidirriotb1bt88ceh0s0i.apps.googleusercontent.com`

Override bila diperlukan: `--dart-define=GOOGLE_WEB_CLIENT_ID=<Web-client-ID>`. Ini ID publik, bukan client secret; AndroidclientID bukan serverClientId. App name/applicationId/signing produksi tetap sesuai repository.

## Satu daftar preflight yang masih dibutuhkan untuk tes nyata

- Pastikan Drive API Enabled, scope tersimpan, audience Testing dan akun uji yang hendak dipakai tercantum.
- Registrasi Android produksi `com.example.kasir_app` dan Android sandbox `com.example.kasir_app.integration` adalah kombinasi package/sertifikat berbeda. Jangan menghilangkan suffix untuk mengakali registrasi.
- APK debug aktual M5 diperiksa apksigner: **D4:EE:1A:96:8D:DC:4D:11:30:72:C5:A5:C8:CC:1F:5F:B0:55:84:03**, cocok dengan SHA1 yang dikirim pengguna. Release lokal saat ini masih development/debug signing; sertifikat rilis final M6 terpisah.
- Pengguna mengonfirmasi registrasi Android `.integration` untuk SHA-1 di atas: `223840564378-vp8nn6or8vd2ua0p5dnhm03fq7qvi0jq.apps.googleusercontent.com`. Ini konfirmasi konfigurasi oleh pemilik, belum bukti consent/API runtime. Client Android tidak dipakai sebagai `serverClientId`. Uji utama Google nyata memakai Poco saat tersedia; jangan menambah akun pada Realme pinjaman.

## Alur aplikasi

Google tidak diminta di startup kasir. Dari pengaturan terproteksi pilih akun melalui SDK resmi GoogleSignIn7.2.0, berikan drive.appdata, lalu konfirmasi identitas tujuan setelah PIN bila dialog Android mengunci aplikasi. UI menampilkan akun tujuan. Sambungan bukan opt-in otomatis: switch auto defaultoff dan memerlukan persetujuan tersendiri serta recovery backup yang sudah dikonfirmasi. Disconnect merevoke policy lokal terlebih dahulu, termasuk jika revoke jaringan gagal.

Worker menggunakan API publik plugin resmi untuk otorisasi akun tertentu tanpa UI; ketika resolution dibutuhkan ia berhenti dengan needs-auth. `about.user.permissionId` dan email diperiksa agar token tidak diam-diam mengarah akun lain. Policy generation dicek sebelum upload/chunk/final. Permintaan yang sudah dikirim ke jaringan tidak bisa ditarik kembali; hasil parsial/timeout harus diperiksa/retry melalui protokol resumable, bukan dinyatakan sukses.

Transport REST memakai appDataFolder, nama/UUID/properti namespace berbeda antaraordinary dan.integration. Arsip selesai diupload dalam chunk256KiB, range disimpan/resume, ukuran/SHA256/MD5 server diperiksa sebelum complete/retention. Session URL disimpan wrapped di luar DB; token hanya memori/SDK. Tidak mengirim mainfile DB aktif.

Retensi7 hanya complete dari store+origin+namespace yang sama, setelah upload baru diverifikasi. Tidak menyapu backup instalasi lain. Restore dapat memilih versi milik akun/namespace yang sesuai dan tetap memerlukan recovery code serta prosedur safety lokal.

Target21:00 zona toko best effort WorkManager, network constraint, backoff dan catch-up coalesced. Jangan mengklaim exactalarm, pelaksanaan setelahforce-stop, atau waktu yang sama pada semuaOEM. Status attempt/success/error/nexttarget harus dibaca dari catatan aktual. Testing consent dapat membutuhkan otorisasi ulang sekitar7hari.

Budget otomatis maksimal3 percobaan per target/generation, persisten di Keystore-wrapped storage. Backoff transient minimum15menit; exhausted mencatat error dan menjadwalkan target hari berikutnya, bukan sukses. Auth/permanent failure tidak diberi retry tanpa batas. Reopen foreground tidak menghidupkan kembali target yang exhausted; manual retry tetap merupakan pilihan pengguna.

Sumber primer: [konfigurasi GoogleSignIn Android](https://pub.dev/packages/google_sign_in_android), [appDataFolder](https://developers.google.com/workspace/drive/api/guides/appdata), [about.get scope](https://developers.google.com/workspace/drive/api/reference/rest/v3/about/get), [resumable upload](https://developers.google.com/workspace/drive/api/guides/manage-uploads), [WorkManager](https://developer.android.com/topic/libraries/architecture/workmanager). Tidak mengubah Console/client/billing/publikasi pada pekerjaan ini.


17Oktober2026: D-MAN01 membuka pemilih Google dan cancel, feedback umum FAIL historis. C25 mapping canceled→Dibatalkan dan kandidat invalidation host/native mock PASS; akun tersimpan dipertahankan. Local policy actual sebelum/sesudah update disconnected/off/no identity; belum consent/API/upload Google. APK fixture terbaru/retst aktual mengikuti ledger C25, tidak mengubah client ID/package/certificate.


**D-MAN01R PASS manual dilaporkan pengguna, 17 Oktober 2026:** pemilih Google nyata dibatalkan pada APK C25; teks halaman kini Dibatalkan. dan tombol Pilih atau ganti akun Google tetap tersedia di bawah tiga baris jadwal. Feedback C25 terkonfirmasi pada Poco; D-MAN01 gagal sebelumnya tetap riwayat. Belum memilih akun/membuktikan consent, tujuan tersimpan, API atau upload; dialog PIN kondisional tidak diasumsikan terjadi. Berikut D-MAN02: pilih akun uji hingga pratinjau Pilihan akun belum disimpan/Gunakan akun ini, tanpa konfirmasi tujuan atau unggah. Kontrol otomatis nonaktif; original APK v6/closing pending. M5 belum selesai, M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man01r-user-report.json).**


**D-MAN02 PASS manual dilaporkan pengguna, 17 Oktober 2026:** pemilihan akun Google nyata kembali dengan status Pilihan akun siap, akun yang benar diperiksa secara pribadi, Pilihan akun belum disimpan dan tombol Gunakan akun ini. Belum konfirmasi tujuan tersimpan atau membuktikan Drive identify/API/upload; kemunculan dialog consent/PIN kondisional tidak diasumsikan. Berikut D-MAN03: Gunakan akun ini sekali lalu periksa status tersimpan, akun tujuan yang benar dan Backup Drive otomatis masih Off, tanpa unggah. Kontrol otomatis nonaktif; original APK v6/closing pending; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man02-user-report.json).**


**D-MAN03 FAIL manual dilaporkan pengguna, 17 Oktober 2026:** konfirmasi Gunakan akun ini pada dua akun uji menghasilkan Operasi Drive belum selesai. Periksa jaringan, otorisasi, dan konfigurasi akun. Pengguna menyatakan kedua akun terdaftar pada audience; identitas tidak disalin. Penyebab belum ditentukan; tujuan tersimpan/API/upload tidak diklaim berhasil. Manual retry dijeda; inspeksi klasifikasi error dan konfirmasi Google Drive API Enabled berjalan. D-MAN01R/02 tetap PASS pada cakupan sebelumnya. Kontrol otomatis perangkat nonaktif; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man03-user-report.json).**


**D-CONFIG01 konfigurasi belum siap, 17 Oktober 2026:** pengguna memeriksa dan melaporkan Google Drive API belum Enabled pada project aplikasi. Diarahkan memilih Google Drive API oleh Google pada skybee-cf8b9 lalu Enable. Aktivasi/hasil retry belum dilaporkan; exact HTTP/reason D-MAN03 tidak ditangkap sehingga belum menyimpulkan satu-satunya penyebab. C26 memperjelas feedback terstruktur API-disabled vs forbidden tanpa membocorkan respons mentah; tes host berjalan, belum native/build/deploy. APK Poco tetap C25. Berikut D-MAN03R setelah API aktif; otomatis perangkat tetap Off, jangan upload/auto dulu. M5 belum selesai/M6 tidak dimulai.**


**Dilanjutkan 18 Oktober 2026 — D-MAN03R PASS manual dilaporkan pengguna:** setelah Google Drive API diaktifkan, APK C25 yang sama berhasil menyimpan akun tujuan yang benar dan switch otomatis tetap Off. Kegagalan sebelumnya konsisten dengan konfigurasi API belum aktif; exact HTTP lama tidak direkam. Ini hasil alur identifikasi/simpan dilaporkan, belum audit policy mandiri atau upload/list/download/restore/penjadwalan nyata. Pengguna melihat-lihat fitur selama jeda dan melaporkan tanpa perubahan DB/cetak/backup/restore; bukan bukti semua tabel identik, metadata/audit mungkin berubah. C26 host34PASS128s selesai sebelum limit; analyzer sebelumnya tidak dieksekusi karena automatic approval review gagal akibat limit, kini dicoba ulang. C26 belum dipasang, Poco terakhir C25. Kontrol otomatis perangkat masih Off; pemeriksaan independen berjalan. M5 belum selesai/M6 tidak dimulai. Bukti: [D-MAN03R](evidence/m5-20261018/d-man03r-user-report.json), [laporan jeda](evidence/m5-20261018/resume-user-report.json).**


**C26 siap lanjut manual, 18 Oktober 2026:** feedback API-disabled/forbidden dibedakan tanpa respons mentah. Host34PASS128s, analyzer finalNoissues6,6s; Poco20PASS; DV 20PASS; exact prior APK/default sandbox hashes and awake restored/read back. Build universal ordinary/fixture/bridge, ikon/min24/16KiB/licenses/signature/negative guard PASS; ordinary tidak dipasang. Audit post_drive_connected before/after masing-masing1PASS: seluruh tabel dan3arsip identik pada interval baseline baru, akun tetap connected/autoOff dan digest policy sama, fakta2sale/stok/HPP/integrity/FK serta rawlegacy/ordinary/public2exports sesuai. Tidak mengklaim semua tabel sama sepanjang pengguna melihat-lihat. C26 installed SHA cocok; own cashier startup/0error marker pada buffer diperiksa. Kontrol otomatis dihentikan. D-MAN03R accept setelah API aktif tetap PASS reported; belum upload/list/download/restore Drive nyata. Berikut D-MAN04 satu backup manual dengan switch auto tetap Off. OriginalAPK6/closing pending, M5 belum selesai/M6 tidak dimulai. Detail [C26](M5_DRIVE_CONFIGURATION_C26.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-drive-config-update-1792309347903\update.json


**D-MAN04 PASS manual dilaporkan pengguna, 18 Oktober 2026:** satu backup manual pada C26/Poco menampilkan Upload arsip Drive sudah diverifikasi., satu riwayat baru Berhasil diverifikasi, dan pemuatan selesai; akun uji benar diperiksa pribadi dan otomatis tetap Off. Ini hasil UI unggahan nyata, bukan audit HTTP/server/arsip mandiri. List/download/restore, jadwal dan retensi nyata belum diklaim. Berikut D-MAN05: Versi backup Drive sekali, periksa baris nama/waktu/ukuran/tombol Pilih untuk pemulihan tanpa menekannya. Kontrol otomatis Off; originalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261018/d-man04-user-report.json).**


**D-MAN05 PASS manual dilaporkan pengguna, 18 Oktober 2026:** Versi backup Drive menampilkan satu baris arsip dengan nama, waktu, ukuran lebih dari0bytes dan tombol Pilih untuk pemulihan; pemuatan selesai. Ini bukti UI listing nyata setelah upload D-MAN04, bukan download/validasi bytes/restore atau audit server mandiri. Berikut D-MAN06: pilih arsip sekali untuk download, periksa status Arsip dipilih dan kolom recovery/Validasi arsip, tanpa memasukkan kode atau mengganti data. Kontrol otomatis Off; originalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261018/d-man05-user-report.json).**


**D-MAN06 PASS manual dilaporkan pengguna, 18 Oktober 2026:** status Arsip dipilih sesuai; kolom Kode recovery backup dan tombol Validasi arsip tersedia. Kolom masih kosong adalah keadaan awal sesuai, tidak diisi otomatis; bukan bug yang dilaporkan. Ini hasil UI download/pilihan arsip nyata, belum autentikasi recovery/pratinjau atau restore, dan belum audit bytes/server mandiri. Berikut D-MAN07: salin kode tersimpan secara pribadi, sembunyikan kembali, Tempel lalu Validasi arsip sekali; periksa metadata tanpa penggantian data. Kontrol otomatis Off; originalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261018/d-man06-user-report.json).**


**D-MAN07 PASS manual + permintaan C27, 18 Oktober 2026:** arsip unduhan Drive terautentikasi/tervalidasi dan metadata toko sintetis/2barang/2sale/schema8/IDR/AsiaJakarta sesuai berdasarkan laporan pengguna. Belum restore. Pengguna meminta tombol Salin ke papan klip yang menghapus spasi/tanda hubung, berlaku pada aplikasi utama juga. Implementasi dimulai; restore manual dijeda. Pembaruan paket uji nanti akan mereset pilihan/pratinjau route, sehingga download/validasi perlu diulang sebelum restore; data aktif tidak diganti. Kontrol perangkat masih Off; M5 belum selesai/M6 tidak dimulai. Bukti: [D-MAN07](evidence/m5-20261018/d-man07-user-report.json), [permintaan C27](evidence/m5-20261018/c27-request.json).**
