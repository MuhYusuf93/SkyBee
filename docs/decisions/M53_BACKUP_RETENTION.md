# G1 — retensi arsip cadangan

1 November 2026. Implementasi sedang dikerjakan; belum ada penghapusan arsip
pengguna atau reset `.skybee`. Acuan: [permintaan §10](M53_REQUEST.md).

Retensi hanya memelihara arsip milik aplikasi, toko, origin dan akun terkait.
Database aktif, transaksi lama, ekspor SAF dan folder umum tidak menjadi target.
Pipeline backup M5 tetap satu-satunya pemicu pembersihan: setelah artefak baru
selesai, diautentikasi dan diverifikasi. Mengaktifkan kebijakan tidak langsung
menghapus berkas. Kegagalan cleanup berbeda dari kegagalan backup.

Mode lokal: nonaktif (default) atau umur 90 hari, dengan minimum tiga cadangan
valid terbaru. Mode Drive: nonaktif, minimum tujuh (kebijakan jumlah lama), atau
umur 90 hari dengan minimum tujuh. Default lama tidak mengaktifkan kebijakan umur
baru. Preview pemilik menampilkan scope, jumlah dan perlindungan sebelum perubahan;
persetujuan usang setelah perubahan policy/account/database ditolak.

Arsip safety, pin, kandidat restore dan arsip yang provenance/umur/kunci
pemulihannya tidak dapat dibuktikan tetap dilindungi. Arsip lama tanpa bukti baru
tidak dianggap telah diverifikasi hanya dari flag `complete`. Minimum valid tidak
dipenuhi dengan berkas asing atau berkas rusak. Kunci tidak dibuat diam-diam untuk
membenarkan penghapusan.

Metadata kebijakan dan bukti tidak disimpan sebagai satu-satunya otoritas di
database aktif: restore/reset dapat memundurkannya. Implementasi memakai secret
privat per scope/arsip yang sudah dibungkus AES-GCM melalui AtomicFile native,
terikat nama alias. Ini menggantikan usulan HMAC/file metadata terpisah pada audit
privat: tidak menambah primitive kriptografi baru. Alias memakai hash pendek dan
payload tetap mengikat identitas lengkap, namespace, fingerprint kunci, checksum,
ukuran, waktu, pin/safety/kandidat. Metadata hilang/rusak/asing berarti dilindungi.
Metadata ini tidak memberi akses manajemen dan tidak diimpor dari backup portable.

Enumerasi Drive harus melewati semua halaman; halaman pertama penuh arsip
dilindungi tidak menyembunyikan arsip berikutnya. Penghapusan dibatasi per batch,
dengan enumerasi ulang sesudah mutasi dan pemeriksaan akun tepat sebelum DELETE.
Lokal hanya menghapus file arsip dan marker yang namanya diketahui di direktori
miliknya; direktori berisi file tak dikenal atau symlink tidak dibersihkan secara
rekursif. Kandidat restore diproteksi sebelum inspeksi/download dan perlindungannya
berlaku sampai dispose; crash meninggalkan perlindungan konservatif.

Status bukti dan batas native/Drive akan ditambahkan setelah implementasi dan
pemeriksaan selesai. Dokumen ini bukan klaim fitur sudah tersedia atau lulus tes.
