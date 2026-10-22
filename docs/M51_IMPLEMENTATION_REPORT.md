# M5.1 — checkpoint implementasi

**Penutupan21 Oktober2026:** A–G selesai pada cakupan implementasi dan
pemeriksaan yang tersedia; ordinary debug0.5.1+8 sudah diperbarui in-place dan
dua kali dibuka di Poco. Build debug/release3ABI/signature/16KiB PASS;
formatter275/0changed/analyze bersih, host77PASS66s, focused migration8→13
1PASS terpisah, reader independen129rowPASS. Queue default6/saved3 native
Poco1PASS16s/output fake/392hashcocok. Kontrol Off; tidak reset. Audit jeda lama
390/391cocok, ordinary DB berbeda dan pengguna mengonfirmasi memakai dummy;
wrapped key/fixture tetap cocok, hasil lama tidak diubah. Paper default6,
biometrik fisik, SAF OEM/natural worker/manual PIN/release runtime tetap belum
diuji. [Laporan akhir dan APK/hash](M51_FINAL_REPORT_20261021.md),
[bukti](evidence/m51-20261021/final-results.json). M5.2 menunggu desain/M6 belum
dimulai. Paragraf checkpoint di bawah historis; tabel A–G memakai hasil terbaru.

**Titik lanjut20 Oktober2026:** pengguna pindah chat. Baca
[NEXT_SESSION_M51](NEXT_SESSION_M51.md) untuk source, log, izin, kabel bergantian,
footer ambiguity dan perintah lanjut yang benar. WAL native2per perangkat PASS;
backup DV final2PASS99s sesudah perbaikan kandidat. Raster USB41717byte/11chunk
PASS transport; manual logo/nominal sesuai, footer baru terlihat setelah3LF
tambahan. Default6/source test tail sudah diubah tetapi belum regresi/analyzer
akhir. Pipeline berhenti di formatter (dua file kemudian diformat); ordinary
M5.1 build/install belum dikerjakan. M5.1 belum selesai; M5.2/M6 tidak dimulai.

**Checkpoint aktif20 Oktober2026:** A–G memiliki implementasi; D/E/G baru dan
schema13 dijelaskan pada [laporan D/E/G](M51_CASH_REPORT_EXPORT_MAINTENANCE.md).
Host final49PASS208s, ekspor cancel repro1FAIL→5PASS, DV D/E/G17PASS302s,
portable backup Poco1PASS60s/DV1PASS80s; hash lama tetap, awake DV pulih exact.
WAL physical-size direpro1FAIL4s lalu host8PASS29s; validasi native terbaru,
build dan handoff ordinary0.5.1+8 masih berlangsung. Jangan menafsirkan paragraf
checkpoint lama berikut sebagai status terbaru. Realme tetap dijeda; M5.2
menunggu desain/M6 belum dimulai.

Checkpoint terbaru: DV adapter USB81/81byte/native1PASS4s, kertas lima baris PASS
dilaporkan pengguna; semua hash lama sama/awake pulih/kontrol Off. Realme98kasus
native unik PASS lintas run sampai antrean cetak; worker nonce1792404362140
terputus sebelum reader/cleanup/audit endpoint, tetap belum terverifikasi. Realme
kini dipakai pribadi. Selanjutnya kabel/Poco dan D/E/G; M5.2 menunggu desain/M6
belum dimulai. [Hasil DV](M51_DV_USB_APP_20261019.md),
[checkpoint Realme](M5_REALME_CURRENT_AUTOMATED_20261019.md).

19 Oktober 2026. Permintaan aktif: `prompt-codex-m51-fitur-m52-ui-20261019.md`.
M5 tetap selesai menurut laporan historis; M5.1 sedang dikerjakan, M5.2 menunggu
arahan desain, M6 tidak dimulai. Tidak ada perubahan identitas/publikasi.

## Handoff M5 sebelum fitur baru

Build ulang source M5 berhasil (release, 56,2 detik), sebelum perubahan fitur
M5.1. Artefak dan baseline Git privat berada di
`build/m51-handoff-20261019-015916/`. HEAD baseline:
`dbcc5db3b2a13fd0b09bb896987efa053560d440`; working tree sudah berisi perubahan
dan berkas tidak terlacak dari kampanye sebelumnya, dipertahankan.

