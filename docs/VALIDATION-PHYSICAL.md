# Validasi HP fisik — 13 Oktober 2026

> Koreksi 13 Oktober 2026: klaim no-uninstall/data pengguna untouched di checkpoint historis ini tidak boleh dijadikan bukti preservation. Flutter integration test default --uninstall=true; insiden M3.1 menemukan package operasional diinstal ulang dan DB lama tidak ditemukan. Lihat [INCIDENT-M31-ANDROID-TEST](INCIDENT-M31-ANDROID-TEST.md). Hasil assertion fixture tetap historis, bukan bukti retensi data produksi.


Checkpoint pemeriksaan M1–M2 dan Localization/Money, development 0.2.1+3/schema4. Tidak mengimplementasikan M3–M6.

## Laporan manual pengguna (MAN-USER-01)

Pengguna melaporkan telah mencoba aplikasi pada emulator dan HP fisik; alur yang dicoba berjalan baik. Dicatat sebagai **pengujian manual yang dilaporkan pengguna**, bukan pengamatan langsung agen atau hasil otomatis. Daftar alur, langkah, versi APK, keyboard, pengaturan accessibility, dan hasil per kasus tidak diberikan. Laporan ini tidak membuktikan seluruh acceptance SPEC, keyboard OEM, TalkBack, build release, atau restore.

## Target dan isolasi pengujian otomatis

`flutter devices` mendeteksi HP **24069PC21G**, ID **7f0edea0**, android-arm64, Android16/API36. Browser Chrome/Edge juga terdeteksi; tidak dipilih. Tidak ada emulator aktif dalam hasil discovery ini. Semua suite integrasi memakai `-d 7f0edea0` secara eksplisit. [Discovery](evidence/physical-devices.log).

Suite memakai database fixture bernama m1_integration_*, m2_integration_*, locale_*, locale_ui_*, m2_ui_*; tidak menunjuk database operasional kasir_app.db. Tidak melakukan uninstall, clear-data, reset, atau restore data pengguna. Pengujian UI memasukkan teks melalui Flutter test input dan mensimulasikan lifecycle; berjalan pada hardware fisik tetapi tidak otomatis menjadi pengujian keyboard OEM atau tombol Home/force-stop.

## Perintah dan hasil (AUTO-PHONE-01)

```powershell
flutter test integration_test/database_test.dart integration_test/management_inventory_test.dart integration_test/locale_currency_test.dart integration_test/localization_ui_test.dart integration_test/management_ui_test.dart -d 7f0edea0 --reporter expanded
```

**Exit0, 33 test lulus, reporter 08:02**. [Log integrasi](evidence/physical-integration.log).

| Suite pada HP | Hasil | Lingkup |
| --- | --- | --- |
| database_test.dart | 11 lulus | Schema/FK/constraint, repository, keyset/index/EXPLAIN, migrasi/rollback/downgrade, coordinator |
| management_inventory_test.dart | 14 lulus | Otorisasi/PIN/lockout/recovery, master/barcode, receipt/HPP/atomicity/idempotency/reversal, expiry/count/waste, undo/settings/paging/migration |
| locale_currency_test.dart | 6 lulus | Bahasa public/persistensi, katalog/guard currency termasuk produk nol/arsip/fakta, USD minor/metadata, V3→V4 integrity dan failure rollback |
| localization_ui_test.dart | 1 lulus | Bahasa ID/EN, PIN/protected USD, nominal live form tetap, currency refusal |
| management_ui_test.dart | 1 lulus | Setup PIN, kategori/produk/receipt/HPP, undo harga, activity dan simulated background lock |

Total **31 SQL + 2 UI**, driver Android sqflite pada HP fisik. Windows 64 test/analyze/format/gen-l10n adalah bukti checkpoint sebelumnya, tidak dijalankan ulang karena tidak ada perubahan kode pada pemeriksaan ini. KDF fixture 600000 putaran/256bit tercatat **5523 ms** pada debug test; tidak menjadi benchmark release atau jaminan latency semua perangkat.

Setelah suite selesai, `flutter build apk --debug` **exit0, Gradle14,9 s** membangun entrypoint aplikasi biasa, bukan test. [Build](evidence/physical-build-debug.log). `adb -s 7f0edea0 install -r build/app/outputs/flutter-apk/app-debug.apk` **exit0, Success**, menggantikan APK test dengan APK debug aplikasi dan mempertahankan data paket; tidak melakukan clear-data/uninstall. [Install](evidence/physical-install-debug.log). Ini bukan restore database/arsip, bukan build release, dan bukan pengujian ulang isi data operasional pengguna.

Audit dokumen/localization `python tools/audit_localization.py` **exit0**: 213 bilingual keys dengan metadata/placeholder cocok, 184 referensi statis, 244 ID requirement lama unik. [Audit](evidence/physical-doc-audit.log).

## Pemeriksaan log (LOG-PHONE-01)

Log integrasi diperiksa bersama snapshot logcat yang dibatasi PID com.example.kasir_app menggunakan adb `-s 7f0edea0 logcat -d --pid=<PID> -v threadtime`. Snapshot bukan rekaman lengkap seluruh sesi/hardware. Error downgrade dan benturan index/kolom pada fixture migration sengaja dipicu untuk membuktikan penolakan/rollback; harus dinilai bersama hasil test, bukan dianggap kegagalan aplikasi operasional.

Snapshot [M2 SQL](evidence/physical-logcat-m2.log), [locale SQL](evidence/physical-logcat-locale.log), [locale UI](evidence/physical-logcat-ui.log), [M2 UI](evidence/physical-logcat-ui-m2.log) diperiksa. Tidak ditemukan FATAL EXCEPTION/AndroidRuntime error/Unhandled Exception/Flutter error pada snapshot yang ditangkap. Ada pesan vendor property/SELinux access denied, Gralloc/GraphicBufferAllocator/AHardwareBuffer gagal probe/alokasi format59 ukuran4×4, serta SQLiteConnection long db operation pada fixture. Pesan tersebut tetap dicatat; seluruh assertion suite lulus, tetapi tidak membuktikan kualitas rendering/performa release maupun seluruh kondisi hardware. Tidak mengubah kode untuk menyembunyikan pesan vendor.

## Belum dibuktikan (UNVERIFIED-01)

- Keyboard/clipboard/IME OEM, seluruh input dan kombinasi layout, TalkBack dan accessibility manual.
- Release/profile/AAB, signing produksi dan performa/KDF release.
- Restore arsip nyata, backup/Drive/printer; M5 belum diimplementasikan.
- Seluruh OS/perangkat dan acceptance akhir M3–M6. Migration fixture SQL yang lulus tidak membuktikan restore.

Bukti emulator/Windows sebelumnya tetap historis di VALIDATION-LOCALIZATION-MONEY; tidak dianggap dijalankan ulang pada checkpoint ini.
