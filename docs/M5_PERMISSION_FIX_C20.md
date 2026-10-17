# C20 — Pengulangan PIN setelah izin Bluetooth ditolak

Dicatat 17 Oktober 2026; M5 aktif, M6 tidak dimulai.

## Temuan dan dampak

P-MAN28, pengguna Poco melaporkan tombol Perangkat berpasangan selalu kembali meminta PIN setelah izin Perangkat di sekitar ditolak. Setelah PIN diisi, pengguna kembali ke halaman printer dan percobaan tombol berikutnya mengulang alur tersebut. Ini kegagalan alur penolakan izin, bukan hasil cetak atau kerusakan data yang telah terbukti.

Pengguna kemudian mengizinkan kembali Perangkat di sekitar melalui pengaturan Android dan menjawab ya: daftar perangkat muncul tanpa pengulangan PIN. Izin telah pulih berdasarkan laporan pengguna; bukan pembacaan ADB.

## Analisis dan perbaikan

Plugin sebelumnya memanggil requestPermissions setiap kali izin tidak diberikan. Dialog/aktivitas izin dapat menonaktifkan fokus aplikasi, sedangkan ManagementSessionProvider memang mengunci pada lifecycle non-resumed. Pengulangan panggilan izin dapat mengulang penguncian. Mekanisme lifecycle Android spesifik Poco belum di-trace; sebab pengulangan permintaan di kode dan model gate dapat direproduksi, tanpa menganggap semua transisi OEM identik.

BluetoothPermissionGate kini memeriksa grant Android aktual terlebih dahulu, lalu mengembalikan denial secara noninteraktif bila permintaan instalasi ini sudah pernah dimulai. Riwayat kecil disimpan pada SharedPreferences package uji/operasional masing-masing, di luar database portable; setelah ditolak, UI mengarahkan pengguna ke pengaturan Android aplikasi. Riwayat tidak memberi izin atau membuka PIN. Pada permintaan pertama, kehilangan fokus tetap mengunci dan pengguna perlu masuk kembali. Grant dari pengaturan langsung dapat dipakai; pencabutan grant berikutnya tetap fail closed. Tidak ada auto-unlock, retry cetak, atau perubahan transaksi.

Pesan printer khusus ID/EN menggantikan pesan denial generik milik peringatan stok. Daftar perangkat sementara dibersihkan ketika ditolak. Pesan ditempatkan tepat sesudah tombol paired/discovery, juga dekat Connect pada form panjang. Tes menemukan notice di atas tombol dapat tidak mounted saat tombol berada di tepi atas viewport; posisi diperbaiki, bukan melonggarkan hit-test assertion.

File utama: packages/kasir_platform/android/src/main/java/com/example/kasir_platform/{KasirPlatformPlugin,BluetoothPermissionGate}.java; lib/features/printer/presentation/printer_settings_{provider,screen}.dart; lib/l10n/app_{id,en}.arb dan accessor hasil gen-l10n; test/m5_settings_ui_test.dart; JVM BluetoothPermissionGateTest.java. Audit acceptance ditambah fase post_printer untuk dua penjualan manual; fase calibration historis tetap ada.

## Bukti dan batas saat pencatatan

- P-MAN28: FAIL manual reported; pemulihan izin sebelum patch PASS manual reported. Bukan retest patch.
- JVM gate: model keputusan lama tanpa history guard, 2 FAIL / 1 PASS (c20-permission-gate-before.log); ini ekstraksi perilaku kode lama, bukan instrumentasi dialog Poco. Sesudah guard: 3 PASS; regresi PortableArchive 6 PASS, c20-jvm-final.log dan XML Gradle.
- Widget before-corrected-helper: 1 FAIL pada pesan generik lama; log awal c20-ui-before.log gagal lebih dahulu karena helper belum mem-pump frame lock. Kegagalan helper tidak disebut bug PIN baru.
- Percobaan widget sesudah patch pertama masih gagal hit-test; diagnosis rect menunjukkan paired di y56 dan scroll298, notice di atas tombol tidak mounted. Raw log dipertahankan. Retest posisi akhir sedang berjalan, belum dianggap PASS.
- Percobaan JVM pertama gagal mengarahkan log karena working directory salah; JVM tidak berjalan pada percobaan itu. Perintah diperbaiki tanpa perangkat. ADB tanpa escalation gagal start daemon; panggilan dengan izin sandbox yang benar mendeteksi Poco7f0edea0/model24069PC21G. Tidak menyimpulkan kabel/HP rusak.
- Audit localization PASS: 512 key ID/EN, 362 referensi pesan, 244 ID requirement asli tetap.
- Analyzer, audit native data sebelum/sesudah, build/retest native dan manual patch masih pending. Data ordinary/default sandbox serta APK original wajib dipertahankan; jangan memakai asumsi calibration finance0 untuk DB manual sekarang.

