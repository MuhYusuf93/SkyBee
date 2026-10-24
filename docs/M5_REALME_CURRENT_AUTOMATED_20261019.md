# Realme C11 — regresi otomatis M5 pada source terkini

19 Oktober 2026. Pengguna meminta USB DV diprioritaskan, lalu meneruskan M5
pada Realme tanpa uji manual. Ini melanjutkan bukti historis, termasuk 88 kasus
SQLCipher Realme terdahulu; tidak menganggap semua acceptance Poco juga lulus
di Realme. Source saat ini 0.5.1+8/schema11, mencakup A–C dan adapter F M5.1.
M5.1 D/E/G belum dibuat, M5.2 menunggu desain, M6 tidak dimulai.

## Preflight dan batas perlindungan data

Serial terkonfirmasi `0062112V2210F9B3`, RMX3231, Android11/API30,
`armeabi-v7a,armeabi`; layar720×1600/density320. Snapshot memori total1914140kB,
tersedia830148kB; ruang data3634296KiB tersedia (86% terpakai); baterai66%,
temperature422 (42,2°C, sensor baterai). Nilai sesaat bukan bukti penyebab bug
atau benchmark. Keyboard aktif Gboard, bukan bukti input fisiknya diuji ulang.
Tidak ada aplikasi lain dihentikan atau pengaturan sistem diubah.

Ordinary package tidak terpasang. Fixture lama release0.4.0+6 tidak debuggable,
sehingga run-as tidak bisa membaca hash database sebelum update. APK asli
disimpan privat; identitas/signing diverifikasi, lalu hanya package
`com.example.kasir_app.integration` diperbarui in-place ke debug0.5.1+8.
Tidak launch/SQL/reset/uninstall/downgrade pada bootstrap. Sertifikat SHA256
`002029d011716641cfb6c8490df92d309920c38be4150770ed14423dd37fcd4c` sama.
Baseline semua berkas DB/no_backup tertutup diambil sesudah update, sebelum tes.
Perbandingan berikut membuktikan interval tes tersebut, bukan byte comparison
sepanjang update APK lama. Artefak privat ignored di
`build/m51-realme-audit-bootstrap-20261019-152021/`.

Runner: `tools/test_m51_android.ps1` → `tools/test_android.ps1`, target eksplisit,
define isolasi/no-uninstall, guard package/ABI, hash sebelum/sesudah dan kontrol
otomatis Off pada finally. Snapshot business lama tidak dipakai sebagai fixture.
Fixture activity mempertahankan layar aktif melalui flag window saja, tidak
mengubah timeout/sistem. Keystore root recovery/Drive/anggaran retry kampanye
harus tetap utuh; tes fault memakai namespace sendiri dan fresh auth aktual.

## Checkpoint pengujian

| Kelompok | Status saat dokumen dibuat |
| --- | --- |
| USB DV USB Host/port baru | BLOCKED_NO_USB_TARGET: 0 target, 0 byte; paper belum diuji |
| Adapter host/JVM/UI | Host27PASS58s; UI USB2PASS10s; JVM19PASS19s; analyzer No issues6,4s |
| Native Realme schema/enkripsi/migrasi | PENDING |
| Backup/restore/authentication/fault | PENDING |
| Antisubmit/uang/stok/piutang | PENDING regresi M5; bukti lama tetap terpisah |
| UI printer/PIN/SAF/Drive dan callback | PENDING; SDK/HTTP/output tiruan dijelaskan per suite |
| Headless/alert/scheduler | PENDING pemeriksaan otomatis yang tersedia |
| Google nyata/printer nyata pada Realme | NOT TESTED; tidak memilih akun pribadi atau mengirim cetak |
| Keyboard OEM/touch/TalkBack/biometrik fisik | NOT TESTED pada run ini; pengguna meminta tanpa manual |

Full host UI yang terhenti saat limit dicatat partial29, bukan full PASS.
USB UI pertama2FAIL karena finder belum hit-testable sesudah scroll/frame;
helper menunggu frame dan memastikan target terlihat, lalu2PASS. Tidak ada
pelonggaran authorizer/validasi aplikasi atau timeout untuk membuatnya lulus.
Log gagal tetap di ignored build. USB physical probe memakai flag eksplisit,
allowlist VID0483/PID5720 dan marker sebelum write; tidak mengulang otomatis.

Hasil suite, log PID sendiri, batas OS/alat, hash isolasi dan pekerjaan tersisa
ditambahkan berdasarkan bukti setelah setiap kelompok. Natural21/reboot/Doze,
akses Google nyata atau hasil paper tidak diturunkan dari PASS mock otomatis.

