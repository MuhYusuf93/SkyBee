# Sesi manual Realme — 16 Oktober 2026

**Finalisasi selesai dengan batas bukti.** Ringkasan actual:
[REALME_C11_MANUAL_RESULTS_20261016.md](../../REALME_C11_MANUAL_RESULTS_20261016.md),
riwayat [manual-findings.md](manual-findings.md), penutup otomatis
[final/verification.json](final/verification.json). Physicaldouble-submit tetap
belum terverifikasi; manual subset PASSreporteduser terpisah dari nativeSQL1/
UIclean2/strictaudit1 dan Windows1PASS. TalkBackfalse/font1,0, releaseAPKhashsama,
draft1pcs12000 dan ordinaryabsence terverifikasi akhir. Rawfailure/retry/cause
semantics belum pasti dipertahankan. Paragraf di bawah adalah checkpoint pembukaan
sesi; pending awal sudah digantikan hasil ringkasan final. Tidak ada reset/uninstall
atau DBrestore yang diklaim, fixture retained; berhenti sebelum M5/M6.

Pengguna meminta melanjutkan sesi yang ditunda15Oktober. Target eksplisit
0062112V2210F9B3 / RMX3231 / API30 / ARM32. Hanya pemeriksaan kesiapan dan
pembukaan paket integration dilakukan sebelum menyerahkan kontrol kepada pengguna.

- `resume-preflight.json`: identitas/ABI, installedAPKhash, packagepresence,
  launcher, awake/keyguard, Gboard, font1,0 dan TalkBackfalse. Hash cocok APK
  release actual cashier15Oktober; ordinarypackage absent pada pemeriksaan.
- `launch-existing-release.log`: am start-W pada fixture yang telah terpasang;
  activityexisting menerima intent, tanpa install/reset/force-stop.
- `initial-cashier.json` / `inspect-initial.log`: own-app semantics disaring,
  field credential direduksi helper; totalIDR0 terlihat. Ini otomatis, bukan
  bukti keyboard/touch atau transaksi manual telah lulus.

Langkah1 barcode000123/Done tiga kali telah diberikan; hasil belum diterima.
Jangan mengendalikan perangkat selama pengguna mencoba. Catat hasil pengguna
sebagai reported manual, terpisah dari verifikasi log/DB otomatis. Tidak ada
penghapusan fixture, ordinarydata atau pengaturan sistem pada pembukaan sesi.
