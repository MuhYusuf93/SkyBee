# Pemeriksaan Git lokal — 18 Oktober 2026

Pengguna menyatakan repository telah diunggah ke GitHub dengan visibilitas public dan folder `.git` kini tersedia. Pemeriksaan ini memakai index/metadata lokal; remote tidak di-fetch atau diaudit.

- Root Git cocok dengan workspace aplikasi. HEAD sudah memuat perubahan source C26 sebelum sesi ini; jangan menganggap source itu belum berubah hanya karena `git diff` kosong. Perubahan fase audit setelah sesi dilanjutkan tetap terlihat sebagai diff terhadap HEAD.
- Index lokal melacak **1.361 file**, termasuk **68 APK dan satu arsip `.kasirbackup`**, total artefak **4.613.638.302 byte**. Arsip tersebut berada pada fixture cross-transfer M5. Klasifikasi ini berdasarkan nama/ukuran, bukan hasil audit dekripsi atau pemindaian secret.
- Tidak ditemukan ekstensi database/keystore/certificate privat dalam klasifikasi file tracked yang diperiksa. Ini bukan bukti tidak ada rahasia pada file teks atau riwayat commit.
- `.gitignore` ditambah untuk APK/arsip/database baru di `docs/evidence`. Aturan ignore tidak mengeluarkan 69 artefak yang sudah tracked dari index/riwayat.
- Output generated `android/build` juga di-ignore. Laporan Gradle HTML yang sudah tracked berubah akibat build sesi ini; salinan working tree dikembalikan ke HEAD setelah build selesai, karena file tersebut bersih pada pemeriksaan awal sesi. Entry Git/riwayat tidak dihapus.
- Salinan APK asli dan berkas uji tetap diperlukan oleh closing restoration; jangan menghapusnya dari disk. Bukti teks, kode skrip, hash, dan laporan tetap dapat ditinjau.
- Tidak ada perubahan index, commit, push, penghapusan file lokal, atau penulisan ulang riwayat dalam pemeriksaan ini. Pembersihan repository/riwayat yang sudah dipublikasikan memerlukan tindak lanjut tersendiri; M5 tetap dilanjutkan.

Inventory lokal: `evidence/m5-20261018/git-public-artifacts-local-index.json`. Nilai OAuth client ID publik bukan client secret. PIN/kode recovery/token atau identitas akun nyata tetap tidak boleh dimasukkan ke laporan/log.
