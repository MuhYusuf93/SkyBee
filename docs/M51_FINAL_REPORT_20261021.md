# Penutupan M5.1 dan handoff ordinary

21 Oktober 2026, WIB. **Implementasi wajib A–G, pemeriksaan yang tersedia dan
handoff pengembangan M5.1 selesai.** Ordinary debug **0.5.1+8** sudah dipasang
in-place dan dibuka di Poco F6 `7f0edea0`. Target skema source13. M5.2 tetap
PLANNED menunggu arahan desain; M6 tidak dimulai. Batas fisik/manual di bawah
tetap UNVERIFIED, bukan acceptance seluruh aplikasi atau kesiapan rilis.

Ringkasan terstruktur tanpa data toko:
[final-results.json](evidence/m51-20261021/final-results.json).
Kontrak tetap [permintaan A–G](decisions/M51_REQUEST_20261019.md), implementasi
dan bukti sebelumnya di [laporan A–G](M51_IMPLEMENTATION_REPORT.md) dan
[laporan D/E/G](M51_CASH_REPORT_EXPORT_MAINTENANCE.md).

## Pemeriksaan source akhir

| Pemeriksaan | Bukti aktual |
| --- | --- |
| Formatter | 275 berkas, 0 perubahan; `build/m51-resume-20261020-format.log` |
| Analyzer | No issues found, 98,2 detik; pengulangan7,0 detik juga bersih. Kedua log resume disimpan, bukan memakai log final lama |
| Regresi host11file | **77 PASS / 66 detik**: tender, ekspor/UI cancel, maintenance/schedule/WAL, checkout, antrean cetak, koreksi/laporan, uang, USB dan metadata backup |
| Migrasi terarah8→13 | **1 PASS** pada source akhir; nilai produk lama tetap, atribut lama null, constraint parsial ditolak. Run terpisah dari77 di atas |
| Pembaca CSV/OpenXML independen | Python csv/openpyxl PASS129baris; total penuh, multiline, anti-formula, barcode000123 dan text uang64bit eksak |
| Native terarah Poco | **1 PASS / 16 detik**; safe runner, package integration, SQLCipher native dan output printer fake. Default6LF, profil lama3LF, duplicate/copy serta fakta keuangan diperiksa |
| Isolasi interval native baru | **392 hash** pre-existing protected files cocok; tidak reset/uninstall/downgrade; kontrol Off |
| Awake DV read-only | screensaver1, timeout900000, plugged-in0; cocok dengan snapshot akhir feed-only sebelumnya. Tidak mengubah awake pada sesi lanjutan ini |

Tes native akhir hanya kasus queue yang berubah akibat default feed. Backup
final DV2PASS99s, WAL native Poco2/DV2PASS, D/E/G17PASS dan bukti A–C/F
historis tetap berlaku pada cakupannya; tidak diulang atau dijumlah sebagai
kasus unik baru. Seluruh proses Flutter/build dan mutasi perangkat diserialkan.
Percobaan penamaan timestamp build pertama berhenti sebelum build/install;
perintah dikoreksi lalu kedua build berhasil. Warning KGP workmanager/deprecated
API dari Gradle tetap tersimpan; tidak menghalangi build dan bukan bukti runtime.

Source aplikasi tidak diperluas ke fitur tahap lain saat resume. Perubahan
default `PrinterProfile.feed`6 dan assertion queue dari checkpoint sebelumnya
kini terverifikasi otomatis. Nilai kalibrasi tersimpan3 tetap3. Helper audit
endpoint/startup ditambahkan; verifier APK kini juga menyimpan signature dan
version metadata serta menolak versi yang tidak sesuai bila diminta.

## Audit jeda Poco dan perlindungan data

Percobaan historis `m51-candidate-before-20261020-021458` tetap BLOCKED sebelum
tes mulai, bukan PASS. Capture tertutup baru disimpan terpisah sebagai
`late-after-20261020-235526.json`: **390/391 hash cocok**, satu perubahan pada
ordinary `databases/kasir_app.db`; seluruh wrapped key dan fixture lama cocok.
Pengguna mengonfirmasi ordinary sempat dibuka/dipakai untuk pengujian dummy
selama jeda serta mengizinkan penghapusan. Tidak ada penghapusan yang diperlukan
atau dilakukan. Ini konteks baseline yang tidak beku, bukan bukti penyebab
internal perubahan byte DB. Tidak mengubah hasil historis menjadi preservation
byte-identik. Interval native berikutnya memakai baseline baru dan392/392 cocok.

Sebelum ordinary update, helper memverifikasi model Poco, package, versi dan
signature. APK terdahulu0.5.0+7 disimpan privat. Setelah force-stop, sandbox
tertutup disalin ke tar privat, hash database/wrapped key diverifikasi terhadap
isi tar dan capture kedua. Snapshot ini **same-installation**, bukan arsip
portable atau ekspor Keystore. Tidak ada klaim pemulihan data insiden M3.1.