## Hasil aktual lanjutan

Tabel PENDING di atas adalah checkpoint awal, bukan hasil akhir berikut.
Semua completed run di bawah membuktikan hash setiap berkas lama yang dilindungi
tidak berubah dan kontrol otomatis Off pada finally. Ordinary tetap absent.

| Suite native Realme | Hasil aktual |
| --- | --- |
| USB | 7PASS/1FAIL01:46 awal; focused migration10→11 1PASS00:23 sesudah perbaikan mock;8kasus unik lintas run, bukan full final8 |
| Enkripsi | 3PASS00:52; SQLCipher4.19.0 community, fresh/reopen, plaintext7 export dan streaming AEAD |
| Migration fault | 5PASS00:42; empat fase promotion/reopen + ruang kurang/future schema |
| Backup lintas key/metadata | 1PASS01:27; safety, snapshot lease dan rekonsiliasi |
| Restore fault | 0PASS/4FAIL02:00 awal key_missing; setelah namespace konsisten4PASS02:54, tiap fase yang diminta benar-benar tercapai |
| Wrong recovery/arsip | 1PASS00:27; preview lama dibersihkan/fakta aktif tetap |
| Checkout antisubmit | 1PASS00:21; barrier submit ganda/lost response/reopen satu hasil keuangan |
| Drive authorization | 4PASS00:17; SDK/HTTP sintetis, silent-null needs-auth/config error tanpa sukses palsu |
| UI settings | 31PASS/4FAIL09:34 awal; retest native pending di checkpoint ini |
| Security/recovery-output/operasional | Belum dijalankan pada checkpoint ini |

Host setelah koreksi helper: UI35+alerts3 =38PASS05:25, analyzer7,6s No issues.
Setelah menyiapkan namespace probe worker analyzer10,8s No issues. Bukan bukti
perangkat. Tes security tambahan membaca FLAG_SECURE aktual; alert tambahan akan
post/cancel ID sintetis yang absent pada baseline bila izin sudah ada, tanpa
dialog/Settings. Probe worker baru memiliki hash sepanjang workflow dan namespace
sendiri; root retry/recovery/origin milik kampanye lama tidak boleh ditimpa.

## Temuan dan klasifikasi sebelum retest native terakhir

1. **TEST — mock channel terlalu luas.** USB migration10→11 gagal
   `m5DatabaseKeyUnavailable` sebelum assertion karena mock USB menangkap
   Keystore untuk DB kedua. `test/support/m51_usb_suite.dart` melepas mock sebelum
   DB kedua dibuat/dibuka. Focused native1PASS00:23; seluruh tabel/DDL tetap dicek.
2. **TEST — namespace crypto tidak konsisten.** Empat restore fault gagal
   `key_missing` sebelum fault yang diminta: DB memakai default platform sedangkan
   BackupService memakai namespaced platform. `integration_test/m5_restore_fault_test.dart`
   menyuntik platform yang sama ke keduanya, fresh auth sesuai kontrak C dan hook
   output pause/resume. Tambahan faultReached wajib true;4PASS02:54. Tidak ada
   pelonggaran auth, rollback, validasi atau perbaikan data aplikasi.
3. **TEST — privacy call dianggap aksi Bluetooth.** Tiga failure UI menyertakan
   `protectedScreen` pada assertion empty/btPermissions. Helper
   `test/m5_settings_ui_test.dart` menangani lifecycle window-flag void terpisah
   dan hanya mengabaikannya pada assertion aksi Bluetooth; assertion negatif juga
   mencakup generic printerConnect/printerWrite. Native FLAG_SECURE diperiksa
   terpisah. Host finalPASS; native retest belum diisi sampai bukti tersedia.
4. **TEST — target belum hit-testable.** Satu failure Show saved code sesudah
   relock/navigation/scroll; helper menyelesaikan frame dan ensureVisible sebelum
   tap. HostPASS; belum menyimpulkan bug layout aplikasi tanpa native retest.

Tidak ada bug aplikasi baru terbukti dari empat kelompok ini. Log gagal tetap
disimpan, tidak dihapus atau diganti label PASS. Belum ada dasar meminta reboot.
Snapshot log enkripsi ownPID20648:56baris/0fatal-unhandled/0EFlutter/1Elibc belum
terklasifikasi; buffer kemudian tidak tersedia, jangan klaim semua log bersih.
Snapshot restore PID26112:9baris/0fatal-unhandled/0EFlutter, PSS162463KiB/
RSS152172KiB/swapPSS72174KiB; satu sampel bukan peak atau bukti bebas leak.

