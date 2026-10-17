# Pengujian DV8910 M1–M4 termasuk M3.1

14 Oktober 2026, Asia/Jakarta. **Pengujian dan cleanup selesai, dengan temuan FAIL yang perlu ditindaklanjuti.** Instruksi pengguna mengadopsi seluruh prompt-codex-uji-dv8910-m1-m4.md. Pengujian tambahan; bukti Poco F6/Windows lama dipertahankan. M5/M6 dan perubahan kode produksi di luar lingkup. SkyBee hanya merek; applicationId/nama aplikasi tidak diganti.

Hasil akhir native: **118 kasus lulus = 109 SQL/Provider + 9 UI; 2 kasus UI gagal**, serta satu benchmark menengah lulus. Kegagalan UI berupa overflow 53 piksel pada management dan 51 piksel pada dialog pelunasan. Windows: 165 kasus fungsi dan dua benchmark lulus. Empat kasus helper yang diulang memperbarui bukti sebelumnya, tidak ditambahkan menjadi 169. Hasil berasal dari beberapa run dan retry; tidak ada klaim satu runner lengkap berakhir exit 0. Input Enter ADB dengan Leanback juga gagal pada jalur yang dicoba, terpisah dari 120 kasus fungsi. Detail [result-summary.json](evidence/dv8910-20261014/result-summary.json).

## Lingkungan dan isolasi

Hardware dikonfirmasi pengguna **DV8910**, firmware melaporkan **DV8947-KIX** (ADB model AX810/product XLHomeSTB22, dicatat tanpa mengubah identitas). LAN **192.168.0.102:5555**, connected/authorized. Android11/API30/security patch2022-02-05, armeabi-v7a/armeabi,1920×1080/density320,~21GB bebas. Root dilaporkan pengguna, tidak digunakan/diuji karena akses biasa mencukupi; bootloader/firmware/HDMI tidak diaudit atau diubah.

Aplikasi0.4.0+6/schema7, repository tanpa Git commit. Produksi com.example.kasir_app dan fixture com.example.kasir_app.integration tidak terpasang saat preflight. Native hanya tools/test_android.ps1, APK gate/flag KASIR_INTEGRATION_TEST=true/--no-uninstall/explicit serial. Tidak memakai VerifyOperationalDatabase yang force-stop ordinary karena paket produksi tidak ada; tidak ada DB baseline yang dapat dihash. Final productionabsence/dataDir fixture/DBkosong/processstopped telah diverifikasi (final-device-state.log);88baselinefilesunchanged/2allowedtestroutingdeltas (production-source-check.json). Tidak ada klaim recovery/preservation dataset lain.

Preflight: docs/evidence/dv8910-20261014/preflight.json dan adb-devices.log. Keyboard TV LeanbackIme/Gboard tersedia; perangkat input remote/IR/CEC ditemukan, belum membuktikan input fisik. Enabled accessibility services null; Paket TalkBack standar tidak ditemukan; TalkBack NOT TESTED/BLOCKED, tanpa memasang paket sistem. Tidak mengubah izin/setting/system clock/IME/display. Reboot Android NOT TESTED karena tidak ada kebutuhan yang membenarkan risiko terhadap penggunaan CCTV; force-stop tidak disamakan dengan reboot.

## Hasil otomatis dan batas bukti

- flutter doctor -v No issues exit0 (doctor.log), flutter analyze No issues56s exit0 (analyze.log).
- Windows165pass/1benchmark opt-in skip, exit0/reporter01:17 (windows-tests.log).
- DV8910 database suite11pass/reporter00:12. Native management run awal timeout30s pada rotasi/recovery PIN; KDF600000 terukur20808ms debug. Timeout diikuti database-closed dari teardown/pending future. Run diinterupsi setelah raw failure; bukan kelulusan seluruh suite.
- Test runner mendapat opsi bounded TestTimeout (default30s, DV8910 15m); KDF/assertion tidak dikurangi. Retest management14pass09:54, currency6pass09:09, cashier30pass00:38, wholesale14pass05:46; ditambah database11pass awal =75SQL unik. UIlocale kemudian tidak selesai43:39 dan adb deviceoffline; temp listener finalization PathNotFound sekunder. Koneksi saat resume sudah device lagi; belum menyimpulkan penyebab firmware/produk. SQLM4/benchmark berikutnya lulus, UI diretest dengan real-IO/boundedsettle/setup-cleanup, bindings/window/helper yang dibedakan; hasil akhir pada tabel per-case. Bukti native-functional.log/native-retest.log.
- Native M4 berikutnya exit0: reports/corrections24pass (09:06), storage10pass (04:01), medium benchmark1pass (01:04). Total **109 SQL/Provider unik +1 benchmark**. Daftar nama setiap assertion/suite ada di [native-suite-index.json](evidence/dv8910-20261014/native-suite-index.json), bukan penjumlahan percobaan gagal/duplikat.
- Medium benchmark Windows2pass/exit0/reporter00:35: 1.000produk/2.000sales seed4987ms dan default10.000/100.000 seed25861ms. Production SQL/query builders dan default besar tetap sama; hanya parameter fixture test ditambahkan.
- Native UI memakai fullyLive/defaultTestTimeout5menit; locale1 dan warehouseM31main1 lulus. KasirUSD1 lulus dalam suite exit1 karena IDRoverflow; seluruh11UIcase mempunyai hasil akhir (9PASS/2FAIL), SQL109 tidak membuktikan seluruh UI TV lulus.
- Build harness debug11,2s, release28,4s/16,1MB, profile43,6s/27,0MB, seluruhnya exit0/ARM32/.integration. Signing development yang sudah ada; tidak membuat/mengganti kunci produksi. Metadata pub/plugin diregenerasi resmi setiap pergantian mode.

