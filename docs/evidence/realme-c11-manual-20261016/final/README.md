# Bukti otomatis penutup manual Realme

16 Oktober 2026. Target0062112V2210F9B3 / RMX3231/API30/ARM32, package
`com.example.kasir_app.integration`. Hasil manual dilaporkan terpisah pada
[ringkasan](../../../REALME_C11_MANUAL_RESULTS_20261016.md).

- `verification.json`: hasil assertion metadata/ledger/hash/settings/source,
  dihimpun oleh `verify_checkpoint.py` sesudah semua writer berhenti. Tidak
  mengendalikan Android atau membuka DB. Physicaldouble-submit false/UNVERIFIED.
- `native-regression-ledger.json`: run pertama SQLPASS/UIFAIL/auditPASS.
  `native-clean-retest-ledger.json`: cleanUI2PASS/strictaudit1PASS, exit0.
  Tidak menjumlah retry sebagai kasus baru;4nativekasus penutup,1Windows.
- `native-exact-ledger*.log`: tiga audit sukses satu kasus, hash15tabel sama
  sebelum/sesudah;2sales/4payments/4allocations/debt26k/stock14/draft1pcs12k.
  `native-exact-ledger.log` FAILlookupnama tetap disimpan; diagnosis read-only
  metadata sintetis ada di `fixture-name-diagnosis.json`, tanpa salinan DB.
- `native-cashier-ui.log`: rawSemanticsHandleFAIL padaUSD, IDR sudahPASS.
  `native-cashier-ui-clean-retest.log`: duaPASS/01:06 tanpa UIAutomator.
  `ui-native-checkpoint.log` probe UI gagal melihat node saat run selesai;
  runtimecheckpoint setelahnyaPIDabsent saat jeda driver. Bukan bukti crash.
  Overlap probe/handle didukung waktu, precisecause tetapUNVERIFIED_CAUSE.
- `windows-checkout-idempotency.log`/`native-checkout-idempotency.log`: concurrent
  request sameattempt/sameID/one sale/payment PASS; bukan physicaltap proof.
- `analyze*.log`: initiallint1/rawexit1, retestNoissues3,0s dan5,7s/exit0.
  `localization-audit.log`/`vendor-audit.log`/`source-check.json`:367keys/287refs/
 244originalIDs/106vendorfiles/license/221unchangedproductionfingerprints.
- `preflight-before.json`/`source-baseline.json`: snapshot baru, baseline15Oktober
  tidak ditimpa. `runtime-before.json`/`runtime-release-restored.json`: TalkBackoff/
  font1,0/ordinaryabsent/releaseSHA969bccdd…1f709f7 beforeafter; ownPIDbuffers2dan
 23lines/0fatalmarkers, exit-info16recentreasons10. Cakupan terbatas ringbuffer.
- `release-apk-verification.json`/`restore-release*.json,log`: AAPTfixture/ABIARM32/
  JNI/ELF16KiB/license/ZIPverified, direct install-r/noreset/nouninstall, startupok.
  `ui-release-restored.json/log`: draft1pcs12000/actualcashier retained. Single
  launchTotalTime5714ms bukan benchmark. Tidak mengambil screenshot keyboard.
- `vm-auth-redaction-ledger.json`:0file membutuhkan redaksi baru; kegagalan dan
  timestamp tidak dihapus. Helper mendukung UTF8/UTF16 dan tidak menulis logaktif.

Tidak clear/reset/delete fixedfixture atau ordinarydata, tidak mengubah sistem,
aplikasi lain, firmware, identitas produksi, maupun memulai M5/M6. Only native
nonce fixtures cleaned by owning tests; manual DB/releaseAPK retained for review.
