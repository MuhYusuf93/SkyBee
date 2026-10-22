# Handoff ke chat baru — M5.1, 20 Oktober 2026

**SUDAH DILANJUTKAN DAN DITUTUP21 Oktober2026** pada cakupan implementasi,
pemeriksaan tersedia dan handoff pengembangan. Ordinary debug0.5.1+8 sudah
terpasang/dibuka Poco; release tersedia. Formatter/analyzer/host77/migrasi1/
nativequeue1/reader independen PASS. Kontrol perangkat Off. Acuan berikutnya
[laporan akhir](M51_FINAL_REPORT_20261021.md) dan STATUS terbaru. Jangan mengulang
langkah pending di checkpoint lama ini atau me-reset data. Paper default6,
biometrik/SAF OEM/natural worker/manual PIN tetap belum diuji; Realme tetap
dijeda. M5.2 menunggu desain/instruksi, M6 tidak dimulai.

Isi di bawah adalah checkpoint historis sebelum resume, dipertahankan sebagai
jejak bukti dan batas otorisasi, bukan status aktif.

Pengguna meminta pindah chat. **M5.1 belum ditutup. Jangan mulai M5.2/M6.**
Kode dan hasil tes di repository adalah titik lanjut; jangan mengulang kampanye
M5 yang sudah selesai, mereset data, mengganti identitas, commit/push atau
mengembalikan working tree ke baseline lama. Baca AGENTS.md, SPEC, PLAN, STATUS,
LESSONS-LEARNED dan laporan M51_IMPLEMENTATION_REPORT serta
M51_CASH_REPORT_EXPORT_MAINTENANCE terlebih dahulu. Kontrak lengkap tersimpan di
`docs/decisions/M51_REQUEST_20261019.md`.

## Arahan pengguna yang tetap berlaku

- Poco F6 dan printer **berbagi satu kabel USB**. Poco sengaja dicabut ketika
  printer dipakai DV. Jangan menyebut ini gangguan debugging atau meminta kedua
  perangkat terhubung bersamaan. Urutan: cetak DV/verifikasi kertas, lalu pindah
  kabel ke Poco untuk audit akhir dan handoff ordinary. Periksa ADB aktual lagi.
- DV8910=`192.168.0.102:5555`, model AX810/firmware DV8947-KIX diterima.
  Pengguna mengizinkan perintah awake sementara dan memaksa izin USB **printer
  khusus pengujian**. Izin Android normal UID fixture10115 telah dipakai; tidak
  perlu root/force grant bila sudah tersedia. Kembalikan awake exact lewat wrapper.
- Poco=`7f0edea0`/24069PC21G. Realme C11=`0062112V2210F9B3` **dijeda/pribadi**;
  jangan melanjutkan worker lama tanpa audit nonce1792404362140 dahulu.
- Tes native hanya `tools/test_m51_android.ps1` → `tools/test_android.ps1`, package
  `com.example.kasir_app.integration`, flag isolasi dan no-uninstall. Tanpa reset,
  uninstall/downgrade atau mengubah aplikasi/sistem lain. Snapshot hash biasa dan
  fixture sebelum/sesudah wajib, pengecualian hanya nama WorkManager/gate tepat.
- Serialize source edits, SDK analyze/test/build dan device mutations. Jangan
  menjalankan dua job mutasi repository/perangkat sekaligus.
- Handoff aplikasi utama terbaru ke Poco diotorisasi; nama/applicationId tetap
  kasir_app/com.example.kasir_app. Izin dummy sebelumnya bukan alasan reset:
  tidak ada reset yang dipakai. Lindungi data/key sebelum in-place install.

## Kondisi source dan Git

- Source **0.5.1+8/schema13**. A–G mempunyai implementasi; optional QR/mnemonik
  belum dibuat. M5.2 PLANNED menunggu desain pengguna, M6 belum dimulai.
- Baseline historis awal `dbcc5db3b2a13fd0b09bb896987efa053560d440`.
  HEAD saat menulis handoff **b975fe303d98615d2df96f2dc1f3bbecc4cd732e**;
  banyak modified/untracked sudah ada. Jangan reset/stash/checkout baseline lama.
- D: TenderDigits/CashTender, numpad/quick per currency, checkout_tenders dan
  draft raw/mode, snapshot tender/change. Legacy tidak dibackfill.
- E: snapshot laporan M4, keyset100row, CSV/XLSX exact text/anti-formula,
  staging bounded, SAF dua fase/auth/readback/cancel native.
- G: kandidat sesudah backup valid, backup-work→DB nonblocking, idle/charging,
  VACUUM SQLCipher in-place, checkpoint WAL tanpa menunggu reader, File.length
  nyata, integrity/HMAC/fingerprint/rekonsiliasi, tidak prune/rekey.
