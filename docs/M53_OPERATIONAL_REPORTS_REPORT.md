# F3 — laporan stok, supplier, dan ekspor

30 Oktober — F3 FINAL cursor source696 frozen. Poco FINAL17PASS7:10/891hashlama sama/controlOff/trueexit0 sudahdikurasi.
Host19PASS1:38/analyze63,8s
bersih/format300/0/l10n1482/905/245/PIN106match. Kasus ledger valid cross-table
UUID reuse103 events lulus: original52000/reversal51000/net1000/sisa9000,
seluruh UI20/source100/CSV. Repro lama103→102 disimpan (0PASS1FAIL5s).
FULL17 DV aktif di `build/m53-operational-cursor-dv-20261030-20261030-032503` (session30419),
BackgroundPaused=true. Tunggu trueexit/finally/hash/controlOff sebelum source
edit; FULL17 perangkat lain berikutnya (DVawake exact wajib). Native17 baru
mencakup domain12/actual-menu IDEN UI2/sharedexport3. Native16 lama dan finalUI2
Poco1:29/889hashsama adalah interval historis, bukan proof reader cursor baru.
Manifest/checks cursor696 sudah disimpan. Setelah kedua17 ditutup, commit/push
F3 lalu G/H; jangan stop pada checkpoint. .skybee/ordinary belum update/reset/
reseed;100/50 hanya H setelah backup dan recovery lama verified. Tidak ada
pertanyaan tertunda. G audit privat m53-g-concrete-audit-20261030.md,
g-retention-contract-candidate.md dan g-reset-key-recovery-details.md.

30 Oktober — F3 FINAL cursor source696 frozen. Host19PASS1:38/analyze63,8s
bersih/format300/0/l10n1482/905/245/PIN106match. Kasus ledger valid cross-table
UUID reuse103 events lulus: original52000/reversal51000/net1000/sisa9000,
seluruh UI20/source100/CSV. Repro lama103→102 disimpan (0PASS1FAIL5s).
FULL17 Poco aktif di `build/m53-operational-cursor-poco-20261030-20261030-031348` (session68388),
BackgroundPaused=true. Tunggu trueexit/finally/hash/controlOff sebelum source
edit; FULL17 perangkat lain berikutnya (DVawake exact wajib). Native17 baru
mencakup domain12/actual-menu IDEN UI2/sharedexport3. Native16 lama dan finalUI2
Poco1:29/889hashsama adalah interval historis, bukan proof reader cursor baru.
Manifest/checks cursor696 sudah disimpan. Setelah kedua17 ditutup, commit/push
F3 lalu G/H; jangan stop pada checkpoint. .skybee/ordinary belum update/reset/
reseed;100/50 hanya H setelah backup dan recovery lama verified. Tidak ada
pertanyaan tertunda. G audit privat m53-g-concrete-audit-20261030.md,
g-retention-contract-candidate.md dan g-reset-key-recovery-details.md.

30 Oktober 2026. F2 `b0cfc60` sudah dipush. F3 schema37 source695 dibekukan
untuk native; **belum ditutup**. G/H tetap wajib. Data ordinary/.skybee belum
diupdate/reset/reseed. [Keputusan](decisions/M53_OPERATIONAL_REPORTS.md),
[panduan ID/EN](M53_OPERATIONAL_REPORTS_GUIDE.md).

## Perubahan

Service laporan khusus Pemilik membaca satu snapshot, maksimal100 source rows
per panggilan, lalu menjumlahkan BigInt. UI hanya satu halaman20 baris, dengan
filter/search, metadata capture dan seluruh-scope summary. Route tersembunyi/
terkunci tidak memicu refresh; request usang dibatalkan di batas halaman. Ekspor
CSV/XLSX memakai writer/tujuan yang sama dengan M5.1; uang/ID sebagai teks eksak,
snapshot scope/waktu/timezone/unit ikut diekspor. Artifact terikat generation
akses/database sehingga kunci/unlock/restore membatalkan pelepasan file lama.

