# Pemeriksaan ulang M3.1 — data dummy

13 Oktober 2026. Pengguna menyatakan data sebelumnya dummy, mengizinkan reset DB/create baru, dan belum memasukkan data penting sampai M6 selesai. Pemeriksaan otomatis yang tersedia pada M3.1 selesai. M4–M6 tidak diimplementasikan. Database baru bukan recovery data lama; histori insiden tetap [INCIDENT-M31-ANDROID-TEST](INCIDENT-M31-ANDROID-TEST.md), referensi berikutnya [LESSONS-LEARNED](LESSONS-LEARNED.md).

## Reset dan startup aplikasi biasa

`flutter devices`/ADB setelah sambung ulang memilih **24069PC21G / 7f0edea0 / Android16 API36 arm64** eksplisit ([discovery](evidence/m31-recheck-devices-reconnected.log)). aapt ordinary package com.example.kasir_app/version0.3.1+5/label kasir_app/fully qualified launcher; direct adb install-r Success.

`tools/reset_dummy_android_db.ps1 -ConfirmDummyData -DeviceId 7f0edea0 -AndroidSdkRoot <SDK>` memverifikasi sandbox/force-stop dan hanya empat file kasir_app.db/wal/shm/journal. **Semua file sudah tidak ada**; tidak ada data lama yang berhasil dipulihkan/dihapus pada reset ini. Tidak pm clear/uninstall/recursive delete. Startup main aplikasi membuat DB lewat migration asli, bukan SQL fixture ([install/reset](evidence/m31-recheck-install-reset.log)).

DB baru **schema6/471040bytes**, quick_check=ok, foreign_key_check kosong, produk/penjualan/pembayaran/PIN0, satu draft kosong/cashier pointer/store_settings. Setelah install debug final/reopen, schema/FK/integritas tetap baik, journal_mode=delete, hash tetap sama. Aplikasi biasa ditinggalkan terbuka; PIN belum dikonfigurasi karena database baru. Metadata/case: [fresh DB](evidence/m31-recheck-baseline.json), [reopen](evidence/m31-recheck-normal-reopen-summary.json). Salinan file hanya dibaca dari DB dummy yang dihentikan, dipakai SQLite read-only dalam temporary directory lalu dibuang; bukan export/restore fitur M5.

## Hasil otomatis

| Pemeriksaan | Hasil aktual | Bukti |
| --- | --- | --- |
| Windows full regression | **128 pass**, exit0/reporter01:17 (124lama+4gaps) | [log](evidence/m31-recheck-windows.log) |
| UI warning/correction tambahan |4pass Windows dan4pass native: above-retail/below-exact-HPP Cancel/Continue; wholesale removed blocks Pay until explicit retail correction; changed wholesale Cancel/Accept latest prices retains mode. Tidak menciptakan sale/mengubah stock diam-diam | test/support/m31_ui_gaps_suite.dart; [Windows](evidence/m31-recheck-gaps.log); native final module |
| Native safe runner | **84 pass =75SQL+9UI**, seluruh10suite, script exit0; tidak interruption/union retest untuk run ini | [raw log](evidence/m31-recheck-android-all.log), [summary](evidence/m31-recheck-native-summary.json) |
| Isolasi | APK fixture verified aapt com.example.kasir_app.integration/label tests; installed dataDir.integration. Semua suite explicit flag/--no-uninstall. Ordinary DB SHA256 sebelum/sesudah sama | tools/test_android.ps1; [installed identity](evidence/m31-recheck-fixture-installed-identity.log) |
| Doctor | Exit0/No issues; Flutter3.44.7/Dart3.12.2/Android36.1/buildtools36.0.0/JDK21.0.10/licenses accepted | [doctor](evidence/m31-recheck-doctor.log) |
| Formatter akhir |109files/0changed0.34s, exit0 | [formatter](evidence/m31-recheck-format-final.log) |
| Analyzer akhir |No issues25.5s/exit0 | [analyze](evidence/m31-recheck-analyze-final.log) |
| Ordinary debug final |Exit0/Gradle25.4s, direct install-r Success/identity com.example.kasir_app0.3.1+5; empty cashier visible/reopen/hash/integrity pass | [build](evidence/m31-recheck-build-debug-final.log), [install](evidence/m31-recheck-install-normal-final.log), [reopen](evidence/m31-recheck-normal-reopen.log) |
| Ordinary release build |Retry with official plugin regeneration exit0/Gradle23.5s/APK51.8MB | [retry](evidence/m31-recheck-build-release-retry.log) |
| Release startup smoke |Normal main entrypoint + fixture flag, build exit0/Gradle32.3s, direct install-r, actual shopping-list/empty message/Pay visible by package-filtered UI hierarchy; ordinary hash unchanged | [build](evidence/m31-recheck-build-release-fixture.log), [runtime](evidence/m31-recheck-release-runtime.log), [summary](evidence/m31-recheck-release-summary.json) |

Release masih **development/debug signing**. Smoke hanya startup kasir kosong pada package terpisah; tidak mengesahkan seluruh alur release/performance/AAB/Play signing. UI hierarchy bukan TalkBack test. Main release tidak memakai entrypoint integration_test; fixture flag hanya mengisolasi applicationId. Raw XML perangkat sementara dibuang; bukti hanya node package aplikasi, tanpa log/screenshot aplikasi pribadi.

Artefak akhir: `build/app/outputs/flutter-apk/app-debug.apk` adalah APK **ordinary** yang dipasang terakhir. `app-release.apk` sekarang hasil **fixture smoke/package integration**, bukan APK ordinary untuk distribusi. Nama file keluaran Flutter tidak membuktikan applicationId; verifikasi aapt wajib sebelum instalasi/build berikutnya.

