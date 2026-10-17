# C24 — ikon notifikasi hilang dari APK release

17 Oktober 2026. M5 masih aktif; M6 tidak dimulai.

Audit setelah restore nyata menemukan `backup_schedule.error_code=m5PeripheralSetupFailed`, sehingga audit gagal (bukan PASS). Pemeriksaan keuangan/stok, integrity/FK/cipher, rekonsiliasi dan 23 hash tabel bisnis sebelum assertion tersebut berhasil. Integritas safety archive belum diperiksa oleh run yang berhenti ini.

## Gejala, penyebab, dan dampak

- APK release C23 berhasil dibangun, tetapi tabel resource AAPT tidak memuat `drawable/ic_stock_notification`.
- Probe release pada Poco F6 mereproduksi `initialized:false`, `errorCode:invalid_icon`, `databaseFilesUnchanged:true`, `release:true`. Probe tidak membuka DB, meminta izin atau menampilkan notifikasi. Resource dipanggil melalui nama oleh plugin; shrinker tidak melihat referensi statis.
- Akibatnya inisialisasi notifikasi gagal. Kasir/keuangan tetap berjalan; startup menyimpan status kesalahan perifer generik. Status itu juga tidak dibersihkan ketika startup berikutnya sukses.
- Ini bug aplikasi/kemasan release, bukan penolakan izin pengguna, kerusakan arsip, atau kegagalan restore finansial.

## Perbaikan

- `android/app/src/main/res/raw/keep.xml`: pertahankan hanya drawable notifikasi yang dipanggil dinamis. Shrinking tetap aktif.
- `tools/verify_m5_apk.py`: wajib menemukan ikon pada tabel resource terkompilasi. Gate baru menolak APK C23 lama dengan pesan ikon hilang (exit1 yang diharapkan).
- `lib/app/m5_runtime.dart`: bersihkan hanya error setup lama setelah semua inisialisasi dan pembacaan launch-details berhasil. Kegagalan parsial dan kode error Drive lain tetap dipertahankan. Dependency scheduler dapat disuplai untuk pengujian.
- `test/m5_runtime_test.dart`: regresi startup pulih, ikon gagal, launch-details gagal, dan error Drive yang tidak terkait.

## Perbaikan helper audit terpisah

`integration_test/m5_post_restore_audit_test.dart` sebelumnya mengharapkan empat **seluruh** print jobs dalam safety snapshot, padahal kampanye juga mencetak kalibrasi. Assertion itu belum dijalankan pada run pertama yang berhenti lebih awal. Diganti dengan perbandingan hash **seluruh** `print_jobs` dan `printer_profiles` terhadap marker sebelum restore, sehingga bukti lebih ketat dan mencakup kalibrasi. Tidak mengubah antrean produksi atau menghapus riwayat.

## Bukti dan status

- Sebelum: `evidence/m5-20261016/poco-post-restore-audit-20261017-065816`, audit1FAIL pada status perifer.
- Repro release: `evidence/m5-20261016/poco-c24-release-before-20261017-070314/result-marker.txt`; ordinary hashes tidak berubah dan APK C23 dipulihkan.
- Gate negatif: `evidence/m5-20261017/c24-old-apk-gate.log`, expected rejection.
- Host run awal: `c24-host.log`, 5PASS/2FAIL. Helper host belum mendaftarkan implementasi Android plugin; diperbaiki dengan `AndroidFlutterLocalNotificationsPlugin.registerWith()`. Ini bukan bukti perbaikan produksi gagal pada perangkat.
- Retest host/analyzer, release probe sesudah, APK aplikasi baru, audit safety dan validasi DV masih berjalan/belum terverifikasi. Jangan menandai M5 selesai dari catatan ini.

Checkpoint sesudah: `c24-host-final.log` **10PASS15s** (runtime4/retry3/alerts3); `c24-analyze-final.log` **No issues8,8s**. Lint awal satu info braces diperbaiki. Probe Poco sesudah di `poco-c24-release-after-*` menunjukkan **initialized:true/errorCode:null/databaseFilesUnchanged:true/release:true**, ikon ada di tabel AAPT, prior C23 APK dipulihkan. Ini bukti inisialisasi saja, belum OS permission/delivery.

Build awal `release-artifacts-20261017-070824` berhenti pada fixture compileReleaseJavaWithJavac: GeneratedPluginRegistrant merujuk IntegrationTestPlugin yang tidak ada pada classpath. Host test dimulai ketika build tersebut masih berjalan; mekanisme internal belum ditrace. Tidak ada instalasi dari run ini. Build serial final `release-artifacts-20261017-071200` menyelesaikan ordinary/fixture/debug bridge, ikon terkemas dan gate package/min24/3ABI/16KiB/lisensi/signature serta negative-isolation guard PASS. Ordinary build-only. Artefak final disiapkan setelah perubahan penanganan error status selesai; run awal tidak menjadi artefak handover.

