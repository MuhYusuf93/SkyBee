# Checkpoint aktif M5.4

6 November 2026, WIB. Kontrak: [M54_REQUEST](decisions/M54_REQUEST.md).

Baseline aktual `c94a2a2`, main, 0.5.3+13/schema37; perubahan lokal awal
hanya delapan berkas `gemini2_` untracked. Jangan menyentuhnya. M5.3 ditutup;
riwayat pengujian lama bukan perintah mengulang seluruh suite.

## Urutan pekerjaan

1. Audit/kontrak/matriks — kontrak asli disalin utuh; audit berlangsung.
2. Keamanan/recovery compatibility/gate/input/form/arsip/kebijakan kas.
3. Retur penjualan/garansi/karantina/refund/QRIS manual/split/rounding.
4. Gudang/supplier/reservasi/lampiran/member/favorit.
5. Recovery PDF/grafik/output/Drive/portable backup.
6. Host lalu acceptance fixture DV/Poco, perbaikan dan regresi terdampak.
7. Handoff `.skybee` in-place tanpa reset/seed; trial release terpisah.
8. Realme M5.3+M5.4 sesudah handoff, jika tersedia.
9. Finalisasi source/APK/manifest/dokumentasi/commit/push biasa.

## Temuan awal

- ADB read-only: Poco `7f0edea0` model24069PC21G; DV `192.168.0.101:5555`
  modelAX810/DV8947-KIX authorized. Realme belum terlihat. Tidak ada instalasi,
  reset, perubahan PIN, seed atau transaksi pada data eksplorasi.
- `PinBoxes` memakai dua pembatas panjang4; commitText barcode panjang dapat
  berubah menjadi PIN4digit. Auto-submit langsung juga menerima prefix burst.
- `CashierLockNavigator` menyisipkan opaque lock di atas setiap route,
  termasuk Kelola; dibutuhkan prioritas route tanpa menghapus lock kasir.
- Lock existing persisten tetapi memakai cooldown eksponensial5detik, belum
  kontrak3/5/8. Recovery PIN32hex terpisah dari backup256bit/64hex.
- Validasi harga master memakai `>` sehingga harga sama masih diterima.
- Signing release existing masih debug certificate; trial membutuhkan signing
  lokal stabil dan tidak boleh membawa source controller debug.

Status belum selesai: seluruh acceptance M5.4 dan handoff M5.4 belum dijalankan.
M5.5 khusus multi-device, belum dikerjakan. Redesign menyeluruh ditunda.


## Lanjutan 7 November 2026, fondasi native ditutup

Host85kasusunik melalui runs/retest; native Poco23unik melalui20awal+3review,
DV23/23PASS08:22. Semua oldprotectedhash unchanged; DVawake exact restored;
controlOff, process exit dan manifest3 verified. Laporan mencatat run gagal,
bukan menghilangkannya. FixtureAPK arm64 saja, bukan APK handoff.

Source dibuka kembali sesudah audit untuk tahap2 kebijakan/sesi kas. Draft9file
diterapkan dengan semua preimage SHA diperiksa. Pisahkan rawpolicy dari mode
sesi aktual; Off boleh Buka sukarelaNotes tanpaubahraw; perubahan owner dengan
open session harus eksplisit berlaku sesi berikutnya. Open/close ikut menaikkan
revisionCAS atomik dan retry tidak menggandakan. UIstatus/clean baseline dan
regresi cash/supplier/portable48/48PASS01:26. UIbaru2PASS00:31,
analyzerfinal104s bersih, l10n1552/947/245, PIN106match; semua fail awal disimpan.
Native7kasus kas PocoPASS04:04 lewat retained-packagewrapper, oldhashsama/
controlOff/trueexit0. DV7/7PASS04:51 pada revisi sama; oldhashsama/awakeexact/controlOff/trueexit0. Manifest4 frozen
889file2ae2e9e160de4083aec52bddca88737587160be85b78f33546b3605d24084ca0;
preflightPoco/DV0pending. Kedua wrapper dan audit
hashlama/awake/controlOff/trueexit ditutup; manifest4 terakhir verified. Laporan M54_CASH_POLICY_REPORT.

Lanjut kas/HID/modal/acceptance arsip, kemudian tahap3–9 berurutan. Tidak ada
izin berhenti di checkpoint. Tidak ada packageuser diupdate/reset/reseed.

Draft input routing berada di build/m54/input-routing-draft/ dan audit
build/m54/input-routing-audit.md. Belum diterapkan/ditest; caller kamera sudah diadaptasi secara sintaks di draft,
belum typechecked. Scope lanjut/renewal setelah dialog dan include-only pending. README berisi urutan reproduksi
dan batas. Jangan copy draft secara buta Source kini boleh dilanjutkan; mulai reproduksi field/scope kecil dahulu.

