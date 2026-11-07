# M5.4 — fondasi awal, belum handoff

Checkpoint 7 November 2026 WIB. Baseline `c94a2a2`/0.5.3+13/schema37.
Source pengembangan kini0.5.4+14/schema38. Ini **bukan penutupan M5.4**.
Kontrak lengkap [M54_REQUEST](decisions/M54_REQUEST.md), keputusan
[keamanan](decisions/M54_SECURITY_DECISIONS.md), matriks
[M54_ACCEPTANCE](M54_ACCEPTANCE.md).

## Implementasi tersedia

- Counter target Kasir/Gudang persisten3/5/8, hard lock, cooldown monotonik
  selama proses hidup, migrasi aditif, merge counter restore toko yang sama.
  PIN referensi Kasir tidak mengubah counter pemilik/usia PIN72jam; witness
  rollback jam pemilik tetap diperbarui pada referensi yang benar.
- Aksi buka blokir target dengan PIN pemilik fresh dan one-use claim di SQL,
  audit, pencabutan sesi. Di gate Kasir tersedia aksi terpisah yang mencabut
  blokir tanpa mematikan kebijakan kunci atau memberi grant Kasir.
- Prioritas gate mengikuti route: Kelola meminta pengelolaan; kembali ke Kasir
  tetap meminta PIN Kasir. Dirty draft dan redaksi konten tetap dipertahankan.
- PIN panjang/alphanumeric tidak dipotong/digit-stripped menjadi empat digit.
  Auto-submit empat digit memakai settling200ms; bukan identifikasi HID/OEM.
- Recovery backup256bit dapat ditampilkan/disalin sebagai24kata English resmi,
  checksum, input64hex lama dan mnemonic, HKDF lama tetap sama. QR recovery
  versioned terpisah; lookup/master/kamera bisnis menolak namespace tersebut.
  Clipboard native tetap foreground+sensitive dan format versioned. PDF/share
  serta scanner recovery khusus **belum tersedia**.
- Form produk memfokuskan field invalid pertama, mempertahankan teks rak yang
  belum terdaftar, membuka panel yang sesuai, dan tidak mewajibkan expiry kosong.
  Harga beli/grosir sama atau lebih tinggi dari retail ditolak; biaya dibandingkan
  per pcs tanpa pembulatan. Rak terisi membutuhkan ID sah pada writer.
- Penolakan arsip tidak lagi langsung dihapus oleh reload detail. Guard stok
  existing dipertahankan; ini bukan izin mengarsipkan stok positif atau hard-delete.
  Long-press edit kategori dihapus; tap rak membuka barang terfilter, Edit terpisah.

## Bukti host saat checkpoint

Gabungan12file:78PASS+1timeout30s,02:13. Timeout terjadi pada fixture G3
`separated=true`, sesuai batas KDF yang pernah dicatat pada LESSONS154. Rerun
dua kasus portable dengan timeout2m dan assertion sama, ditambah2kasus baru
kompatibilitas key/namespace:4PASS00:36. Empat kasus clipboard terpisah4PASS00:28.
Dengan memperhitungkan overlap, **85 kasus unik melewati assertions melalui
runs/retest tersebut**, bukan satu run85exit0.

Di dalam gabungan tersebut terdapat regresi form25PASS01:21 (termasuk UIID/EN
320px/text2), input PIN/lockout, gate/dirty draft, biometrik sintetis, lookup label
dan replay fakta portable A–F. Vektor BIP39 independen8kasus256bit dan random100
round-trip berada dalam kasus codec; jangan menjumlah setiap vektor sebagai
kasus runner. HKDF publik zero-entropy juga dibandingkan hasil Python stdlib
RFC5869 independen, bukan hanya round-trip implementasi yang sama.

Analyzer native-ready: No issues6,8s. Formatter45file/0changed sebelum penambahan
entrypoint cleanup; entrypoint tersebut juga diformat. Lokalisasi1544key/
944staticrefs/245IDasli; PIN106upstreamfiles unchanged. Diff whitespace bersih.

