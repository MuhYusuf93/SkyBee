# Retensi cadangan — panduan ID/EN

## Indonesia

Buka **Cadangan → Bersihkan cadangan lama** dengan akses Pemilik. Buat cadangan
lokal pertama dan simpan kode pemulihan terlebih dahulu agar scope toko/origin
tersedia. Drive tetap opsional; hubungkan akun di halaman Cadangan bila digunakan.

Pilih kebijakan untuk lokal dan Drive secara terpisah:

- **Nonaktif**: tidak ada pembersihan arsip otomatis pada tujuan tersebut.
- **Umur lebih dari 90 hari**: hanya arsip yang dapat diverifikasi dan lebih tua
  dari batas itu yang memenuhi syarat. Minimum tiga versi valid terbaru tetap
  disimpan untuk lokal, tujuh untuk Drive.
- **Simpan minimum 7 versi**: kebijakan jumlah Drive sebelumnya. Ini default
  Drive; mode umur baru tidak diaktifkan diam-diam untuk pengguna lama. Arsip
  lama yang belum mempunyai bukti pemulihan baru tetap dilindungi.

Tekan **Tinjau kebijakan dan jumlah**, baca jumlah serta ID toko/origin/akun,
kemudian **Simpan kebijakan ini**. Penyimpanan kebijakan tidak menghapus arsip.
Pembersihan baru berlangsung setelah backup berikutnya benar-benar berhasil dan
tervalidasi, maksimum 30 arsip per siklus. Preview yang berubah atau kehilangan
akses harus ditinjau kembali. Back saat draft berubah tetap meminta konfirmasi,
termasuk saat akses sedang terkunci.

Pada daftar arsip, centang **Lindungi arsip dari pembersihan** untuk menyimpan
arsip yang sudah diverifikasi. Safety, sumber upload yang belum selesai, kandidat
restore aktif, kunci tidak tersedia, umur/metadata tidak terpercaya dan arsip
lama tanpa bukti yang cukup otomatis dilindungi. Checkbox yang tidak dapat diubah
bukan izin menghapusnya. Melepas pin tidak langsung menghapus arsip dan tidak
membatalkan perlindungan lain atau minimum versi.

Status pembersihan lokal terpisah dari riwayat Drive. Pesan pembersihan ditunda
tidak membatalkan backup yang telah berhasil. Database aktif, penjualan lama,
ekspor SAF dan berkas umum tidak menjadi target. Fitur ini berbeda dari VACUUM
dan bukan sinkronisasi antarperangkat. Simpan kode pemulihan portable di luar
aplikasi; daftar arsip bukan jaminan pemulihan tanpa kode yang sesuai.

## English

Open **Backups → Clean up old backups** with Owner access. Create the first local
backup and save its recovery code first. Drive is optional; connect an account
on the backup page when needed.

Local cleanup defaults to **Off**. Drive keeps its previous **Keep at least 7
versions** policy; the new age policy is not silently enabled. **Older than 90
days** retains at least the 3 newest valid local backups or 7 Drive backups.
Legacy archives without sufficient recovery proof remain protected.

Select a policy, preview its scope and counts, then save it explicitly. Saving
does not delete archives. Cleanup follows the next successful, validated backup,
up to 30 archives per cycle. Changed or expired previews require a new review.
Unsaved changes still prompt on Back, including when management is locked.

Use **Protect archive from cleanup** on verified entries to pin them. Safety
archives, unfinished upload sources, active restore candidates, unavailable keys,
untrusted ages/metadata and unverified legacy archives remain protected. A
disabled checkbox does not authorize deletion. Unpinning never deletes an archive
immediately or overrides another protection or the minimum valid version floor.

Local cleanup and Drive history have separate status. Deferred cleanup does not
invalidate a completed backup. The active database, historical sales, SAF exports
and general files are outside this feature. This is neither VACUUM nor device
sync. Keep the portable recovery code outside the app; archive availability alone
does not prove recoverability without the matching code.
