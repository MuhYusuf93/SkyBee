# Validasi M4

14 Oktober 2026. **Implementasi dan pemeriksaan otomatis M4 selesai; berhenti untuk review.** Aplikasi development **0.4.0+6**, schema **7**, ordinary app sudah dipasang dan dibuka pada HP fisik24069PC21G/7f0edea0 Android16/API36. Tidak ada reset/uninstall ordinary. M5–M6 belum diimplementasikan. Keputusan arsitektur/policy: [M4-NOTES](M4-NOTES.md).

## Hasil otomatis dan perintah

| Pemeriksaan | Hasil aktual | Bukti docs/evidence |
| --- | --- | --- |
| flutter doctor -v | exit0, No issues; Flutter3.44.7/Dart3.12.2, Android36.1/build-tools36.0.0/JDK21.0.10 | m4-doctor.log |
| dart format --output=none --set-exit-if-changed lib test integration_test | exit0,131files/0changed0.41s | m4-format-final.log |
| flutter analyze | exit0, No issues3.1s | m4-analyze-final-pass.log |
| flutter gen-l10n + audit_localization.py | exit0;367bilingual keys/287static refs/244original requirement IDs | m4-gen-initial.log, m4-localization-audit-final.log |
| flutter test --reporter expanded | exit0,165pass/1skip, reporter01:08. Benchmark opt-in default skip | m4-windows-all-final.log |
| Windows opt-in benchmark --dart-define=KASIR_PERFORMANCE_FIXTURE=true | pass1/exit0, reporter00:27; separate from165functional/unit | m4-benchmark-windows-final.log/json |
| Physical native safe runner | exit0,120functional=109SQL/Provider+11syntheticUI, plus1benchmark;14suites. Unique cases, no summing retests | m4-native-all.log, m4-native-suite-results.json |
| Ordinary debug build | exit0, Gradle26.5s initial/19.8s final after fixture/release regeneration | m4-build-debug.log, m4-build-debug-final.log |
| Ordinary release build | exit0, Gradle34.1s,53.5MB; development signing. No M4 release runtime/performance acceptance | m4-build-release.log, m4-release-identity.log |
| APK identity/install/startup/reopen | verified com.example.kasir_app0.4.0+6, direct adb install-r Success; cold startup ok1815ms; cashier Kelola semantics visible; final reopen ok/PID22368 | m4-debug-final-identity.log, m4-ordinary-install/start/reopen.log, m4-ordinary-smoke.json, m4-ordinary-final-identity/pid.log |

Native command: `tools/test_android.ps1 -DeviceId 7f0edea0 -AndroidSdkRoot <actual SDK> -VerifyOperationalDatabase -PerformanceFixture -TestFiles @(...)` dengan14entrypoint tabel berikut. Wajib explicit KASIR_INTEGRATION_TEST=true, package gate `.integration`, `--no-uninstall`, pub metadata resmi. flutter devices memilih HP fisik eksplisit (m4-devices.log), bukan emulator/browser. Fixture path nonce dan sandbox terpisah; native installed dataDir `/data/user/0/com.example.kasir_app.integration`, ordinary `/data/user/0/com.example.kasir_app`.

| Native entrypoint | Pass | Durasi reporter (di luar build/install) |
| --- | --- | --- |
| database_test.dart | 11 | 00:03 |
| management_inventory_test.dart | 14 | 01:49 |
| locale_currency_test.dart | 6 | 02:13 |
| cashier_sql_test.dart | 30 | 00:13 |
| wholesale_packaging_sql_test.dart | 14 | 01:28 |
| localization_ui_test.dart | 1 | 00:29 |
| management_ui_test.dart | 1 | 00:29 |
| cashier_ui_test.dart | 2 | 00:47 |
| wholesale_packaging_ui_test.dart | 1 | 01:03 |
| m31_ui_gaps_test.dart | 4 | 00:56 |
| reports_corrections_sql_test.dart | 24 | 02:32 |
| m4_storage_test.dart | 10 | 01:07 |
| m4_ui_test.dart | 2 | 00:36 |
| m4_performance_test.dart | 1 | 02:16 |

Coverage M4: full-range >page, signed correction period, snapshot/HPP/repayment, money/USD/residue, authorization/attestation/retry, seven sale rollback stages/three payment stages/auth-loss, later restock/sale/expiry, nonmutating reconciliation, Jakarta/NY DST,178tie events, customer IDs, cursor filter/revision/generation/cache150, V6→V7 old facts/provenance/unknown defaults/rollback/FK/guards. UI narrow390×844 dan wide900×1200 text2×, report→detail→sale return/ID–EN/lock privacy; ini input sintetis, bukan keyboard/TalkBack/physical refund proof.

