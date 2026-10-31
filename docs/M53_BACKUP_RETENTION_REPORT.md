# G1 — retensi arsip cadangan

1 November2026. **Software G1 selesai**, schema37/source709 review. G2/G3/H masih
wajib; `.skybee`/ordinary belum diperbarui, direset atau diisi ulang.
[Keputusan](decisions/M53_BACKUP_RETENTION.md), [panduan ID/EN](M53_BACKUP_RETENTION_GUIDE.md).

## Perilaku

Pipeline M5 dan lease backup-work tetap satu. Lokal default Off, pilihan umur90hari
dengan floor3 valid terbaru. Drive menawarkan Off/jumlah7/umur90hari+floor7;
kebijakan umur baru tidak diaktifkan diam-diam. Arsip legacy tanpa proof tetap
dilindungi. Preview pemilik memuat scope dan jumlah, terikat policy revision,
isi metadata, akun dan grant/database generation; aktivasi tidak menghapus arsip.
Cleanup hanya setelah backup baru berhasil/tervalidasi, maksimal30 arsip per siklus.

Keystore-wrapped AtomicFile metadata di luar DB mengikat scope, SHA/ukuran/umur,
fingerprint recovery dan proteksi; restore/reset DB tidak memundurkan pin/policy.
Safety, pin, sumber upload tertunda, kandidat restore serta metadata/umur/kunci
yang tidak dapat diverifikasi dilindungi. Floor valid tidak diisi file rusak atau
asing. Protected first100 Drive tidak menyembunyikan halaman berikutnya.
Setiap request menjaga akun; metadata dicek ulang sebelum DELETE, tidak memakai
page token lama setelah mutasi. Lokal memeriksa canonical owned directory dan
allowlist file; tidak recursive-delete direktori dengan file asing/symlink.

Restore selection/inspection/export memegang perlindungan sampai disposal.
Kandidat yang tertinggal akibat crash konservatif tetap dilindungi. Katalog
recovery memakai work lease, dengan jalur sudah-held saat restore untuk menghindari
reentry. Pending-upload path set dibaca sekali per pass, bukan SQL per arsip.
Cleanup/status-write failure tidak membalikkan upload sukses atau memicu upload
ulang; status lokal/Drive terpisah. Active DB, transaksi lama dan ekspor SAF bukan
target. Tidak ada worker retention kedua, VACUUM atau ledger keuangan baru.

UI actual-menu ID/EN320px/text2 mencakup preview, save dan dirty Back ketika
terkunci. Draft route-owned; barcode/receipt/sale/stok/HPP tidak ditulis cleanup.
AppServices dapat menginjeksi backupPlatform fixture; policy/session/workGate Drive
mengikuti BackupService sehingga tidak menyentuh secret manual fixture lain.

## Bukti

| Pemeriksaan | Hasil |
| --- | --- |
| Host final |42PASS56s: planner/metadata12, HTTP6, local service/filesystem7, pipeline fault2, UI2, transport lama11, portable metadata2 |
| Analyzer |13,8s bersih; sesudah satu fixture native phone berubah85,7s bersih |
| Formatter/l10n/PIN |613/0;1512 paired key/926 referensi/245 ID asli;106 upstream+lisensi sama |
| Poco review |22PASS03:52;946hash lama sama;controlOff/trueexit0 |
| DV review |22PASS06:07;980hash lama sama;awake exact/controlOff/trueexit0 |

Native22 = planner12/HTTP6 + portable cross-key nyata1 + actual backup-menu UI2 +
pipeline crypto/wrapped-proof/symlink/pending-upload/minimum1. Portable regression
menguji source/target SQLCipher key berbeda dan restore/failure/consistency yang
sudah ada. Pipeline baru membuat arsip terenkripsi melalui writer asli, menjaga
penjualan/HPP, menguji pin dan lease, symlink/file asing, metadata proof rusak,
kunci/proteksi, cleanup exact dan reopen proof. Jam umur sintetis, bukan natural90hari.

[Host checks](evidence/m53-20261026/backup-retention-host-checks.json),
[manifest awal](evidence/m53-20261026/backup-retention-source-sha256.json),
[manifest review](evidence/m53-20261026/backup-retention-review-source-sha256.json),
[review checks](evidence/m53-20261026/backup-retention-review-checks.json),
[Poco](evidence/m53-20261026/backup-retention-poco.json),
[DV](evidence/m53-20261026/backup-retention-dv.json).

Produksi/host-test sama antara host42 dan final native. Review hanya menambah
nomor dummy pada fixture portable lama. Semua native lewat wrapper package
`.integration`, background paused/--no-uninstall, tanpa downgrade/reset package lain.

## Kegagalan dan perbaikan

Review host mereproduksi1PASS2FAIL9s: sumber upload pending belum dilindungi;
gagal menyimpan error cleanup mengubah upload sukses menjadi gagal. Keduanya
diperbaiki dan tercakup final42, termasuk retry operation tidak mengunggah ulang.
Retest2PASS1FAIL10s menyisakan ekspektasi fixture salah (satu arsip tua, bukan dua);
batas90hari produksi tetap. Host awal39PASS1:02 tersimpan sebelum review ini.

UI awal menunggu lazy child, memakai gate Android pada host, memilih teks menu
yang belum mengubah draft atau mengasersi dialog sebelum selesai tutup. Helper
mereveal hit target, memberi IO nyata, memeriksa nilai draft/dirty registry dan
menunggu route. Gate Drive kini gate BackupService. Callback savePolicy tidak
bertabrakan dengan State.activate. Log gagal privat/digest dipertahankan.

Native Poco awal21PASS1FAIL2:36/910hash sama/controlOff/trueexit1:
fixture portable lama tidak mengisi nomor anggota wajib. Satu fixture ditambah
nomor PUBLIC dummy08000000001, tidak melemahkan validasi. Full22 Poco+DV review
kemudian PASS pada source sama. [Bukti gagal](evidence/m53-20261026/backup-retention-poco-initial.json).

## Batas dan kelanjutan

HTTP tiruan bukan Drive nyata; tidak ada cloud cleanup akun pengguna. Input widget
sintetis bukan sentuhan/OEM. Tidak mengklaim uji power-cut atau menunggu90hari.
G2 akan menambah rotasi key/jurnal dan fsync parent untuk primitive secret native,
dengan regresi archive/proof terkait. Belum ada runtime ResetToko atau H reset100/50.
Tidak ada raw DB/key/PIN/token/log pribadi/APK pada evidence Git. Lanjut G2/G3/H;
M5.4/M5.5/M6 tetap di luar tahap aktif.