Poco `7f0edea0`/24069PC21G terdeteksi. Aplikasi utama aktual sudah 0.5.0+7,
debuggable, diperbarui 19 Oktober sekitar 01:17; `secret-database-v1` sudah ada.
Jadi asumsi baseline ordinary schema7 plaintext historis tidak boleh digunakan.
Tidak membaca isi key. APK terpasang disalin privat, sertifikat SHA256 sama
`002029d011716641cfb6c8490df92d309920c38be4150770ed14423dd37fcd4c`.
APK baru lolos pemeriksaan package ordinary, launcher, tiga ABI, SQLCipher,
ELF/ZIP16KiB, ikon notifikasi dan lisensi. Signing masih development.

**Handoff terpasang sebelum fitur baru:** pengguna menjawab bahwa data ordinary
adalah dummy dan boleh dihapus jika perlu. Tidak ada penghapusan yang diperlukan.
Setelah quiesce, sandbox privat disimpan di ignored `build/`; isi tar diverifikasi
terhadap hash database/key wrapped sebelum dan sesudah capture. Ini snapshot
same-installation, bukan portable backup/ekspor Android Keystore atau bukti
restorability lintas instalasi. Izin dummy terbaru memungkinkan melanjutkan tanpa
meminta pengguna menyiapkan portable backup. Jangan gunakan asumsi ini pada data
masa depan.

APK **debug ordinary** M5 0.5.0+7 dibangun dari source M5 sebelum fitur baru,
diverifikasi lalu dipasang `adb -s 7f0edea0 install -r`, tanpa uninstall/reset/
downgrade. SHA256 `1b7598740607c3cb15ee673b6eb91f69507c0793f6fd413c884aabb24eec0b43`;
APK terpasang ditarik dan hash sama. Seluruh hash database dan wrapped secret
sama sebelum startup. `MainActivity` dibuka; UI menunjukkan Daftar belanja,
Belum ada barang, Total IDR0, Bayar dan Kelola. Buffer PID4724 diperiksa:
0 penanda FATAL/Unhandled/ANR/E/flutter. Ini bukti startup, bukan seluruh regresi
atau bukti manual Gudang/Pengaturan. Ordinary sudah M5 sebelum handoff; schema
aktual belum diaudit terpisah, tidak mengklaim migration7→8 baru dijalankan.
Helper awal mencari judul Kasir, tetapi judul aktual nama toko; pemeriksaan
semantik diperbaiki ke komponen kasir, bukan bug aplikasi.

Kontrol otomatis Off. Pengguna diminta memeriksa Gudang/Pengaturan/data dengan
PIN pribadi; hasil masih pending. Release M5 tersedia terpisah; debug dipilih
untuk penggunaan pengembangan/Android Studio serta audit isolasi berikutnya,
bukan signing M6. Panduan: [Android Studio](ANDROID_STUDIO_RUN_AND_HANDOFF.md).

## Checklist A–G dan bukti