## Isolasi dan upgrade ordinary

Baseline V6:471040bytes, SHA256 `2d3803984e87c541806fc25f5dc15f495f3da7d8f54ff77ee95f4ffab4af37c7`. Hash sebelum/sesudah seluruh14native suite **sama**, runner exit0. Inspector setelah native juga membandingkan row multiset lama: sama. Baseline berisi satu settings/draft/cashier_state/android_metadata; produk/sale/payment/PIN0. Bukti ini melindungi baseline dummy yang diuji, bukan recovery data insiden atau seluruh dataset pengguna.

Actual ordinary startup migration V6→V7:507904bytes/schema7, quick_check ok/FK0, old-column counts dan row-value digests **semua cocok**. Hash baru `989aa556a59063e7c5b0faa92d19a9263a86c103cb2ef44838c9a1f419e76e22`; perubahan hash karena additive DDL wajar. Reopen mempertahankan hash dan nilai tersebut, lalu ordinary app ditinggalkan terbuka. Bukti m4-ordinary-before-initial.json (raw probe awal), m4-ordinary-before.json, m4-ordinary-after-upgrade.json, m4-ordinary-after-reopen.json. Tidak mengonfigurasi PIN atau memasukkan dummy fixture ke ordinary DB.

Inspector read-only mengambil file quiescent setelah scoped force-stop, menolak WAL dan nonzero rollback journal header. Main-file header hanya mengidentifikasi rollback family, **bukan** runtime DELETE/TRUNCATE/PERSIST; label `delete` pada raw probe awal merupakan inferensi terlalu kuat, diperbaiki pada probe berikutnya. Journal ordinary ada dengan header nol; runtime mode tidak diklaim. Hanya metadata/hash ditulis, tanpa nilai PIN/nama/HP. Ini bukti upgrade, **bukan fitur archive/restore M5**; migration populated fixtures diuji terpisah Windows/Android.

## Benchmark dan query plan

Fixture10000produk/100000sales/100000items/allocations/sale-ledger,10000batch/initial ledger,600payments; rekonsiliasi seluruh fixture konsisten. Seed/index/anchor di luar samples;1warmup+5timed, tabel median ms. Far anchor ~75000records memakai exact PK tanpa OFFSET. Mode **debug test**, bukan release/profile/SLA atau peak RAM measurement; batch250 membatasi objek sementara. Raw samples/max/plans ada dalam JSON.

| Query | Windows FFI ms | HP Android ms |
| --- | --- | --- |
| Katalog pertama | 0.361 | 2.809 |
| Katalog berikutnya | 0.398 | 2.160 |
| Katalog jauh | 0.558 | 2.115 |
| Riwayat pertama | 0.483 | 4.112 |
| Riwayat berikutnya | 0.479 | 4.919 |
| Riwayat jauh (~75k) | 0.586 | 3.900 |
| Laporan detail pertama | 0.495 | 3.864 |
| Laporan detail berikutnya | 0.509 | 3.995 |
| Laporan detail jauh (~75k) | 0.549 | 5.548 |
| Pencarian umum | 14.352 | 59.291 |
| Ringkasan bulanan | 116.026 | 322.327 |

Windows SQLite3.53.4/journaldelete/59389pages×4096, seed20461ms/index5494ms. HP SQLite3.44.5/journalpersist/59463pages×4096, seed91414ms/index40361ms. Fixture closed/deleted sesudah test, metadata/timings disimpan.

EXPLAIN memakai production query builder yang sama. Katalog composite tuple indexed seek; history/date/reversal menggunakan period index dan PK joins. Single effective period end pada continuation mencegah broad scan sebelum far anchor. Report outer SCAN/TEMP B-TREE mengurutkan maksimal102branch candidates yang sudah LIMIT51; summary SCAN events memang mengagregasi seluruh rentang. Search memakai exact barcode/SKU dan term prefix indexes tetapi GROUP BY/ranking/active-candidate join tetap berbiaya. Tidak mengklaim keyset membuat seluruh operasi O(1).

## Log scoped dan batas

