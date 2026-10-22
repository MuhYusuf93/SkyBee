# C29 — konteks tampilan saat akun Drive berubah

Status terbaru,18 Oktober2026: **C29 terpasang di paket uji Poco**, host50PASS,
native Poco2PASS13s/DV2PASS25s, analyzer final8,9s No issues. Semua tabel,
13arsip dan policy sama pada audit interval update sebelum/sesudah; delapan
remote ID unik dikonfirmasi. Build ordinary hanya diverifikasi. Akun B Google
nyata masih menunggu interaksi pengguna. M5 berlangsung, M6 tidak dimulai.

Temuan awal direproduksi pada host; bukan laporan bahwa arsip benar-benar
diunggah ke akun yang salah. Riwayat repro/persiapan tetap di bawah.

## Temuan yang disatukan

Gejala: setelah tujuan akun B diterima, Provider masih menyimpan daftar versi
dan cursor halaman yang sebelumnya dimuat untuk akun A. Daftar dirender di bawah
tujuan yang baru. Disconnect membersihkan daftar tetapi meninggalkan cursor.
Kedua operasi menjalankan refresh scheduler, tetapi overview route juga masih
menyimpan target lama meskipun akun baru default otomatis OFF/disconnect.

Penyebab: invalidasi state akun tidak lengkap di `acceptAccount`/`disconnect`.
Validasi identitas, consent generation dan pemisahan Drive sebenarnya tetap
berada di service/transport. Klik file A sesudah ganti akun B dapat berakhir pada
file-unavailable dan Next memakai cursor yang tidak cocok; jangan menyimpulkan
pelanggaran isolasi cloud atau kerusakan database tanpa bukti.

Perbaikan `lib/features/backup/presentation/backup_settings_provider.dart`:
setelah operasi akun berhasil, kosongkan `remote` dan `nextRemote`, lalu muat
ulang overview melalui BackupService sesudah scheduler refresh. Tidak menulis SQL
di Provider, tidak mengganti aturan consent, tidak mengubah arsip cloud/stock/
penjualan, dan tidak menghapus state akun lama sebelum penerimaan berhasil.

## Bukti sebelum/sesudah

Regresi baru di `test/m5_settings_ui_test.dart` memakai policy/SDK/HTTP/WorkManager
tiruan dengan identitas publik `.invalid`, service penerimaan akun asli dan
database SQLite fixture. State halaman versi A disiapkan seperti sesudah daftar
berhasil; HTTP about menjawab identitas B. Bukan bukti OAuth akun kedua nyata.

- Upaya pertama gagal memuat kelas SDK fixture karena method abstrak belum
  diwakili. Helper dilengkapi `noSuchMethod` yang menolak pemanggilan tidak
  diharapkan. Ini kesalahan tes, bukan bug aplikasi.
- Repro final: **2FAIL8s**. Accept masih memuat `public-file-a`; disconnect masih
  memuat `public-cursor-a`. Raw failure dipertahankan.
- Sesudah patch: **2PASS8s**. Policy penerimaan B tetap otomatis OFF, disconnect
  tidak terhubung, daftar/cursor kosong, target overview null, semua hash tabel
  selain jadwal tetap. Kegagalan/pembatalan pemilih tetap dicakup regresi lama.
- Upaya full regression pertama salah menyebut `m5_retry_test.dart`; nama aktual
  `m5_retry_budget_test.dart`. Hasil parsial tidak disebut full PASS dan log tetap
  disimpan. Jalankan kembali enam file dengan path yang benar.

Bukti: [repro](evidence/m5-20261018/c29-account-repro.log),
[sesudah patch](evidence/m5-20261018/c29-account-after.log).

## Validasi dan deployment berikutnya

Catatan persiapan historis: full host/analyze, native Poco dan DV, tiga APK (ordinary hanya build), audit
strict all-table/arsip/policy sebelum-sesudah update dan startup release sedang
disiapkan. Jangan menganggap source patch berarti APK Poco sudah berubah.

Fase audit baru `post_drive_worker` mempertahankan fase lama dengan5arsip/run0;
fokus baru mempunyai minimal13arsip dan delapan run nonce dari probe headless.
Semua digest tabel, arsip lama/baru dan policy harus sama pada interval update
baru. Fase lama tidak dijalankan di state13arsip agar histori tidak ditulis ulang
atau assertion dilemahkan hanya untuk meloloskan update.

Sesudah C29 diserahkan, uji akun B nyata melalui pemilih Google pengguna. Akun B
tidak diasumsikan kosong; bandingkan identitas versi dengan akun A dan tidak
melakukan restore/unggah otomatis tanpa langkah uji yang jelas. Akun A baru saja
mempunyai7versi setelah [probe nyata](M5_LIVE_DRIVE_WORKER_20261018.md). Natural21,
reboot/Doze, origin cloud lain, dan penutupan kampanye tetap dilaporkan terpisah.

