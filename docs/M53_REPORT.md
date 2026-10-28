# Laporan M5.3 — checkpoint fondasi dan akses, belum handoff akhir

Laporan ini menyimpan fondasi schema16 historis. Progres aktif sudah source26;
lihat [checkpoint terkini](M53_CHECKPOINT.md), [browse](M53_WAREHOUSE_REPORT.md)
dan [editor penerimaan](M53_RECEIPT_REPORT.md). Sejak28Oktober14:00 Poco dipakai
pribadi; [checkpoint Poco](M53_POCO_CHECKPOINT.md) tersimpan, delta/handoff
pemasangan berikutnya ditunda. Host dan DV tetap tersedia. Seluruh E–H aktif.

26 Oktober 2026. Kontrak aktif [M53_REQUEST](decisions/M53_REQUEST.md),
klarifikasi [Back terkunci](decisions/M53_LOCKED_BACK.md), kelanjutan pada
[checkpoint](M53_CHECKPOINT.md). Source development **0.5.2+12/schema16**;
Paket Eksplorasi Mandiri tetap **0.5.2+12/schema14**. Belum diupdate/reseed/reset.

## Implementasi yang tersedia

Migrasi15–16 aditif mempertahankan kolom/row lama. Preferensi tampilan tidak
menghapus grosir/kemasan/barcode/expiry; mode toko ditinjau terhadap seluruh
katalog dan konflik ditolak tanpa mengubah saldo. Tracked baru pada policy
aktif memerlukan quantity eksplisit, termasuk0; sentinel999 tetap memakai flag.
Transisi saldo lebih lanjut, onboarding dan biaya unknown belum selesai.

Pola1/2 tetap PIN pengelolaan; pola3 memakai verifier Gudang terpisah dengan
KDF yang sama, PIN berbeda dan stock-all wajib. Pemilihan akses terjadi sebelum
PIN, tanpa mencoba semua verifier. Inventory/promo/rak/master memilih capability
inventory secara eksplisit; default owner-only berlaku pada pengaturan,
laporan, riwayat, repository yang dibuka layanan dan backup. Epoch capability
terpisah dari binding biometrik sehingga upgrade/perubahan pola tidak menghapus
binding owner. Rotasi/pola tugas mencabut sesi lintas engine.

Interval biometrik72jam hanya direset PIN sukses. Observasi waktu tersimpan
mendeteksi rollback setelah restart; verifikasi PIN pada jam yang dikoreksi
memulai interval aktual tanpa mengurangi perlindungan lockout. Pengujian memakai
clock terkontrol, bukan menunggu72jam nyata.

Back terkunci dengan perubahan meminta pilihan tetap terkunci atau buang dan
kembali Kasir. Peringatan tidak memuat isi form. Batal keluar tidak memberi akses;
buang menutup stack tanpa commit dan mempertahankan cart/tender Kasir. Test
mencakup cache field owner setelah autentikasi Gudang, Back framework dan Back PIN.

Model `StockValuation`/`PurchaseCostInput` mempunyai5tes domain lulus: unknown
berbeda dari0, campuran incomplete tidak di-average memakai subtotal known,
rekonsiliasi quantity eksplisit, snapshot immutable serta currency/overflow.
**Model belum dihubungkan ke persistensi/checkout/laporan.** Biaya tersembunyi
masih ditolak layanan sampai propagasi ini selesai; bukan fitur final.

Metadata versi backup/about yang tertinggal+9 diselaraskan dengan pubspec+12.
Ini bukan downgrade/bump M5.3. Printer/feed/protokol tidak diubah atau dicetak.

## Pemeriksaan dan bukti

