# C25 — pembatalan pemilih akun Google

17 Oktober 2026. M5 masih aktif; tidak memulai M6.

## Gejala dan bukti sebelum

D-MAN01: pengguna membuka pemilih akun lalu membatalkan. Pesan halaman adalah “Operasi belum berhasil. Periksa izin, koneksi, atau masuk kembali melalui PIN”. Ini kegagalan feedback pembatalan, bukan bukti API/akun/token berhasil terhubung atau bermasalah. Tiga baris jadwal belum terjadwal yang dilaporkan tidak membuktikan apakah kontrol akun lain tampil. Nilai/email/token tidak dikumpulkan. Kategori exception native percobaan itu tidak direkam.

`BackupSettingsProvider.task` memetakan exception SDK Google yang tidak dikenali menjadi kegagalan umum. Repro melalui SDK/platform fixture menghasilkan GoogleSignInException(canceled) → m5OperationFailed, padahal pembatalan harus m5Cancelled. Pilihan ulang juga mempertahankan kandidat lama bila await gagal sebelum assignment; kandidat sementara perlu diinvalidasi saat memulai pilihan ulang, tanpa mengubah tujuan yang telah disimpan.

## Perubahan

- `lib/features/backup/presentation/backup_settings_provider.dart`: chooseAccount membersihkan pendingAccount sebelum pemilihan dan menangani hanya enum canceled sebagai m5Cancelled. Interrupted/configuration errors tetap kegagalan. Tidak mengubah autentikasi Google, persetujuan, PIN, policy, scheduler, format/enkripsi backup atau aturan bisnis.
- `test/m5_settings_ui_test.dart`: lima kasus SDK boundary: cancel/disconnected, cancel/kandidat lama, cancel/kandidat lama dengan tujuan tersimpan+autoOn, interrupted, clientConfigurationError. Semua melalui tombol UI, management lock/unlock, membandingkan fingerprint DB/policy sebelum unlock berikutnya dan memeriksa kontrol akun. Fixture menggantikan platform SDK dalam proses tes, tidak membuka akun/Google UI atau menghubungi API. Native memakai root nonce terpisah, bukan database kampanye manual.
- `integration_test/m5_acceptance_audit_test.dart`: fase post_restore sebelum uji consent nyata juga mewajibkan local Drive policy disconnected/off/no identity melalui assertion boolean. Jangan gunakan fase ini setelah consent nyata.

## Hasil/checkpoint

- Host sebelum `evidence/m5-20261017/c25-host-before.log`:4FAIL2:18, kasus pertama mereproduksi tepat mapping canceled→m5OperationFailed. Tiga kasus berikut terhalang drain/fixture dan cleanup yang melempar dummy exception; tidak dihitung sebagai tiga bug aplikasi terpisah. Helper memindahkan inisialisasi SDK yang di-cache ke tester.runAsync agar tidak terikat fake clock testcase sebelumnya. Retest ketat lulus, tetapi kontribusi perubahan helper terhadap masing-masing failure belum diisolasi; mekanisme internal tiga kegagalan lanjutan tidak diklaim sudah ditrace. Rawfailure dipertahankan.
- Focused sesudah `c25-host-focused.log`: **5PASS33s**. Kandidat sementara kosong; policy/consent lama dan seluruh fingerprint DB sama sebelum autentikasi PIN berikutnya. Interrupted/configuration tidak dianggap canceled. Ini SDK mock, belum retest picker Google nyata.
- Regresi host/analyzer, native Poco/DV, build universal dan update terjaga masih berjalan/belum diklaim selesai pada checkpoint ini. Semua perintah Flutter diserialisasi.