`adb install -r` berhasil tanpa reset/uninstall/downgrade. Hash database dan
wrapped key sama sebelum/sesudah install **sebelum startup**. APK terpasang
ditarik kembali dan SHA256 cocok dengan artefak debug. Database dapat berubah
sesudah startup karena migrasi dan runtime; byte-identik pascamigrasi tidak
disyaratkan atau diklaim.

## Artefak ordinary dan startup

Folder privat:
`build/m51-final-handoff-20261021-000031/`.
Pointer `build/m51-final-handoff-current.txt` menunjuk folder ini. APK, snapshot,
hierarchy UI, log PID, source fingerprints serta hasil rinci tetap di ignored
build/. Identitas `kasir_app` / `com.example.kasir_app`, launcher `MainActivity`.

| APK | SHA256 |
| --- | --- |
| `kasir-app-0.5.1-ordinary-debug.apk` — terpasang Poco | `fdb5de9397d66bb0ffb972cbdabf4936adfbbe28b880f92279a242cd1c8ef7f5` |
| `kasir-app-0.5.1-ordinary-release.apk` — tersedia, tidak dipasang | `3240de00de558e8e5279065143de466d83474a26c4d042d3d89dbdb599fe091e` |

Build debug20,2detik/release72,1detik. Keduanya0.5.1/versionCode8, minSDK24,
ABI armeabi-v7a/arm64-v8a/x86_64 lengkap, engine/SQLCipher/KDF, ELF+ZIP16KiB,
ikon notifikasi, lisensi dan ketiadaan launcher fixture diverifikasi pada APK
aktual. Signature terverifikasi dengan sertifikat development Android Debug
`002029d011716641cfb6c8490df92d309920c38be4150770ed14423dd37fcd4c`, cocok dengan
APK Poco sebelumnya. Ini bukan signing/distribusi M6.

Startup pertamaPID8524 dan clean reopenPID8525 memperlihatkan package sendiri,
Daftar belanja, Bayar dan Kelola. Masing-masing buffer log PID tersedia memiliki
0penanda FATAL/Unhandled/ANR dan0E/flutter. Wrapped secret tetap sama sesudah
startup pertama, header DB tetap terenkripsi. Reopen melewati bootstrap produksi
yang menjalankan quick_check/FK, envelope HMAC dan pemeriksaan cipher sebelum
coordinator dapat membuka kasir. Source menargetkan schema13 dan migrasi host
8→13 lulus; tidak mengklaim PRAGMA versi ordinary dibaca lewat SQL eksternal
atau seluruh row bisnis ordinary dibandingkan. Akses Gudang/Pengaturan melalui
PIN pribadi belum dilakukan oleh otomatisasi atau dilaporkan pengguna.

Konfigurasi Android Studio `main_dart.xml` menunjuk `lib/main.dart` tanpa flag
fixture. [Panduan Run/Debug dan handoff](ANDROID_STUDIO_RUN_AND_HANDOFF.md)
diperbarui. Kontrol perangkat otomatis **Off**; ordinary terakhir tetap terbuka
untuk pengguna, fixture tidak disebut aplikasi utama.

## Batas pengujian yang tetap terbuka

- Paper DV historis: raster41717byte/11chunk accepted; logo,5barang dan nominal
  sesuai dilaporkan pengguna. Footer terlihat setelah3LF tambahan, sebelumnya
  dilaporkan belum tercetak. Posisi versus flush belum dipastikan. **Struk baru
  default6 belum dicetak**; printer tidak terhubung pada resume. Marker lama
  tidak diulang, tidak ada cetak diagnostik baru.
- Biometrik/enrollment fisik, recovery paper, SAF laporan/provider/keyboard OEM,
  Poco USB/80mm, fault kabel/kertas nyata, TalkBack dan runtime ordinary release
  terbaru belum terverifikasi.
- Natural idle/reboot/Doze maintenance/worker tidak dibuktikan oleh pemicu atau
  fixture terkontrol. Realme pribadi tetap dijeda; endpoint worker historis
  nonce1792404362140 belum diaudit dan tidak disentuh pada resume ini.
- QR/mnemonik recovery tetap opsional dan belum diimplementasikan. Keystore
  snapshot tidak menjadi pengganti backup portable lintas instalasi.

Langkah pengguna yang tersedia sekarang: mencoba ordinary terbaru, termasuk
Gudang/Pengaturan dengan PIN sendiri. Pemeriksaan fisik di atas dapat diteruskan
sebagai tindak lanjut M5.1 bila perangkat/hardware tersedia. M5.2 membutuhkan
arahan desain dan instruksi baru; M6 belum dikerjakan. Tidak ada commit/push,
publikasi, penggantian identitas, atau perubahan aplikasi/sistem lain.
