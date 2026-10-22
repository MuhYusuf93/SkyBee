# Arahan perangkat lanjutan — 19 Oktober 2026

**Koreksi operasional20 Oktober2026:** Poco F6 dan printer berbagi satu kabel
USB; pengguna mencabut Poco untuk menyambungkan printer ke DV8910. Ini pergantian
kabel yang disengaja, bukan gangguan ADB/USB debugging. Selesaikan cetak DV dan
tunggu verifikasi kertas terlebih dahulu, kemudian minta perpindahan kabel ke
Poco untuk audit interval tertunda/handoff. Jangan meminta keduanya tersambung
bersamaan atau meminta perbaikan debugging saat Poco memang menunggu printer.
Pada percobaan raster pertama0target/0byte, belum ada marker/write; pengguna
kemudian menyatakan printer sudah tersambung ke DV. Realme tetap dijeda.

Pengguna menegaskan kembali20 Oktober: izin USB printer DV boleh dipaksa khusus
pengujian. Gunakan izin Android normal bila sudah tersedia; otorisasi ini bukan
izin firmware/root permanen, perubahan aplikasi lain atau retry hasil cetak
ambigu. Izin normal UID fixture10115 sudah diberikan pada dialog printer PYN-58L.

Pengguna mengizinkan pengujian rutin saat Poco F6, DV8910 atau Realme C11
terdeteksi, tanpa meminta konfirmasi ketersediaan lagi. Autentikasi manusia,
pemeriksaan kertas dan kemampuan OEM tidak boleh diasumsikan dari koneksi ADB.

Arahan terbaru memprioritaskan cetak USB pada DV8910 yang dilaporkan tersambung
ke printer, menggunakan ADB agar pengguna tidak perlu mengoperasikan remote.
Sesudah pengiriman cetak yang benar-benar terjadi, minta hasil kertas pengguna.
Ini menggantikan batas lama dokumen M5.1-F yang tidak meminta USB fisik pada DV.
Identitas DV8947-KIX/AX810 di 192.168.0.102 tetap diterima.

Sesudah itu catat checkpoint dan lanjutkan tes M5 sampai perubahan terbaru
pada Realme C11 yang tersambung PC, tanpa pengujian manual pengguna. Tidak
menghapus bukti Realme terdahulu: 88 regresi SQLCipher historis pernah lulus;
yang belum terbukti adalah perubahan acceptance M5 berikutnya pada Realme.
Tidak menyamakan tes SDK/HTTP/output tiruan dengan Google/printer/keyboard/
TalkBack fisik. Pengujian independen diteruskan bila hardware/akun terhalang.

Semua tes memakai paket integration dan data fixture. Tetap tanpa reset,
uninstall, downgrade paksa, perubahan firmware/sistem/aplikasi lain. Snapshot
awake DV wajib dikembalikan dan dibaca ulang. M5.1 D/E/G tetap belum selesai;
M5.2 menunggu desain dan M6 belum dimulai.
