# Bukti audit/perbaikan M1–M4 termasuk M3.1

Tes 14 Oktober 2026; laporan/pemeriksaan statis difinalisasi 15 Oktober. Rincian temuan dan batas bukti: [laporan](../../M1_M4_BUGFIX_REPORT.md). File sebelum/sesudah, failure, retry dan interruption tetap dipertahankan.

| Target | Kasus fungsi unik PASS | Bukti utama |
| --- | --- | --- |
| Windows |173; dua benchmark opt-in SKIP pada fungsi, dua benchmark PASS terpisah |windows-final-auth.log, windows-benchmarks.log |
| Poco F6 /7f0edea0 |128=113SQL/Provider+15UI |poco-native-final.log (127/14suite), poco-protected-reads.log (1) |
| DV8910 /192.168.0.102:5555 |74=59SQL/Provider+15UI; satu benchmark menengah terpisah |dv-native.log (11selesai+12managementpartial), dv-pagination-retry.log (1), dv-migration-retry.log (1), dv-cashier-final.log (30), dv-database-final.log (11), dv-locale-ui-retest.log (1), dv-wholesale-ui-final.log (1), dv-gaps-ui-final.log (4), dv-m4-ui-final.log (2) |
| Emulator /emulator-5554 |30=15SQL/Provider+15UI |emulator-native-final.log (7), emulator-independent-database_test.log (11), emulator-bootstrap-management_ui_test.log (1), emulator-bootstrap-cashier_ui_test.log (2), emulator-independent-localization_ui_test.log (1), emulator-wholesale-repeat.log (1), emulator-independent-m31_ui_gaps_test.log (4), emulator-independent-m4_ui_test.log (2), emulator-independent-protected_reads_test.log (1) |

Angka target tidak dijumlah menjadi unique produk. DV/emulator berasal dari run independen, bukan satu all-pass runner; retry3 DV, wholesale repeat, focused host7 dan cold-frame diagnosis1 tidak dihitung lagi. Suite SQL penuh yang tidak diulang pada DV tercantum pada laporan. Frame starvation/handshake emulator dan ADBoffline DV tidak memiliki diagnosis internal yang pasti meski retest lulus.

- `suite-evidence-index.json`: per-log suite/last reported count/exit; partial berbeda dari all_passed.
- `final-verification.json`: pemeriksaan hitungan, hash baseline operasional dan hash salinan APK tersimpan.
- `source-change-audit.json`:7file aplikasi,81file baseline sama,2delta routing uji sebelumnya; schema/business math tidak berubah.
- `format-final-6.log`, `analyze-final-6.log`, `localization-audit-final-2.log`, `python-ast-final.log`, `powershell-parse-final.log`: hasil pemeriksaan terakhir.
- `ordinary-artifact-verification.json`: APK debug/release biasa, ID/label/launcher/seluruhDEX; salinan di build/bugfix-20261014, tidak diinstall ordinary.
- `isolation-negative-build-result.json`: expected Gradle rejection exit1/tanpa install, entrypoint uji tanpa flag.
- `poco-ordinary-before/after.log`: main+journal hash cocok. `emulator-ordinary-before/after/final.log`: mainhash cocok, journal0byte awal/akhir; digestawal journal tidak direkam, digestkosong terukur sesudah/final. DV ordinary absent awal/akhir; tidak ada DBhash preservation DV.
- `emulator-owned-cleanup.json`:8exact owned files integration dihapus, remaining kosong; ordinary tidak disentuh. `dv-fixture-final.log`:DBdiruji kosong; APKuji dipertahankan.
- `scoped-log-summary.json`:15snapshotPID, rentang buffer terbatas;0fatal tidak berarti seluruh log bersih. `debug-uri-redactions.json`:auth URI VM sementara disunting pada bukti baru.
- `windows-benchmark-data.json`, `dv-benchmark-data.json`:rawplan/samples. Debug/1warmup5samples; bukan fullrelease/peakRAM/SLA.

MAN-USER-01 adalah laporan manual pengguna historis. Synthetic UI/ADB bukan keyboard OEM/scanner/TalkBack. Release build bukan full release runtime. Backup/restore/printer/Drive tetap M5/M6, belum dikerjakan. Database lama insiden M3.1 tetap missing/unrecovered; baseline preservation dan cleanup fixture bukan restore.