- Perbaikan terakhir `backup_service.dart`: catch **seluruh tahap maintenance
  opsional sesudah artifact/index valid**, bukan hanya scheduler. Trigger fault
  kandidat sebelumnya membuat backup valid dilaporkan gagal; sudah diretest.

## Bukti akhir yang benar-benar sudah ada

| Run privat di build/ | Hasil |
| --- | --- |
| m51-deg-dv-final-20261019-221306 | D8/E3/G5/nativegate1 =17PASS302s; hash lama sama/awake exact/controlOff |
| m51-backup-dv-final-20261019-222002 | portable1PASS80s, data tender/config/metadata lintas key |
| m51-backup-poco-final-20261019-222320 | portable1PASS60s, hash lama sama |
| m51-wal-poco-final-20261020-020633 | DELETE+WAL2PASS42s, berkas17780736→638976 sebelum close |
| m51-wal-dv-final-20261020-020921 | DELETE+WAL2PASS60s, berkas17780736→638976; awake pulih |
| m51-candidate-dv-before-20261020-021623 | repro1FAIL19s pada UPDATE kandidat sesudah archive/index selesai |
| m51-backup-final-dv-20261020-022651 | **2PASS99s**: full portable restore normal + candidate failure tetap menghasilkan archive terautentikasi/index1; seluruh hash lama sama/awake exact/controlOff |
| m51-usb-raster-v2-20261020-022418 | **1PASS6s**, satu dokumen,11chunk/41717byte accepted, normal USB permission; seluruh hash lama sama/awake exact/controlOff |
| m51-usb-feed-only-20261020-023132 | **1PASS4s**, hanya3LF/3byte, tanpa cetak ulang; hash lama sama/awake exact/controlOff |

Host sebelum perubahan feed terakhir: final49PASS208s; export cancel repro1FAIL
→UI+E5PASS19s; WAL repro1FAIL (logical634880/mainfile17444864)→host8PASS29s,
termasuk reader BEGIN DEFERRED/nonblocking/timeout tetap. Log/detail di laporan
D/E/G. Pembaca Python CSV/openpyxl independen129row/64bit/formula/000123 PASS.
Jangan menjumlah subset/retest menjadi kasus unik baru.

Poco percobaan `m51-candidate-before-20261020-021458` **BLOCKED sebelum test
dimulai**, setelah APK fixture dipasang, karena kabel sengaja dipindah ke printer.
`result.json`: isolation NOT CHECKED/controlOff. **Audit endpoint tertunda**:
bandingkan setiap pre-existing protected hash pada before.json dengan capture
tertutup baru; simpan late-after terpisah. Jangan klaim preservation interval ini
sebelum cocok; jangan menyalahkan tes jika pengguna memakai app selama jeda.

## Cetak, footer, dan perubahan PALING TERAKHIR

- Percobaan awal raster0target/0byte SKIPPED; sesudah kabel dipindah request USB
  timeout24s/0byte, lalu izin normal diberikan pada dialog yang diamati.
- Helper raster v1 kemudian FAIL usb_invalid_chunk5s: satu buffer >4096.
  `UsbPrinterIo` menolak **sebelum Link.transfer**; queue produksi sudah4096.
  Helper diperbaiki ke chunk4096 dalam satu output lease, guard tidak dilonggarkan.
- V2 mengirim41717byte. Pengguna melaporkan logo M51, judul,5barang/grosir,
  total42000/tender50000/change8000/paid42000/debt0 sesuai. Footer belum terlihat.
- Sesudah hanya tambahan3LF, jawaban terakhir pengguna persis:
  **“ya terlihat namun footer sebelumnya tidak tercetak sama sekali”**.
  Catat footer kini terlihat menurut pengguna; **belum dipastikan apakah
  sebelumnya tertahan di dalam printer atau menunggu flush/advance**. Jangan
  menyimpulkan sebab dari dugaan awal, atau mengklaim seluruh jalur baru terbukti.
- Source terakhir mengubah default `PrinterProfile.feed` **3→6** untuk profil
  baru; controller printer memakai default yang sama. Explicit saved feed3 tetap
  3 (tidak migrasi/menimpa kalibrasi pengguna). Queue/recovery sudah mengirim LF
  sesuai profile. Test queue diperkuat untuk enam LF, legacy feed3 dan fakta uang.
  **Perubahan default6 dan assertion terbaru belum dijalankan host regression.**
- Probe helper kini mode `KASIR_PUBLIC_USB_FEED_ONLY=true` khusus tiga LF dan
  marker sendiri. Marker lama tidak dihapus; **jangan menjalankan ulang raster
  v2/feed-only** karena keduanya sudah submitted. Nama marker:
  `m51_usb_raster_cash_20261019_v1.attempt` (reject sebelum transfer),
  `m51_usb_raster_cash_20261020_v2.attempt` (submitted),
  `m51_usb_feed_20261020_v1.attempt` (submitted). End-to-end struk baru default6
  belum dicetak; jangan mengirim diagnostik baru otomatis saat resume.