Checkpoint berikut: host regression **43PASS97s** termasuk focused5 yang sama. Analyzer awal2isu (braces info/non-null warning) hanya pada test fixture diperbaiki; final **No issues6,6s**. Poco native **18PASS120s** pada root fixture baru, ordinary hash unchanged dan exact C24 APK dipulihkan; SDK diganti fixture, tidak membuka akun nyata. DV native sedang berjalan dengan awake snapshot1/900000/0; belum klaim selesai/restored pada checkpoint ini. Pipeline berurutan dan ledger: `evidence/m5-20261017/c25_pipeline.ps1`, `evidence/m5-20261016/poco-google-cancel-update-1792226124001/update.json`. Default sandbox DV di-hash sebelum/sesudah dan APK sebelumnya disimpan untuk finally restoration. FixtureDatabase override campaign Poco/nonceworker DV menjaga default lama; ordinary tidak dipasang.

DV selesai **18PASS227s**. Awake1/900000/0 restored/readback; exact prior APK SHA cocok sesudah dipulihkan. Default fixture `kasir_app.db` SHA `ae853ac4507fae86a75115980032eacd55a6433eec1a1477e52a8137d1363cf0` dan3sidecar ABSENT sama sebelum/sesudah. Ordinary package absent sebelum/sesudah, bukan klaim pelestarian DB ordinary yang tidak ada. Build-only universal ordinary/fixture/bridge sedang berjalan di `release-artifacts-20261017-154438`; belum deploy C25 acceptance pada checkpoint ini.

## Batas dan langkah berikut

N-MAN01–06/08 adalah PASS manual pada scope yang dilaporkan; N-MAN07 lockscreen tidak terlihat tetap UNVERIFIED meskipun izin lockscreen dilaporkan aktif. Notifikasi aplikasi Off terakhir melalui N-MAN08. Jangan mengubah pengaturan pribadi untuk memaksakan tampilan.

Manual dijeda selama antrean otomatis. Setelah APK terverifikasi dipasang hanya ke package.integration dan hash/arsip/DB/startup lulus, ulang D-MAN01 cancel nyata; jelaskan tombol akun secara konkret. Consent/upload/list/download/restore Google nyata tetap belum terverifikasi. Original fixture v6 dan cleanup penutup tetap pending; jangan overwrite pointer original atau reset/reseed data.


**C25 siap retest manual17Oktober2026:** cancel Google sekarang dipetakan khusus canceled→Dibatalkan, kandidat sementara diinvalidasi sebelum retry; tujuan/consent tersimpan tetap. Host43PASS97s (focused5 subset), analyzerNoissues6,6s; Poco18PASS; DV 18PASS; exact prior APK/default sandbox hashes and awake restored. Ordinary/fixture/bridge universal/ikon/min24/16KiB/licenses/signature/negativeguard verified; ordinary tidak dipasang. Strict before/after masing-masing1PASS: seluruh tabel+3archiveSHA sama, fakta2sale/stok/HPP/legacy/ordinary/public2exports dan localDrivePolicy disconnected/off/no identity PASS pada checkpoint. C25 installed hash cocok dan startup own cashier/0marker PASS. Kontrol otomatis dihentikan. D-MAN01 feedbackFAIL historis tetap; D-MAN01R actual Google cancel belum. Tidak memilih akun/upload/reset/restore ulang. OriginalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Detail [C25](M5_GOOGLE_CANCEL_C25.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-google-cancel-update-1792226124001\update.json


**D-MAN01R PASS manual dilaporkan pengguna, 17 Oktober 2026:** pemilih Google nyata dibatalkan pada APK C25; teks halaman kini Dibatalkan. dan tombol Pilih atau ganti akun Google tetap tersedia di bawah tiga baris jadwal. Feedback C25 terkonfirmasi pada Poco; D-MAN01 gagal sebelumnya tetap riwayat. Belum memilih akun/membuktikan consent, tujuan tersimpan, API atau upload; dialog PIN kondisional tidak diasumsikan terjadi. Berikut D-MAN02: pilih akun uji hingga pratinjau Pilihan akun belum disimpan/Gunakan akun ini, tanpa konfirmasi tujuan atau unggah. Kontrol otomatis nonaktif; original APK v6/closing pending. M5 belum selesai, M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man01r-user-report.json).**