## Rekap suite native dan kasus UI

| Suite | PASS unik / waktu reporter | Run yang menjadi bukti |
| --- | --- | --- |
| database |11 /00:12 | native-functional.log |
| management_inventory |14 /09:54 | native-retest.log |
| locale_currency |6 /09:09 | native-retest.log |
| cashier_sql |30 /00:38 | native-retest.log |
| wholesale_packaging_sql |14 /05:46 | native-retest.log |
| reports_corrections_sql |24 /09:06 | native-m4.log |
| m4_storage |10 /04:01 | native-m4.log |
| SQL/Provider total |**109** |7suite, bukan satu cleanrun baru |
| medium benchmark |1 /01:04 | native-m4.log, terpisah109 |

| ID / requirement | Kasus UI native | Hasil saat ini / bukti |
| --- | --- | --- |
| DV-UI-01 / M2-01/05/09 | SetupPIN, gudang/receipt/average,backgroundlock | **FAIL overflow53px** pada pemeriksaanakhir01:37, ui-management-driver-final.log; business/lifecycle assertions tercapai |
| DV-UI-02 / LC-01–08 | Publiclanguage/protectedUSD/liveform/currencyrefusal | PASS1/01:23/runnerexit0, ui-final-localization_ui.log |
| DV-UI-03 / M3-03/05/07/09 | IDR3scan/weightedcheckout/doublesubmit/recovery/settlement | **FAIL overflow51px dialogpelunasan**,02:15suite/+1-1; ui-final-cashier_ui.log |
| DV-UI-04 / M3-05,LC-07 | USDpartial/liveIDEN/same-namecustomerselectedID | PASS1 dalam suiteexit1, ui-final-cashier_ui.log; tidak mengklaim suiteM3 seluruhnya lulus |
| DV-UI-05 / M31-02–08 | Warehouseboxes/count/wholesalescan/draft/bilingualpartial | PASS1/01:51/runnerexit0, ui-wholesale_packaging_ui.log |
| DV-UI-06 / M31-01 | Above-retailwarningCancel/Continue | PASS; ui-check-m31_ui_gaps.log (4cases03:55/runnerexit0) |
| DV-UI-07 / M31-01 | Below-averagecostwarningCancel/Continue | PASS; ui-check-m31_ui_gaps.log (4cases03:55/runnerexit0) |
| DV-UI-08 / M31-08 | RemovedwholesaledraftblocksPay/explicitretail | PASS; ui-check-m31_ui_gaps.log (4cases03:55/runnerexit0) |
| DV-UI-09 / M31-08 | ChangedwholesaledraftCancel/Accept/nomutation | PASS; ui-check-m31_ui_gaps.log (4cases03:55/runnerexit0) |
| DV-UI-10 / M4-03–05/12 | Narrowreport/protectedsalecancellation/snapshots/liveIDEN | PASS1, ui-final-m4_ui.log (2cases/01:55/runnerexit0) |
| DV-UI-11 / M4-12 | Wide2xtext/reportlock/privacy | PASS1, ui-final-m4_ui.log; syntheticappview, bukan semuafisikTV |

Windowsfunctional165 awal+focusedM31updated4 tidak dijumlah menjadi169; fokus memperbarui bukti4kasus di165 tersebut. Medium/defaultbenchmark2 terpisah. Poco F6 historical120functional+1benchmark tetap di VALIDATION-M4/STATUS, bukan hasil DV. Dokumen pengguna melaporkan M1–M4 diujiPoco; itu manualreported, tidak mengarang case/log baru. Kedua konfirmasi screenwakeDV adalah availability, bukan manualtestpass.

## Matriks requirement → skenario → bukti

PASS berlaku hanya pada cara uji yang disebut. Satu klausul gabungan tidak dianggap seluruhnya compatibleTV bila sebagian jalur hardware/UI belum terbukti. ID FND/M2/LC/M3/M31/M4 mengacu matriks REQUIREMENTS yang tetap; DV-* adalah ID bukti tambahan.

