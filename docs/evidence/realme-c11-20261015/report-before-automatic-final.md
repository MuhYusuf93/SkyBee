# Pengujian tambahan Realme C11 M1–M4 termasuk M3.1

15 Oktober 2026, Asia/Jakarta. **IN PROGRESS — belum merupakan penerimaan seluruh skenario.** Pengguna mengadopsi seluruh `prompt-codex-uji-realme-c11-dan-perbaikan.md`; pekerjaan audit sebelumnya selesai sebelum pengujian ini dimulai. Cakupan adalah pengujian dan perbaikan bug terbukti sampai M4, tanpa M5/M6/QRIS/rename. Riwayat Poco/DV/emulator dan insiden M3.1 dipertahankan.

## Preflight dan perlindungan data

Target eksplisit `0062112V2210F9B3`, manufacturer realme/model RMX3231, Android11/API30/security patch2024-02-05, ABI armeabi-v7a/armeabi. Tidak mengasumsikan chipset/varian pemasaran dari nama C11. RAM MemTotal1914140kB (~1,83GiB), MemAvailable1125664kB pada snapshot; storage3648804KiB bebas (~3,48GiB),86% terpakai. Layar720×1600/density320/fontscale1,0. Keyboard aktif Gboard LatinIME, package dump mencatat versi updated18.4.1 dan factory10.5.03; bukan bukti seluruh input keyboard lulus. Baterai60%/USBpowered/40,3°C, thermal status0 pada preflight; suhu sensor CPU/GPU berbeda dan tetap dicatat apa adanya.

DoctorNoissues/exit0, Flutter3.44.7/Dart3.12.2. Repository tanpa `.git`, sehingga tidak ada commit/uncommitted diff Git; fingerprint sumber sebelum pengujian disimpan. Tidak ada proses pengujian lama aktif pada discovery. Baseline sumber/build configuration/lockfile direkam; perubahan terbatas dicatat di bawah. App0.4.0+6/schema7, ordinary `com.example.kasir_app`, fixture `com.example.kasir_app.integration`. Ordinary dan fixture package absent pada awal; tidak ada DB ordinary yang dapat dihash/preservation/restore untuk diklaim.

Native hanya `tools/test_android.ps1` dengan serial/SDK eksplisit, flagisolasi/identity gate/--no-uninstall. Pengujian menggunakan nonce DB sintetis; tidak memakai VerifyOperationalDatabase yang menghentikan ordinary. Kegagalan satu suite tidak memberi PASS suite lain: orchestration melanjutkan suite independen dan menyimpan rawexit. Build terbaru dibuat dari sumber sesudah audit sebelumnya. Bukti: `evidence/realme-c11-20261015/preflight.json`, doctor/devices/source-baseline, per-suite log dan result ledger.

## Matriks pengujian (diperbarui berdasarkan hasil nyata)

