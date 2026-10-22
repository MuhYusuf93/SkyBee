# C32 — status kegagalan worker dan audit penutup M5

Dilanjutkan 19 Oktober 2026 dari kampanye bukti `m5-20261018`. M6 tidak dimulai.
APK terpasang sebelum antrean C32 adalah C31 pada package integration. D-MAN17
Putuskan lulus menurut pengguna, lalu pemilih akun dibuka tak sengaja dan
dibatalkan tanpa menghubungkan. Jeda limit bukan interval metadata beku;
policy/data perlu diverifikasi kembali secara native.

## Bug aplikasi dan perbaikan

Scheduler menyimpan `backup_schedule.error_code`, termasuk kegagalan sebelum
baris backup_runs dibuat. Overview sudah membacanya, tetapi halaman hanya
menampilkan waktu percobaan/sukses/target dan riwayat pekerjaan. Akibatnya,
kegagalan latar belakang sebelum pembuatan run hilang dari tampilan ketika
route dibuka kembali. C31 memperbaiki tipe error silent SDK; C32 melengkapi
penampilan status tersimpan ini.

- Provider memetakan kode persisten ke pesan ID/EN yang sama dengan kegagalan
  foreground, tanpa SQL atau perubahan policy/scheduler di widget.
- Layar menampilkan kegagalan percobaan otomatis terakhir sebagai riwayat
  perangkat, dengan penjelasan bahwa tujuan mungkin akun sebelumnya. Tidak
  mengatribusikan error lama kepada akun aktif, menghapus riwayat, menampilkan
  kode internal/payload tak dikenal, atau mengubah persetujuan.
- Dua key localization beserta generated code dan pemetaan ditambahkan.
- ManagementGate tetap melindungi keterangannya; status hilang dari tampilan
  bila error persisten sudah bersih.

File utama: backup_settings_provider.dart, backup_settings_screen.dart,
lib/l10n, test/m5_settings_ui_test.dart. Tidak ada migration atau perubahan
aturan uang, stok, HPP, penjualan, printer, ataupun format backup.

## Bukti host dan kesalahan helper

Awal `c32-status-before.log` 2 FAIL9s dan percobaan sesudah patch
`c32-status-after.log` juga 2 FAIL9s: helper mencari item sebelum bagian lazy
dibawa ke viewport. Failure awal itu sendiri tidak cukup membedakan rendering
yang hilang dari item yang belum mounted. Helper diperbaiki dengan pump sesudah
load dan bounded scroll ke tombol akun yang sudah ada.

`c32_reproduce_final_helper.ps1` kemudian mengisolasi omission rendering pada
source C31 yang ekuivalen: hanya blok UI baru C32 dilepas sementara, final helper
tetap, dan source C32 dipulihkan byte-identik lewat finally. Repro final-helper
`c32-status-repro-final-helper.log`: **2 FAIL9s**. Dengan blok C32 kembali,
`c32-status-final-helper.log`: **2 PASS10s**. Ini dua testcase bahasa dengan
vektor kebutuhan otorisasi/jaringan/retry-limit/kode tak dikenal, clear dan PIN;
vektor/retry tidak dijumlah menjadi kasus unik.

Regresi tujuh file `c32-host-regression.log`: **58 PASS159s**, termasuk dua
focused. Analyzer sesudah helper closing final diformat: **No issues41.3s** pada
`c32-analyze.log`; pemeriksaan9.3s sebelumnya dipertahankan terpisah. Native UI
Poco/DV, build, audit penutup dan pemulihan APK asli masih pending saat laporan
awal ini dibuat. Hasil ditambahkan setelah benar-benar selesai.

## Audit penutup yang dijalankan terpisah

`integration_test/m5_closing_audit_test.dart` hanya membuka kampanye yang sudah
ada dan memeriksa empat file legacy tanpa membukanya. Before-role membandingkan
23 tabel bisnis dengan checkpoint C31; membedakan metadata PIN/alert/jadwal
dari perubahan bisnis, lalu membuat baseline baru sesudah autentikasi PIN
fixture publik. Recovery tetap di memori perangkat, tidak dibaca tool host.

Audit mengautentikasi 13 arsip, memeriksa SQLCipher/integrity/FK/keuangan/logo,
membandingkan 8 snapshot worker ke checkpoint bisnis yang tepat, serta menjaga
provenance lima arsip lama yang sudah diaudit. Antrean cetak/draft historis tidak
dipaksa menjadi keadaan live. After-role membandingkan seluruh fingerprint,
digest arsip dan policy pada interval pemasangan tanpa startup. Final-role
memeriksa ulang sesudah startup release; hanya metadata evaluasi alert boleh
berbeda, dengan digest field store/alert selain counter tetap sama.

Cleanup hanya meminta pembatalan work M5 milik package fixture. Helper Python
read-only memeriksa metadata WorkManager yang sudah tertutup setelah APK v6
dikembalikan, tidak menyimpan payload/ID work atau mengakses aplikasi lain.
Snapshot nol work aktif nanti bukan bukti transisi cancel job aktif sebelumnya,
jadwal alami21:00, reboot atau Doze. APK v6 asli dipulihkan tanpa launch; kampanye
SQLCipher, legacy, ordinary dan ekspor dipertahankan dengan hash. Semua klaim
tersebut menunggu completion marker nyata, bukan dianggap lulus dari rencana.

**M5 acceptance utama ditutup,19 Oktober2026:** C32 host58PASS159s/analyzer41.3s No issues; Poco2/DV2 UI native PASS. Audit before/after/final mengautentikasi13arsip,8snapshot worker/23tabel bisnis, strict interval seluruh tabel+policy+arsip sama, startup/alert metadata diperiksa. Disconnected/Off/targetnull; nol work M5 pending pada snapshot sesudah cleanup. Exact originalAPK6 fixture kembali tanpa launch; ordinary/legacy/campaign/ekspor hash terpelihara dan DV awake/APK asal pulih. Manual D-MAN17 dan pembatalan tambahan tetap reported, diverifikasi native terpisah. M5 selesai pada cakupan tersedia; natural21/reboot/Doze/revoke nyata/80mm/OEM/TalkBack dan batas lain tetap UNVERIFIED. M6 tidak dimulai. [Laporan akhir](M5_FINAL_REPORT_20261019.md).**