| ID / requirement | Cara uji | Expected | Actual / status | Bukti |
| --- | --- | --- | --- | --- |
| DV-A1 / M2-01 | SQL PIN nol depan, salah/benar, salted600kKDF, lockout persisted, rotation/recovery | Tidak plaintext; lockout/recovery sah | PASS14suite gabungan, tidak memublikasikan credential | native-retest.log/management |
| DV-A2 / M2-02 | SQL monotonic timeout/revoke queuedwrites, process restart fixture | Pengelolaan terkunci setelah restart | PASS SQL +restart nyata; seluruh OEM lifecycle NOT TESTED | native-retest.log, debug/release/profile recovered |
| DV-A3 / M2-09 | Setup/show-hidePIN/recovery acknowledgement via native UI | Form dan gate bekerja | ManagementUI FAIL53px; localeUI gate PASS | ui-final-localization_ui.log; management retest |
| DV-B1 / M2-03 | SQL master/nullable category/supplier/SKU/barcode/archive/restore | Unik termasuk arsip; relasi/snapshot tetap | PASS | management14/cashier30 |
| DV-B2 / M2-04–05 | SQL initial/receipt/zero/requiredcost/idempotency/rollback | Average9000, no partial stock/value/facts | PASS | management14 |
| DV-B3 / M2-06–08 | SQL expiry/undated/FEFO/opname/waste/reversal/price/archiveundo/timewindow | Stok/nilai konsisten; perubahan lanjut tidak tertimpa | PASS | management14/cashier30 |
| DV-C1 / M3-02–04 | SQL exactleadingzero/token/alias/category/stale/draft/scan3/quantity/stock/undo | Satubarisqty3, draft tanpa pengurangan stok | PASS software; hardware scanner NOT TESTED | cashier30/native-retest.log |
| DV-C2 / M3-03 | ADB inputtext barcode +Enter named/numeric66 pada actual profile cashier, Leanback IME | Exactscan submit, searchclear, qty bertambah | **FAIL jalur input teramati**: suffix `t`, qty0. Sebab belum terisolasi | profile-scan3-ui.json/profile-enter66-ui.json/log |
| DV-C3 / M3-04 | Hentikan/buka proses fixture debug | Draft3 tetap, stok20 | PASS, PID berubah dan durablestate diverifikasi | debug-draft-recovered.json |
| DV-D1 / M3-05–06 | SQL fullpaid/partial/debt/invalidcurrency/samenamecustomers/lastunitrace/10faultstages | Atomic stock/payment/draft/audit, tanpa duplicate | PASS | cashier30 |
| DV-D2 / M3-07 | Debug checkout sebelum acknowledgement →force-stop→retry |1sale/sameID/stock17/debt26000 | PASS restart nyata, bukan reboot/powerloss | debug-before-restart.log/debug-committed-recovered.log |
| DV-D3 / M3-08–09 | SQL weighted snapshot/expiry/residue/205batches/oldestpayment/idempotency/3faults | Repayment tidak menambah sale/HPP/profit | PASS | cashier30 |
| DV-E1 / M31-01–03/08 | SQL nullablewholesale/protectededit/undo/toggle/scan/quantity/reopen/explicitcorrection | Mode manual perbaris dan snapshot lama tetap | PASS; UI lihat per-case tabel | wholesale14/native-retest.log |
| DV-E2 / M31-04–07 | SQL5dus×40/zero/negative/overflow/inputcost/USD-MYR/residue/configedit/count |200base, total600000; cost/inputunit exact, satu saldo | PASS; UI lihat per-case tabel | wholesale14 |
| DV-F1 / M4-01–02 | SQL fullperiod/repayment/USDfraction/negativeprofit/overflow |36000/27000/9000/debt26000, exact financial snapshots | PASS | reports24/storage10 |
| DV-F2 / M4-03–05 | SQL sale/payment reversal protection/reason/attestation/idempotency/10faults/expiredreturn/latermovements | Append-only consistent corrections; no partial facts | PASS syntheticattestation; physical goods/money NOT TESTED | reports24 |
| DV-F3 / M4-06–09 | SQL reconciliation/drift/filter/customerIDs/DST/halfpopen/ties/178events/cache150/generation | Fullperiod totals dan cursor tidak skip/duplicate | PASS | storage10/reports24 |
| DV-G1 / LC-02–05/09 | SQL IDENpersist/currencyindependence/financialguard/metadata/migration | Bahasa bebas; currency terkunci setelah fakta | PASS6SQL +1localeUI retest | locale_currency/native-retest.log; ui-final-localization_ui.log |
| DV-G2 / LC-06–08 | Windows formatter/parser/composing/cursor/selection/paste/separator/8locale-currencyroundtrip | Exact minorunits/caret/error | PASS suite Windows; bukan clipboard/IME perangkat | windows-tests.log |
| DV-G3 / LC-01/07,M4-12 | Actual1920×1080 release receipt dan profile cashier, ownapp screenshot/hierarchy | Bilingual layout/financial privacy readable | PASS limited visible receipt/cashier; management/dialog FAIL; keyboard fisik/virtual penuh NOT TESTED | release-cashier.png/UI, profile-receipt-ui.json |
| DV-G4 / LC-07,M3-03 | Externalkeyboard/scanner/mouse/remotephysical and OEMPoco input | Physical input nyaman/sesuai | NOT TESTED; userwakeavailability saja | preflight/inputmetadata; userreport terpisah |
| DV-G5 / R16-019 | TalkBack actual | Accessibility interaction | BLOCKED: standardpackage absent/enabledservicesnull; tidak dipasang | talkback-package.log/preflight |
| DV-H1 / FND-05–11,M2-10,LC-09,M3-11,M31-09,M4-11 | SQLite fresh/upgradepopulated/rollback/FK/index/immutableguards/reopen | Old values/relations retained; failure rollback | PASS database11 +milestoneSQL; bukan upgradeordinary DV (absent) atau restoreM5 | native-suite-index.json |
| DV-H2 / M3-07 | Release/profile preserve testfixture across installs/process restart | Same committedsale/counts/pointer/retry/lock | PASS modesmallfixture | release-recovered.log/profile-recovered.log |
| DV-H3 / R16-016 | Normal Android reboot/powerloss/realIOdiskfull/realbackuprestore | Durable acceptance | NOT TESTED reboot/powerloss; IO faultinjection PASS hanya stageSQL; M5 restore OUT OF SCOPE | userboundaries/currentSPEC |
| DV-P1 / M4-09–10 |1kproducts/2ksales debug native, productionqueries/EXPLAIN/1warmup5samples | Actualtimings/boundedpages/indexes | PASS measurement/reconciliation, tanpa SLA dibuat | android-benchmark.json/native-m4.log |
| DV-P2 / M4-10 |1product/1sale release/profile harness samples/FrameTiming | Actual mode runtime/sample numbers | PASS limited smoke/measurement; mediumprofile/fullreleaseacceptance NOT TESTED | release-cashier.log/profile-enter66.log |
| DV-X / M5,M6 | Printer/Drive/notifications/backuprestore/legal/publicrelease | Tahap mendatang | OUT OF SCOPE, bukan failM1–M4 | SPEC/STATUS |