| Checkpoint | Kontrak wajib | Implementasi / pengujian saat ini |
| --- | --- | --- |
| A | Ukuran eksak/unit, rak/catatan null; create/edit/cart/draft/snapshot/migrasi/backup | IMPLEMENTED; host50PASS35s + UI2PASS; Poco native1PASS49s/DV1PASS59s; analyzer No issues9,9s. Form OEM/manual belum diuji |
| B | Strong biometric opt-in/binding/PIN fallback; sesi 1/5/15/immediate; fresh auth dan stale callbacks | IMPLEMENTED IN SOURCE; host30PASS03:08 mencakup12kasus B/UI, analyzer No issues105,1s; Poco10PASS/DV9PASS+SDK1PASS, backup native1per perangkat; fisik biometrik belum diuji |
| C | Cetak recovery nonpersisten, autentikasi baru, konfirmasi target/rahasia, tanpa auto retry | IMPLEMENTED; host49PASS + focused19PASS (subset/additional), analyzer No issues7,5s; native10per perangkat dan restore-lease Poco1PASS; paper recovery nyata belum diuji; QR/mnemonik opsional ditunda |
| D | Numpad/uang cepat per currency; tender/applied/change/debt snapshot atomik/struk | IMPLEMENTED schema12; host D8, DV D8, Poco D7sebelum tambahan fallback; backup terbaru kedua perangkat1PASS. Numpad/tender/legacy/idempotensi teruji otomatis; sentuhan fisik baru belum diuji |
| E | CSV/XLSX konsisten/paged/eksak/aman formula; SAF/progress/cancel | IMPLEMENTED; E host4 + UIcancel1PASS, native E3per perangkat; reader Python/openpyxl independen129row/64bit/formula/barcode PASS. SAF nyata/OEM belum diuji |
| F | USB Host printer class, selected-device permission/detach/ambiguous result, profil transport | IMPLEMENTED/schema11; bukti adapter/JVM/UI historis tetap. DV raster41717byte/11chunk accepted; logo/barang/nominal sesuai reported, footer terlihat setelah3LF tambahan. Host77 mencakup default6/saved3, nativequeue Poco1PASS16s output fake; paper default6/Poco USB/fault fisik belum diuji. [Laporan akhir](M51_FINAL_REPORT_20261021.md) |
| G | Kandidat sesudah backup valid; idle/lease lintas engine/threshold/cooldown; encrypted VACUUM | IMPLEMENTED schema13; WAL native Poco2/DV2PASS, backup final DV2PASS99s termasuk kandidat-fault; host77 mencakup G/WAL/schedule. Natural idle/reboot/Doze belum diuji |
| Handoff | Ordinary terbaru dan Android Studio | COMPLETE pada cakupan pengembangan: debug/release0.5.1+8 verified3ABI/16KiB/signature; debug in-place Poco dan dua startup kasir PASS/controlOff. Manual PIN/release runtime belum diuji |

PASS otomatis, PASS manual dilaporkan pengguna, BLOCKED dan NOT TESTED dicatat
terpisah saat bukti tersedia. Tidak mengulang seluruh kampanye M5 tanpa sebab.

## Batas saat ini

### Bukti checkpoint A

Schema9 aditif, metadata ukuran integer thousandths, pasangan null/value-unit,
rak80/note1000 Unicode; tidak mengubah unit dasar/HPP. ProductAttributes dipakai
domain/form/detail/cart, snapshot checkout menyimpan metadata nullable; encoder
struk tetap mengecualikan catatan internal. Create/edit/clear, parserID/EN,
legacy8→9, draft reopen, checkout/HPP/stok/barcode/snapshot historis diverifikasi
host. Suite regresi kasir/grosir/dus50PASS35s mencakup3kasus A (bukan53kasus).
UI2bahasa sempit/text2x/long-note/pay-visible PASS terpisah.

Native menggunakan test_m51_android.ps1 → test_android.ps1, package integration,
tanpa uninstall/reset/downgrade. Backup/restore SQLCipher lintas key menambahkan
metadata produk dan sale items pada fingerprint lengkap; Poco1PASS49s,
DV1PASS59s. Ini fixture pada masing-masing perangkat, bukan bukti transfer
berkas fisik Poco→DV atau pengisian keyboard OEM. Setiap file lama yang dilindungi
(ordinary jika ada, DB/arsip fixture dan wrapped secrets) sama pada audit sesudah.
DV ordinary absent, bukan bukti preservasi ordinary yang tidak ada; awake pulih
dan readback tepat. [Ringkasan hasil](evidence/m51-20261019/a-native-results.json).

Percobaan Poco pertama FAIL dipertahankan: satu BackupService fault-test belum
diberi platform namespaced; key_missing mendahului StateError yang diharapkan.
Audit awal juga memasukkan no_backup/androidx.work.workdb WAL/SHM. Pembandingan
terpisah membuktikan hanya dua berkas WorkManager itu berubah, seluruh bisnis/
wrapped secret sama. Dependency fixture dan filter **hanya nama WorkManager**
diperbaiki, tanpa mengendurkan pemeriksaan data bisnis. Namespace fixture
ditolak pada ordinary, restore meneruskan dependency platform ke consent store.
Hash dibatch pada perangkat agar326file tidak memerlukan326roundtrip ADB.
Analyzer awal memiliki2lintinfo pada iterasi berbeda, diperbaiki; hasil final
No issues9,9s. Log privat/build berisi before/after, runner, failure dan retest.