## Titik berhenti — Realme dipakai pribadi, 19 Oktober2026

Pengguna mengalihkan fokus ke DV8910. Tidak ada antrean/kontrol host Realme aktif;
stop flag menahan runner kampanye dan worker sampai ketersediaan diotorisasi lagi.
Tidak meminta reboot. APK terakhir fixture debug0.5.1+8; ordinary tetap absent.

- UI retest34PASS/1FAIL09:40: satu assertion kedua saat regrant masih memakai raw
  calls. Helper itu diperbaiki ke operasi Bluetooth yang sama. Focused native
  1PASS00:37, sehingga35kasus UI unik mempunyai PASS lintas run, bukan satu
  full finalPASS. Seluruh assertion bisnis/PIN tetap.
- Security11PASS03:01 termasuk FLAG_SECURE aktual dan status Class3/keyguard;
  autentikasi biometrik fisik tetap belum diuji.
- Recovery-output11PASS01:57 termasuk native cross-owner output lease; output
  tiruan/key publik, bukan paper.
- Alerts3PASS00:52 pada suite operasional3PASS/1FAIL. Probe notifikasi gagal pada
  immediate read sesudah cancel; isi generik/visibility private sudah lolos.
  Retest bounded3detik tanpa cancel ulang1PASS00:00, firstReadVisible=false,
  removed=true pada7ms, native metadata juga absent dan ID lain tetap.
  Ini masalah asumsi immediate completion yang diperbaiki pada probe; mekanisme
  internal keterlambatan run pertama belum ditrace, bukan bug aplikasi terbukti.
- Antrean cetak SQLCipher10PASS03:28: double tap, partial/restart unknown tanpa
  retry, fakta finansial/snapshot pelunasan, stale epoch dan raster58/80mm.
  Tidak mengirim ke printer nyata.
- Host UI35+alerts3 =38PASS05:25; denial focused1PASS00:18 adalah subset.
  Tambahan delapan file host39PASS02:22 (queue/runtime/retry/schedule/Drive/
  manifest/generation). Analyzer final11,0s No issues. Kesalahan import probe
  sementara diperbaiki sebelum instalasi berikutnya; log/test failure lama tetap
  tersedia, tidak diubah menjadi PASS.

Total98kasus native unik mempunyai PASS lintas run saat ini, termasuk hasil
sebelum checkpoint dan focused retest. Angka bukan pengganti matriks cakupan.
Setiap completed runner sampai antrean cetak membuktikan semua hash berkas lama
yang dilindungi sama/kontrol Off. Bukan klaim seluruh interval berikut tetap.

**Worker terputus/BLOCKED:** nonce1792404362140 sempat setup PID3467 dengan state
scheduled. Realme kemudian tidak terdeteksi ADB, sehingga result/reader/cleanup
callback dan hash sesudah tidak diperoleh. Sebelum probe, metadata WorkManager
tertutup konsisten:0pending/0terminal. Probe memakai namespace sendiri untuk DB,
origin/recovery/retry, tetapi ini tidak menggantikan audit sesudah. Jangan klaim
worker PASS, job sudah dibatalkan, callback sudah pulih atau preservation akhir.
Tidak mencoba ulang/mereset saat HP dipakai pribadi. Bukti privat:
`build/realme-current-worker-1792404362140/`.

Saat Realme kelak tersedia: audit exact nonce/marker/WorkManager dan bandingkan
seluruh key before.json sebelum menulis; bila selesai, jalankan reader nonce
yang sama; bila tertunda, retire hanya task nonce ini dan pulihkan callback
produksi melalui cleanup terisolasi. Jangan menjalankan setup baru terlebih
dahulu, merotasi root recovery/retry atau memakai wrapper legacy tanpa guard.
Google nyata, paper Realme, OEM/touch/TalkBack/lockscreen/biometrik fisik,
release runtime terkini, natural21/reboot/Doze tetap NOT VERIFIED pada run ini.

Addendum23Oktober2026: interval worker yang tertunda di atas telah diaudit
dan ditutup, tanpa replay setup. Semua257entri baseline awal cocok; metadata
terminal sebelum update membuktikan succeeded, reader/cleanup retest2PASS6s
dan callback produksi pulih. Failure/raw BLOCKED19Oktober tetap dipertahankan.
Delta schema14/AOT dan worker current memakai hasil sesi lanjut tersendiri,
bukan mengubah98kasus di laporan ini menjadi hasil source terbaru. Lihat
[laporan kelanjutan](REALME_C11_RESUME_20261023.md).