## Performa aktual

Native medium: SQLite3.28.0/journaltruncate,1827pages×4096bytes (~7,48MB). Fixture1000products/2000sales/2000items+saleledger/1000initialbatches/600payments, consistentreconciliation. Seed48311ms/index14039ms terpisah dari query.1warmup+5samples; faranchor primarykey lookup, tanpaOFFSET. Debugtest; bukan profil rilis/SLA/peakmemory.

| Query | Median ms |
| --- | ---: |
| Catalog first / continuation / far |8,796 /8,900 /5,238 |
| History first / continuation / depth1500 |9,787 /10,249 /9,090 |
| Report detail first / continuation / depth1500 |9,531 /10,286 /9,799 |
| Common search |60,853 |
| Monthly summary |58,170 |

Smallfixture service samples setelah recovery (sekali, bukan distribution): debug search158,083ms/report117,362ms; release30,241/24,563ms; profile35,238/41,798ms. `am start -W` observed debugdraftrestart6986ms/release925ms/profile1945ms, coldprocess/task wait; tidak sama dengan firstusableframe atau seluruh startupdistribution.

FrameTiming rolling240initialharness/cashierframes: releaseframesseen1832/maxbuild14,753ms/maxraster28,435ms; profile1836/16,714/28,170ms. Tidak mengukur sustainedjank seluruh layar. Debug PIN PSS187772KB/RSS297204KB snapshot, bukan peak; gfxinfoTotalFrames0 tidak membuktikan zerojank. Raw EXPLAIN/plans/samples tersedia dalam android-benchmark.json.

## Recovery dan smoke modes

Fixture tetap `databases/dv8910_restart_20261014.db`, domainclockfixed tanpa perubahan jam/zona waktu DV. Initial20unitavg9000/barcodeleadingzero/draft3. Debugrestart pertama mempertahankan draft3/stock20; checkoutpartialpaid10000committed kemudian proses dihentikan sebelum acknowledgement. Restart kedua membuktikan1sale/revenue36000/cost27000/profit9000/debt26000/stock17/sameID/reconciled/managementlocked. Release/profile install-r danrestart membaca committedfixture yang sama dan retry aman; actualreceipt tampil dengan debt, tanpa HPP pada kasir publik.

Ini force-stop/proses mati terarah, tidak mengklaim reboot Android, pemadaman, restore, seluruh OEM lifecycle, atau normal app freshUI penuh. Kode harness test menyuntik AppServices/clock dan tidak mengubah codeproduction. Ketika `Belanja berikutnya` ditekan di profile, cartbaru aktifkosong; inputADBEnter gagal tanpa menambahsale/stockmovement.

Per-case latestreporter [native-UI-index.json](evidence/dv8910-20261014/native-UI-index.json) dan hasiljumlah [result-summary.json](evidence/dv8910-20261014/result-summary.json) memisahkan mixedrunFAIL dari caseUSD yangPASS. [artifact-manifest.json](evidence/dv8910-20261014/artifact-manifest.json) mencatat nama/ukuran/hash artefak lokal; bukan ekspor data aplikasi lain.

## Perintah dan alat yang dijalankan

Root kerja `C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit`. Flutter/Dart di `C:\Users\ACER\dev\flutter\bin`, SDK/ADB/aapt di `C:\Users\ACER\AppData\Local\Android\sdk`; aapt build-tools36.0.0. Python runtime Codex dipakai untuk probe/JSON/audit, bukan WindowsApps alias. Flutter3.44.7/Dart3.12.2/JDK21.0.10, Android SDK36.1. Tidak ada Git repository/commit yang dapat dilaporkan.

Semua ADB di bawah memakai `-s 192.168.0.102:5555`, semua deploy/test device ID yang sama. Output disimpan di direktori evidence khusus; tidak ada network scan. Daftar perintah berikut adalah keluarga perintah aktual beserta argumen pembeda; raw log per-run menyimpan keluaran dan waktu, bukan klaim semuanya satu run exit0.

