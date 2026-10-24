# Koreksi default ruang kosong footer — 25 Oktober 2026

Pengguna menemukan Skybee+11 masih menampilkan6baris sesudah footer setelah restart, sementara header sudah3. Penyebab: constructor default3 tidak menggantikan default6 yang sudah tersimpan dalam profil lama.

Pembacaan pengaturan tanpa marker `footerFeedVersion` dengan feed6 sekarang menghasilkan3. Nilai lama lainnya tetap. Save berikutnya menyimpan marker versi1, sehingga pilihan manual0–8 termasuk6 tidak dinormalisasi lagi. Karena data lama tidak menyimpan asal nilai6, pilihan manual6 pada build lama juga mengikuti aturan ini; pengguna tetap dapat memilih dan menyimpan6 pada build baru.

Tidak ada migrasi/rewrite SQL, perubahan schema, atau reset. UI, preview, recovery dan job baru memakai parser pengaturan yang sama. Snapshot job historis dibaca melalui parser snapshot yang mempertahankan feed aslinya, termasuk6 dan top0 pada snapshot lama. Feed atas tidak berubah.

Hasil aktual:

- Host44/44 PASS66s: seluruh0–8, roundtrip, form legacy6/reopen/save, job baru3 versus snapshot lama6, output/recovery.
- Analyzer bersih176,2s; formatter4file. Build debug24,2s; paket/version12/debug certificate/3ABI/13library/16KiB PASS.
- Poco native form1/1 PASS12s melalui wrapper resmi: 451hash lama cocok, kontrol otomatis berakhir.
- Update in-place11→12:463hash lama tertutup sama sebelum launch. Startup/key/prefs/seed/proof/package lain PASS. Tidak mengklaim hash seluruh DB sama setelah startup karena metadata runtime dapat berubah.
- Profil aktual terpilih80mm/ESC-POS Raster pada dua peluncuran termasuk cold restart: rawFooter6/rawVersionnull tetap, form footer3/header3. Verifikasi memakai callback UI Flutter debug milik aplikasi dan metadata read-only; tidak ada SQL write/cetak/perubahan PIN/fingerprint/perizinan. Debugger dilepas.

Tidak ada cetak fisik tambahan: kasus ini tentang nilai pengaturan. Tidak mengulang suite perangkat lain, menunggu uji mandiri, mengklaim protokol hardware baru atau memulai milestone lain. Data, binding printer, geometry dan protokol tetap.

[Bukti terkurasi](evidence/printer-footer-default-20261025/validation-results.json). APK/log/hash sandbox/URI debugger tetap lokal pada build/printer-footer-default-20261025.
