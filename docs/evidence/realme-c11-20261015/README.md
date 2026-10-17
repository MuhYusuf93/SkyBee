# Bukti Realme C11, 15 Oktober 2026

Status pekerjaan/interpretasi: [laporan utama](../../REALME_C11_FINAL_M1_M4_TEST_REPORT.md).
Target Realme `0062112V2210F9B3`, paket `com.example.kasir_app.integration`.
Semua DB/nominal/nama pada fixture adalah sintetis. Tidak ada Git pada workspace;
`source-baseline.json` berisi 174 fingerprint awal. Enam file lama diubah sengaja
(Gradle, kedua Activity, PinHasher dan dua helper UI). GeneratedPluginRegistrant
dapat berubah otomatis mengikuti jenis build; gunakan `source-check.json` akhir
untuk jumlah aktual. Penambahan helper/native/vendor dicatat terpisah.

## Cara membaca bukti

- `suite-evidence-index.json`: indeks reporter/exit dari raw log, termasuk gagal,
  partial dan retry. `functional-totals.json` menghitung kasus unik, memisahkan
  sebelum/sesudah backend PIN dan DV; eksperimen KDF bukan kasus baru berulang.
- `native-*_test.log`: fase awal. `post-pin-realme/`: regresi setelah perubahan
  KDF. `post-pin-dv/`: subset lintas perangkat terbaru bila tersedia.
- Windows awal `windows-all.log`; akhir `windows-post-pin.log`: 179 PASS dan
  dua opt-in benchmark SKIP. Hasil fokus acceptance2 tidak ditambahkan lagi.
- `native-pin_factory_reference.log` / `native-pin_native_backend_test-mac.log`:
  eksperimen OS Java 18–21 detik, kompatibel tetapi tidak dipilih untuk final.
  `native-pin-mbedtls-attempt3.log`: kontrak final empat kasus/01:04, lima vektor,
  native-vs-Dart, verifier lama dan lima sampel3,06–3,08s. Dua build sebelumnya
  gagal header transitif sebelum install; bukan crash perangkat.
- M3.1 UI original/attempt2 FAIL pointermiss tetap disimpan. Attempt3 helper
  PASS02:05; tidak ada marker wait pada PASS, jadi internal overlay/timing tidak
  dipastikan. Strict hit target/mode/stock/biaya assertions tetap.
- M2 `post-pin-realme/management_ui_test.log` FAIL pointer Save; attempt2 PASS
  setelah bounded hit-test wait, dengan marker M2_HIT_WAIT benar-benar terjadi.
  Assertion harga, undo dan background lock tetap; tidak dijumlah sebagai kasus baru.
- `medium-benchmark.json`: raw metadata/plans/5samples,1000produk/2000sales,
  debug. Seed/index tidak dimasukkan ke query latency. Tidak ada SLA rekaan.
- `*-before-pin-opt*`: baseline profile APK/log/JSON dipertahankan. Runtime
  pertama `runtime-profile-too-early.json` invalid karena probe mendahului
  install; `runtime-install-overlap-times.json` menunjukkan urutannya.
  `runtime-profile-before-pin-opt.json` adalah retry serial yang sah.
- `profile-mixed-abi-rejected.json`: narrow profile awal ditolak gate sebelum
  install karena CMake mengiklankan ABI tanpa engine. Target CMake diperbaiki;
  verifikasi ARM32 fixture dan universal tiga ABI ordinary tersimpan terpisah.
- `runtime-profile-after-pin-focus-blocked.*`: empat cold berhasil, kemudian
  NotificationShade mengambil fokus. User menutup panel; runtime-profile.json
  dan runtime-profile-after-pin-retest.log memuat retry lengkap PASS. Raw blocker
  tetap disimpan; bukan bukti crash atau SKIPPED_SYSTEM.
- Profile/release berikutnya dan `actual-*` memisahkan recovery harness (termasuk
  KDF) dari startup `KasirApp` tanpa KDF otomatis. `TotalTime` Activity bukan
  latensi interaksi/UIAutomator atau startup penuh semua fitur.
- `preflight.json`, doctor/devices, PID/memory/battery logs: snapshot sesuai
  waktu, bukan peakRAM/leak proof atau jaminan seluruh log bebas error.
- `actual-release.json`: tiga cold/tiga warm, tiga siklus route/detail dan Home
  relock. `metrics-summary.json` mempertahankan sampel/range; PSS akhir40.877KiB
  tidak dipakai mengklaim peak atau tidak ada leak.
- `checkout-release.json`: satu warmup/lima checkout service release pada DBnonce
  terpisah, lima sampel62,668–72,849ms; konsistensi enam sale diverifikasi dan
  nonce DBdeleted. Tidak ada before/after checkout latency yang setara.
- `native-realme_integrity-pre-manual.log` dan `native-realme_integrity-after-cycles.log`:
  masing-masing1PASS, kasus sama dihitung sekali. Keduanya SEBELUM interaksi
  fisik pengguna; bukan bukti integrity pascamanual.
- `apk-cashier-release-restored-verification.json`, install/launch-restored,
  `cashier-release-ready.png`: APK actual release yang sama dikembalikan dan
  kasir kosong siap. `manual-handoff-state.json`: TalkBackfalse/font1,0 sebelum
  manual. `final/preflight.json` menjaga source-baseline174files awal.
- `report-before-automatic-final.md`: snapshot laporan progress sebelum penutupan
  otomatis. Jangan menjalankan ulang finish_automatic_checkpoint.py setelah
  laporan manual ditambahkan; script ini hanya membangun checkpoint otomatis.

Log PowerShell5 sebagian UTF16LE/BOM; parser mendeteksi encoding. Jangan rewrite
log aktif. Redaksi VM auth hanya sesudah writer selesai; jangan menyalin PIN,
verifier, token, isi clipboard atau saran keyboard pribadi ke laporan.

## Isolasi dan tindakan tulis

Native suite hanya melalui `tools/test_android.ps1`, explicit DeviceId/SDK,
APK package gate, isolation define, no-uninstall. Build smoke/manual memakai
define yang sama dan direct install-r setelah AAPT `.integration`/ARM32 gate.
Tidak ada ordinary install/open/reset/uninstall, root atau perubahan OS.
Ordinary package absent awal; tidak ada hash ordinaryDB untuk diklaim preserved.

Nonce fixture dibuat/dihapus oleh suite pemiliknya. Fixture tetap
`realme_restart_20261015.db` dimiliki task ini untuk process-recovery/manual;
tabel tambahan `realme_probe` hanya metadata uji. Uang/stok tetap melalui
service produksi. Jangan menghapus fixture tetap sebelum manual/final integrity
selesai; cleanup hanya nama tepat dalam sandbox, tidak wildcard/pm clear.
Test APK/fixture manual boleh dipertahankan untuk review dengan status eksplisit.

User menyatakan tersedia untuk interaksi fisik; hasil belum dianggap PASS sampai
laporan langkah benar-benar diterima. Gboard/touch/TalkBack dibedakan dari
Flutter synthetic/ADB. TalkBack awal disabled dan font scale1,0; jika berubah
untuk manual harus dipulihkan. Bukti Poco/DV/emulator lama tetap historis.