Pengguna menunda pemeriksaan manual ordinary Gudang/Pengaturan dan meminta
melanjutkan tahap berikutnya. Handoff M5 tetap terpasang; manual bukan PASS.

Tidak ada bukti fisik baru biometrik, printer USB, cetak recovery atau UI M5.1.
Hasil M5 pada 13 arsip/8 snapshot/23 tabel dan batas natural21/Doze/OEM tetap
sebagaimana [laporan akhir M5](M5_FINAL_REPORT_20261019.md).

### Checkpoint B — pemeriksaan berlangsung

Schema10 menambah management_policy singleton. Instalasi lama memakai legacy
(kunci background dan idle5menit), instalasi baru immediate (idle5menit).
Pilihan1/5/15menit mengukur idle termasuk background; resume tidak memperpanjang.
Layar pengelolaan disembunyikan/FLAG_SECURE, form dipertahankan di Offstage dengan
focus/semantics dimatikan; kasir/draft publik tetap tersedia. Scope dialog sistem
mempunyai request/generation/deadline60detik; external activity penuh masih
memerlukan PIN pada immediate, callback lama tidak menghidupkan sesi.

AndroidX Biometric1.1.0 Class3+Keystore AES256/GCM CryptoObject per-use memakai
alias sendiri terikat epoch PIN/installation. Tidak menerima weak face/device
credential. App PIN/KDF600k/lockout tetap, enabling dan kebijakan perlu fresh PIN.
Fresh proof60detik terikat recovery/security/restore/recoveryPrint. Binding tidak
portable dan tidak menjadi key database/backup. Belum ada bukti autentikasi fisik
atau build Android B pada checkpoint ini.

Bug nyata: service A masih dapat membaca gudang setelah service B mengganti PIN.
Before7PASS/1FAIL (`build/m51-b-security-before.log`), focused after1PASS18s.
Authorizer kini membandingkan epoch credential tersimpan di lease DB pemanggil,
termasuk sebelum protected commit/hasil. Tidak mengubah aturan stok/uang atau
memindahkan SQL ke Provider. Host regresi final30PASS03:08 meliputi9domain sesi,
3UI, protected read1, inventory15 dan atribut3. Subset bukan tambahan jumlah unik.

Percobaan helper UI sempat timeout/runAsync reentrant dan finder melihat frame
lama. Setup/cleanup real IO dipindah ke setUp/tearDown; event memulai SQL di zona
real-async dan frame dipompa sebelum pemeriksaan visibility. Log gagal dipertahankan
(`m51-b-ui-retest.log`, `m51-b-ui-retest2.log`), tidak dianggap bug tambahan atau
PASS. Final log `m51-b-regression-retest.log`. Analyzer final105,1s No issues.
Validasi staging backup menolak policy tidak dikenal serta memeriksa tipe/panjang
metadata sebelum mengambil teks; native backup retest setelah perubahan masih
pending. Regresi C20/SAF/notifikasi/headless diperlukan sebelum B ditutup.


Checkpoint B lanjutan: DV9PASS02:22 pada SQLCipher/KDF native dengan outcome
biometrik sintetis; semua hash berkas lama yang dilindungi sama dan awake pulih
readback exact. [Hasil](evidence/m51-20261019/b-dv-security-result.json).
Build Android pertama berhasil58,0s; bukan bukti fingerprint/face nyata.
Regresi M5 awal56PASS/6FAIL03:53: enam helper recovery belum mengikuti fresh auth.
Sesudah pembaruan, UI penuh31PASS03:04, ditambah31kasus nonUI yang sudah PASS
pada run pertama (62kasus unik dalam cakupan suite ini; retry/subset tidak ditambah).
C20 denial/retry/regrant, SAF cleanup, akun/target/histori Drive, headless scheduler,
alert dedup dan antrean printer/regresi uang tetap diperiksa. Log gagal/helper
navigasi tetap di build: fresh grant tidak boleh disamakan dengan lazy widget sudah
terbangun atau posisi scroll tombol reveal masih di bawah. Kode dibuang pada
lock sesuai kebutuhan baru; tes tidak lagi meminta recovery muncul otomatis
setelah unlock. Poco10/native backup/final analyze masih sedang dilanjutkan.


### Penutupan otomatis B pada cakupan tersedia