| ID / skenario | Metode / build | Expected | Actual / status / bukti |
| --- | --- | --- | --- |
| RC-01 fondasi/migration/index/FK/cursor | Native SQLite debug | Fresh/reopen/migration rollback dan keyset konsisten |11PASS, native-database_test.log; expected injected migration error dipisahkan dari assertionfailure |
| RC-02 PIN/session/CRUD/persediaan | Native management14/debug | KDF asli, lockout/recovery/gate/stock/undo/FEFO valid |14PASS/12:33, native-management_inventory_test.log; KDFdebug600k26388ms |
| RC-03 search/cart/checkout/piutang | Native cashier30/debug | Exact/suggestion, atomicity/idempotency/recovery/allocations |30PASS/00:53, native-cashier_sql_test.log |
| RC-04 grosir/dus/pecahan/snapshot | Native wholesale14/debug |5×40=200,total600000,residu exact,explicit pricing,migration |14PASS/07:19, native-wholesale_packaging_sql_test.log |
| RC-05 laporan/koreksi/rekonsiliasi | Native reports24/debug |Fullperiod/signedreversal/stok/uang/saldo konsisten | 24 PASS sebelum backend; regresi pascaperubahan 24 PASS/02:08, post-pin-realme/reports_corrections_sql_test.log |
| RC-06 storage/pagination/cache/generation | Native storage10/debug |Keyset/tie/filter/cache150/migration7 | 10 PASS sebelum dan sesudah backend; retest01:01, post-pin-realme/m4_storage_test.log |
| RC-07 localization/currency | Native locale6/debug |IDEN/currency/minor units/persistence/guards | 6 PASS sebelum dan sesudah backend; retest02:16, post-pin-realme/locale_currency_test.log |
| RC-08 lima bug audit sebelumnya | Native regression7+protected-read1/debug |Provider commit, CAS, layout, revoke access | 8 PASS sebelum backend; regresi pascaperubahan sedang berjalan |
| RC-09 UI pengelolaan/kasir/localization | Native syntheticUI/debug |CRUD/checkout/locale/protection/input/layout assertions | 4 PASS sebelum backend; synthetic Flutter bukan bukti interaksi fisik; retest akhir pending |
| RC-10 UI grosir/dus/M31gaps/M4 | Native syntheticUI/debug |Warnings/corrections/snapshots/2x/narrow/wide | 7 PASS sebelum backend, termasuk satu wholesale retest; dua rawFAIL tetap disimpan; retest akhir pending |
| RC-11 contoh HPP wajib | Shared production-service/SQLite test |10×8000+10×10000=avg9000;sale36000/HPP27000/profit9000/debt26000;pay tidak mengulang laba | Windows/native suite2kasus PASS (host00:08/native01:50); retest pascaperubahan pending |
| RC-12 average pecahan | Shared service/SQLite IDR |1minor/3units;HPP333333+666667micro-minor;stock/value0 | Windows/native suite2kasus PASS; exact333333+666667micros dan sold-out value0; retest akhir pending |
| RC-13 benchmark medium |1000produk/2000sales/debug |Rawqueryplans/samples, tanpa SLA rekaan | 1 PASS/01:25; rawmetadata/plans/5samples di medium-benchmark.json; bukan release/SLA |
| RC-14 profile/release startup/recovery/smoke | Isolated harness + actual KasirApp |Restart draft/commit, same sale, PIN relock, reports | Baseline profile serial PASS untuk draft/commit/retry/3cold+3warm; setelah backend dan release pending |
| RC-15 memori/siklus route/PIN latency | Own PID/meminfo/stopwatch |Metrik aktual dan bounded state, bukan klaim leak dari satu snapshot | KDF Dart26,10s vs native3,06–3,08s (5sampel); debugPSS209MiB satu snapshot; actual cycles pending |
| RC-16 keyboard/touch/paste/Done | Interaksi fisik pada Gboard/layar aktual |Input/selection/grouping/form/rapid taps benar |NOT TESTED; ADB input tidak dianggap fisik |
| RC-17 TalkBack | Perangkat fisik jika tersedia |Label/order/total/error/dialog dapat digunakan |NOT TESTED; presence bukan acceptance |
| RC-18 offline/background/lockscreen | Own test process/lifecycle/manual |Alur lokal/relock/draft tidak rusak | Process restart profile baseline PASS; lockscreen fisik dan release akhir belum diperiksa |
| RC-19 isolasi/ABI/cleanup/build akhir | AAPT/ZIP/explicitADB/sourcechecks |Ordinary tidak berubah, native libs cocok, hanya fixture dibersihkan |Preflight packageabsence verified; akhir belum diperiksa |

## Temuan dan diagnosis

### RC-F01 — APP: verifikasi PIN terlalu lambat di ARM32

Gejala: KDF debug awal26.388ms; sampel referensi Dart terisolasi sesudahnya26.102.985µs. Pipeline profile committed-recovery sekitar39s mencakup KDF dan operasi lain (bukan waktu PIN murni). Setup profile pertama82,906s mencakup tiga derivasi dan seed. Fungsi tetap benar, tetapi jeda pengelolaan sangat panjang.

Penyebab yang dibuktikan: derivasi PBKDF2/HMAC sendiri memakan waktu besar pada implementasi Dart/target ini; stopwatch derivasi dipisahkan dari DB. Implementasi OS SecretKeyFactory dan loop JavaMac tetap sekitar18s/21s, sehingga tidak dipilih. Tidak menyimpulkan usia perangkat atau kerusakan OS sebagai penyebab.

Perbaikan: PinHasher memakai Mbed TLS3.6.7 terpin/checksum/lisensi melalui MethodChannel serial background queue dan satu JNI call untuk seluruh KDF. Hanya empat implementation units dikompilasi; parameter600k–2m/256bit, UTF8, random salt, domain PIN/recovery, verifier DB, CAS, lockout, session dan aturan uang tetap. Backend unavailable memakai Dart asli di isolate dengan parameter sama; error derivasi tidak menghasilkan dummy.

File aplikasi penting: `lib/features/management/application/pin_hasher.dart`; `android/app/src/main/kotlin/com/example/kasir_app/MainActivity.kt`; `android/app/build.gradle.kts`; `android/app/src/main/cpp/{CMakeLists.txt,pin_kdf.c,pin_crypto_config.h}` serta vendor/provenance/license. IntegrationActivity mewarisi MainActivity supaya pengujian memakai backend produksi yang sama. Tidak ada migration/schema/finance/source identity berubah.