## Checkpoint otomatis berikutnya

- Windows final-v4:15PASS42s; denial/relock/regrant dan notice hit-testable di bawah paired button. Analyzer final No issues16,5s.
- Poco native settings8PASS51s pada fixture terpisah (OS Bluetooth channel dimock pada UI suite); ordinary hash sama dan APK C19 restored. Tidak menggantikan uji dialog izin OEM.
- Native before audit1PASS3s: dua nomor struk berbeda; sale30000+12000/HPP27000+9000/payment10000+12000/allocations/receipts/jobs/mainstock16/secondary2/value150000/pack40/grosir10000/integrity/FK. Default sandbox filehash sama baseline tanpa dibuka, ordinary4hash sama. Fingerprint seluruh tabel disimpan privat untuk after comparison; bukan restore backup.
- DV native settings dan build/update/after-audit masih pending; tidak menyerahkan APK untuk manual sebelum gate selesai.

Native DV settings8PASS1:44 pada evidence c20-settings-20261017-012257; awake dipulihkan/readback tepat screensaver1/timeout900000/stayawake0. Ordinary package absent pada interval wrapper ini, bukan preservation DB ordinary yang tidak ada. Mock Bluetooth di suite native tidak disebut sebagai uji dialog OEM. Release baru sedang dibangun, ordinary build-only.

## Handover C20 selesai, retest OEM pending

Release/bridge terverifikasi: build/m5-acceptance-20261017-012541; metadata docs/evidence/m5-20261016/release-artifacts-20261017-012541. Ordinary hanya build. Tiga ABI/minSdk24/ELF+ZIP16KiB/lisensi/signature PASS, negative isolation guard menolak sesuai harapan. Vendor audit106 sumber Mbed TLS/lisensi unchanged.

Deploy hanya fixture melalui script scoped deploy_c20_update.ps1, mempertahankan APK C19 yang hash-nya cocok. After audit poco-c20-after-1792174330020-20261017-012902:1PASS3s, seluruh tabel dan versi identik dengan before, fakta dua penjualan/nomor unik/HPP/stok/payments/receipts/jobs/integrity/FK sesuai; default sandbox hash cocok baseline tanpa membuka DB itu dan ordinary endpoints sama sepanjang update. Kedua run adalah fase satu kasus audit. Tidak reset/uninstall/restore backup/ordinary deploy. Installed APK ditarik dan hash cocok artefak baru.

Startup own release PID28792/banner UJI COBA M5 terlihat/0penanda error di buffer yang diperiksa. Ini startup saja, bukan klaim seluruh log bersih/OAuth/restore. Kontrol otomatis dihentikan dan ledger di-update. Original sandboxAPK6 belum dipulihkan karena manual M5 masih berlanjut; logo Download milik tes dan final closing audit tetap pending.

P-MAN29 yang akan dijalankan: deny Nearby di Android Settings, paired action (first OS dialog may relock once), PIN ulang bila diminta, dua percobaan berikutnya harus memberi petunjuk izin tanpa mengulang PIN; pulihkan Allow dan verifikasi paired list. Hasil belum ada, sehingga C20 berstatus fixed/automated validated, physical OEM retest pending. Kasus P-MAN28 lama tidak diubah menjadi PASS.

P-MAN29 stage3 partial user report: paired pressed twice, permission-denied text visible and saved RPP02N retained. This matches denied-state feedback; not a new proven bug or full PASS. Asked explicitly whether PIN stopped repeating and requested stage4 restore Allow/list confirmation. Pending response, no device control.

## Hasil manual C20 — PASS reported17Oktober2026

Pengguna mengonfirmasi ya pada follow-up eksplisit: dua paired attempts setelah denial tidak meminta PIN lagi; setelah Nearby dipulihkan Allow lewat Android Settings dan PIN masuk kembali bila diminta, daftar perangkat tampil. Bersama stage3 pesan denial terlihat/profil tersimpan tetap, P-MAN29 PASS manual reported. C20 fixed/automated+manual validated pada Poco untuk alur tersebut. P28FAIL historis tetap, bukan diubah/dihapus; model lain/semua kemungkinan dialog tidak dianggap lulus. Tidak mencetak atau mengubah transaksi pada retest. Nearby Allow dipulihkan menurut pengguna; kontrol otomatis tetap tidak aktif. Lanjut B-MAN01 status recovery sebelum menyiapkan kode, supaya tidak merotasi key existing tanpa perlu.