Poco sesi10PASS01:31 (9domain sintetis +1API status Class3/keyguard native), DV
9PASS02:22 +1API status native00:17. Keduanya tidak menguji sidik jari/wajah manusia.
Backup native terbaru Poco1PASS00:56/DV1PASS01:17 memverifikasi fresh auth,
manifest/schema10/metadataA, ciphertext cross-key/safety/failure/restore relock.
Seluruh hash berkas lama yang dilindungi sama pada setiap run; DV awake pulih
readback exact. Ordinary M5 tidak diganti. Kontrol otomatis Off. Bukti JSON pada
`docs/evidence/m51-20261019/b-*-result.json`, log rinci privat di build.

Tambahan host2PASS00:04: metadata version cocok pubspec dan logical staging
menolak forged policy, tipe/ukuran metadata berbahaya, NUL, pasangan parsial;
akhir fixture quick_check/FK bersih. Ini bukan arsip terenkripsi native tambahan.
Source masih melabeli About/manifest0.5.0+7 sesudah pubspec naik0.5.1+8; satu
app_version.dart sekarang dipakai keduanya dan test mencegah drift versi source.
Build override versi kustom tetap harus diselaraskan dengan declared release.
Tidak menulis ulang manifest arsip M5 lama. Helper native fresh restore dibenahi
ke PIN target publik0002 sebelum restore,0001 setelah restore; setiap baseline
hash fault dicapture sesudah fresh auth karena credential/audit memang berubah.
Kesalahan import pada iterasi dan fixture belum unlock disimpan pada log gagal,
lalu2PASS; tidak diklaim bug atau hasil perangkat.

Analyzer checkpoint sebelum tambahan metadata/helper No issues105,1s; formatter
file terakhir sudah dijalankan. Full analyze berikutnya tetap diperlukan pada
penutupan group berikut/M5.1. Natural lifecycle/prompt biometrik fisik, enrollment
change nyata dan OEM behavior belum diuji. C–G masih wajib diimplementasikan.


### Checkpoint C — cetak recovery dan regresi otorisasi printer

[Jalur cetak recovery](M51_RECOVERY_PRINT.md) memuat kontrak, source dan batas.
Windows9PASS18s awal; regresi49PASS04:08 mencakup9recovery/33UI/7antrean. Tambahan
repro kalibrasi stale PIN1FAIL00:08: prepareCalibration hanya memeriksa RAM.
Kini epoch diverifikasi pada lease DB sebelum commit; konteks history dinyatakan
oleh caller dan dicek pada prepare/preview, tanpa menambah PIN pada salinan kasir.
Focused19PASS01:13 mencakup10antrean (3tambahan) +9recovery subset. Tidak menjumlah
ulang subset/retry. Analyzer7,5s No issues. Tambahan native khusus epoch dan host
setelah wipe input UTF8 sedang disiapkan; hasil tidak diasumsikan lulus.

Poco10PASS01:15/DV10PASS01:29 pada key publik/output fake/SQLCipher/KDF native;
case ke10 memeriksa mutex output Android sesungguhnya, tidak mencetak.
Restore dengan pause/await-resume lease printer produksi Poco1PASS00:58; seluruh
hash lama yang dilindungi sama; DV awake pulih exact. Full API/physical receipt
printer belum diuji pada M5.1. Uji USB PC tetap terpisah dari recovery dan OTG.
Buffer PID fixture Poco13837 tersedia:0fatal/unhandled,0E/flutter;11baris tag
native/OEM/graphics/startup dicatat, tidak diklaim seluruh log bersih/semuanya
harmless. Scope buffer tersedia bukan monitor ANR seluruh sistem.

C tidak menambah migration. Permission/printer layout/transport tetap service;
no Provider global. Secret tidak masuk print_jobs/receipt/job filename atau
clipboard otomatis. Claim fresh opaque single-consumer mencegah reuse proof
antarservice saat output sedang ditahan. Lease satu dokumen berlaku juga untuk
struk, koneksi manual dan restore; lock order output→DB. QR/mnemonik ditunda
sebagai opsional, bukan stub selesai. C paper/biometrik fisik/OTG Android masih
UNVERIFIED. D/E/F/G wajib berlanjut; M5.2 tetap menunggu desain/M6 tidak dimulai.