### Rincian native (count unik per suite, durasi reporter)

| Suite | Count | Reporter |
| --- | --- | --- |
| database_test.dart | 11 | 00:03 |
| management_inventory_test.dart | 14 | 01:39 |
| locale_currency_test.dart | 6 | 01:35 |
| cashier_sql_test.dart | 30 | 00:13 |
| wholesale_packaging_sql_test.dart | 14 | 01:01 |
| localization_ui_test.dart | 1 | 00:26 |
| management_ui_test.dart | 1 | 00:27 |
| cashier_ui_test.dart | 2 | 00:45 |
| wholesale_packaging_ui_test.dart | 1 | 01:06 |
| m31_ui_gaps_test.dart | 4 | 00:47 |

Fingerprint ordinary DB:
`2d3803984e87c541806fc25f5dc15f495f3da7d8f54ff77ee95f4ffab4af37c7`.
Sama setelah seluruh native suite, isolated release smoke, dan install/reopen ordinary final. Ini membuktikan byte retention baseline DB dummy tertutup yang diuji; bukan recovery database lama, jaminan seluruh keadaan/WAL, atau restore operasional.

## Pemeriksaan log (snapshot scoped)

| Scope | Snapshot | Hasil/batas |
| --- | --- | --- |
| Fresh ordinary startup |PID26642/186baris |0fatal/unhandled/E-flutter/databaseexception;11error platform/vendor/GPU/ashmem tercatat |
| Native UI gaps terakhir |PID6885/43baris, waktu buffer10-13 05:58:54.582–05:59:22.305 (clock perangkat) |PID diverifikasi exit-info package fixture;0fatal/unhandled/Flutter/databaseexception pada snapshot.2error MiuiPreloadClassImpl/FramePredict;5warning MessageMonitor/InsetsSource. **Buffer parsial**, bukan seluruh47detik suite/seluruh84kasus |
| Isolated release startup |PID15051/170baris |0fatal/unhandled/Flutter/databaseexception;12error termasuk GPU/FrameInsert dan17warning platform tetap dicatat |
| Ordinary reopen final |PID25846/188baris |0fatal/unhandled/Flutter/databaseexception;12error/19warning platform termasuk GPU/FrameInsert tetap dicatat |

[Fresh log](evidence/m31-recheck-fresh-startup-logcat.log), [UI log](evidence/m31-recheck-ui-logcat.log), [release log](evidence/m31-recheck-release-logcat.log), [reopen log](evidence/m31-recheck-normal-reopen-logcat.log); summary JSON masing-masing di evidence/. Log snapshot bukan klaim semua log bersih atau semua hardware lulus. Intentional migration errors dalam raw native log (duplicate columns/cashier_state/currency guards) adalah fault injection dan assertion rollback lulus. Warning InputConnection/Spannable historis tetap didokumentasikan di VALIDATION-M31; buffer terbaru yang parsial tidak membuktikan masalah itu hilang.

## Hambatan/kegagalan yang diperbaiki atau dibatasi

- HP awal absent/sempat hadir lalu terputus; tidak reset/install/test saat discovery kosong. Setelah pengguna menyambungkan ulang, discovery berhasil dan proses dilanjutkan pada ID fisik yang sama. Log absence lama dipertahankan; tidak mengganti ke emulator.
- Release awal --no-pub exit1 karena GeneratedPluginRegistrant masih merujuk IntegrationTestPlugin. Retry resmi tanpa --no-pub meregenerasi metadata mode release dan berhasil. tools/test_android.ps1 memakai pub regeneration saat switch debug/release; tidak mengedit generated file/upgrade dependencies. [Failure](evidence/m31-recheck-build-release.log).
- Probe UI release pertama exit1 karena harness mengasumsikan judul Kasir; actual UI memakai nama toko/Daftar belanja. Assertion diperbaiki berdasarkan source/UI aktual, tanpa perubahan business code; retry exit0. [Initial failure](evidence/m31-recheck-release-runtime-initial.log).
- Probe metadata package sempat tidak dieksekusi: automatic approval review gagal karena usage limit, bukan keputusan unsafe. Runner yang sudah diotorisasi tetap selesai84/exit0. Saat pengguna meminta lanjut, metadata/log diambil melalui approval review yang berhasil; tidak bypass izin.
- Test Windows gaps awal syntax/label helper diperbaiki sebelum pass; raw failure m31-recheck-gaps-initial.log/m31-recheck-format-initial.log tetap ada. Reset tanpa ConfirmDummyData menolak sebelum ADB; parser scripts pass. Safety guard negatif native sebelumnya tetap bukti VALIDATION-M31.

## Manual pengguna dan belum diperiksa

**MAN-USER-01 historis:** pengguna mencoba alur emulator/HP dan melaporkan berjalan baik, tanpa rincian kasus; sebelum M3.1. Konfirmasi dummy/USB readiness bukan pengujian manual fitur baru. Tidak ada laporan manual M3.1/OEM/TalkBack baru.

**Unverified/pending:** keyboard/clipboard/scanner OEM nyata, TalkBack/seluruh adaptive accessibility, lifecycle/power-loss semua kondisi, full release checkout/soak/performance/AAB/production signing. Actual backup/archive/restore/manifest/WAL/logo/safety recovery/Drive/printer bergantung M5; cancellation/report M4 dan acceptance M6 belum diimplementasikan. Migration/copy fixture tertutup bukan actual restore. Pemeriksaan otomatis yang tersedia selesai; berhenti pada M3.1 untuk review. Tidak meminta data penting sebelum M6 sebagaimana instruksi pengguna.
