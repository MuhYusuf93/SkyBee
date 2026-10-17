# Validasi M3 — 13 Oktober 2026

> Koreksi 13 Oktober 2026: klaim no-uninstall/data pengguna untouched di checkpoint historis ini tidak boleh dijadikan bukti preservation. Flutter integration test default --uninstall=true; insiden M3.1 menemukan package operasional diinstal ulang dan DB lama tidak ditemukan. Lihat [INCIDENT-M31-ANDROID-TEST](INCIDENT-M31-ANDROID-TEST.md). Hasil assertion fixture tetap historis, bukan bukti retensi data produksi.


Development 0.3.0+4/schema 5. M3 selesai pada scope bukti di bawah. APK aplikasi final dibuat setelah semua test APK; tidak menganggap seluruh aplikasi/M4–M6 selesai.

## Lingkup dan target

Windows SQLite FFI dan HP 24069PC21G/7f0edea0 Android 16/API36 arm64, dipilih eksplisit. Flutter 3.44.7/Dart 3.12.2. Seluruh suite SQL/UI Android memakai database fixture m1_integration_*, m2_integration_*, locale_*, locale_ui_*, m2_ui_*, m3_integration_*, m3_ui_*. Suite test tidak membuka/menghapus database operasional kasir_app.db; tidak melakukan uninstall/clear-data/reset/restore pengguna. Startup APK biasa sesudahnya membuka database operasional melalui jalur runtime/migration normal; tidak mengaudit isi seluruh data pribadi pengguna.

Manual pengguna 13 Oktober sebelum M3 tercatat di VALIDATION-PHYSICAL/STATUS-LOCALIZATION: alur emulator/HP yang dicoba baik, rincian/versi APK tidak diberikan. **Belum ada laporan manual pengguna untuk M3 baru.**

## Pemeriksaan aktual

| Perintah/pemeriksaan | Hasil | Bukti |
| --- | --- | --- |
| flutter analyze | Exit0, No issues found,2,3 s | evidence/m3-analyze.log |
| flutter test --reporter expanded | **Exit0,103 lulus**, reporter 01:10:64 regresi+30 SQL M3+4 Provider+5 layout | evidence/m3-tests-windows.log |
| flutter test test/cashier_provider_test.dart test/cashier_layout_test.dart | 8 lulus saat perbaikan locale; final 4 Provider+5 layout ikut 103 test Windows, termasuk late scan guard | evidence/m3-ui-windows.log |
| Native Android awal M3 | 29 SQL lulus, lalu UI gagal install karena INSTALL_FAILED_USER_RESTRICTED; pengguna mengonfirmasi siap USB dan install berikutnya berhasil | evidence/m3-android.log |
| Regresi 7 suite Android -d7f0edea0 | 61 SQL+2 M3 UI lulus;2 regresi UI gagal hanya finder readiness shell lama; run awal exit1/63 pass / 2 fail | evidence/m3-android-final.log |
| Ulang 2 regresi UI lama | **Exit0,2 lulus**, reporter 01:22 setelah finder menunggu kolom pencarian aktif; assertion bisnis dipertahankan | evidence/m3-android-regression-ui.log |
| M3 UI final setelah guard scanner | **Exit0,2 lulus**, reporter 00:46 | evidence/m3-android-ui-final.log |
| Focused M3 sesudah payment-intent correction | Exit0,38 lulus, reporter 00:07; subset sebelum test late scan tambahan | evidence/m3-targeted-final.log |
| gen-l10n | Exit0, SDK generator dari ARB | evidence/m3-gen.log |
| dart format lib test integration_test | Exit0,96 files / 0 changed | evidence/m3-format.log |
| localization/requirement audit | Exit0,272 keys/metadata/placeholder,233 references,244 IDs lama unik | evidence/m3-audit.log |
| flutter doctor -v | Exit0,No issues found | evidence/m3-doctor.log |
| flutter build apk --debug | Exit0,Gradle 13,2 s,APK aplikasi normal 0.3.0+4 | evidence/m3-build-debug.log |
| adb -s 7f0edea0 install -r APK / am start | Exit0/Success dan exit0/start activity; tidak uninstall/clear-data | evidence/m3-install-debug.log +m3-launch-debug.log |

**Total Android: 65 kasus unik lulus (61 SQL+4 UI) melalui run utama dan retest yang disebutkan. Run utama tetap exit1 di log historis; bukan seluruh suite dijalankan ulang sampai satu exit0.** Dua fixture lama menunggu teks teknis Local storage ready yang dihapus dari kasir produksi M3; readiness diubah ke kolom pencarian aktif.

Perintah run utama:

