# Penyiapan baru M5.3 — keputusan implementasi berikutnya

Status: desain untuk langkah A2 berikutnya; belum diimplementasikan/diterima.

Marker instalasi baru sudah berasal dari migrasi15 saat oldVersion0. Update
toko lama mempunyai marker completed1, termasuk toko kosong; jangan menebak
instalasi baru dari jumlah barang. Toko lama tanpa PIN tetap melalui setup
pengamanan yang sesuai, tanpa mengulang wizard penuh.

Wizard tujuh langkah mengikuti kontrak pengguna. Draft berisi konfigurasi non-
secret bertipe/bounded dan nomor revisi, disimpan dalam DB terenkripsi; bahasa
publik tersimpan terpisah dan controller tetap hidup saat ID/EN berganti.
Langkah selesai harus persisten sebelum pindah. PIN mentah, konfirmasi serta
recovery plaintext tidak boleh berada pada draft/log/export.

Langkah PIN menyiapkan verifier PBKDF2 dan salt dengan parameter lama dalam
staging terpisah, belum memberi capability. Recovery owner ditampilkan sekali
dan harus diakui tersimpan; bila proses mati sebelum pengakuan, PIN perlu
disiapkan ulang. Pola3 membutuhkan dua PIN berbeda; perubahan pola membatalkan
staging yang tidak lagi cocok. Gudang tetap direset oleh owner.

Selesai memvalidasi identitas, pola/stok, fitur serta staging/revisi, kemudian
menulis konfigurasi+credential+completed secara atomik hanya pada toko baru yang
belum mempunyai fakta bisnis. Kegagalan tidak menghasilkan completed sebagian.
Tidak memberi sesi Kelola otomatis. UI printer memakai layanan publik terbatas
yang ada; pilih/tes/lewati boleh gagal tanpa menghalangi wizard dan profil hanya
berubah sesudah Save. Tidak menyentuh clipboard, enrollment OS atau akun Google.

Kasir/runtime operasional dibuka setelah commit selesai. Jalur seed fixture
pengembangan harus menandai penyiapannya secara eksplisit; ini bukan alasan
mengubah marker/data Paket Eksplorasi Mandiri yang sudah terpasang.