| Perintah / alat | Hasil / bukti |
| --- | --- |
| `flutter doctor -v`, `flutter devices`, `adb connect 192.168.0.102:5555`, `adb devices -l` | Toolchain siap/deviceauthorized; doctor.log/adb-devices.log/preflight.json |
| `adb shell getprop` properti model/device/ABI/API/securitypatch; `wm size/density`, `df -h /data`, `pm list features`, `pm path` dua package; input/accessibility metadata | Read-only, data relevan disimpan preflight.json; production+test awal absent |
| `flutter analyze`, `dart format` filetest/harness yang diubah | No issues sesudah perbaikan lint helper; analyze*.log/format*.log; final check dicatat setelah UI |
| `flutter test --reporter expanded` |165pass/1 opt-in benchmarkskip, windows-tests.log |
| `flutter test test/m4_performance_test.dart test/dv8910_performance_test.dart --dart-define=KASIR_PERFORMANCE_FIXTURE=true --reporter expanded` |2benchmarkpass, windows-benchmark.log/json |
| `tools/test_android.ps1 -DeviceId 192.168.0.102:5555 -AndroidSdkRoot <SDK> -TestFiles @(...)` | APKidentitygate, explicitflag/--no-uninstall; initialfunctional.log defaulttimeout failure |
| Runner sama `-TestTimeout 15m` | native-retest.log75baseSQL; native-m4.log34SQL+1mediumbenchmark (`-PerformanceFixture`); UI perfile retests terpisah |
| `flutter build apk --debug/--release/--profile --target tools/dv8910_smoke.dart --target-platform android-arm --dart-define=KASIR_INTEGRATION_TEST=true` | Modebuild pass, build-smoke-*.log |
| `aapt dump badging <APK>`, `adb install -r <APK>` | Setiapdeploysmoke identity.integration verified, installSuccess; smoke-*-identity/install.log |
| `adb shell am force-stop com.example.kasir_app.integration`, `am start -W -n com.example.kasir_app.integration/com.example.kasir_app.MainActivity` | Scoped restart/mode launch; no reboot/otherpackage stop |
| `python tools/dv8910_device_probe.py --action inspect/tap/text/key/log/screenshot` | Uniqueobservedbounds/packagefocusguard; ownUI/log/screenshot only; selectedJSON/PNG/log |
| `adb shell settings get secure default_input_method`, `input --help` | Leanback active; usageprinted then unknowncommand error (help syntax), input sources verified; no settings writes |
| `input text 000123`, `input keyevent KEYCODE_ENTER`, `input keyboard keyevent 66` | Enter suffix `t` observed; profile-enter66-ui.json; actual scanner not tested |
| `adb shell dumpsys power`, filtered ownactivity/window metadata | Dreaming diagnosis; user woke remote, later Awake/ON. No system action |
| `adb logcat -d --pid=<own verified PID> -v threadtime`, `dumpsys meminfo/gfxinfo <testpackage>` | Scoped snapshots/PSS/frames limits, raw logs preserved |

## Bugs/observations

DV-HARNESS-01: credential rotation/recovery requires multiple600000-round KDF operations on32-bit DV8910; default30s body timeout closes fixture DB before pending future completes. Reproduce management_inventory_test with default timeout. Expected assertions finish; actual TimeoutException then database closed. Harness issue/high impact on evidence validity; retest bounded15m, unchanged security settings. Debug KDF latency is an observation, not release performance conclusion or firmware attribution.

DV-INPUT-01 — **FAIL pada jalur ADB + Leanback; asal belum terisolasi, dampak sedang untuk kasir TV/scanner Enter**. Repro: profile fixture actual KasirApp →Belanja berikutnya →fokus pencarian →`input text 000123` →Enter. Expected satu produk masuk dan pencarian bersih. Actual search `000123t`, cart0, stock17/sale1 tetap. Tiga percobaan menghasilkan `000123t000123t000123t`; Enter numerik66/sumberkeyboard juga sama. SQL scan3/synthetic input action merupakan bukti jalur berbeda. Tidak cukup bukti menyalahkan firmware/IME atau produksi. Saran tindak lanjut terpisah: reproduksi pada keyboard/scanner fisik, bandingkan editoraction/rawkey dengan instrumentasi uji, lalu putuskan perbaikan. Tidak mengubah IME/keymap/production handler.

DV-HARNESS-02 — initial UI43:39 terputus ADBoffline, retestrealIO masih tersangkut firstpump saat Dreaming. Local SDK IntegrationTest binding defaulttimeoutNone, sehingga CLI timeout saja tidak membatasi testWidgets. Test-only fullyLive/default5m membuat test berjalan ke assertion form; layar Awake diperiksa. Ini tidak membuktikan screensaver satu-satunya penyebab. Kegagalan baru locatorstokawal di locale adalah ketukan yang meleset/NoElement; helper fokus/scroll diperbaiki tanpa mengurangi financial assertions. Raw failures tetap disimpan.

DV-PROBE-01 — `dumpsys window windows` API30 tidak berisi currentfocus, sehingga helper sempat false-negative meski actualUI ada. Pakai fullwindowdump in memory lalu filter currentfocus; Android11 field kosong dibaca lewat class/hint. Diagnosis probe, bukan bug produk. Tidak menyimpan data window aplikasi lain.

DV-LAYOUT-01 — native UI management reported RenderFlex bottom overflow2px pada Gudang/InventoryProvider constraints960×420logical, bersama miss pada expansion. Native M3 IDR mencapai akhir business assertions namun `takeException()` menemukan overflow51px; testcase tetap FAIL. Repro awal:1920×1080density320 →safe runner managementUI atau cashierUI →produk/checkout/receipt/settlement flow; simpan ui-management_ui.log/ui-cashier_ui.log. Dampak sedang: konten bisa terpotong pada viewport pendek/keyboard/transisi. Belum dipastikan apakah2px tetap setelah helper fokus/scroll diperbaiki, atau route persis overflow51px; retest dengan diagnostik phase meneruskan error asli. Saran perbaikan produksi terpisah: reproduksi viewport/keyboard, periksa Flex/scroll area dan tinggi minimum, lalu regression pada TV/HP. Tidak mematikan error assertion.

DV-UI-LOOKUP-01 — USDsame-namecustomer native UI tidak menemukan phone-suggestion fixture dalam90s; helper tidak menggulir lazy suggestion di bawah field. SQLsame-nameID tetap PASS. Saran/retest test-only: drainlookup, scroll ke suggestion, pertahankan assertion selectedcustomerID/currency/locale. Tidak langsung menyimpulkan query produksi rusak. ui-cashier_ui.log rawexit1 disimpan.