Bukti sesudah: empat kontrak native PASS/01:04, backend available/mainThreadfalse, lima vektor hashlib independen (ASCII/recovery/UTF8/empty/long dengan600001rounds), parity Dart, penolakan parameter dan unlock verifier lama tanpa mengganti salt/verifier. Lima native sampelµs:3070947,3082258,3067709,3064156,3062998; unlock DB lama3203660µs. Log `native-pin-mbedtls-attempt3.log`. Windows179PASS/2opt-inSKIP/01:24. **Status: fungsi/kompatibilitas terbukti, regresi perangkat dan profile/release akhir masih berjalan.** Sekitar3s masih merupakan jeda nyata; tidak menjanjikan PIN instan atau SLA baru.

### RC-F02 — TEST/ENV: target tap UI M3.1 tidak menerima pointer

Gejala: original dan attempt2 FAIL pada tapcenter(180,405), checkbox grosir tidak berubah. Assert jumlah200/receive40/count200/biaya600000000000 micro-minor (IDR600.000) sudah tercapai; kegagalan bukan commit keuangan parsial.

Perbaikan di `integration_test/wholesale_packaging_ui_test.dart`: guard hitTestable, ensureVisible terpusat bila perlu, bounded realframe wait, assert mode segera sesudah tap dan tetap setelah scan. Tidak mengurangi invariant stok/biaya/harga. Attempt3 PASS02:05/exit0. Tidak ada markerM31_HIT_WAIT pada PASS; cabang tunggu/scroll tidak terbukti dieksekusi dan penyebab internal overlay/timing belum dipastikan. **Status: retest helper PASS, diagnosis internal terbatas; bukan klaim bug aplikasi atau OS telah diperbaiki.** Regresi akhir pada backend baru pending.

### RC-F03 — TEST/ENV: helper dan urutan instalasi

Helper acceptance Windows awal gagal import/dispose API dan mencoba membaca HPP dari DTO publik yang memang tidak mengeksposnya. Helper diperbaiki membaca snapshot SQL fixture terisolasi; DTO publik tidak dibuka. Retest dua kasus PASS Windows/native.

Probe profile pertama dimulai sebelum build/install selesai dan tidak menemukan ownPID; rawfailure/timestamp disimpan (`runtime-profile-too-early.json`, `runtime-install-overlap-times.json`). Retry serial profile PASS. Ini kesalahan urutan workflow yang terbukti, bukan bukti aplikasi crash. Dua build awal backend gagal header transitif sebelum instalasi; header resmi dilengkapi dan build/native tests kemudian PASS. Analyzer dua unnecessary_import diperbaiki; retest Noissues5,3s. **Status helper/build: diperbaiki; raw gagal tidak dihapus.**

Tidak ada SKIPPED_SYSTEM berdasarkan usia perangkat. Expected SQLite fault-injection error/migration rollback dipisahkan dari crash. UNKNOWN tetap UNVERIFIED_CAUSE/BLOCKED_ENVIRONMENT; hasil historis perangkat lain tidak membuktikan kesehatan Realme.

## Performa dataset menengah

SQLite3.28.0, journaltruncate,1827pages×4096byte.1000produk/2000sales/items/stockledger,600payments; seed62704ms dan index19915ms di luar query samples. Satu warmup/lima sampel; anchor primary-key, tanpa OFFSET. Median queryms: katalog awal10,984/lanjut10,850/jauh5,380; history13,056/12,583/jauh1500=12,097; reportdetail11,937/12,235/jauh1500=13,032; commonsearch85,224; monthlysummary84,908. Plans/rawsamples tersimpan `medium-benchmark.json`. Ini debug/service, belum latensi keyboard/render/debounce, release atau klaim100kRealme. Profile/release smallfixture dan pengamatan memori route sedang disiapkan.

## Batas dan pekerjaan berikutnya

Poco belum terhubung pada discovery; DV dan emulator tersedia untuk regresi relevan jika perubahan domain diperlukan. Bukti historis bukan hasil Realme. Keyboard/touch fisik/TalkBack membutuhkan interaksi yang benar-benar dilakukan; langkah manual akan diberikan pada package uji setelah otomatis selesai agar tidak bertabrakan. Fullrelease/public signing/Play, reboot/powerloss dan backup/restore/printer/Drive M5/M6 tetap di luar acceptance task ini. Status akhir belum ditetapkan.

Referensi diagnosis resmi yang diperiksa: [pengelolaan memori Android](https://developer.android.com/topic/performance/memory/manage-app-memory) dan [diagnosis ANR](https://developer.android.com/topic/performance/anrs/diagnose-and-fix-anrs). Diagnosis kebocoran memerlukan pengamatan alokasi/lifecycle; satu snapshot PSS tidak cukup untuk menyimpulkannya. Tidak menambahkan optimasi atau mengganti arsitektur secara spekulatif.