**C29 siap di Poco,18 Oktober2026:** stale versi/cursor akun dan target sesudah accept/disconnect direpro2FAIL8s→focused2PASS8s/fullhost50PASS (subset), analyzer 8.9s No issues; Poco2PASS/DV 2PASS account UI mocks; exact prior APK/default hashes/awake restored and read back. Native UI menggunakan SDK/HTTP/WorkManager tiruan. Ordinary/fixture/bridge universal verified; ordinary tidak dipasang. Strict before1/after1PASS: semua tabel/13arsip/policy identik,8run success/8remoteIDunik, real consent/autoOn terjaga. Own cashier release terlihat/0error marker pada buffer. Worker Google nyata terpisah8upload/retensi7/native reader1PASS3s/preservasi ordinary/default/ekspor PASS dengan pemicu ADB -s hanya nonce, bukan natural21. C28-MAN01R OFF/ON PASS manual; berikut D-MAN15 ganti akun B tanpa upload/restore. Kontrol otomatis Off; originalAPK6/closing pending. Natural21/reboot/Doze/lintas-origin nyata belum terverifikasi. M5 belum selesai/M6 tidak dimulai. [C29](M5_DRIVE_ACCOUNT_CONTEXT_C29.md), [worker](M5_LIVE_DRIVE_WORKER_20261018.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-account-ui-update-1792328869099\update.json

**D-MAN15a PASS manual dilaporkan pengguna,18 Oktober2026:** pada C29 Poco, Backup Drive otomatis dibiarkan ON dan Versi backup Drive menampilkan7baris arsip dengan tombol Pilih untuk pemulihan. Ini observasi UI; tidak ada unggah/unduh/restore baru atau pemilihan akun B. Bukti retensi/worker/native sebelumnya tetap terpisah. Berikut D-MAN15b pilih akun uji berbeda hingga kandidat belum disimpan/Gunakan akun ini, tanpa konfirmasi tujuan dahulu. Kontrol perangkat Off; M5 belum selesai/M6 tidak dimulai; originalAPK6/closing pending. [Bukti](evidence/m5-20261018/d-man15a-user-report.json).**

**D-MAN15b PASS manual dilaporkan pengguna,18 Oktober2026:** akun uji kedua yang berbeda telah dipilih dan diperiksa pribadi; Pilihan akun belum disimpan/Gunakan akun ini terlihat pada C29 Poco. Tujuan B belum dikonfirmasi; tidak membuktikan penyimpanan policy, daftar B atau isolasi cloud. Dialog izin/PIN kondisional tidak diasumsikan muncul. Berikut D-MAN15c konfirmasi sekali, periksa tujuan B/otomatis Off/target belum terjadwal dan daftar7versi lama kosong tanpa refresh. Jangan unggah/restore. Kontrol perangkat Off; M5 belum selesai/M6 tidak dimulai; originalAPK6/closing pending. [Bukti](evidence/m5-20261018/d-man15b-user-report.json).**

**D-MAN15c PASS manual dilaporkan pengguna,18 Oktober2026:** pada C29 Poco, tujuan akun B dikonfirmasi sekali, status Akun tujuan disimpan/otomatis nonaktif, switch Off, target belum terjadwal, kandidat sementara hilang dan7baris arsip A kosong tanpa refresh. Ini validasi fisik UI C29 sesudah ganti akun, bukan bukti daftar cloud B, cancel job OS atau SQL/policy native. Berikut D-MAN16 muat Versi backup Drive pada B dan laporkan jumlah/keadaan kosong/error; jangan unggah/restore/aktifkan otomatis. Kontrol perangkat Off; M5 belum selesai/M6 tidak dimulai; originalAPK6/closing pending. [Bukti](evidence/m5-20261018/d-man15c-user-report.json).**

**D-MAN16 akun B kosong dilaporkan pengguna,18 Oktober2026:** delapan baris Berhasil diverifikasi/tanggal juga terlihat. Source membuktikan s.remote berasal Drive API dan s.runs berasal backup_runs lokal semua akun; delapan pekerjaan konsisten checkpoint worker sebelumnya, bukan bukti delapan arsip B. Tampilan belum memberi heading/konteks akun riwayat lokal; C30 repro dan penjelasan UI disiapkan, tanpa menghapus riwayat atau mengubah retensi. Belum audit native B/isolation. Manual dijeda; perangkat belum dikontrol otomatis; B connected/autoOff dilaporkan. M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/d-man16-user-report.json).**
