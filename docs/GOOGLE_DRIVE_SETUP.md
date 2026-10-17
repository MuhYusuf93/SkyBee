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
