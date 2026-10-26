# Penyiapan baru M5.3 — keputusan implementasi berikutnya

Status27Oktober: source19 diimplementasikan; host acceptance13+regresi biaya10 PASS34s.
Native DV/Poco berikutnya; ini belum handoff M5.3.

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

Kasir/runtime operasional dibuka setelah commit selesai. Marker completed0 dengan credential operasional atau fakta bisnis dianggap
jalur legacy yang sudah dikonfigurasi: routing melewati wizard tanpa rewrite
marker/data. Deteksi tidak bergantung pada jumlah produk saja. Toko lama tanpa
PIN tetap menggunakan setup keamanan legacy saat membuka Kelola.


Detail implementasi: `onboarding_progress` berisi JSON whitelist bounded16KiB,
step/revision/readiness/nonce. `onboarding_credentials` hanya salt/verifier KDF
lama600k, bukan credential aktif. Opaque proof terikat issuer/DBgeneration/nonce/
revision; lock sesi biasa tidak membatalkan pengakuan recovery toko baru. Proses
mati sebelum ack perlu menyiapkan ulang; sesudah ack hash cukup untuk melanjutkan.
Mengubah pola membatalkan staging. Finish memvalidasi marker, tidak ada credential
operasional/fakta bisnis dan revision lagi, lalu menyimpan identitas/policy/PIN/
audit/completed dan menghapus staging dalam satu transaksi. Tidak grant Kelola.

Draft tidak memuat PIN/konfirmasi/recovery. PIN controller hanya RAM; inactive
menutup seluruh wizard dan reset visibility, kode recovery perlu reveal lagi.
ID/EN bertahan pada setiap langkah; controller serialisasi autosave, menjaga
input baru ketika SQL save lama selesai. Step selesai wajib flush sebelum pindah.
Kasir dan runtime worker/alert ditunda sampai commit penyiapan. Printer memakai
halaman publicAccess terbatas yang sudah ada, tidak auto-print/auto-save profil.
Validasi portable backup menolak staging tersisa; arsip toko selesai tidak boleh
menghidupkan wizard lain. G masih memerlukan acceptance portable menyeluruh.
