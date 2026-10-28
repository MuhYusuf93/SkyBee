# Ralat Paket Eksplorasi Mandiri — 29 Oktober 2026

Instruksi langsung terbaru pengguna menggantikan syarat mempertahankan database
aktif `.skybee` pada handoff akhir saja. **Setelah seluruh pekerjaan M5.3 selesai**,
tempatkan paket yang sama pada kondisi pertama dibuka agar pengguna dapat mencoba
onboarding baru. Bersihkan database lama dan inject dataset sintetis baru:
100 produk dengan berbagai kondisi, beberapa supplier, beberapa pelanggan
terdaftar, dan **50 transaksi**, menggantikan seed lama 20 transaksi.

Sampai tahap tersebut, seluruh data lama tetap dilindungi. Buat dan verifikasi
cadangan terenkripsi beserta material pemulihan yang diperlukan sebelum reset.
Reset ini khusus paket `.skybee` target handoff dan bukan izin menghapus paket
ordinary, fixture lain, akun OS, atau arsip backup. Jangan uninstall atau
menurunkan versi untuk mensimulasikan instalasi pertama.

Dataset baru harus memakai writer domain dan invariant asli. Seed berlangsung
sekali, deterministik/idempotent dengan marker dan bukti jumlah, tidak membentuk
grant manajemen aktif, tidak menyimpan PIN mentah, dan tidak menandai onboarding
selesai. Konfigurasi dasar yang diperlukan fixture harus kompatibel dengan
pilihan onboarding; currency historis seed tidak boleh dikonversi diam-diam.
Pengguna tetap menjalani setup pertama ID/EN dan memilih credential sendiri.

Rencana kondisi mencakup tracked kosong/positif/999, untracked sentinel,
biaya known/zero/unknown, batch layak/expired/campuran, produk arsip, kategori,
kemasan dan supplier beragam. Pelanggan/50 transaksi harus konsisten dengan stok,
HPP snapshot, status lunas/piutang dan reversal yang memang didukung. Nama/nomor
sepenuhnya sintetis. Penerimaan, retur, tagihan atau jadwal tambahan hanya jika
diperlukan untuk eksplorasi dan harus dilabeli sebagai fixture.

Pengujian reset/seed/onboarding terlebih dahulu pada `.integration`. Handoff H
baru menjalankan reset `.skybee` yang kini diotorisasi dan merekam bukti backup,
jumlah/baris, onboarding pending, dua startup, package/signature/version serta
batas verifikasi fisik. Permintaan ini bukan bukti bahwa reset sudah dilakukan.