Retest yang telah selesai: localeUI1PASS01:23 sesudah unfocus/scroll; M3USD1PASS dalam suite02:15/+1-1 sesudah lazycustomersuggestion digulir (selectedID/locale/financial assertions tetap). M3IDR tetap **FAIL** karena overflow51px, direproduksi ulang. Diagnostic `DV8910_LAYOUT phase=tap Catat pembayaran` mengidentifikasi dialog **Rincian pembayaran hutang** sesudah input pelunasan26000 pada native960×540logical. Source kandidat `lib/features/receivables/presentation/receivables_screen.dart:171` AlertDialog/Column dengan listcap240; saran investigasi scroll/flexibleheight terhadap keyboard/insets, tanpa patch produksi. Seluruh business assertions IDR sebelum pemeriksaan `takeException()` tercapai, tetapi testcase tidak dilabelPASS.

Overflow2px management awal belum muncul lagi pada retest01:08; kegagalan terbaru adalah tap expansioncollapse di y=-104 setelah ensureVisible tanpa frame settle, lalu NoElement untuk expansion berikutnya. Helper seluruhtap/show diperbaiki dengan unfocus/scroll/drain, business/lifecycle assertions tetap; retestdriverakhir01:37 mencapai seluruh business/lifecycle assertions lalu FAIL53px; tidak ada NoElement pada run akhir. Tidak memublikasikan2px sebagai bug permanen yang sudah terisolasi.

M4 windowrun: narrowcase1PASS01:06, widecase kedua didnotcomplete/ADBoffline01:55 lalu PathNotFound finalization sekunder. Ketika diagnosis berikutnya koneksi sudahdevice/Awake, ownPID11238 masihhidup; snapshot disimpan lalu hanya processfixtureforce-stop. Sebab network/firmware/SDK belum dibuktikan. KeduaM4cases diulang dan2PASS01:55/runnerexit0 di ui-final-m4_ui.log; narrowretry tidak dijumlah dua kali.

Management helper settledtap retest01:27 mendapatkan overflow53px pada masterregistry/PagedController constraints960×420 serta NoElement saat memilih kategori. Unfocus helper menyebabkan autocomplete menghilang; diperbaiki agar option selection mempertahankan focus. Overflow masterlist tersimpan sebagai observasi layout underlay/transisi yang memerlukan isolasi dampak visual, bukan pasti konten foreground53px terpotong. Raw ui-check-management_ui.log tetap ada, inspector deactivatedancestor adalah secondary error ketika mendeskripsikan disposedRenderFlex. Satu verifikasi setelah perbaikan fokusoption berikutnya selesai01:37, semua business/lifecycle assertions tercapai lalu `takeException()` tetap FAILoverflow53px pada ui-management-driver-final.log. Tidak ada NoElement pada run akhir.

## Log dan observasi visual

[log-snapshot-index.json](evidence/dv8910-20261014/log-snapshot-index.json) mencatat PID/rentang/baris: management35baris04:14:50–04:14:59, debugcommitted33baris06:12:07–06:12:37, release26baris06:14:58–06:16:38, profile111baris06:18:28–06:26:35, cashiersnapshot116baris06:32:47–06:34:07. Lima snapshot historis tidak memuat severity FlutterError/FATAL EXCEPTION/Unhandled Exception, tetapi **runner UI memuat kegagalan/overflow**; tidak menyatakan semua log bersih. Vendor/InputConnection/viewport/Choreographer warnings dan expectedFTS5/SQLitefault injections dibedakan. Regex awal terlalu luas sempat membaca URL engine/Flutter sebagai error; koreksi matchseverity, tidak menghapus rawlog. Snapshot managementUI setelah failure tidak tersedia karena PID sudah berhenti.

Screenshot release-cashier.png benar-benar menampilkan actualreceipt pada1920×1080; debug-draft.png adalah harnesscheckpoint. Keduanya diperiksa visual, bukan bukti navigasi semua form. M4 sharedtests memalsukan appviewphysicalSize390×844/900×1200,dpr1 dan2×text; jika lulus, itu syntheticadaptive UI pada perangkat, **bukan displayvirtual Android baru**, tidak mengubah resolusi/densityTV atau membuktikan semua layar native960×540logical.

FinalmainPID12975 buffer 51baris, matchingFlutterfatal/unhandled=0; bufferparsial dan expectedFTS5 probe/SQLite capabilityfallback tetap dibedakan. Ini tidak membatalkan dua UIrunnerFAIL.

## Konfigurasi uji dan penjagaan APK biasa

Sesudah layar kedua kali Dreaming, ditambahkan `IntegrationActivity` pada source directory `android/app/src/integrationFixture/kotlin` yang hanya ikut build bila flag KASIR_INTEGRATION_TEST=true. Activity memverifikasi package.integration dan memasang FLAG_KEEP_SCREEN_ON pada window sendiri. Tanpa wake lock/permission baru, perubahan setting screensaver, atau penghentian sistem; flag berakhir ketika Activity/proses berhenti. User mengaktifkan layar kembali dengan remote, availability saja. test-window-policy.log membuktikan flag pada window test.

