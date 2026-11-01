# G3 — Backup portable dan resume snapshot

1 November 2026. Schema37, source732. G2B sudah push `e0a5eb7`.
**Software G3 selesai**, native kedua perangkat ditutup pada source identik.
H regresi/build/handoff masih wajib.

## Perubahan

Retry Drive memakai snapshot tertutup yang sama. Path UUID/root/no-follow,
identitas toko, manifest dan SHA asli harus cocok dengan creation receipt dalam
SQL terenkripsi. File yang hilang, berubah, receipt hilang atau metadata parsial
menjadi kegagalan terminal dengan pesan ID/EN. Tombol Backup Sekarang membuat
operasi baru secara eksplisit; retry tidak diam-diam mengambil snapshot baru.

Sebelum transport, arsip resume diautentikasi native dengan recovery yang sudah
tersimpan, diekstrak ke staging privat, diperiksa hash anggota, SQLCipher/schema,
integritas, migrasi staging dan seluruh invariant bisnis. Arsip asli tidak
berubah. Sesudah pemeriksaan, digest asli diperiksa ulang. Antrean mengikat
grant, generation DB dan akun/consent saat permintaan dibuat; tidak mengadopsi
unlock, toko atau akun berikutnya. Callback terlambat tidak menulis status ke
database pengganti. HTTP fixture host mengganti autentikasi native saja;
provenance/path/hash tetap wajib. Native menguji autentikasi sebenarnya.

Restore mempertahankan fakta bisnis, preferensi dan verifier PIN; installation
pointer baru, grant terkunci, local Drive consent dicabut, antrean/profil printer
dibersihkan. Cache admission/pengjadwalan supplier dinonaktifkan; delivery target
dan fingerprint dipertahankan agar refresh tidak menggandakan pemberitahuan.
Struk wajib, witness konfirmasi/exception dan profil QR tetap portable meskipun
printer perangkat harus dipilih kembali.

## Temuan dan perbaikan

Repro source sebelum G3 membuktikan arsip resume yang byte-nya diubah masih bisa
menyelesaikan PATCH metadata transport. Perbaikan mengikatnya pada creation SHA,
kemudian authentic native/business validation. Uji menolak perubahan, file hilang,
metadata parsial, receipt hilang, auth gagal, perubahan selama auth, serta antrean
setelah grant/DB/account berubah. Tidak ada upload write atau recapture pada
sumber invalid. Regresi memastikan upload sukses/idempotent tidak berubah gagal
karena cleanup retensi gagal.

Fixture lintas A–F menemukan `backupReceiptDraftInvalid` pada retur supplier sah.
Validator penerimaan lama mensyaratkan receipt_id pada semua operation source-item;
retur/reversal memang bukan penerimaan baru dan menyimpan null receipt_id.
Perbaikan menerima bentuk tersebut hanya melalui witness immutable retur atau
reversal yang mengikat operation, source item, produk dan penerimaan asal.
Supplier validator tetap memeriksa quantity, biaya, snapshot dan reversal chain.
Uji tambahan menolak orphan adjustment yang hanya meniru pointer source-item.
Tidak ada perubahan skema atau penulisan ulang angka historis.

## Bukti

- Host gabungan 11 file: **61 PASS, 00:56**, timeout eksplisit2m. Run awal
  **60 PASS/1 timeout30s, 01:08** disimpan; kegagalan batas waktu fixture dengan
  KDF/role terpisah, tanpa assertion bisnis gagal. Focus sebelumnya28PASS00:46.
- Analyzer final **bersih113,9s**. Review sebelumnya bersih77,5s; initial compile
  import sqflite dan enum fixture diperbaiki, style/ManagementRole import juga
  diperbaiki sebelum native. Format fokus13file, lalu delta2file0changed.
- Lokalisasi **1532** key ID/EN, **939** static reference, **245** original IDs;
  checksum PIN **106** upstream file unchanged dan lisensi cocok.
- Poco native **3 PASS, 06:01**, seluruh **1310** entry terlindungi lama hash sama,
  controlOff, true exit0. [Bukti Poco](evidence/m53-20261026/portable-poco.json).
- DV native **3 PASS, 08:08**, seluruh **1212** entry terlindungi lama hash sama,
  awake dipulihkan/dibaca ulang tepat, controlOff, true exit0.
  [Bukti DV](evidence/m53-20261026/portable-dv.json).
- [Host checks](evidence/m53-20261026/portable-host-checks.json).
- [Source732](evidence/m53-20261026/portable-initial-source-sha256.json).

Dua fixture real-writer mencakup partial stock serta stock-all/task3/Gudang:
biaya unknown/free/known, expiry campuran, snapshot penjualan/HPP, pelanggan,
kas fisik/jurnal/closure, opname, receipt draft, tagihan/cicilan/retur/kredit/
refund/reversal, kunjungan/reminder, cashier credential, QR profile dan receipt
requirement/confirmation/exception/pending gate. Seluruh fingerprint tabel
non-local dibandingkan sebelum/sesudah restore dengan key sumber/target berbeda;
config lokal yang berubah diperiksa terpisah. Wrong code, corrupt archive,
cancel/dispose, confirmation ditolak, grant dan dua pembukaan diperiksa.

Kasus schema14 memakai database schema14 asli berisi sale/debt dan kontak legacy
invalid; native format1 packing dimodelkan sebagai produsen lama. Itu bukan
arsip yang dihasilkan APK lama. Migrasi hanya pada staging, byte arsip asli tetap,
semua kolom lama sale/item/credential dan kontak raw tetap, status incomplete
jujur, reconcile konsisten.

## Batas dan langkah berikutnya

Transport HTTP, printer, paper acknowledgement, reminder sink dan biometric
dependency bersifat sintetis. Native arsip/SQLCipher/filesystem adalah nyata;
tidak mengklaim Drive cloud, enrollment biometrik OS, cetakan/scanner fisik,
notifikasi fisik, tunggu72jam/90hari alami atau power-cut nyata.

Tidak ada update/reset/reseed `.skybee` atau ordinary. Sesudah commit/push G3,
lanjut H regresi/build/handoff dan perlindungan eksternal sebelum reset yang
secara khusus diminta pengguna. Draft writer100/50 privat sudah3PASS00:40 untuk
stock off/partial/all; aktivasi atomic dengan Finish wizard dan admin backup/reset
belum dipasang. Genuine wizard harus tetap kosong sampai Finish; 100/50 aktif
bersamaan dengan setup yang dipilih pengguna, bukan dengan melemahkan guard.