| Snapshot | PID dibuktikan | Baris | Rentang buffer | Fatal/unhandled/E_flutter |
| --- | --- | --- | --- | --- |
| m4-native-log-snapshot.log | 24755 | 180 | 10-14 03:02:46.215–10-14 03:03:32.803 | 0 |
| m4-native-locale-log.log | 26429 | 183 | 10-14 03:05:00.690–10-14 03:07:02.671 | 0 |
| m4-native-ui-log.log | 15587 | 222 | 10-14 03:21:31.427–10-14 03:22:07.735 | 0 |
| m4-native-benchmark-log.log | 16910 | 175 | 10-14 03:22:32.725–10-14 03:24:46.182 | 0 |
| m4-ordinary-startup-log.log | 19416 | 377 | 10-14 03:30:27.494–10-14 03:30:58.232 | 0 |

Buffer parsial, bukan seluruh lifecycle. UI memuat RemoteInputConnectionImpl/WindowOnBackDispatcher/FrameInsert/platform/SQLite Long db operation warnings. Benchmark memuat satu E SQLiteLog `no such module: fts5` dari capability probe yang ditangani fallback; pencarian dan benchmark tetap pass. Expected SQL fault injection juga ada pada raw suite, bukan assertion failure. Tidak menyebut semua log bersih. PID UI historis15587 dibuktikan exit-info package; ordinary startup19416/final22368 dan fixture benchmark16910 tercatat. Log hanya package/PID terkait, tanpa global log aplikasi pribadi.

## Kegagalan dan perbaikan

- Initial analyze29issues:CurrencyPolicy import dan28lint; diperbaiki import/dart fix. Expanded analyze16lint/unused imports test; dart fix15, formatter kemudian dijalankan. Raw m4-analyze-initial.log/m4-analyze-expanded.log/m4-dart-fix*.log tetap disimpan.
- SQL awal4pass/20fail karena helper next() memakai saleId, API memerlukan draftId. Ganti helper, assertion tidak dikurangi; retest24pass.
- UI waiting pumpAndSettle dapat menahan IO nyata dan salah melihat teks parent selama transisi. Cleanup pumpWidget dalam global tearDown gagal inTest/guard; urutan local function juga sempat load-fail. Unmount+drain SQL/close di finally body test saat binding aktif dan wait real-IO/frame selesai. Narrow retest1pass00:07, lalu full kelompok13pass. Dua run Windows yang tersangkut dihentikan; tidak menjadi bukti exit0. Tidak pernah menyentuh package HP pada failure ini.
- Large fixture initial gagal PIN capability sebelum periode laporan:configure tidak unlock. Perbaiki explicit synthetic unlock; seeding di DB temporary/cleanup tetap. Tidak ada angka performance sukses dari run gagal.
- Error SQL pada test V7 rollback yang sengaja membuat tabel konflik adalah expected fault injection, bukan kegagalan assertion atau bukti semua log kosong.

- Initial full Windows162pass/3fail/1skip exit1: fixture dua invoice timestamp sama diurutkan UUID, allocation expected4actual2; beri second invoice+1ms. Penggantian literal versi terlalu luas sempat mengubah count quantity6→7, dikembalikan quantity6. Assertion upgradeV5 expectation6 diganti Schema.version7. Final165pass/1skip menggantikan run gagal, raw tetap disimpan.
- Query far-page awal~9ms Windows; dua redundant time bounds belum memperbaiki. Single effective time end=min(period end,cursor+tie allowance) mempertahankan semantik tie/filter dan menghasilkan final far median~0.55–0.59ms. Plans/samples tersimpan; tidak mengklaim semua queries O(1).


- Probe ordinary UI pertama gagal karena memeriksa atribut text saja; Flutter memakai content-desc. Harness diperbaiki (text/description semantics), produk tidak diubah. Retest smoke exit0/Kelola visible/PID19416, migration/reopen exit0.
- Peninjauan izin read-only baseline sempat tidak selesai sebelum deadline; retry sekali sesuai hasil tool berhasil. Build/install/upgrade selesai; tidak ada blocking approval tersisa atau bypass review.

## Manual dan belum diverifikasi

MAN-USER-01 historis: pengguna melaporkan alur yang dicoba pada emulator/HP berjalan baik, tanpa rincian kasus. Konfirmasi HP siap M4 adalah ketersediaan perangkat, bukan manual acceptance M4. Tidak ada laporan manual baru yang mengesahkan seluruh fitur.

Belum diperiksa: keyboard/clipboard/scanner OEM, TalkBack dan tablet fisik, seluruh lifecycle/power-loss, compatibility perangkat/API lama, peak RAM, release/profile runtime/performance/AAB/production signing. Printer/Drive/notifikasi/backup/restore nyata M5 serta legal/release acceptance M6 tetap pending. M4 selesai pada lingkup implementasi dan otomatis yang dinyatakan; seluruh aplikasi belum selesai. Berhenti M4 untuk review pengguna.