```powershell
flutter test integration_test/database_test.dart integration_test/management_inventory_test.dart integration_test/locale_currency_test.dart integration_test/cashier_sql_test.dart integration_test/localization_ui_test.dart integration_test/management_ui_test.dart integration_test/cashier_ui_test.dart -d 7f0edea0 --reporter expanded
```

## Skenario baru dan kegagalan yang diperbaiki

- SQL M3: exact/prefix/compact/alias/category, literal syntax/bounded16, dirty index, ambiguous cross-code; scan3 merge; persisted draft/form/reopen; stock/quantity/overflow; stale undo/price acceptance;36k/27k/9k/debt26k; full/partial/debt/zero/currency errors; retry hash/completed guards; postcommit pointer recovery; competing local coordinators last stock; fault at10 checkout stages; expiry/undated/FEFO205batches; oldest-first multi-sale repayment/stale/duplicate/overpayment; faults at3 repayment stages; same-name/customer keyset; V4→V5 preservation and failedV5 rollback. FK/quick_check setiap fixture.
- Provider/widget: stale query/dispose,3 overlapping Enter intents, ID/EN conditional checkout fields/live locale canonicalMoney, portrait320×568/tablet1024×768/landscape568×320 dengan teks 2× dan synthetic keyboard inset.
- Native M3 UI: M2 real initial10×8000+receipt10×10000, scan3,partial10000, total36000/HPP27000, double tap, recreateUI/recovery,next draft, public settlement26000 tanpaPIN; USD20.00/15.50→15,50 dan explicit same-name customer/phone002 selection. Status akhir berdasarkan log, bukan definisi test saja.
- Perbaikan: initial fixture memakai API create/receive yang salah diperbaiki; finder money label mengikuti suffix currency. Widget SQL startup dijalankan di real async zone; lazy fields digulir, bukan dianggap selalu mounted. Footer landscape overflow diperbaiki dengan layout horizontal dan nominal eksak dapat scroll tanpa mengecilkan text scale. Scanner generation tidak membuang intent Enter. Undo snackbar memegang token tindakan. Indeterminate loader tidak berjalan saat dialog manusia; native initial timeout dicatat di m3-android-ui-initial.log. Sibling preview locale memakai listener frame-safe; native error awal dicatat di m3-ui-locale-initial.log dan regresi widget live-locale lulus. Dua finder readiness shell lama diperbarui menjadi Search products/Cari barang tanpa mengurangi assertion PIN/inventory/currency. Correction quantity mempertahankan payment intent/customer/paid tersimpan; late success tidak membersihkan newer scan/error, dengan regression 4 Provider.

Expected errors pada negative migration/downgrade/FTS5 probe dibedakan dari assertion/testfailure. Native HP tidak mendukung FTS5; fallback BINARY token prefix dipakai dan diuji. Windows mendukung FTS5, backend tetap sama. Tidak mengklaim full catalog benchmark atau seluruh clipboard/keyboard.

## Log dan startup aplikasi final

Startup APK aplikasi biasa dibuka pada HP setelah install -r. Snapshot [m3-logcat-app-final.log](evidence/m3-logcat-app-final.log) dibatasi PID 31763:tidak ditemukan fatal/unhandled/Flutter error atau exception database startup pada snapshot. Ada8 pesan Gralloc/GraphicBufferAllocator/AHardwareBuffer tentang probe/alokasi format59 dan property/SELinux vendor. Pesan tetap dicatat; bukan bukti kompatibilitas semua GPU/keyboard/OEM. Native M3UI final juga mengambil takeException(null) pada kedua alur. Snapshot diagnostic lama m3-logcat-ui.log berasal dari investigasi sebelum perbaikan; tidak digunakan sebagai klaim log final bebas error. Screenshot m3-ui-diagnostic.png hanya fixture syntheticAlex/00123 ketika kasir terbukti foreground, bukan data operasional.

Versi terpasang diverifikasi: versionName0.3.0/versionCode4, minSdk24/targetSdk36 ([metadata](evidence/m3-installed-version.log)); ini bukan verifikasi kompatibilitas seluruh Android24–36. Install -r mempertahankan data paket; am start hanya memeriksa startup, bukan pembuktian manual seluruh isi data pengguna. Migration fixture bukan restore.

## Batas bukti

Keyboard/clipboard/IME OEM, scanner fisik, TalkBack manual, Home/force-stop/power-loss seluruhOEM, seluruhOS, release/profile/AAB/signing/performa rilis, printer/Drive/restore arsip nyata belum terverifikasi. Lifecycle/UI input sintetis dan reopen database bukan seluruh recovery OS/hardware. M4–M6 tetap pending; tidak mempublikasikan aplikasi.