Potensi stok menggunakan jumlah tracked layak × harga eceran dan bagian carrying
cost moving average terkait. Unknown tidak0, untracked999 tidak aset, tracked999
sah; expired/arsip/nonjual dipisahkan. Group kategori/supplier/toko deterministik
tanpa join riwayat penerimaan. Supplier berdasarkan master barang, bukan asal
batch. Selisih opname menggunakan snapshot posted yang tidak dihitung ulang
dengan stok hari ini. Tidak menciptakan omzet/HPP penjualan atau tuduhan pencurian.

Utang menggunakan proyeksi tagihan/kredit operasional yang sama. Saldo saat ini
dipisahkan dari pembayaran/refund periode, overdue bagian saldo terbuka, bucket
tanggal kalender toko1–7/8–30/>30, tanpa due date terpisah. Kredit tersedia, retur
fisik belum disetujui dan penerimaan belum direkonsiliasi tidak disamarkan sebagai
pengurang utang. Currency dipisahkan. Audit kas menautkan ledger/histori D.

## Pemeriksaan host

| Pemeriksaan | Bukti |
| --- | --- |
| Final gabungan |18 PASS,1:35; domain11, UI ID/EN2, ekspor lama4, pembatalan UI ekspor1 |
| Analyzer | Tidak ada issue,7,0s |
| Formatter |299 file,0 berubah pada pemeriksaan final |
| Lokalisasi |1480 key berpasangan/metadata sama,905 referensi statis,245 ID kebutuhan asli |
| PIN/KDF |106 upstream file dan lisensi APK tetap sama |
| Migrasi36→37 | Semua hash tabel lama sama; hanya lima indeks ditambahkan |
| Planner | Actual service queries memakai seek, tanpa temp sort pada group/keyset yang diuji |

[Manifest source](evidence/m53-20261026/operational-reports-source-sha256.json)
dan [pemeriksaan host](evidence/m53-20261026/operational-reports-host-checks.json)
menyimpan digest source/log, termasuk kegagalan terdahulu. Tidak menyimpan DB,
PIN, recovery key, APK atau isi data pribadi.

Kasus mencakup expiry campuran/alokasi biaya, unknown vs gratis, untracked999 vs
tracked999, USD2 dengan skala satu juta per minor, jumlah >15digit, leading0/
formula CSV/XLSX, ekspor melebihi UI20/source100, pembatalan/kunci/pembersihan
artifact, group129 produk/24 kategori dengan pagination, immutable opname sesudah
checkout, pembayaran sebagian/reversal/bucket due, retur pending/approval/
allocation/refund/reversal tanpa perubahan sale/HPP, role Pemilik/Gudang/terkunci,
dan ID/EN320px/text2 termasuk kunci/unlock serta ekspor scope.

## Native terisolasi — sedang berjalan

Target `integration_test/m53_operational_reports_test.dart`:16 kasus koheren
(domain11/UI2/ekspor lama3), SQLCipher, background paused, wrapper
`tools/test_m51_android.ps1` → `tools/test_android.ps1`. Tidak ada bare integration
atau uninstall/downgrade/reset package operasional.

| Perangkat | Status |
| --- | --- |
| Poco F6 `7f0edea0` awal |15PASS/1FAIL5:21,851 hash lama sama/controlOff/trueexit1; mock fixture menghalangi native unlock |
| Poco F6 review |16PASS5:25/869 hash lama sama/controlOff/trueexit0, review source695 |
| DV8910 `.101:5555` |16PASS7:09/927 hash lama sama/awake exact/controlOff/trueexit0, review source695 |

Tunggu trueexit/finally/hash data lama/controlOff dan DV awake exact; passing case
sebelum finally bukan preservation proof. Source tidak boleh berubah selama run.
Input UI dan tujuan ekspor sintetis; tidak mengklaim keyboard OEM, touch fisik,
kertas/scanner atau penulisan dokumen SAF sungguhan. Waktu native bukan benchmark
ARM32 terisolasi dan tidak menetapkan CCTV sebagai penyebab perlambatan.

## Kegagalan yang diperbaiki

Fixture ekspor M5.1 lama belum memasukkan telepon pelanggan yang kini wajib;
hanya fixture diperbaiki. UI awal memakai header lazy di luar cache sebagai
saksi readiness; helper reveal diperbaiki. Test menemukan refresh commit ketika
route terkunci dapat membatalkan autentikasi PIN yang sedang commit; runtime
sekarang memeriksa Pemilik/route aktif, lalu refresh saat kembali. Route-return
`pumpAndSettle` tidak memberi IO nyata pada DB/indikator; diganti bounded readiness.
ARB baru sempat memakai snake_case dan switch multiline lama tertinggal sesudah
rename; kini camelCase + metadata berpasangan lulus audit. Final18 lulus.

