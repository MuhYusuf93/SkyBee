# Backup portable dan restore M5

Status: implementasi/pemeriksaan berlangsung; lihat M5_TEST_REPORT. Google Drive adalah transport opsional, bukan sinkronisasi. Satu perangkat aktif per toko tetap berlaku.

## Recovery dan format

Pada Kelola→Pengaturan→Backup, buat kode recovery acak256bit dan simpan salinan pribadi di luar perangkat; konfirmasi kode yang disimpan. Kode ini berbeda dari PIN/recovery PIN. Kode baru hanya untuk backup berikutnya; arsip lama tetap memerlukan kode lamanya. Tidak ada master key pengembang, kata sandi Google, client secret atau key DB perangkat lama di arsip.

Format1 adalah ZIP beranggotakan tetap manifest.json/database.db/logo.png opsional, langsung di dalam Tink AES256-GCM-HKDF streaming64KiB. AAD `kasir-portable-archive-v1`. Database dalam ZIP juga SQLCipher dengan key HKDF-SHA256 dari recovery code dan backup UUID (`kasir-backup-database-v1`), bukan raw key instalasi. Enkripsi streaming memakai [Tink](https://developers.google.com/tink/streaming-aead), bukan konstruksi enkripsi chunk buatan sendiri.

Manifest mencatat format/schema/appversion/UUID/store/origin/UTC/currency/scale/zona toko dan SHA256/ukuran setiap anggota. Tidak memuat kode recovery/verifier/token. Verifier PIN berada hanya dalam DB terenkripsi sebagai bagian data penuh. Key dan consent Google tersimpan di Keystore/noBackup terpisah. Riwayat operasi dalam snapshot dapat memuat identitas akun pseudonim, tetapi tidak access/refresh token atau email consent lokal.

Snapshot diambil dengan writer gate melalui ekspor SQLCipher konsisten, divalidasi logis, lalu transport membaca arsip selesai. Tidak menyalin mainfile SQLite yang masih aktif/WAL secara buta. Buffer stream64KiB; HTTPchunk256KiB. Tidak memuat seluruh DB/ZIP ke RAM. Ruang kosong/disk I/O tetap bisa menggagalkan operasi; `.partial` tidak dinyatakan backup berhasil. Arsip baru dibaca/autentikasi ulang sebelum dikatalogkan.

## Lokal

Backup privat di dalam app belum merupakan salinan di luar perangkat. Pilih Ekspor untuk ACTION_CREATE_DOCUMENT melalui SAF; file hasil ditutup dan dibaca ulang untuk checksum. Cancel/provider gagal tidak dihitung sukses. Tidak memerlukan izin storage menyeluruh. Katalog lokal memakai keyset created_at/id; completed.json memungkinkan indeks artefak selesai dipulihkan setelah interupsi tanpa menganggap partial sebagai sukses. Jangan menghapus salinan luar aplikasi sebelum pengujian restore yang diperlukan.

## Pemulihan penuh

1. Masuk melalui PIN dan pilih berkas/versi Drive. Android dialog boleh mengunci Kelola; masuk melalui PIN lagi untuk melanjutkan pilihan tertunda.
2. Masukkan recovery code arsip, autentikasi/decrypt ke staging privat, tolak path/anggota ganda/ukuran tak aman/checksum/schema baru yang tidak dikenal. Migrasikan staging lama melalui jalur skema aplikasi dan verifikasi FK/integrity/rekonsiliasi.
3. Periksa metadata asal/waktu/currency/zona dan setujui penggantian seluruh data, termasuk draft lokal. Draft dari backup mengikuti isi backup, bukan digabung dengan draft aktif.
4. Safety backup terenkripsi dari data aktif WAJIB berhasil. Lease maintenance menahan writers dari snapshot safety hingga promosi; source lama tidak diganti bila validasi/safety gagal. Jika belum ada kode lokal, safety menggunakan kode arsip yang diberikan pada alur ini, tanpa mengaktifkan backup otomatis.
5. Database staging diekspor ulang dengan key instalasi tujuan. Logo harus tersedia sebelum DB mengarah kepadanya. Durable journal/previous memungkinkan rollback sebelum commit atau penyelesaian sesudah commit. File lama tidak dibuang sebelum verifikasi.
6. Scope/session/navigator direset. PIN setelah restore berasal dari backup; recovery archive tidak otomatis membuka Kelola. Audit lama/relasinya dipertahankan, identitas instalasi aktif baru ditunjuk eksplisit.

Tidak mengimpor consent/token Google atau penerimaan dokumen legal sebagai izin instalasi sekarang. Backup otomatis/notifikasi/pilihan printer dan antrean cetak direset; tidak auto-print/auto-upload. Sambungkan dan setujui kembali integrasi yang dibutuhkan. Riwayat finansial penuh, harga/HPP snapshot, batch, supplier, pembayaran/alokasi/reversal, pengaturan dan logo harus diverifikasi sesuai matriks.

## Batas dan recovery gagal

Backup Drive otomatis memakai budget maksimal tiga percobaan per target harian dan generasi consent, disimpan wrapped Keystore agar membuka ulang aplikasi/proses tidak mengulang budget. Transient failure mendapat backoff minimum15menit. Setelah percobaan ketiga gagal, status mencatat batas retry dan target berpindah ke hari berikutnya, tanpa mengubah last_success. Kegagalan otorisasi memerlukan tindakan pengguna; worker tidak membuka dialog. Backup manual tetap tersedia. Ini batas percobaan aplikasi, bukan janji eksekusi21:00 atau bukti Doze/reboot/OEM.

Keystore hilang bukan kasus yang dapat diselesaikan dengan mengganti PIN. Error storage mempertahankan DB. Safety/promotion error tidak boleh dipresentasikan sebagai sukses atau sebagai rollback tanpa memeriksa jurnal. Restore lintas key pada satu sandbox bukan uji lintas perangkat; native roundtrip awal DV membuktikan subset berisi data, sedangkan fault terbaru/perangkat lain/Drive nyata masih tercatat terpisah.

Checkpoint16Oktober19:10: lintas perangkat nyata DV→Poco1+1PASS/18digest/key instalasi berbeda/safety/relock. Tes terpisah DV source/target directory berbeda1PASS58s mencakup logo terisi+relokasi path, sale/payment reversal, WAL, writer bersamaan, safety dan stale intent. Fault restore4PASS. Ini bukti fixture native pada domain teruji, bukan SAF fisik/Drive nyata/power-loss. Histori/batas lain tetap pada M5_TEST_REPORT.


Catatan fixture M5 17Oktober2026: atas permintaan pengguna, build KASIR_INTEGRATION_TEST=true menampilkan teks pada input recovery backup/konfirmasinya, tetap dalam PIN gate. Build biasa tetap masked. Jangan menangkap/log/menyalin recovery aktual ke bukti pengujian; gunakan kode publik sintetis untuk otomatis. Inspeksi gagal tidak boleh menyisakan preview terdahulu; pesan kode/arsip tidak valid atau tidak dapat dibaca bukan bukti pasti kunci salah dan tidak melakukan restore. C23 validasi source/native/manual terbaru lihat M5_ARCHIVE_REJECTION_C23.md.
