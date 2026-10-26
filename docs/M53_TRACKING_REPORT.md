# M5.3 — checkpoint transisi pelacakan, belum handoff akhir

Source **0.5.2+12/schema18**, setelah checkpoint biaya `1b034f2`. Paket
Eksplorasi Mandiri tetap **+12/schema14**, tanpa update/reset/reseed. Kontrak
[scope transition](decisions/M53_TRACKING.md) mempertahankan saldo, batch dan
nilai historis; ini bukan opname0, kehilangan barang atau beban HPP baru.

## Perubahan

Penutupan tracking bersaldo memerlukan jumlah/revisi yang ditinjau, alasan dan
konfirmasi. Event dan snapshot batch append-only, ledger serta flag untracked
berubah atomik; nilai lama tidak dibuang. Reference cost dapat memakai average
historis, input eksplisit atau unknown sesuai preferensi. Input0 tetap meminta
konfirmasi; historical rounding0 berbeda dari pembelian gratis.

Pembukaan kembali meminta jumlah fisik baru, termasuk0. Sentinel999 bukan jumlah
fisik dan tidak membatasi penjualan untracked. Retry terikat payload, preview
stale ditolak, jumlah batch direkonsiliasi, SQL failure menggulung seluruh operasi.
Penjualan/HPP lama dan keranjang/tender tidak ditulis ulang. Retur penjualan
tracked lama ditolak ketika produk untracked dan dapat diproses setelah scope
fisiknya direkonsiliasi kembali.

Tanggal paling awal pada batch yang ditutup menjadi reference expiry secara
konservatif. Tanggal lama dibawa saat dibuka kembali, termasuk tanggal lewat atau
fitur expiry yang sedang nonaktif. Penerimaan pembelian baru tetap memakai
validasi tanggal masa depan. Bug nyata ditemukan: kasir sebelumnya mengabaikan
reference expiry untracked. Kini CartService, cart snapshot dan checkout menolak
barang tersebut; UI menandai expiry dan menonaktifkan hasil yang tidak layak.

Mode toko seluruh/nonaktif yang masih konflik dapat dimulai dari parsial melalui
konfirmasi owner, tanpa rewrite saldo massal. Pengguna meninjau tiap barang dan
kembali menyelesaikan target. Dialog preview terlindungi dan scrollable. Form
busy menolak discard saat unlocked; setelah locked, warning dirty generik tetap
berlaku. Keluar mencabut sesi, tanpa menyimpan draft atau kehilangan keranjang.

Riwayat tracking mempunyai cursor/index sendiri. Restore memeriksa snapshot
batch, link opening, reference historis dan tanggal. Laporan selisih opname yang
masih akan dibuat wajib mengecualikan inventory operation yang terhubung ke
tracking change; current realized HPP/profit tetap hanya dari snapshot penjualan.

Audit i18n terakhir juga melengkapi dua label hasil rekonsiliasi yang dipanggil
secara dinamis oleh laporan. Test host1PASS4s memeriksa ID/EN dari seluruh key
yang benar-benar dikembalikan SQL; static audit saja tidak mencakup lookup ini.
Delta ini hanya terjemahan dan tidak mengubah aturan/native SQL yang sudah diuji.

## Bukti aktual

| Run | Hasil |
|---|---|
| Host awal domain/regresi |24PASS1FAIL31s; gagal expiry untracked nyata |
| Host domain sesudah fix |8PASS19s |
| Host UI/M52forms/cashier awal |54PASS1FAIL1:17; finder menunggu dialog async |
| Host focused partial UI |1PASS8s sesudah bounded readiness |
| Host acceptance+cost+M52ops |34PASS1:32; acceptance17 +cost10 +M52ops7 |
| Analyzer/lokalisasi |No issues pada final check;751key/500staticref/245requirement asli PASS |
| DV acceptance |16PASS1FAIL11:06,556hash protected lama sama |
| DV focused partial UI retest |1PASS38s,576hash lama sama |
| Poco acceptance17 |17PASS3:49;505hash protected lama sama |

Kasus acceptance mencakup domain8, widget8 dan populated14→18 beserta full
interrupted-upgrade rollback1. DV memiliki PASS seluruh17 kasus lintas run,
bukan satu all-pass17. Kasus ulang tidak dijumlah sebagai kasus unik tambahan.

Kegagalan DV berada pada helper widget: `pumpAndSettle` dipanggil sesudah SQL
preview mulai, sementara spinner busy aktif. Native tertahan sampai idle-lock
5menit lalu drain gagal mencari tombol yang sudah redacted. Dua settle tersebut
diganti bounded real-IO drain, tanpa mengubah assertion ataupun source fitur;
host dan focused native lulus. Raw failure awal tetap dipertahankan. Percobaan
inspeksi VM berhenti ketika proses test sudah selesai; tidak ada klaim diagnosis
berdasarkan umur OS atau log startup yang tidak terkait.

Seluruh wrapper DV selesai controlOff, awake dipulihkan/readback exact, termasuk
run gagal. Hash hanya membuktikan scope/interval protected databases/no_backup
yang dinyatakan runner; WorkManager metadata dan lease terdokumentasi terpisah.
Pengujian memakai package `.integration`, flag isolasi/background pause dan
`--no-uninstall`, DB sintetis baru, tanpa root atau salinan sandbox bisnis.

Widget native menggunakan callback/test keyboard; bukan bukti sentuhan atau IME
fisik. Debug integration ARM32/ARM64 berhasil dibuild; ordinary/release final dan
in-place `.skybee` tetap bagian H. Seluruh wrapper kini tertutup/controlOff. [Bukti terkurasi](evidence/m53-20261026/tracking-validation.json)
dan [source checksums](evidence/m53-20261026/tracking-source-sha256.json) tersedia.
Raw log/APK/DB/key tetap privat di `build/` dan tidak dipush.

Onboarding masih tahap berikutnya, dengan model draft non-secret yang disiapkan
privat dan belum diimport aplikasi. Sisa B serta C–H tetap aktif. Checkpoint
ini tidak menyatakan keseluruhan M5.3 selesai.