Dua file build/manifest mendapat routing conditional launcher; nilai ordinary tetap MainActivity dan applicationId/label asli. Tidak ada perubahan lib atau MainActivity produksi/SQL/business/security. Baseline90files sebelumnya seluruhnya sama; final88unchanged+2allowedtestconfig deltas. APKordinary finaldebug build11,0s/exit0: IDcom.example.kasir_app/labelkasir_app/launcherMainActivity; semuaDEX diperiksa dan IntegrationActivity absent, tidak diinstallDV (ordinary-final-identity.log/ordinary-class-exclusion.json). Ini perubahan minimal build khusus test yang diizinkan dokumen, bukan refactor merek/fitur.

M31gap helper SQL menyiapkan produk sebelum UI lifecycle observer, lalu autentikasi Provider melalui PIN asli untuk state UI. Partial-setUp flags mencegah double-dispose provider dari kasus sebelumnya. Windows retest pertama kehilangan stateProvider dan gagal2/4 (raw disimpan); correctedretetst4/4pass00:21. Proteksi/finder/error assertions tetap. Native retry berikutnya4/4PASS03:55/runnerexit0 pada ui-check-m31_ui_gaps.log; assertions tetap, tidak menjumlahkan above-retail yang diulang.

Perubahan repository khusus uji: tools/test_android.ps1 (timeout), medium benchmark helper dan2wrappers,6nativeUI bindings/helper, m31sharedfixturehelper, tools/dv8910_smoke.dart, tools/dv8910_device_probe.py, scopedcleanupscript, IntegrationActivity plus2routingconfig, dokumen/evidence. Tidak ada fitur atau perbaikan produksi yang disisipkan. Pemeriksaan akhir19files0changes0,04s dan analyzeNoissues4,1s/exit0 (format-final-complete.log/analyze-final-complete.log). Audit367IDENkeys/287refs/244originalIDs; PythonAST/credential-literal log audit pass. Intermediate lint/deprecatedfinder dan dua Windowshelper failures yang diperbaiki tetap tercatat.

Satu retest native M31gap sebelumnya gagal di setUpAll00:22 dengan ADBoffline/PathNotFound finalization;0casepass pada run tersebut. Window tetap Awake ketika diperiksa, koneksi sudahdevice. Pada run gagal itu belum ada proof finalnative4/4; Windows4/4/oldnativeabove-retail1 disimpan terpisah. Retry berikutnya memberi proof4/4native yang aktual. Pada checkpoint kegagalan itu nativegap lain/freshfinalabove-retail BLOCKED; **retry berikutnya4PASS03:55**, transport pulih dan helperfinalnative terverifikasi; tidak menuduh credential/firmware failure tanpa bukti.

SDK livebinding pump schedules native frame and waits for its completer; paused lifecycle disables frame scheduling. Management helper now asserts synchronous authorizationlock while paused and UIprivacy after resumed, with resumed cleanup. This is test timing, not a relaxation of backgroundlock. That path was not claimed tested by the earlier failing runs. Redundant bodyensureVisible on absentlazyfields removed in favor of sharedshow; autocomplete retainsfocusuntilselection. Each intermediatefailure remains in evidence, latest result: management selesai01:37, FAIL53px pada assertionakhir; helper tidak lagi tersangkut lazy/autocomplete/paused.

## Smoke main, input ADB, dan batas IME

Finalbuild ordinarydebug11,0s dan isolatedmain debug10,8s exit0, officialpubregeneration. IsolatedAPK dipasang install-r/Success dengan gate ID.integration/IntegrationActivity; ordinaryAPK hanya diverifikasi lokal. Directmaincold `am start -W`8189ms/Wait8203ms, bukan firstusableframe distribution. Actualfreshcashier terbuka tanpa login, basketkosong/IDR0/Paydisabled pada1920×1080 (main-startup-ui.json/main-startup.png), gambar diperiksa visual. Normalmainstartup membuat `kasir_app.db` hanya di sandbox.integration.

ADBTab memindahkan focus dari kosong ke controlstore/language (main-tab-ui.json), tapsearch dan inputtext mempertahankan `000123` (main-typed-ui.json). Back menyembunyikan IME: mInputShowntrue→false (normalizedactualstdout: ime-observation.json), viewport kembali tinggi, teks tetap (main-back-verified-ui.json/main-back.png). Ini smoke keyboardADB, bukan navigasi semua shortcut/remote/physicalkeyboard. Tidak ada produk di fixturemainkosong sehingga tidak dipakai mengklaim exactscan/cart pass baru.

UIAutomator tidak mengeluarkan node tombol IME walaupun dumpsysmetadata menunjukkan mInputShowntrue dan viewportshrunk. Properti awal `ime_visible:false` padaJSON hanya berarti **nodes tidak ada di dump**, bukan keyboard tidak terlihat; helperfinal menamakannya ime_nodes_in_dump dan menambah system_input_shown. Directkeyselection virtualTVkeyboard **BLOCKED pada probe tersebut** (keysmetadataempty), EnterADBprofile tetap temuan terpisah; keyboardOEM/hardware belum diuji. Screenshotguard kini menolak mInputShowntrue/unknown; hanya booleans dibaca, bukan prediction/private text. Tidak mengubah selectedIME.

## Write ledger dan cleanup aktual

Initialordinary dan testpackage absent; semua artefak Android tugas ini dibuat hanya untuk `.integration`. Finalpackagecom.example.kasir_app.integration/version0.4.0/code6/dataDir/data/user/0/com.example.kasir_app.integration, debugordinarymainentrypoint+isolatedtestActivity, **retained dan stopped**. Produksi masih absent; tidak ada install/start/stop/clear/uninstall ordinary atau package lain. Permission/temp/systemsetting/root operations:none. WindowKEEP_SCREEN_ON berakhir ketika prosesfixture dihentikan; tidak ada wake lock atau setting yang perlu dikembalikan.