Pipeline terkontrol: `evidence/m5-20261017/c24-pipeline.ps1`, ledger `evidence/m5-20261016/poco-notification-update-1792195919961/update.json`. Audit install-only memakai **fase post_restore baru**: semua hash tabel dan ketiga hash arsip wajib identik sebelum/sesudah instalasi, tanpa menjalankan startup di antaranya. Fase post_backup lama tetap mengharapkan2arsip/profil terpilih; tidak dilemahkan. Setelah itu production startup memperbaiki status, lalu audit safety harus lulus dengan error_code null tanpa pengecualian. Hasil tahap berikut belum diklaim di checkpoint ini.

Checkpoint berikut: DV release probe **initialized:true/errorCode:null/databaseFilesUnchanged:true**; exact prior APK SHA sama sesudah dipulihkan. Awake restored/readback `1/900000/0`. Ordinary package DV absent, bukan klaim preservation DB existing. Helper pipeline sempat berhenti setelah cleanup DV karena argumen positional Select-String tertukar, sebelum tindakan Poco. Diperbaiki menjadi `-LiteralPath/-Pattern`; dilanjutkan dari ledger yang diverifikasi tanpa mengulang build/probe atau menghapus evidence gagal.

Audit strict Poco sebelum/sesudah instalasi masing-masing1PASS3s (dua fase kasus yang sama): seluruh hash tabel dan ketiga SHA arsip identik, legacy/default dan ordinary endpoint tetap. Artefak C24 terpasang cocok SHA256 `cdbefe1e1fde5581680d49a1bb51b9158d500ad05990ca9bdfd2aa074c7a0aa9`. Tidak ada startup di antara kedua audit, tidak ada reseed/restore/reset; sesudah audit barulah startup produksi berjalan. Native safety audit sesudah startup masih pending pada checkpoint ini.

Retest pertama post-startup1FAIL16s pada pemeriksaan direktori logo; assertion status error_code null sudah lewat, ketiga inspeksi/safety assertions sebelumnya juga lewat. Helper membandingkan child canonical dengan parent noncanonical. Koreksi kedua sisi canonical tetap mempertahankan containment dan SHA logo. Retest final **1PASS18s**, marker `rootAliasChanged:true/containedInCanonicalRoot:true` membuktikan alias Android pada kasus ini. Tidak ada perubahan produksi untuk penempatan logo, tidak ada restore ulang/reset. Bukti final: `poco-c24-post-restore-final-1792195919961-20261017-072030/runner.log`. Seluruh fingerprint DB live setelah autentikasi identik sesudah inspeksi3arsip. PIN fixture menambah satu audit/attempt yang disengaja sebelum freeze tiap run; metadata itu tidak dihapus.

Pemeriksaan terakhir sebelum handover: formatter5files/0changed, analyzer **No issues8,5s**. Final cold startup own cashier/PID/banner/0error markers PASS; bukti `poco-notification-update-1792195919961/startup.json` (startup sebelumnya disimpan terpisah). Permission POST_NOTIFICATIONS masih **granted=false**, tanpa USER_SET/USER_FIXED pada pembacaan paket saat handover; belum menjadi hasil penolakan/grant pengguna. Enam ledger handover diperbarui, kontrol otomatis dihentikan. N-MAN01 berikut: switch On/Simpan, tolak izin Android, periksa pesan inline/daftar tetap tersedia; hasil belum ada.

Manual B-MAN17/18 PASS dilaporkan pengguna: profil tersimpan kosong, switch notifikasi Off, pengingat5hari dan barang stok rendah2/min5. Belum membuktikan izin OS/delivery/tap, OAuth/Drive nyata, atau safety archive.


## Hasil akhir checkpoint

**C24 selesai pada cakupan perbaikan17Oktober2026:** ikon release hilang direpro invalid_icon lalu initPASS Poco/DV; keep.xml dan gate APK mencegah pengulangan. Host10PASS15s, analyzerbersih, ordinary/fixture/bridge verified; ordinary tidak dipasang. Strict install before/after masing-masing1PASS3s: semua tabel+3arsip identik. Actual post_restore audit1PASS: integrity/FK/cipher/reconcile, 23business hashes/2receipts/keuangan-stok, autentikasi3arsip termasuk safety pre-swap/profil+fullqueue, logo dan reset device defaults/Drive PASS; setup error null setelah startup produksi tanpa SQL repair/reset/restore ulang. Ordinary/default/public2exports unchanged pada checkpoint. DV priorAPK dan awake1/900000/0 restored/readback. B17/18 tetap PASS reportedmanual. Kontrol otomatis Poco berhenti; N-MAN01 deny notification berikutnya. Sisa3kelompok: notifikasi, real Drive, closing. M5 belum selesai/M6 tidak dimulai. Detail [C24](M5_NOTIFICATION_RELEASE_C24.md).**

Ledger terperinci: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-notification-update-1792195919961\update.json. Uji sebelum/sesudah instalasi adalah dua fase kasus yang sama, bukan dua fitur unik. Audit post_restore menambah satu verification audit/attempt melalui PIN fixture sebelum freeze; inspeksi3arsip tidak mengubah fingerprint DB live sesudah freeze. Tidak mengumpulkan recovery value. Semua rawfailure awal dipertahankan.
