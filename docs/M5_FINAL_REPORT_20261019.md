# Laporan akhir implementasi dan acceptance utama M5

19 Oktober 2026. **M5 selesai dalam cakupan implementasi dan pemeriksaan yang
tersedia; M6 belum dimulai.** Skenario yang belum terverifikasi tetap terbuka di
bawah. Tidak ada publikasi, push Git, penggantian nama/applicationId produksi,
reset/uninstall database, atau pemasangan APK ordinary pada kampanye ini.

## Perubahan terakhir dan bukti

| Temuan | Sebelum → sesudah | Status |
| --- | --- | --- |
| C30: daftar cloud bercampur secara visual dengan riwayat lokal | B cloud0/8run lokal; heading/konteks akun/empty-page ID–EN; otomatis+audit B dan C30-MAN01 manual PASS | Fixed UI; riwayat tetap |
| C31: silent Google SDK null menjadi error umum | 2PASS/2FAIL→host4/full56; Poco4/DV4 SDK/HTTP sintetis; exception needs-auth nonretry tanpa UI worker | Fixed; kondisi revoke Google nyata belum diuji |
| C32: kegagalan worker persisten tidak tampil setelah reload | Repro helper final2FAIL9s→focused2PASS10s/full58PASS159s; Poco2PASS21s/DV2PASS43s | Fixed; status historis perangkat tidak diatribusikan ke akun baru |
| Helper C31/32 | fixturePathRequired/lazy finder dipisahkan dari bug aplikasi; nama fixture/pump/scroll diperbaiki, raw failure dipertahankan | CLOSED TEST BUG, guard tidak dilonggarkan |

Detail gejala, penyebab, dampak, file dan log:
[C30](M5_DRIVE_HISTORY_CONTEXT_C30.md), [C31](M5_SILENT_AUTHORIZATION_C31.md),
[C32](M5_PERSISTED_WORKER_STATUS_C32.md), [seluruh perbaikan](M5_FIXES_AND_VALIDATION.md).

## Arsitektur dan file penting

Provider tetap scoped pada layar/alur; service/repository memiliki transaksi,
aturan bisnis, transport dan persistensi. SQLCipher memakai key instalasi acak
terproteksi Keystore, terpisah dari PIN. Migrasi/snapshot/promosi staging dan
recovery diuji pada fixture, tidak dijalankan pada ordinary DB pengguna.
Arsip portable terautentikasi memakai recovery kuat terpisah dari key perangkat.

Printer memakai snapshot commit dan antrean idempotent; kegagalan/copy tidak
menciptakan sale atau mengurangi stok. Peringatan mengevaluasi batch/stok
terpisah dari sink Android; notifikasi generik dan route detail melalui PIN.
Drive tetap opsional appDataFolder dengan scope minimum, store/origin namespace,
consent generation guard, retensi7 sesudah verifikasi, dan retry harian terbatas
yang bertahan restart. Target21:00 bersifat best effort, bukan janji waktu tepat.

| Modul | File utama |
| --- | --- |
| SQLCipher/key/migrasi | lib/data/database/encrypted_database.dart, durable_promotion.dart |
| Snapshot/arsip/safety/restore | lib/features/backup/application/backup_service.dart |
| OAuth/Drive/consent/retensi | lib/features/backup/application/drive_authorization.dart, drive_rest.dart, drive_backup_service.dart |
| Jadwal/backoff | lib/features/backup/application/backup_scheduler.dart, backup_retry_store.dart |
| Antrean printer | lib/features/printer/application/print_queue_service.dart |
| Peringatan | lib/features/alerts/application/alert_service.dart, android_stock_notifications.dart |
| Perbaikan UI C30–32 | lib/features/backup/presentation/backup_settings_provider.dart, backup_settings_screen.dart, lib/l10n |
| Batas native/perlindungan rahasia | packages/kasir_platform/android/src/main/java/com/example/kasir_platform/KasirPlatformPlugin.java |

## Pemeriksaan akhir aktual

- Host final:58PASS159s, analyzer No issues 41.3s, formatter selesai.
  Focused2 adalah subset; native menggunakan kembali testcase bahasa yang sama.
- UI native C32: Poco F6 ARM64/API36 2PASS21s; DV8910 ARM32/API30 2PASS43s.
  Ini SDK/HTTP/worker-state sintetis pada SQLCipher native, bukan Google revoke nyata.
- Audit penutup: satu testcase dalam3role. Before mengautentikasi13arsip dan
  memverifikasi8snapshot worker terhadap23tabel bisnis; kelima arsip historis
  mempertahankan provenance yang sudah diverifikasi. Seluruh hash live tetap
  selama inspeksi setelah metadata autentikasi fixture yang dicatat.
- After: seluruh tabel/13arsip/policy identik pada interval pemasangan tanpa
  startup. Final: startup release terlihat/0marker error pada buffer tersedia;
  metadata evaluasi alert dipisahkan dan field stabil store/alert tetap sama.
- Drive disconnected/otomatisOff/targetnull setelah D-MAN17 dan pembatalan
  pemilih tambahan diverifikasi native. Delapan run sukses tetap ada.