| Operasi tulis / target | Tujuan dan bukti | Keadaan akhir |
| --- | --- | --- |
| Install/update APK.integration, debugnative/smoke, release/profile, finalisolatedmain | Gateaapt sebeluminstall; safe runnerflag/no-uninstall, directinstall-r tanpafallback; native/build/smoke/install logs | Finalisolateddebugmain terpasang, PIDabsent |
| SQLfixtures nonce `databases/m1_integration_*`,m2/m3/m31/locale/m4 variants yang disebut wrappers | Schema/service/Provider/UI/fault tests, syntheticonly; wildcard di kolom ini hanya **notasi family**, tidak dipakai untuk delete | Normaltestcleanup masing-masing close/delete; leftoverexactnames dicatat di bawah |
| `databases/dv8910_restart_20261014.db` dan ownprobe table |20stock/draft3/sale1/restart/retry/report, fixedtestclock | ExactDB/journal dihapus setelah log/JSON disimpan |
| `databases/kasir_app.db` pada **package.integration** | Directoriginalmain startup smoke, bukan DBproduksi | ExactDB/journal dihapus; bukan restore/datareset pengguna |
| Testactivity/windowflag dan inputtap/text/Tab/Enter/Back | Ownapp foreground/fixture UI, tanpa settings | Prosesstopped; flaggone/inputfixturedeleted |
| UIAutomator `/dev/tty`, exec-outscreenshot, PIDlog capture | Metadata/gambar ownapp ke folderlaptop; tidak membuat screenshotfile padaAndroid | Artefak laptop dipertahankan; tidak ada devicecapturefile yang perlu dihapus |

Cleanup menggunakan tools/cleanup_dv8910_test_fixtures.py, normalUID/run-as, assertserial/package/absolute sandbox, force-stoponlytest, exactwhitelistnames, no wildcard/recursivedelete/pmclear/uninstall/root. [fixture-cleanup-plan.json](evidence/dv8910-20261014/fixture-cleanup-plan.json) disimpan sebelummutation; [fixture-cleanup-result.json](evidence/dv8910-20261014/fixture-cleanup-result.json) mencatat setiapdelete dan remaining_database_files kosong. **12file =6DB+6journal** dihapus:

- dv8910_restart_20261014.db dan .db-journal;
- kasir_app.db dan .db-journal (sandboxintegration saja);
- locale_ui_1791927772825158.db dan .db-journal;
- locale_ui_1791932538344909.db dan .db-journal;
- m31_gaps_1791934822660387_2.db dan .db-journal;
- m31_gaps_1791934822660387_3.db dan .db-journal.

Finalread-onlyprobe [final-device-state.log](evidence/dv8910-20261014/final-device-state.log): deviceconnected, productionpm-pathempty, fixtureinstalled/dataDircorrect, PIDabsent/DBdirempty. Janganlaunch ulang untuk finalcheck karena akan membuat DBbaru. APK uji berguna dipertahankan lokal `build/dv8910/integration-debug.apk`, smoke-release.apk, smoke-profile.apk; ordinary-debug.apk hanya buildverification, tidak diinstallDV. Semua screenshot/log/report tersimpan khususdi docs/evidence/dv8910-20261014. TestAPK yang retained akan membuat DBtesbaru saat nanti dibuka pengguna.

## Kesimpulan dan pekerjaan berikutnya

Fondasi/data/business M1–M4/M3.1 pada DV8910 teruji:109SQL/ProviderPASS,9UIcasesPASS,1mediumbenchmarkPASS, restartdraft/committedactualdebug dan committedretryrelease/profilePASS pada fixturekecil. **Dua UIcaseFAIL** karena overflow management53px dan dialogpelunasan51px; bukan semuaM1–M4TVacceptance lulus. Ad hoc EnterADB+Leanback juga tidak berhasilsubmit; sebab belum terbukti. Windows165functional+2benchmark serta focusedsharedhelper4PASS, doctor/analyze/format/audit/build/ordinaryidentity/class-exclusion/cleanup terbukti. Rawfailures/interruption/transportofflinelog tetap disimpan, tidak ditimpa dengan klaim kelulusan.

Perbaikan layout/dampak underlaymanagement dan validasi input pada keyboard/scanner fisik memerlukan tugas produksi terpisah sebelum menganggap DV8910 nyaman dipakai untuk kasir/pelunasan. CoreM4 menjadi dasar milestoneberikutnya, tetapi **M5/M6 tidak dimulai** pada tugasini; bukan siap rilis publik. Bukti Poco F6/Windows historis/MAN-USER-01/manualuserM1–M4 tetap dipertahankan dan tidak digantikan oleh DV.

Belum diperiksa/BLOCKED: directvirtualIMEkeyselection pada probe nodekosong, keyboard/scanner/mouse/remotephysical untuk alurapp, clipboard/OEMPoco, actualTalkBack(packageabsent), seluruhTVlayout/fonts/Androiddevices/nonrootcompatibility, normalAndroidreboot/powerloss/realIOdiskfull, peakRAM/sustainedjank/fullreleaseprofilemediumbenchmark/AAB/production signing. Force-stop tidak membuktikan reboot atau restore. M5: actualprinterBluetoothESC/POS/notifications/export/Driveopt-in/consistentbackup/safe restore. M6: legal/identitas/config/signing/accessibility/release acceptance. Perangkat printer/GoogleCloud yang disiapkan pengguna belum menjadi bukti integrasi.
