# F3 — laporan stok, supplier, dan ekspor

1 November 2026. **Software F3 selesai**, schema37/source696. Final coherent
host19 dan native17 di kedua perangkat memakai source yang sama. G/H masih
wajib; `.skybee`/ordinary belum diupdate/reset/reseed. [Keputusan](decisions/M53_OPERATIONAL_REPORTS.md),
[panduan ID/EN](M53_OPERATIONAL_REPORTS_GUIDE.md).

## Perubahan dan batas perhitungan

Pemilik mendapatkan potensi nilai jual stok dan estimasi laba kotor (produk,
kategori, supplier master, toko), selisih opname posted, utang supplier saat ini,
pembayaran/refund periode, kredit tersedia, penerimaan belum direkonsiliasi dan
retur menunggu persetujuan. Histori dan kebijakan audit kas D ditautkan tanpa
ledger duplikat. Picker readonly mencakup arsip, label kosong berarti Semua,
filter tersembunyi tidak masuk scope ekspor. Route terkunci/tersembunyi tidak
menjalankan refresh baru; parent laporan tidak merevoke verifikasi PIN.

Potensi memakai tracked saleable × harga eceran, dikurangi bagian moving-average
carrying cost terkait; biaya unknown bukan0. Untracked999 bukan aset, tracked999
sah. Arsip/expired/nonjual dan cakupan biaya belum lengkap terpisah. Group supplier
berdasarkan data barang, bukan provenance batch. Ini bukan prediksi atau laba
bersih. Selisih opname hanya snapshot immutable, bukan saldo hari ini atau bukti
pencurian. Pembayaran dan kredit tidak menghitung ulang omzet/HPP historis.

Utang berlabel **saat ini**, tanpa picker saldo historis. Overdue bagian saldo
terbuka, bucket kalender toko1–7/8–30/>30, tanpa due date terpisah. Pembayaran asli
memakai paid_date operator, reversal memakai tanggal pencatatan dalam timezone
toko. Refund memakai event_date operator. Currency, bank/laci/dana pemilik dan
retur fisik belum disetujui dipisahkan.

UI menyimpan satu halaman20, service membaca source100 dan menjumlahkan BigInt
seluruh scope dalam satu snapshot. Ekspor CSV/XLSX memakai engine/tujuan lama,
uang/ID sebagai teks eksak, formula dinetralkan, metadata scope/capture/unit ikut.
Artifact terikat grant/database generation. Cursor UNION memakai jenis kejadian
dan ID tabel, sehingga UUID yang sama lintas tabel tidak menggandakan/menghilangkan
fakta. Group mentah kursor tidak mengagregasikan kejadian keuangan.

Schema37 hanya menambah lima indeks; hash setiap tabel lama sama pada migrasi
36→37. Planner actual query membuktikan seek tanpa temp sort pada group/keyset
persediaan/tagihan/retur yang diuji; equality-group/ID-range dan next-group-range
mengisi maksimal100 baris, bukan satu panggilan per barang. Tidak ada klaim
benchmark ARM32 terisolasi atau penetapan CCTV sebagai penyebab perlambatan.

## Bukti final pada satu source

| Pemeriksaan | Hasil |
| --- | --- |
| Host |19PASS01:38: domain12/UI2/ekspor lama4/pembatalan ekspor UI1 |
| Analyzer | No issues, 63.8s |
| Formatter / l10n / PIN |300/0;1482 key,905 referensi,245 ID kebutuhan asli;106 upstream+lisensi sama |
| Poco F6 |17PASS07:10;891 hash lama sama;controlOff/trueexit0 |
| DV8910 |17PASS09:42;961 hash lama sama;awake exact/controlOff/trueexit0 |

Native17 = domain12, actual-menu ID/EN320px/text2 UI2, shared legacy export3.
Uji presisi XLSX tambahan dan UI pembatalan tujuan berada di host entry, tidak
dihitung sebagai kasus native. Semua native melalui wrapper terisolasi,
SQLCipher/background paused/verified `.integration` APK/`--no-uninstall`;
tidak ada reset/downgrade package lain.

[Manifest final](evidence/m53-20261026/operational-reports-cursor-source-sha256.json),
[host final](evidence/m53-20261026/operational-reports-cursor-checks.json),
[Poco final](evidence/m53-20261026/operational-reports-cursor-poco.json),
[DV final](evidence/m53-20261026/operational-reports-cursor-dv.json).

Kasus mencakup expiry campuran, alokasi carrying pool, unknown/gratis,
untracked999/tracked999, USD2 (1e6 per MINOR), nilai >15digit, leading0/formula,
scope melebihi UI20/source100, pembatalan/kunci/partial cleanup,129 produk/24group,
opname setelah checkout nyata, payment/reversal/due buckets, kredit/retur/refund
tanpa perubahan sale/HPP, role denial, archived debt2000/noDue, actual navigation
dan owner re-unlock. Ledger valid52 pembayaran/51 reversal dengan UUID sama
lintas tabel menghasilkan103 kejadian,52000 original/51000 reversal/net1000/
sisa9000,103 identitas unik di seluruh halaman dan CSV.

## Interval historis dan kegagalan yang diselesaikan

Source awal695 host18PASS1:35, nativePoco15PASS1mockFAIL5:21/851hashsama. Fixture
mock dinonaktifkan ketika PIN/crypto native nyata berjalan; host review4PASS23s
dan full16 Poco5:25/869hashsama +DV7:09/927hashsama/awakeexact. UI final696 awal
nativePoco0PASS2FAIL1:11/887hashsama karena guarded expect di callback pump;
expectSync mempertahankan asersi, host2PASS22s/analyze106,5s dan PocoUI2PASS1:29/
889hashsama. Semua interval controlOff dan trueexit sudah ditutup.

UI juga menemukan parent laporan merevoke PIN verification lewat refresh commit
locked; actual-menu repro0PASS1FAIL11s, diperbaiki dan dicakup final17. Kasus uang
valid cross-table UUID mereproduksi103→102 (host0PASS1FAIL5s); fixedcase1PASS5s,
kemudian coherent final19/17 di atas. Fixture telepon pelanggan lama mengikuti
aturan wajib baru. ARB mengikuti camelCase/metadata berpasangan; helper reveal/
real-IO readiness menghindari lazy header/pumpAndSettle false failures.

Metadata lama/source/log digest tetap tersimpan di prefix operational-reports-*;
tidak ditimpa atau dijumlahkan sebagai kasus unik final. Final17 supersedes
interval16/UI2 untuk semua source terbaru. Tidak ada DB/key/PIN/APK/log mentah
atau data pribadi di evidence Git.

Input UI dan tujuan ekspor sintetis; tidak mengklaim keyboard OEM/touch fisik,
kertas/scanner atau penulisan dokumen SAF sungguhan. Setelah commit/push F3,
lanjut G retensi/reset/portable restore dan H handoff.100/50 serta first-run
`.skybee` hanya H setelah backup/recovery data lama terverifikasi.

Run DV 30 Oktober terputus setelah +13 tanpa hasil akhir/finally. Pada resume,
943 hash fixture lama masih sama; pengaturan awake dipulihkan persis. Status
run asli tetap INTERRUPTED_UNVERIFIED, bukan PASS. Percobaan resume pertama
ditolak guard sebelum build/install karena flag background-paused belum diberikan;
isolasi hash sama dan awake dipulihkan. Run terpisah dengan flag yang benar pada
1 November menghasilkan final17PASS9:42/961hashsama/controlOff/trueexit0 di atas.
[Bukti run terputus](evidence/m53-20261026/operational-reports-cursor-dv-interrupted.json).