- WorkManager fixture setelah cleanup: 5catatan M5,
  pending/unknown0; database metadata tertutup/integrity/hash tetap. Ini snapshot
  sesudah cleanup, bukan bukti transisi pembatalan job aktif sebelumnya.
- Tiga APK universal/minSdk24/ABI ARM32+ARM64+x64, alignment16KiB, identitas,
  icon/license/signature dan negative isolation guard terverifikasi. Development
  signing; signing distribusi/Play merupakan pekerjaan M6.

## Keadaan data dan perangkat

| Fakta kampanye sintetis | Nilai akhir |
| --- | --- |
| Barang/penjualan | 2/2, dua nomor struk berbeda |
| Penjualan/HPP/laba kotor | 42.000/36.000/6.000 IDR |
| Pembayaran/piutang | 22.000/20.000 IDR |
| Stok fisik/kedaluwarsa/nilai | 18/0/150.000 IDR |
| Arsip lokal | 13, digest awal tetap; seluruhnya terautentikasi |
| Printer/notifikasi aplikasi | Profil kosong/Off, pengingat5hari |

APK fixture v6 asli dikembalikan byte-identik dengan install-r-d, **tanpa launch**.
Keempat file legacy, file kampanye tertutup, ordinary dan dua ekspor publik sama
pada interval penutupan. Kampanye SQLCipher8 tetap tersimpan; APK v6 tidak dibuka
untuk membaca/migrasikannya. Aplikasi ordinary tidak dipasang ulang atau dibuka
oleh audit. DV kembali ke APK/pengaturan awake asal dengan readback. Tidak ada
klaim pemulihan data historis ISSUE-M31-DATA dari pelestarian kampanye ini.

## Manual dan integrasi nyata — dipisahkan dari tes otomatis

Printer Poco/Iware58mm: koneksi, unicode/logo/font18/24/32, struk grosir/piutang,
pencegahan cetak pertama berulang, SALINAN, gagal printer mati/reconnect dan
rekonsiliasi dilaporkan PASS oleh pengguna. Notifikasi izin/tap PIN/dedup/rearm/
disable serta backup lokal/export/restore dan Drive manual/restore dilaporkan
PASS sesuai laporan masing-masing; audit native terpisah tersedia pada
[M5_TEST_REPORT](M5_TEST_REPORT.md). D-MAN17 PASS dilaporkan, tambahan pemilih
dibatalkan dicatat dan keadaan disconnected diverifikasi ulang native.

Headless Google nyata:8upload terverifikasi, retensi7 dan PID worker berbeda
dengan pemicu ADB terkontrol; bukan eksekusi alami21:00. Audit B nyata:
identitas berbeda dari A, list0, file A unavailable lewat B, autoOff menolak run.
Portabilitas arsip terenkripsi DV→Poco dibuktikan terpisah dari Google lintas
perangkat. Hasil Realme/historis tetap bertanggal semula, tidak dihitung sebagai
rerun C32. Lihat [worker nyata](M5_LIVE_DRIVE_WORKER_20261018.md).

## Batas pemeriksaan dan pekerjaan berikutnya

- Natural21:00/reboot/Doze/force-stop delivery, revoke Google nyata,
  account-switch in-flight dan pelestarian origin lain di Drive nyata belum
  terverifikasi. Mock/generation guards/controlled worker bukan pengganti bukti itu.
- Drive lintas perangkat nyata belum dilakukan; akun/perangkat kedua yang cocok
  belum digunakan. Jangan menambah akun pribadi pada Realme pinjaman.
- Printer80mm/paper-out/partial-write ambigu fisik, redaksi panel clipboard OEM,
  konten notifikasi lockscreen dan TalkBack fisik belum terverifikasi.
- Realme tidak tersedia untuk patch C31/C32. Runtime ordinary/OAuth identitas
  distribusi dan signing rilis belum divalidasi pada aplikasi pengguna.

Berikutnya pengguna meninjau M5. M6 menunggu instruksi eksplisit; hasil di atas
tidak menyatakan seluruh aplikasi siap publikasi atau semua skenario lulus.

## Artefak

- [APK M5 aplikasi utama](C:/Users/ACER/Documents/Proyek/kasir_app/codex-kasir-kit/build/m5-acceptance-20261019-005702/kasir-app-0.5.0-ordinary-release.apk) — build verified, belum dipasang.
- [APK M5 uji terakhir](C:/Users/ACER/Documents/Proyek/kasir_app/codex-kasir-kit/build/m5-acceptance-20261019-005702/kasir-app-0.5.0-m5-isolated-release.apk) — tested lalu diganti kembali dengan v6 asli.
- [Ledger dan bukti penutup](C:/Users/ACER/Documents/Proyek/kasir_app/codex-kasir-kit/docs/evidence/m5-20261016/poco-worker-status-update-1792345948116/update.json).
- [STATUS](STATUS.md), [REQUIREMENTS](REQUIREMENTS.md), [LESSONS-LEARNED](LESSONS-LEARNED.md).