Failure awal dipertahankan pada `build/m54/`: dua kesalahan harness pertama,
ekspektasi harga/cooldown lama, klien input PIN yang belum siap, query SQL dalam
fake zone yang sempat macet, dan notifikasi controller relasi saat build.
Tidak melemahkan KDF, constraint, auth, assertion uang/stok atau guard isolasi.
Stale tap Copy dari halaman terkunci kini tidak membuka route auth baru atau
mengubah witness kredensial; fingerprint seluruh DB pada4tesclipboard tetap sama.

## Native dan perangkat

Fondasi native selesai; source boleh diedit kembali untuk tahap2.
Semua Android melalui test_m51_android.ps1→test_android.ps1 pada package
com.example.kasir_app.integration, define isolasi dan --no-uninstall.

| Run privat build/ | Hasil aktual | Audit akhir |
| --- | --- | --- |
| m54-dv-work-cleanup-20261107-001347 | 1PASS00:02 scoped WorkManager cancel | oldhashsama/controlOff/exit0/awakeexact |
| m54-foundation-poco-20261107-001900 | 20PASS3FAIL04:43 input harness | oldhashsama/controlOff/exit1 |
| m54-pin-input-poco-review-20261107-034201 | 4PASS00:05 | oldhashsama/controlOff/exit0 |
| m54-foundation-dv-20261107-034614 | 23PASS08:22 | oldhashsama/controlOff/exit0/awakeexact |

Poco23kasusunik terpenuhi melalui20awal+3koreksi, bukan satu run23PASS.
Binding integration registerTestTextInput=false; sesudah Done klien tertutup.
Review hanya test/m54_pin_input_test.dart: register/refocus klien secara eksplisit
dan assert teks4digit benar-benar diterima sebelum assertion auto-submit200ms.
Produksi/KDF/assertion bisnis tidak diubah. Host4PASS00:01 sesudah review.

Manifest2:888file dda6b0bf610c87c59de7dc07838070df385a63d9e62bce30735ea18beb0761f3.
Manifest3:888file 05c3648f05069ee24eb91b4663a06ce2c47964b2429c39bf0ad59e11b3100634.
Diff persis satu harness tersebut, verifikasi akhir sebelum perubahan kas PASS.
Fixture source3 disimpan build/m54/foundation-source3-fixture.apk. Verifikasi
packageintegration/version0.5.4+14/arm64-v8a/ELF+ZIP16KiB PASS. Actual fluttertest
device build arm64 saja; verifikasi awal ekspektasi universalABI ditolak dan
disimpan. Ini bukan APK universal/debug/release handoff user.

DVpreflight menemukan1legacy jobfixture kasir-alerts-periodic-v1; cleanup via
APIWorkManager, tanpa initcallback baru atau buka DBbisnis; preflight sesudahnya0.
Poco0pending. Tidak ada uninstall/reset/reseed/update ordinary/.skybee.

Bukti ini bukan acceptance seluruh M5.4 maupun scanner fisik, kamera fokus,
cetakan, cloud, enrollment, screen-lock OEM, reboot/power-cut. Realme belum
terhubung; urutan pengujiannya tetap setelah handoff awal.

## Yang masih harus dikerjakan

Tahap2 belum ditutup: kebijakan/sesi kas, routing HID/modal secara menyeluruh,
dan acceptance arsip/navigasi yang belum tercakup masih perlu dilanjutkan.
Tahap3–5 belum selesai: retur penjualan/garansi/karantina/refund, QRIS manual+
split/rounding/pecahan, penerimaan15/12/20/capability, banyak supplier/reservasi,
lampiran terenkripsi/backup, member/favorit/sort/hard-delete, fokus kamera/Code128,
PDF pemulihan, grafik dan Drive. Matriks menjadi acuan, bukan daftar ini saja.

Belum update/reset/reseed `.skybee`/ordinary; belum APK Uji Teman, belum handoff,
belum commit/push M5.4, belum pengujian M5.3+M5.4 Realme. Paket eksplorasi/PIN/
data pengguna bukan fixture. PrefixGemini_/gemini_/gemini2_ tidak diubah.
M5.5 khusus multi-device, belum dikerjakan. Jangan menyatakan aplikasi selesai.
