# C31 — status otorisasi ulang Google pada jalur silent

18 Oktober 2026. Perbaikan terarah M5; C30 tetap terpasang di Poco selama
pengguna memeriksa heading daftar cloud dan riwayat lokal. Tidak ada kontrol
perangkat, panggilan akun nyata, upload, restore, atau perubahan database
perangkat pada checkpoint host ini. M6 tidak dimulai.

## Temuan dan penyebab

Kontrak SDK resmi lokal `google_sign_in_platform_interface` 3.1.0 pada
`clientAuthorizationTokensForScopes` menyatakan hasil null bila diperlukan
prompt tetapi request tidak mengizinkannya. Implementasi aplikasi memang
mengirim `promptIfUnauthorized: false` dengan akun tujuan eksplisit. Namun,
hasil null dilempar sebagai `StateError('driveNeedsAuthorization')`, sedangkan
UI dan scheduler mengklasifikasikan hanya `DriveFailure`. Akibatnya kebutuhan
otorisasi ulang menjadi kegagalan umum. Ini bug klasifikasi aplikasi yang
direproduksi dengan SDK sintetis, bukan kegagalan akun Google pengguna yang
teramati pada perangkat.

Tidak ada bukti kehilangan data atau upload ke akun salah pada kasus ini.
Identifikasi akun gagal sebelum HTTP, pembuatan run dan arsip. Jangan menyamakan
hasil ini dengan bukti pencabutan izin akun nyata atau pemicu jadwal alami.

## Perbaikan

- `lib/features/backup/application/drive_authorization.dart`: exception bertipe
  `DriveAuthorizationRequired` khusus untuk hasil silent null, tanpa payload SDK.
- `lib/features/backup/application/drive_rest.dart`: petakan tipe tersebut ke
  `DriveFailure('driveNeedsAuthorization')` non-retryable. Kegagalan SDK lain
  tidak diubah menjadi kebutuhan consent. Tidak memanggil UI dari worker.
- `test/m5_drive_authorization_test.dart`: empat kasus sumber token/transport
  nyata dengan batas SDK/HTTP sintetis, termasuk token sah, konfigurasi SDK
  gagal, feedback UI dan penjadwal dengan DB fixture baru.
- `integration_test/m5_drive_authorization_test.dart`: entrypoint untuk suite
  yang sama pada SQLCipher terisolasi; belum dijalankan saat dokumen dibuat.

## Bukti sebelum dan sesudah

- `evidence/m5-20261018/c31-auth-before.log`: 2 PASS / 2 FAIL, durasi tes 2 detik.
  Failure pertama menunjukkan StateError, bukan DriveFailure; kedua menunjukkan
  `m5OperationFailed`, bukan `m5DriveNeedsAuth`. Kasus kedua berhenti di assertion
  UI, sehingga assertion scheduler belum dijalankan pada run sebelum perbaikan.
- `evidence/m5-20261018/c31-auth-after.log`: 4 PASS, durasi tes 2 detik.
  UI memberi status kebutuhan otorisasi, tidak macet; tiga pemanggilan scheduler
  pada hari yang sama hanya mencoba sekali, tidak menandai last_success,
  menyimpan kode kebutuhan otorisasi dan target hari berikutnya. Seluruh hash
  tabel di luar backup_schedule sama; seluruh hash DB pada aksi UI sama,
  integrity/FK lulus. Tidak ada request HTTP atau metode interaktif Google pada
  jalur token null. Akun/consent tidak diganti.

Regresi gabungan, analyzer, native Poco/DV, build dan pemasangan C31 dicatat
terpisah setelah selesai; tidak diwarisi dari C30. Tes host menggunakan SQLite
FFI dan SDK/HTTP tiruan, bukan bukti SQLCipher atau Google nyata. Pemeriksaan
fisik C30-MAN01 masih menunggu jawaban pengguna; perangkat tetap diserahkan
kepada pengguna. APK C30 serta seluruh pointer pemulihan APK asli v6 tetap
dipertahankan. Closing dan pemulihan APK asli masih pending.

Regresi gabungan tujuh file: **56 PASS 02:30**; empat focused adalah subset. Analyzer **No issues 9.3s**. Bukti `evidence/m5-20261018/c31-host-regression.log` dan `c31-analyze.log`. Native/build/deploy tetap pending; C30 di Poco tidak diganti.

## Koreksi helper native pertama

Run Poco `poco-c31-ui-1792332954413-*`: **3 PASS / 1 FAIL 1 detik**.
`EncryptedFixtureFactory` menolak nama `fixture.db` dengan `fixturePathRequired`
sebelum database dibuka. Ini kesalahan helper baru, bukan bug aplikasi. Nama
disposable diganti menjadi `m5_regression_<nonce>.db` yang memenuhi guard;
adapter/pembatas tidak dilonggarkan. Wrapper menyimpan raw failure, hash empat
file ordinary tetap dan mengembalikan APK C30. Pipeline berhenti sebelum DV,
build atau deployment C31. Context/ledger nonce lama dipertahankan.

Final helper: focused **4 PASS 2 detik**, analyzer **No issues 8.2 detik** pada
`c31-auth-final-helper.log`/`c31-analyze.log`; analyzer sebelum perubahan nama
disimpan di `c31-analyze-before-fixture-path-fix.log`. Full56 menggunakan source
produksi final yang sama sebelum koreksi nama fixture; focused4 adalah subset,
bukan kasus tambahan. Antrean native diulang dengan nonce baru.

**C31 siap di Poco,18 Oktober2026:** SDK silent-null kini menjadi kebutuhan otorisasi ulang nonretry tanpa UI worker. Before2PASS/2FAIL→focused4/full56PASS150s; analyzer8.2s No issues; Poco4PASS/DV4PASS pada SDK/HTTP sintetis dengan SQLCipher native. DV exactAPK/default hashes/awake dipulihkan. Build3 verified, ordinary tidak dipasang. Audit B nyata sebelum1PASS/strict sesudah1PASS: seluruh tabel,13arsip dan policy sama sesudah metadata PIN fixture yang didokumentasikan; B connected/Off dan targetnull,8runA tetap. Ordinary/default/2ekspor sama; startup kasir terlihat dan0marker pada buffer tersedia. C30-MAN01 label/empty PASS dilaporkan pengguna. First native3PASS/1FAIL fixturePathRequired adalah helper filename yang diperbaiki, guard tetap ketat; raw failure disimpan. Final-helper host4PASS adalah subset, bukan56+4kasus unik. Kontrol otomatis Off; berikut D-MAN17 Putuskan B lalu audit penutup/pemulihan exact originalAPK6. Real revoked-consent/natural21/reboot/Doze/OS-job cancellation/in-flight-change/lintas-origin tetap unverified. M5 belum selesai/M6 tidak dimulai. [C31](M5_SILENT_AUTHORIZATION_C31.md).**

**D-MAN17 PASS manual dilaporkan pengguna,18 Oktober2026:** Putuskan berhasil, kontrol akun/upload/versi/otomatis hilang, target belum terjadwal dan8riwayat tetap. Sesudahnya pemilih akun sempat dibuka tak sengaja lalu dibatalkan tanpa menghubungkan; teks status akhir tidak dikutip dan metadata tidak diasumsikan beku. Berikut regresi status worker C32 dan audit penutup/pemulihan exact originalAPK6; manual dijeda, kontrol perangkat belum aktif pada persiapan host. M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/d-man17-user-report.json).**