Index saja menghilangkan temp sort, tetapi row-value expression keyset masih
SCAN. Equality-group+ID-range dan next-group-range membuktikan SEARCH pada query
yang benar-benar dipakai service. Pada batas group maksimal dua source read
mengisi100 baris, bukan banyak panggilan kecil per barang.

## Berikutnya

Selesaikan dua interval native dan kurasi, tutup F3/commit/push, kemudian G
retensi/reset/portable restore serta H handoff. Pengosongan `.skybee` dan contoh
100 produk/50 transaksi hanya H sesudah backup terenkripsi dan material
pemulihan data lama terverifikasi; bukan bagian pengujian F3 ini.

Review native pertama mengubah hanya test/support/m51_report_export_suite.dart:
mock dinonaktifkan saat PIN/snapshot native nyata, lalu dipasang lagi untuk
penolakan tujuan ekspor. Assertions sama; host review4PASS23s. Produksi dan
seluruh fixture F3 lain identik. Manifest review terpisah dari manifest awal;
jumlah native16 karena uji presisi XLSX tambahan hanya di entry host.

Review fixture host4PASS23s/analyzer155,2s bersih;
[evidence review](evidence/m53-20261026/operational-reports-review-checks.json),
[native Poco review](evidence/m53-20261026/operational-reports-poco.json), dan
[interval awal gagal](evidence/m53-20261026/operational-reports-poco-initial.json)
berdiri sendiri. Review UI filter setelah DV tetap harus selesai sebelum F3
ditutup: label kosong harus Semua, dan filter tersembunyi tidak masuk scope
ekspor sebagai filter yang diterapkan. Tidak ada perubahan SQL/domain direncanakan.

Full16 kedua perangkat sudah selesai, DV awake pulih persis;
[evidence DV](evidence/m53-20261026/operational-reports-dv.json). Review UI final
masih berjalan: Semua vs pilihan tertentu, arsip supplier dan scope filter aktif.
Navigasi melalui ReportsScreen asli menemukan refresh parent saat PIN commit
yang merevoke unlock; host mereproduksi0PASS1FAIL11s, sesudah guard2PASS22s.
Fixture final memakai utang riil supplier arsip2000/no due. SQL/domain/math tidak
berubah. Host/analyze/focused UI2 native final harus ditutup sebelum F3 commit.

Final UI host2PASS22s/analyze10,3s bersih/format300/1/l10n1482/905/245/PIN106.
[Manifest final filter696](evidence/m53-20261026/operational-reports-filter-source-sha256.json)
dan [checks final filter](evidence/m53-20261026/operational-reports-filter-checks.json)
memuat11 file delta, tanpa perubahan SQL/domain/math. Final UI menguji menu asli
ReportsScreen serta utang riil supplier arsip2000/no due. Focused UI2 Poco RUNNING
di build/m53-operational-filter-poco-20261030-20261030-023430 (session43863); DV2 berikutnya. Full16 snapshot sebelumnya
dan finalUI2 adalah interval berbeda, bukan klaim satu fullrun source696.

**Review cursor setelah interval di atas:** finalUI2 Poco retry PASS1:29/889
hashsama/controlOff/trueexit0. Konflik expect di callback pump diperbaiki menjadi
expectSync tanpa perubahan produksi/asersi; initial0PASS2FAIL1:11/887hashsama
tersimpan. Kemudian kasus ledger legacy valid menemukan cursor UNION kehilangan
satu dari103 kejadian ketika ID sama lintas tabel dan memotong batas100. Repro
0PASS1FAIL5s; sesudah (kind,id) fixedcase1PASS5s:103 events,52000 original/51000
reversal/net1000/sisa9000, seluruh UI20 dan CSV. Reader berubah sesudah full16
lama, sehingga FULL17 source cursor baru wajib kedua perangkat sebelum F3 tutup;
focusedDVUI2 saja tidak cukup dan digantikan full17. Host final19 sedang berjalan.
