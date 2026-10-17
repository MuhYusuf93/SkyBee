# Status proyek

> Koreksi 13 Oktober 2026: klaim no-uninstall/data pengguna untouched di checkpoint historis ini tidak boleh dijadikan bukti preservation. Flutter integration test default --uninstall=true; insiden M3.1 menemukan package operasional diinstal ulang dan DB lama tidak ditemukan. Lihat [INCIDENT-M31-ANDROID-TEST](INCIDENT-M31-ANDROID-TEST.md). Hasil assertion fixture tetap historis, bukan bukti retensi data produksi.


**13 Oktober 2026 — Validasi HP fisik selesai; Localization/Money siap review sebelum M3.** Development **0.2.1+3**, schema **4**. M1–M2 dipertahankan; histori lengkap di STATUS-M2/VALIDATION-M1/M2 dan log m1-/m2-. Proyek/database tidak dibuat ulang. M3–M6 belum dimulai pada tugas ini. Tidak ada perubahan kode aplikasi pada pemeriksaan HP.

| Tahap | Status |
| --- | --- |
| M1 — Fondasi/arsitektur/skema/pagination | Diterima; regresi tetap lulus |
| M2 — PIN/persediaan/HPP/pengelolaan | Selesai; regresi Windows/Android lulus |
| Localization/Money — pekerjaan tersendiri | Implemented/verified pada lingkup bukti di bawah |
| M3 — Kasir/checkout/piutang/recovery | Pending |
| M4–M6 — Laporan/integrasi/legal/rilis | Pending |

## Hasil dan keputusan

- Bahasa ID/EN langsung tanpa PIN; perangkat id/en pada awal, fallback en, kemudian pilihan tersimpan. MaterialApp/Navigator/controller/session tetap dimiliki scope yang sama. Nama/master/alamat/footer/alasan pengguna tetap asli. Copy, validasi, dialog, snackbar, tooltip, accessibility/loading/error memakai ARB/SDK localization; 213 key dengan metadata/placeholder/plural.
- Currency IDR scale0 adalah kebijakan rupiah bulat; USD/MYR/EUR scale2. Number locale id_ID/en_US mengikuti bahasa, tidak memilih currency/timezone. Dropdown terproteksi service/PIN, kode di depan pada teks besar. Snapshot diterapkan setelah commit; penolakan mengembalikan pilihan tersimpan.
- Semua harga produk, **termasuk nol/arsip**, adalah Money terikat yang memblokir perubahan currency, bersama valuation/receipt/sale/payment/draft berharga/ledger/history/operations. Kategori/supplier tanpa nilai finansial tidak memblokir. Tidak ada relabel/konversi/penghapusan untuk mengizinkan dropdown. Bahasa tetap boleh diganti.
- Money(amountMinor,currencyCode,scale), BigInt checked arithmetic/mismatch/overflow, biaya 10^6 per minor terpisah currency_scale. MoneyCodec exact parser/intl formatter; major-unit typing, cursor/paste/delete/composing/partial input. MoneyEditingController menyimpan codec/canonical value saat field offscreen/unmounted; blur/submit menormalisasi. Biaya dibulatkan memakai metadata header dan menolak mismatch.
- V4 additive IDR0 backfill **tanpa x100/perubahan nominal/stok/HPP/nilai**. Driver tetap sqflite; M2 tidak memakai SQLCipher dan tidak ada driver/kunci enkripsi dihapus. Header/fakta menyimpan metadata, detail mewarisi header. FK/quick_check/failure rollback; reason_key membedakan pesan sistem dari user text. SQL suffix *_rupiah lama storage kompatibilitas minor units; domain priceMinor/amountMinor/Money menjelaskan unit.
- Batas input/arithmetic baru 9.000.000.000.000 minor; inventory fixed-point signed64 checked. Nominal lama di luar display boundary tetap dibaca/ditampilkan secara eksak tanpa double, tidak dipangkas. Kontrak archive versi lama/metadata di BACKUP-CONTRACT, bukan implementasi M5.

## File penting

- `lib/l10n/app_id.arb`, `app_en.arb`, `l10n.yaml`, generated app_localizations*.dart, localization.dart/LocalizedNotice: source/generator/overlay. Jangan edit generated manual.
- `lib/core/money/`, core/domain/value_types.dart: Money/policy/exact codec/formatter/controller/field, cost precision/mismatch.
- `lib/features/settings/application/settings_service.dart`, locale_provider/currency_selector/SettingsProvider/Screen: public language dan protected currency/scoped form state.
- `lib/app/kasir_app.dart`, presentation M1/M2: locale root dan semantic messages/money fields/labels.
- `lib/data/database/schema.dart`, repositories/domain inventory/catalog/sale_history: migration4, metadata, minor units/readers.
- Tests money/localization/support locale_currency_suite dan integration_test, tools/audit_localization.py.
- SPEC/PLAN/REQUIREMENTS/ARCHITECTURE/SCHEMA/README, [LOCALIZATION-MONEY](LOCALIZATION-MONEY.md), [BACKUP-CONTRACT](BACKUP-CONTRACT.md), [VALIDATION-LOCALIZATION-MONEY](VALIDATION-LOCALIZATION-MONEY.md), evidence. **244 ID lama + 10 LC clauses** tetap terlacak.