## Titik berhenti: tes/build/handoff masih HARUS dilanjutkan

1. Tidak ada job SDK/perangkat yang perlu ditunggu. Runner terakhir final/control
   Off; awake DV telah dipulihkan/readback exact. Pada pemeriksaan handoff terbaru
   ADB daemon baru dimulai dan **devices kosong**, sehingga tidak ada pemeriksaan
   ulang live settings yang berhasil. Jangan menganggap perangkat masih online.
   Get-Process tidak menemukan dart/flutter_tester/java, hanya shell pemeriksaan.
2. Pipeline terakhir berhenti **di formatter**, sesudah native backup2PASS99s:
   `build/m51-final-format-check.log` melaporkan quick_cash_service.dart dan
   m51_report_export_suite.dart belum formatted. Keduanya **sudah diformat** pada
   job feed-only berikutnya, tetapi formal formatter check belum diulang.
3. `build/m51-final-analyze.log` adalah **log lama19-Oktober21:57** dengan warning
   BytesBuilder, bukan analyzer akhir source sekarang. Salinan historis ada di
   `build/m51-20261019-analyze-deprecated-bytesbuilder.log`; checkpoint sebelumnya
   `m51-final-analyze-clean2.log` No issues. **Jalankan analyze baru** dengan nama
   log unik setelah perubahan feed, jangan menganggap file bernama final terbaru.
4. Jalankan formatter check, analyze, host regresi relevan (daftar di bawah),
   reader CSV/XLSX independen. Jangan mulai native sebelum endpoint Poco tertutup
   atau baseline baru dijelaskan. Tidak perlu mengulang full M5 campaign.
5. Build ordinary **debug dan release**0.5.1+8/3ABI; verifikasi package/launcher/
   SQLCipher/KDF/ELF-ZIP16KiB/resource/license/signing/hash dengan verify_m5_apk.py.
   **Belum ada ordinary M5.1 final APK/build/handoff baru.** Ordinary M5 0.5.0+7
   historis tetap terakhir yang dipasang. M51 fixture bukan ordinary.
6. Handoff Poco in-place setelah audit/proteksi. `tools/handoff_m51_ordinary.py`
   sudah dibuat/syntax checked, **belum dijalankan**. Ia memerlukan pointer
   build/m51-final-handoff-current.txt ke direct-child build/m51-final-handoff-*
   berisi kasir-app-0.5.1-ordinary-debug.apk dan debug-apk.json. Jangan gunakan
   pointer/artefak lama tanpa verifikasi. Snapshot tertutup privat same-install
   bukan portable backup/Keystore export. Tidak uninstall/reset/downgrade.
7. Periksa launch ordinary, log PID/semantik kasir dan wrapped key setelah migrasi.
   DB boleh berubah karena schema8→13; jangan menuntut byte-identik setelah startup
   atau mengarang akses Gudang/Pengaturan jika PIN pribadi belum diuji pengguna.
8. Tutup laporan/evidence/status/requirements dan Android Studio handoff dengan
   hasil aktual; sebagian top-level docs masih checkpoint sebelum final. Update
   bukti paper terbaru/ambiguitas footer, default6/legacy3 dan keterbatasan.

Contoh host (bukan native/bukan satu pipeline paralel):

```powershell
flutter test test/m51_cash_test.dart test/m51_report_export_test.dart test/m51_report_export_ui_test.dart test/m51_space_test.dart test/m51_space_schedule_test.dart test/m5_checkout_test.dart test/m5_print_queue_test.dart test/reports_corrections_sql_test.dart test/money_test.dart test/m51_usb_test.dart test/m51_backup_metadata_test.dart
python tools/verify_report_exports.py
```

Nama yang benar **reports_corrections_sql_test.dart**. Pipeline yang sudah stop
memuat typo reports_corrections_test.dart pada perintah yang **belum dieksekusi**;
jangan menyalin typo itu atau membuat alias test palsu. File suite print queue
aktual adalah test/m5_print_queue_test.dart (fungsi m5PrintQueueSuite), settings
test/m5_settings_ui_test.dart; jangan mengandalkan nama support fiktif.

SDK: Flutter C:\Users\ACER\dev\flutter\bin\flutter.bat; Android SDK
C:\Users\ACER\AppData\Local\Android\sdk; Python bundled
C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe.
APK/DB/key/arsip/log privat hanya ignored build/, jangan dimasukkan ke Git publik.
SAF laporan nyata/OEM, biometrik fisik, natural idle/reboot/Doze, USB Poco/80mm,
TalkBack dan release runtime terbaru tetap UNVERIFIED. M5.2 menunggu desain.