## Routing input — native source5 aktif

Source guardedlookup/SQL/route/field dan rawPIN setup/rotasi aktif. Reproduksi
field1PASS2FAIL lalu7PASS; rawPIN4FAILprefix lalu4PASS. Regresi akhir77PASS+
4fixtureerror02:03, retest14PASS00:09 =81unik (overlap tidak dijumlah ulang).
Analyzer110,8s bersih; formatter84/0; l10n1553/948/245; PIN106match.
Kas source4 native kedua perangkat sudah ditutup. Routing12kasus Poco sedang
berjalan melalui safe wrapper, DV setelahnya. Source894file dibekukan pada
manifest5 SHA6bf9750dc7d093d2537734beea1e9c5a5975fe28c585cd4255388a556819f94a.
Jangan edit maintainedsource selama wrapper aktif. Hashlama/controlOff/exit0,
DVawakeexact dan manifest harus diverifikasi sebelum lanjut arsip/navigasi.
Draft input-routing-draft kini historis; source aktual telah diperbaiki, jangan
copy ulang. Laporan M54_INPUT_ROUTING_REPORT merinci bukti/failure/batas.

## Native routing review6 — aktif

Filter NameFilter adalah literal --plain-name. Runregex0kasus=FAILED, hash lama
sama/controlOff/exit1; jangan ulang regex. FullPoco21 =19PASS2FAIL02:04, hanya
dua rotasiPIN helpergulir (native switchlazy), semua real assertion lain lulus.
Audit oldhashsama/controlOff/trueexit1. Revisi6 hanya helpervertical jump ke min,
strict switchpresence tetap; host4PASS00:08. Produksi identikmanifest5; diff persis
test/support/m54_pin_setup_suite.dart. Source894file frozen manifest6
882365ca194b0a8ec19a9bfb5d980f92b3f0d886caa2221aab89e07ded888467.
Retest2Poco berjalan, laluDVfull21 tanpafilter. Jangan editsource hingga semua
wrapper/hash/awake/controlOff/exit ditutup. Draft arsip di build/m54/archive-draft
belum diterapkan/ditest; meliputi scopes/Undoexpired dan dugaan reloadhilangkanerror.

Poco menutup 21 kasus unik setelah retest dua rotasi lulus. DV pertama berhenti
setelah 17 kasus lulus karena ADB offline. Kode keluar aktual 1. Pemulihan
manual dari snapshot awake berhasil setelah koneksi kembali dan audit susulan
menemukan 1.264 hash cocok. Result.json asli disimpan karena finally gagal
memublikasikan status akhir. Bukti susulan ada pada folder run
`m54-input-routing-dv-all-20261107-051101`. DV kedua menjalankan 21 kasus dari
manifest 6. Draft arsip berisi tujuh kasus dan kandidat perubahan. Jalankan
tes terhadap source sebelum perbaikan untuk mengonfirmasi diagnosis.

Full run DV kedua lulus 21 kasus dalam 2:48. Audit hash dan awake ditutup,
kontrol otomatis berhenti dan kode keluar aktual 0. Manifest 6 diverifikasi
sebelum source dibuka untuk repro arsip.

## Operasional tahap 2 selesai di host

Arsip/Undo/stale checkout, navigasi kategori/supplier/rak dan bahasa promo
lulus dalam regresi host 75/75 pada schema 38. Analyzer bersih. APK fixture
terkompilasi dengan area fokus kamera belakang, dan diverifikasi package/ABI/
16 KiB. Fixture build belum dipasang. Uji native arsip dan optik/HID fisik
terbuka. Runner kini menyimpan hasil terminal ketika pemulihan awake gagal.
[Laporan](M54_OPERATIONAL_REPORT.md). Lanjut tahap 3 dari snapshot garansi,
kode struk dan retur transaksi. Data perangkat belum diubah untuk handoff.


## Tahap 3 · skema 43

Garansi snapshot, kode struk Code 128/QR, retur parsial, pengurangan
piutang, refund dengan sesi kas aktual, dan pengaturan gambar QRIS privat
telah melalui regresi host 64/64 dalam 1:25. Analyzer bersih. Tes UI ID/EN
320 px pada skala 2 mencatat refund eksternal tanpa mutasi laci. Dua run
driver awal dihentikan saat menunggu I/O. Run berikutnya memperbaiki
navigasi field lazy dan status hasil yang sempat muncul ganda. Gambar
sintetis diuji tanpa pembayaran nyata. Split checkout dan pembulatan
masih dalam pengerjaan. Paket pengguna belum dipasang ulang.
