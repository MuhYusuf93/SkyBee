# E2 — sesi opname fisik

Opname schema29 selesai untuk scope E2: host34PASS46s, Poco15PASS6:15 dan
DV15PASS7:39 pada source588 yang sama. Seluruh699/777 protected entries lama
pada masing-masing interval native memiliki hash identik; kontrol otomatis
berhenti dan awake DV dipulihkan serta dibaca ulang tepat. Analyzer bersih6,0s,
format492/0, bahasa1045/710/245 dan PIN106match.
[Bukti DV](evidence/m53-20261026/stocktake-dv.json),
[Poco](evidence/m53-20261026/stocktake-poco.json),
[host/audit](evidence/m53-20261026/stocktake-host-checks.json).
Build fixture terverifikasi `.integration`; bukan pembaruan aplikasi operasional.
Tidak ada reset/reseed/downgrade `.skybee`, dan tidak ada klaim kamera fisik,
OEM IME atau sentuhan ADB. E3 supplier, F/G/H tetap aktif; bukan handoff akhir.
Catatan di bawah adalah riwayat verifikasi hingga penutupan ini.

Poco native15PASS6:15 pada source588: seluruh699 pre-existing protected entries
memiliki hash sama sebelum/sesudah, kontrol otomatis berakhir, tanpa reset atau
downgrade. [Bukti Poco](evidence/m53-20261026/stocktake-poco.json),
[host34 dan audit](evidence/m53-20261026/stocktake-host-checks.json),
[manifest source](evidence/m53-20261026/stocktake-source-sha256.json).
Saat catatan Poco ini dibuat, DV masih berjalan. H tetap belum selesai.

29 Oktober00:10: final host34PASS46s (domain11/UI4/hint6/receipt8/stockguard3/
backupmetadata2), analyzer bersih6,0s, formatter492/0, bahasa1045/710/245 dan
PIN106match. Source588 frozen/verified; native15 Poco aktif danDV berikut.
Paragraf proses lama di bawah dipertahankan sebagai riwayat, bukan hasil akhir.

Source0.5.2+12/schema29 setelah receipt `9c6c66a`. Implementasi draft/count/
batch/undo/recount/atomic posting dan antarmuka sudah ditulis; verifikasi akhir
telah selesai untuk scope E2. Ini bukan handoff akhir M5.3. E3 supplier dan F/G/H tetap aktif.
[Keputusan dan batas](decisions/M53_STOCKTAKE.md).

Opname dapat dimulai dari gudang atau tombol stok opname pada detail produk.
Draft menyimpan baseline master/stok terpisah, NULL vs0, input kemasan, seluruh
batch fisik, coverage biaya dan total nilai pool kosong. Scan ambigu tidak
menebak batch. UI memisahkan hitungan dari mutasi stok; finalisasi memerlukan
review/alasan dan menolak baseline yang berubah. Snapshot posted immutable,
retry idempotent dan kegagalan lintasproduk rollback atomik.

Host awal domain7PASS/1FAIL karena fixture policy revision lama, lalu8PASS
tetapi invocation juga membawa path test salah dan exit keseluruhan FAIL.
Setelah backup/migration tests ditambah, domain10+hint6=16PASS31s. UI awal
compile gagal (`AppServices.dispose` tidak ada), lalu perbaikan helper label
Stay/hit-test/busy/lazy menghasilkan4PASS29s untuk ID/EN320px/text2. Uji UI
mencakup dirty Back terkunci, countNULL/0/Undo/recount/final, expiry lampau,
pack24 dan total10000 tanpa receipt. Ini input sintetis, bukan kamera fisik.

Regresi gabungan33:32PASS/1UI-helperFAIL38s; helper masih memakai `.first` pada
finder yang ter-evict selama menunggu IO. Helper diperbaiki agar reveal dan
memeriksa tombol aktif pada tiap iterasi bounded. Tambahan uji peran Gudang
menguji capability dan aktor snapshot. Retest terarah/gabungan masih berlangsung;
hasil akhir/native dicatat setelah proses benar-benar keluar.

Setelah review perbaris, regresi34 berikutnya32PASS2UIFAIL karena pesan konflik
panjang membesarkan satu target kartu melewati viewport. Kartu kini memakai
caption pendek dan penjelasan lengkap di halaman. Beberapa retest UI berikut
mengungkap dua kesalahan harness: menunggu child scan yang belum dibangun dan
mengharapkan scan1 setelah actualreceipt menambah batch kedua. Uji kini memilih
observationId secara eksplisit, mengisi0/1 per batch dan mengulang reveal ketika
reload menggeser child keluar viewport. Hasil final34PASS46s mengulang semua
enam file, termasuk kedua bahasa serta peran Gudang yang eksplisit.

Audit bahasa sudah1044key ID/EN,709referensi statis,245 requirement asli.
PIN106upstream/license/archive tetap cocok. Analyzer UI terakhir bersih6,3s;
analyzer dan formatter final sesudah label/harness terakhir belum ditutup.
Native29 belum dijalankan pada saat paragraf ini ditulis. Kedua perangkat
terdeteksi lagi28Oktober23:51; setiap run berikut wajib hash baseline baru.
.skybee tidak diupdate/reset/reseed dalam implementasi dan host tests ini.