## Hasil aktual

| Pemeriksaan | Hasil |
| --- | --- |
| gen-l10n | Exit0, generator SDK dari ARB |
| doctor | Exit0, No issues found; lisensi Android diterima |
| analyze | Exit0, No issues found |
| format | Exit0, 73 files/0 changed |
| Flutter tests Windows | **64 lulus**: 40 regresi M1/M2 + 12 Money + 6 locale/UI + 6 SQL |
| SQL Android | **20 lulus**: 6 locale/currency/migration + 14 M2 regression |
| UI Android final | **2 alur lulus**: language/currency/live form/refusal + M2 setup/receipt/average/undo/lock |
| Audit | 213 bilingual keys/metadata/placeholder, 184 static references, 244 ID lama unik |
| APK debug aplikasi final | **Exit0, berhasil; Gradle 17,9 s**, evidence/locale-build-debug.log; build/app/outputs/flutter-apk/app-debug.apk |

Perintah, scope, expected error fixture rollback, kegagalan awal yang diperbaiki dan log di VALIDATION-LOCALIZATION-MONEY. Target Windows SQLite FFI dan emulator Pixel_7/emulator-5554 Android17/API37; Flutter3.44.7/Dart3.12.2. FFI bukan bukti Android; test APK bukan APK aplikasi final; migration bukan backup/restore nyata.

## Pembaruan validasi HP — 13 Oktober

| Jenis bukti | Hasil aktual dan batas |
| --- | --- |
| Manual dilaporkan pengguna — MAN-USER-01 | Pengguna mencoba aplikasi pada emulator dan HP fisik; alur yang dicoba berjalan baik. Rincian kasus/versi APK tidak diberikan. Bukan pengamatan langsung agen, tidak membuktikan seluruh acceptance |
| Discovery | flutter devices: HP 24069PC21G, 7f0edea0, Android16/API36 arm64; target dipilih eksplisit dengan -d 7f0edea0. Emulator tidak aktif saat discovery |
| Otomatis HP — AUTO-PHONE-01 | Exit0, **33 lulus (31 SQL + 2 UI)**: 11 M1 + 14 M2 + 6 locale/currency/migration + 2 UI; reporter 08:02. Database fixture terpisah, bukan database operasional |
| Log aplikasi — LOG-PHONE-01 | Snapshot logcat hanya PID aplikasi; tidak ditemukan fatal/unhandled/Flutter error pada snapshot. Ada pesan vendor property/SELinux, GPU buffer format59/probe, SQLite long operation; tetap dicatat. Error migrasi/downgrade di log test adalah negative fixture yang lulus |
| Build/install aplikasi debug | Build exit0, Gradle **14,9 s**; adb -s 7f0edea0 install -r exit0/Success mengganti APK test dengan aplikasi biasa dan mempertahankan data paket. Bukan restore database/arsip |
| Audit dokumentasi/localization | Exit0: 213 bilingual keys/metadata/placeholder, 184 referensi statis, 244 ID requirement lama unik |
| Pemeriksaan belum dilakukan — UNVERIFIED-01 | Keyboard/clipboard/IME OEM, seluruh UI manual/TalkBack, release/profile/AAB/signing/performa release, restore nyata, printer/Drive dan seluruh platform |

Detail suite/perintah/log di [VALIDATION-PHYSICAL](VALIDATION-PHYSICAL.md). Flutter tests menggunakan enterText dan lifecycle sintetis meskipun targetnya HP fisik. KDF test debug tercatat 5523 ms, bukan benchmark release. Bukti Windows/emulator pada tabel sebelumnya merupakan checkpoint 12 Oktober dan tidak dijalankan ulang pada pemeriksaan ini. Tidak melakukan uninstall/clear-data/reset/restore pengguna.

## Batas dan berikutnya

Tidak ada kegagalan assertion pada target yang diuji. HP fisik sudah mempunyai bukti otomatis terbatas di atas dan laporan manual pengguna; keyboard/clipboard/IME OEM/manual seluruh UI/TalkBack, seluruh OS/platform, release/profile/AAB/signing, printer/Drive/restore nyata masih unverified/pending. Composing/widget input/lifecycle merupakan pengujian sintetis Flutter pada emulator/HP, bukan seluruh keyboard/force-stop OEM. Pesan vendor/GPU dan latency debug bukan sertifikasi rendering/performa release. Kasir/cart/checkout/piutang M3 belum operasional.

Berhenti untuk review. M3 hanya setelah instruksi pengguna: reuse Money/minor/currency header, canonical form/draft, ARB, atomic checkout/price-HPP/batch/payment, stock revision/overflow/currency guards. M4–M6 memakai metadata fakta pada laporan/cetak ulang, localization notifikasi/legal dan kontrak backup staging/migration. Jangan lanjut M3 otomatis.
