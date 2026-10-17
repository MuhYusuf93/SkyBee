# Printer dan kalibrasi M5

C20,17Oktober: setelah izin Bluetooth ditolak, percobaan berikutnya memberi petunjuk membuka izin aplikasi di Pengaturan Android, tanpa memunculkan dialog izin berulang. Dialog pertama atau keluar ke Pengaturan tetap dapat mengunci pengelolaan; masuk PIN kembali secara eksplisit. Memberi izin tidak membuka PIN otomatis dan tidak mengirim cetakan. Riwayat prompt bersifat lokal instalasi, tidak masuk backup portable. Validasi patch fisik masih pending pada checkpoint ini.

**Konfirmasi kertas16Oktober:** UJI COBA/1234567890/-12,34 € semuanya benar menurut pemeriksaan ulang pengguna. Profil dasar configured58mm/384dot/203DPI, margin8/8/shift0 **PASS manual** pada Poco+Iware/RPP02N; perpindahan baris bukan clipping pada sampel tersebut. Tidak mengukur DPI fisik atau menjamin setiap logo/font/model/80mm. Tidak perlu menerapkan offset OpenLabel-4mm pada baseline yang sudah bekerja.

**Bukti fisik terbaru16Oktober:** pengguna melaporkan Cetak UJI COBA keluar melalui aplikasi di Poco+Iware MP-581RL/RPP02N, configured58mm/384dots/203DPI/margin8/8/shift0. Baseline koneksi dan output dasar PASS manual. Kelengkapan judul/digit/desimal/€ masih diperiksa karena transkripsi belum persis template; jangan menganggap wrap sebagai clipping atau profil sebagai pengukuran hardware. Hasil lengkap/perubahan status pada PRINTER_TEST_REPORT_M5. Seluruh skenario/logo/80mm belum otomatis lulus.

Histori checkpoint awal: backend/UI dan tes fake/raster tersedia; kertas fisik saat itu belum diverifikasi. Hasil fisik terbaru ada di atas. Nama aplikasi tetap kasir_app. Tidak mengubah firmware printer/perangkat atau aplikasi OpenLabel.

Target utama pengguna: **Iware MP-581RL**, Bluetooth **RPP02N**, kertas~58mm. Sampel OpenLabel memakai ESC1/Conti/203DPI/57×57mm dan horizontal-4mm. Keberhasilan OpenLabel bukan bukti Flutter. Transport aplikasi saat ini **Bluetooth Classic SPP/ESC-POS**, bukan BLE-only, dan tidak mengklaim semua printer kompatibel.

## Penyiapan

1. Pada Poco yang tersedia, nyalakan printer dan pasang kertas. Kelola→Pengaturan→Printer Bluetooth. Izin diminta saat fitur dipakai; Android12+ SCAN/CONNECT, Android≤11 lokasi untuk discovery. Tidak ada ADVERTISE/backgroundlocation. Jika dialog mengunci Kelola, masuk melalui PIN kembali lalu lanjutkan.
2. Muat daftar berpasangan atau lakukan discovery12detik. Hasil dideduplikasi berdasarkan alamat, dapat dibatalkan. Pasangkan melalui dialog Android bila belum berpasangan, kemudian verifikasi daftar kembali. Jangan memilih perangkat lain hanya karena nama mirip.
3. Pilih ID stabil/nama RPP02N yang benar dan simpan profil. Generic58 default384dots/203DPI; Generic80 default576dots/203DPI. Ini awal kalibrasi, bukan hasil pengukuran hardware pengguna.
4. Defaultmargin8dots kiri/kanan, shift0, font24dots. 203DPI berarti sekitar8dots/mm. Lebar kertas berbeda dari printable width. Shift negatif harus ditopang margin kiri agar konten tidak keluar; untuk -4mm perlu sekitar-32dots dan margin yang sesuai. Jangan menjadikan -4mm default universal atau menutupinya dengan pemotongan angka.
5. Pilih font18/24/32, bold, header/footer alignment, logo, feed0–8. Nama panjang dan angka dibungkus; bidang nominal tetap utuh. Profil tersimpan per-device. Reset mengembalikan template profil, bukan mereset transaksi/data.
6. Periksa preview dan cetak sedikit halaman **UJI COBA**. Periksa batas kiri/kanan, ukuran, wrapping, digit/desimal/currency/minus, feeding dan keterbacaan. Sesuaikan satu parameter, ulangi secukupnya. Jangan mengaktifkan cutter/drawer yang belum didukung.

Header/footer toko berada pada pengaturan toko. Impor logo tersedia melalui SAF image-only, maksimum4MiB/4MP; normalisasi PNG terbatasi dan asset hash immutable menjaga struk lama. Ukuran logo50/75/100% dan linegap0/3/6/9dot. Preview logo memakai piksel monokrom threshold yang sama dengan encoder; uji reproduksi warna dan retest otomatis tercatat dalam M5_TEST_REPORT. Test80mm hardware tidak boleh ditandaiPASS dari renderer atau Iware58mm.

## Pengiriman

Struk memakai snapshot publik saat sale commit (termasuk grosir), tanpa HPP. Printer tidak berada dalam transaksi finansial. Pembayaran piutang sesudahnya tidak mengganti paid/debt pada snapshot asli; sale lama tanpa bukti awal memakai penandaan provenance yang jujur.

Antrean menyimpan prepared/sending/submitted/failed/unknown. Submitted berarti data transport diterima, bukan bukti kertas keluar. Putus/timeout sesudah percobaan write adalah unknown; periksa kertas dahulu. Restart tidak mengulang otomatis jobinflight/ambigu. Pilihan cetak ulang membuat job baru bertanda **SALINAN**, tidak checkout/kurangi stok lagi. Lupakan perangkat hanya menghapus binding aplikasi, tidak meng-unpair perangkat lain di sistem.

Uji fisik utama wajib Poco+Iware: pasangan/scan/koneksi/test, struk normal/panjang/grosir/customerdebt, lebar/margin/shift/logo, printeroff/kertashabis/putus/tapulang/background, inspeksi kertas dan rekonsiliasi finansial. Laporan: PRINTER_TEST_REPORT_M5.md. Jangan memaksakan printer fisik di DV/Realme sebagai pengganti target utama.