| Pemeriksaan | Hasil aktual |
|---|---|
| Host role/domain/regresi |66PASS2:02, termasuk protected reads dan koreksi/laporan |
| Host shared UI/valuation/metadata |10PASS28s; sebagian overlap66, tidak dijumlah sebagai kasus unik baru |
| Policy3 stock enforcement negatif |1PASS32s terarah; tidak dapat mematikan enforcement pola3 lewat save fitur |
| DV domain/security |14PASS4:55,511entri protected lama sama |
| Poco domain/security |14PASS3:03,467entri protected lama sama |
| Poco UI sintetis/native SQLCipher |3PASS35s,484entri protected sama |
| DV UI sintetis/native SQLCipher |3PASS1:23,528entri protected sama; awake dipulihkan/readback exact |
| Analyzer/format/lokalisasi |No issues137,7s; format clean;728pesan/493referensi/245ID asli PASS |
| KDF/license |106berkas vendor tidak berubah; parameter/backend tidak dilemahkan |
| Guard negatif |M53 tanpa pause flag ditolak sebelum build/install; override background pada ordinary ditolak Gradle |
| Debug ordinary |Build19,3s;3ABI/13library/signature/resource/lisensi/16KiB PASS; tidak diinstall |
| Release ordinary |Build73s/72,2MB;3ABI/12library/signature/resource/lisensi/16KiB PASS; tidak diinstall |

Hash APK, sertifikat publik, source manifest dan ringkasan terkurasi:
[bukti checkpoint](evidence/m53-20261026/a1b-validation.json). APK/log/DB/key
privat tetap di `build/`, tidak dimasukkan Git. Kedua APK checkpoint memakai
entrypoint `lib/main.dart`, tanpa flavor/integration flags. Signing development.
Handoff `.skybee` final akan memakai entrypoint/flag demo dan versionCode aktual
yang dinaikkan, setelah semua bagian M5.3 selesai dan snapshot aman tersedia.

Hash berlaku pada interval dan berkas protected `databases/no_backup` yang
dinyatakan wrapper, bukan bukti seluruh storage/setting OS. Worker integration
lama dibatasi flag khusus test sehingga tidak membuka DB default retained;
metadata WorkManager/lease mempunyai scope terpisah. Skybee tidak diinstall atau
dimigrasi, jadi belum ada klaim logical migration/handoff M5.3 untuk data pengguna.

## Failure, perbaikan dan retest

- Fixture jam host lebih maju dari clock sintetis dan proyeksi credential ke
  schema9 sempat gagal. Timestamp fixture/proyeksi aditif diperbaiki, assertion
  KDF/lockout/kolom lama tetap; retest host lulus.
- Native menyamarkan injected migration error menjadi safe DatabaseSecurityError.
  Matcher menerima kode yang spesifik; rollback dan seluruh old-column proof
  tetap diperiksa. Raw Poco8PASS1FAIL dan retest1PASS dipertahankan.
- Bug nyata interval PIN setelah jam mundur direproduksi1FAIL; anchor aktual dan
  high-water observation memperbaiki loop, termasuk restart. Host/native lulus.
- Refactor authorization sempat mengambil epoch sebelum audit pertama membuat
  installation identity:19PASS22FAIL. Epoch dipindah setelah audit;66PASS retest.
- Widget helper sempat salah menunggu IO/transisi/lazy field dan menutup DB di
  fake zone, serta memilih Back yang ambigu. Bounded real IO/route readiness,
  scoped finder dan cleanup diperbaiki tanpa melemahkan assertion nilai/SQL.
  Seluruh failure/raw lama tetap di build; curated PASS tidak menutupi run gagal.

## Sisa cakupan wajib

A2 onboarding dan unknown cost pada seluruh boundary; sisa B termasuk kunci
kasir; C pencarian/popularitas, tender dan member; D kas fisik; E kamera/gudang/
supplier/opname/retur/tagihan/pembayaran/jadwal; F label/struk/laporan; G retensi,
reset fixture dan portable restore; H regresi/Git/in-place Skybee dan dua startup.
Tidak ada tombol mock yang dihitung sebagai selesai. Tidak menunggu review untuk
melanjutkan pekerjaan yang diotorisasi.

Sentuhan/IME OEM, biometrik fisik baru, interval72jam alami, printer label dan
notifikasi H-1 alami belum dibuktikan checkpoint ini. Tidak ada job cetak/transfer
bank/upload Drive atau pengiriman data bisnis baru pada pengujian ini.
