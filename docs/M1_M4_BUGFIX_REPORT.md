# Audit dan perbaikan M1–M4, termasuk M3.1 — 14 Oktober 2026

Status akhir 15 Oktober 2026: pekerjaan implementasi, regresi yang tersedia, dan pelaporan audit selesai. Lima kelompok bug aplikasi ditutup pada kasus yang direproduksi. Pengujian dilakukan 14 Oktober; finalisasi dokumen dan pemeriksaan statis terakhir dilakukan 15 Oktober. Windows173, Poco128, DV74 dan emulator30 kasus fungsi unik lulus; cakupan tiap perangkat berbeda dan retry tidak dijumlahkan. Gangguan transport/runner serta acceptance hardware yang belum terbukti tetap dicatat di bawah. Dokumen ini melengkapi, bukan mengganti, bukti historis. M5/M6 tidak dimulai; aturan bisnis, versi skema, nama aplikasi dan applicationId produksi dipertahankan.

## Acuan dan cara penilaian

AGENTS, SPEC, PLAN, STATUS, REQUIREMENTS, LESSONS-LEARNED, M31/M4-NOTES, laporan VALIDATION M1/M2/localization/physical/M3/M31/M31-RECHECK/M4, INCIDENT-M31-ANDROID-TEST dan DV8910_M1_M4_TEST_REPORT beserta log kegagalan dijadikan acuan. Temuan dibedakan antara aplikasi, helper/runner, lingkungan, dan perangkat. Hasil manual pengguna MAN-USER-01 tetap laporan pengguna tanpa rincian skenario, bukan hasil otomatis atau acceptance keyboard/TalkBack/release/restore.

Audit sumber memeriksa coordinator/migration, integer/BigInt dan money codec, otorisasi, persediaan/HPP, checkout, pelunasan/koreksi, cursor/query/cache, ownership Provider dan formulir. Tes regresi menggunakan SQLite nyata, KDF asli 600000 putaran dan fault injection; tidak mengganti layanan dengan stub sukses atau melemahkan validasi. Bukti baru ada di `evidence/m1-m4-fixes-20261014/`.

## Temuan aplikasi

### FIX-01 — Hasil pelunasan salah setelah route dilepas

- Gejala: pembayaran berhasil commit, tetapi `ReceivablesProvider.pay` mengembalikan false dan error operasi setelah layar ditutup.
- Penyebab: `pay` memanggil `load` setelah commit; `load` memanggil `notifyListeners` pada Provider yang sudah disposed. Exception ditangkap sebagai kegagalan pembayaran.
- Dampak: operator dapat menerima indikasi gagal walau saldo sudah berkurang. SQL idempotency tetap mencegah penggandaan untuk key yang sama, tetapi umpan balik UI menyesatkan.
- Perbaikan: `lib/features/receivables/presentation/receivables_provider.dart`; load/submit baru menolak Provider disposed, sementara submit yang sudah diterima tetap mengembalikan hasil commit. Tidak membatalkan transaksi bisnis karena route ditutup.
- Sebelum: `regression-before-complete.log`, expected true/actual false, direproduksi pada barrier sesudah insert payment sebelum commit.
- Sesudah: `regression-after-2.log`, success, rollback dan submit bersamaan; retry key sama, saldo 900/1000 sesuai commit/rollback, satu sale, stok empat, FK/quick_check diperiksa. Windows full juga lulus. Poco retest tujuh regresi baru PASS; pembayaran commit/rollback dan rotasi PIN terverifikasi dengan sqflite Android.
- Status: CLOSED pada kasus yang direproduksi; otomatis Windows/Poco/DV/emulator lulus. Bukan acceptance seluruh lifecycle atau release.

### FIX-02 — Dua rotasi PIN dapat menerima kredensial lama yang sama

- Gejala: dua instance ManagementService sama-sama melaporkan sukses mengganti PIN menggunakan PIN lama; rotasi terakhir menimpa rotasi pertama.
- Penyebab: `_changing` hanya mengunci satu instance. Verifikasi berada di transaksi terpisah dari penulisan kredensial setelah KDF baru selesai.
- Dampak: race pada batas layanan kredensial, walaupun composition root normal memakai satu instance. Kredensial yang sudah usang tidak boleh mengesahkan penggantian berikutnya.
- Perbaikan: `lib/features/management/application/management_service.dart`; verifikasi menghasilkan identitas salt yang diverifikasi, lalu replacement melakukan compare-and-swap pada salt di transaksi. Salt selalu acak baru pada rotasi. Hanya satu perubahan dan audit boleh commit. Guard submit lokal, rate limit persisten, recovery verifier, KDF dan generation lifecycle tetap dipertahankan. Tidak memerlukan migration.
- Sebelum: `regression-before-complete.log`, expected satu sukses/actual dua.
- Sesudah: `regression-after-2.log`; hanya satu sukses, PIN pemenang dapat unlock, hanya satu audit pin_changed. Regresi PIN/recovery/lockout/queued-write lama dijalankan kembali dalam full suite.
- Status: CLOSED pada race yang direproduksi; Windows/Poco/DV/emulator regresi competing instances lulus. Regresi PIN Poco14 kasus lulus; DV14 kasus unik tercakup melalui12 kasus run terputus dan dua retest terfokus, bukan satu runner penuh yang lulus.

### FIX-03 — Header daftar gudang/master melampaui tinggi tersisa

- Gejala: DV management overflow 53px (run awal juga 2px), terutama ketika keyboard mengurangi viewport; product/master lists memakai susunan yang sama.
- Penyebab bersama: header tinggi tetap, Expanded ListView dan footer kosong di luar scroll. Header/footer harus selalu muat sebelum daftar mendapat ruang.
- Dampak: debug error dan kontrol dapat keluar dari viewport pada layar landscape pendek/keyboard/teks besar.
- Perbaikan: `lib/features/inventory/presentation/master_list.dart` dan `inventory_screen.dart`; header, status, daftar lazy dan footer berada dalam satu CustomScrollView dengan slivers; tab memakai NestedScrollView agar header tab juga dapat bergulir ketika safe area menyisakan ruang sangat pendek. Keyset, page size dan cache tiga halaman tidak berubah.
- Sebelum: `docs/evidence/dv8910-20261014/ui-management-driver-final.log` (bukti native aktual). Percobaan test baru pertama salah melewati unlock Provider UI dan hanya menghasilkan finder error; tidak dipakai sebagai bukti overflow aplikasi.
- Sesudah: `regression-after-2.log`, Products/Categories/Suppliers pada 960×540/inset300, teks 1× dan 2×, bisa digulir tanpa exception. SQL full tetap lulus. Kasus native gagal lama lulus pada Poco dan DV dalam run baru. Poco run pertama menampilkan overflow tab4/14px; ini memperluas penyebab header tetap, bukan diabaikan. Tambahan safe-area60/24 pada test Windows menangkap kondisi tersebut; helper kini mengembalikan outer header sebelum beralih tab dan mengassert chip benar-benar terpilih.
- Status: CLOSED pada kasus yang direproduksi; Windows/Poco/DV/emulator regresi baru lulus. Kasus management/IDR cashier yang dahulu gagal pada DV juga lulus di run baru.

### FIX-04 — Preview pelunasan tidak muat di atas keyboard

- Gejala: DV IDR cashier overflow 51px pada dialog Catat pembayaran; Windows mereproduksi overflow juga pada teks 2×.
- Penyebab: Column dialog berisi heading/nominal dan daftar hingga240px tanpa scroll untuk seluruh isi.
- Dampak: preview/alokasi tidak dapat ditinjau dengan benar pada ruang pendek.
- Perbaikan: `lib/features/receivables/presentation/receivables_screen.dart`; dialog scrollable dan daftar lazy memakai viewport finite240px. Heading ikut scroll, tombol konfirmasi tetap di area actions. Keyboard tidak perlu dipaksa tutup untuk meluluskan tes.
- Sebelum: `ui-final-cashier_ui.log` historis dan `regression-before-complete.log`. Percobaan pertama scrollable dengan hanya maxHeight memicu intrinsic viewport error, dicatat `regression-after.log` dan diperbaiki dengan tinggi finite; bukan hasil akhir.
- Sesudah: `regression-after-2.log`, preview nyata/SQLite pada960×540/inset280/1×–2×, Cancel tidak mencatat pembayaran. Kasus native gagal lama lulus pada Poco dan DV dalam run baru.
- Status: CLOSED pada kasus yang direproduksi; Windows/Poco/DV/emulator regresi baru lulus. Kasus management/IDR cashier yang dahulu gagal pada DV juga lulus di run baru.

### FIX-05 — Pembacaan pengelolaan yang mengantre lolos setelah sesi dicabut

- Gejala: detail/HPP, batch, latest receipt, master dan pengaturan masih dikembalikan oleh service setelah sesi PIN dikunci saat menunggu antrean DB. History sudah menolak hasil sebagai kontrol pembanding.
- Penyebab: lima operasi hanya memeriksa capability sebelum memasuki antrean. Pengamanan visibility UI tidak menutup celah pemanggilan service langsung.
- Dampak: data pengelolaan dapat keluar dari batas service pada sesi yang sudah dicabut, meskipun layar normal sudah menampilkan gate terkunci.
- Perbaikan: `lib/features/inventory/application/inventory_service.dart` memakai helper pembacaan terproteksi untuk enam jalur query, dengan pemeriksaan sebelum queue, saat eksekusi dan setelah IO; `lib/features/settings/application/settings_service.dart` menerapkan guard yang sama pada load. SQL, rumus HPP, pagination dan pembacaan informasi kasir publik tidak diubah.
- Sebelum: `protected-reads-before.log`, hasil denial enam operasi `[false,false,false,false,true,false]`, exit1; barrier coordinator nyata, tanpa stub authorization.
- Sesudah: retest dan regresi selesai. `protected-reads-after.log`:45 kasus PASS/exit0/01:06 bersama PIN/persediaan/currency/laporan. Full Windows sesudah guard:173PASS/dua benchmark opt-in SKIP, exit0/01:24 (`windows-final-auth.log`). Tes juga membuka kembali sesi dan memastikan keenam jalur tetap bekerja ketika akses valid.
- Status: CLOSED pada kasus service boundary yang direproduksi; Windows/Poco/DV/emulator lulus. Retest emulator independen1PASS/00:09 (`emulator-independent-protected_reads_test.log`) menggantikan status belum terverifikasi pada run handshake yang dihentikan; failure/interruption lama tetap disimpan.

## Temuan historis, lingkungan dan batas bukti

| ID / kelompok | Gejala dan sebab yang terbukti | Tindakan/status |
| --- | --- | --- |
| HIST-01 kehilangan DB M3.1 | Bare integration runner Flutter default uninstall menghapus sandbox operasional; fixture DB berbeda dalam package sama tidak melindungi | Pengamanan existing `.integration`/Gradle flag/identity/no-uninstall dipertahankan dan diverifikasi pada run baru. Data lama missing/unrecovered; reset dummy historis bukan restore dan bukan izin reset sekarang |
| TEST-01 helper/fixture | IO pump, lifecycle paused frame, disposal helper, lazy finder, saleId vs draftId, timestamp FIFO tie, penggantian literal quantity/version terlalu luas | Perbaikan historis tetap; regresi penuh baru memeriksa ulang. Dua kesalahan enum fixture dan gate pada test baru dicatat sebagai kesalahan test, bukan bug aplikasi |
| ENV-01 | Install restricted, device hilang/offline, Flutter listener temp PathNotFound, screensaver menghentikan frame | Masalah availability/transport; tidak mengubah firmware/settings. Aktivitas khusus test keep-screen-on tetap. Penyebab hardware/network offline belum terbukti |
| ENV-02 KDF ARM32 | Timeout test30s sementara PBKDF2 debug600k~20s/derive; provider/KDF sudah isolate | Runner timeout bounded15m, UI5m; KDF tidak dikurangi. Bukan bukti deadlock aplikasi atau latency release |
| ENV-03 SQLite/log | FTS5 capability probe unavailable/fallback; expected migration/fault errors; vendor input/GPU warnings | Tidak disembunyikan atau dianggap semua log bersih. Hasil assertion dan log fatal diperiksa terpisah |
| INPUT-01 Enter DV | Fixture baru/actual cashier: IME terlihat mengubah000123→000123t; setelah Back mInputShownfalse, Enter menerima barcode yang sama. Tiga intent:cart0→1→2→3, sales0, stock20, total36000, search kosong | DIAGNOSED jalur ADB+IME-visible, bukan kegagalan pemrosesan barcode. Jalur terlihat tetap tidak cocok untuk simulasi scan. Tidak patch/strip suffix atau mengganti IME. Physical scanner/OEM tetap UNVERIFIED. dv-enter-ime-visible.json/log, dv-before/after-enter-ime-hidden.json/log, dv-three-enter-ime-hidden.json/log |
| LIMIT-01 | TalkBack DV package absent; OEM keyboard/clipboard/scanner, reboot/power loss, peak RAM/full release acceptance belum lengkap | UNVERIFIED/BLOCKED sesuai perangkat. Build release bukan bukti semua alur release lulus |
| FUTURE | Printer/Drive/backup/restore/legal/public release | M5/M6 belum dimulai; tidak mengklaim lulus |

## Pemeriksaan baru

| Pemeriksaan | Bukti dan hasil |
| --- | --- |
| Doctor | `doctor.log`: No issues found, sebelum perangkat tersambung kembali |
| Discovery | `devices-ready.log`: Poco24069PC21G/7f0edea0 dan DV8947-KIX/192.168.0.102:5555; emulator Pixel_7 tersedia |
| Windows focused | Tujuh regresi baru PASS00:42 (`regression-after-2.log`); bukan tambahan jumlah di luar full suite |
| Windows full | Final173PASS/dua opt-in benchmark SKIP, exit0/01:24 (`windows-final-auth.log`); dua benchmark PASS terpisah. Checkpoint172 dan failed repro tetap disimpan. Helper akhir7PASS/01:05 (`fixture-final-host.log`), bukan tambahan kasus unik |
| Isolasi awal Poco | Main DB SHA256989aa556… dan journal076a27c7…; ordinary PID tidak ada. Read-only, tidak force-stop/open/delete ordinary (`poco-ordinary-before.log`) |
| Isolasi awal DV | Ordinary package tidak ada, sandbox integration databases kosong (`dv-ordinary-before.log`, `dv-test-before.log`) |
| Poco native |127PASS dalam14suite/runnerexit0 +1guard readPASS terpisah =128functional (113SQL/Provider+15UI), tanpa double-count focused retries. poco-native-final.log/poco-protected-reads.log |
| Poco retensi |Main DB dan journal hash sama sebelum/sesudah128case, PIDordinary absent/noWAL pada daftar, read-only/noordinary force-stop/install/open/delete. Bukti baseline ini, bukan restore/data lama recovered |
| Windows benchmarks |Dua PASS/exit0/00:39, 1k/2k dan10k/100k. Far100k historymedian0,510ms/report0,615ms; commonsearch16,870ms/monthsummary133,323ms. debugFFI/1warmup+5samples, bukan release/SLA/peakRAM. windows-benchmarks.log/windows-benchmark-data.json |
| Emulator | API37 Pixel_7:30functionalPASS unik (15SQL/Provider+15UI): regresi7, database11, managementUI1, cashierUI2, localizationUI1, wholesaleUI1, M31gaps4, M4UI2, protected-read1. Retest independen, bukan satu all-pass runner. Cold minimal frame1PASS adalah diagnosis terpisah, tidak menambah30. Mainhash ordinary sama sebelum/sesudah/final; journal0byte awal/akhir (digestawal tidak direkam, digestkosong akhir terukur) |
| DV native |74functionalPASS unik (59SQL/Provider+15UI): managementUI1, cashierUI2, regresi7, protected-read1, managementSQL14, cashierSQL30, database11, localizationUI1, wholesaleUI1, M31gaps4, M4UI2. Management14 diperoleh dari12 sebelum offline +pagination1 +migration1; retry3 tidak dihitung. Raw transport failures tetap, bukan satu all-pass runner |
| DV benchmark |1mediumbenchmarkPASS/exit0/01:07,1kproduk/2kpenjualan; far catalog4,568ms/history9,809ms/report10,326ms/search65,545ms/monthsummary60,244ms. Debug/1warmup+5samples, bukan benchmark100k native/release/peakRAM. `dv-benchmark-final.log`, `dv-benchmark-data.json` |
| Finalisasi statis |`format-final-6.log`:142files0changed/0,58s/exit0. `analyze-final-6.log`:No issues found/7,5s/exit0. Audit localization367IDENkeys/287refs/244originalIDs; syntax Python tools dan PowerShell runner diperiksa |
| Build biasa |DebugPASS17,5s; releasePASS38,0s/53,7MB. Salinan `build/bugfix-20261014/ordinary-debug.apk` dan `ordinary-release.apk`; aapt IDcom.example.kasir_app/labelkasir_app/version0.4.0+6/MainActivity. IntegrationActivity absent pada seluruhDEX keduanya, tidak diinstall pada perangkat (`ordinary-artifact-verification.json`) |
| Guard negatif |Build entrypoint integration tanpa flagisolasi ditolak Gradle, expectedexit1, tanpa installattempt (`isolation-negative-build-result.json`). Ini build negatif terkontrol, bukan bare integration test pada package operasional |
| Isolasi akhir |Poco main507904bytes SHA989aa556…/journal512 SHA076a27c7… tetap sebelum/sesudah128kasus. Emulator main471040 SHA bad683d0… sama sebelum/sesudah/final; journal0byte awal/akhir, digestkosong e3b0c442… terukur sesudah/final, tidak direkam awal. OrdinaryPID absent/noWAL pada baseline. DVordinary package absent awal/akhir, bukan DBpreservation |
| Cleanup/log |Hanya fixture milik run ini dalam sandbox.integration dibersihkan;8file emulator tepat tercatat `emulator-owned-cleanup.json`, inputfixtureDV tepat dibersihkan. DBdiruji DV/emulator kosong akhir, APKtestretained/PIDstopped.15snapshotPID:tanpa fatal pada rentang buffer yang diperiksa; bukan seluruhlogbebaswarning (`scoped-log-summary.json`) |

Tidak ada klaim seluruh aplikasi sempurna. Daftar akhir membedakan bug yang ditutup, kegagalan test yang dibetulkan, dan acceptance perangkat yang belum terbukti.

## Diagnosis fixture dan transport

**TEST-FRAME-01 — emulator sebelum first pump.** Initial suite memiliki3SQLPASS, kemudian timeout5menit pada inventory pertama; tiga kegagalan binding berikutnya merupakan cascade. Single-case legacy metrics dan local native viewport sama-sama timeout, sehingga perubahan metrik bukan sebab tunggal yang terbukti. Minimal MaterialApp tanpa layanan/SQL lulus1kasus/00:01 (`emulator-frame-cold.log`). Autentikasi Provider dipindahkan dari `tester.runAsync` sebelum frame pertama ke regular `setUp`; persiapan piutang dilakukan dengan pola yang sama. Focused inventory lulus1/00:23 (`emulator-setup-control.log`), tujuh regresi baru lulus7/01:20 (`emulator-native-final.log`), Windows helper akhir7/01:05. Kesimpulan dibatasi pada urutan persiapan fixture/live binding yang direproduksi; tidak mengklaim telah menemukan defect engine internal. KDF/SQL/gate/selected-chip/Cancel-no-payment assertions tetap. Native memakai window renderer asli dengan Navigator maksimal960×540 dan MediaQuery lokal; Windows memakai viewport960×540.

**ENV-RUNNER-01 — handshake emulator berikutnya.** Setelah7kasus lulus, protected-read suite dibangun/diinstall tetapi tidak menampilkan reporter. Log PID21167, Awake/focusintegration, VMpauseEventResume/stackkosong disimpan; tidak ada bukti assertion atau appcrash pada snapshot. Runner dihentikan secara eksplisit, exit130 anotasi berasal dari penghentian, bukan exitFlutter asli. Ini berbeda dari timeout first-pump yang sudah diperbaiki. Root cause handshake belum cukup bukti. VM diperiksa read-only melalui forward diagnostik sementara lalu forward itu dihapus; tidak ada resume/evaluate/setting sistem. Retest independen protected-read1PASS/00:09 menyelesaikan kasus ini. Suite independen lainnya selesai sesuai tabel30kasus. Penyebab internal handshake belum dapat dipastikan; tidak diklaim sebagai bug aplikasi atau defect engine yang sudah diperbaiki.

**ENV-ADB-01 — DV transport.** Run awal selesai managementSQL12 kasus sebelum `adb.exe: device offline` pada pagination; full retry berhenti setelah3 pada rotasi/recovery. PathNotFound listener terjadi saat finalization setelah offline. Tidak menyimpulkan screensaver atau bug PIN sebagai sebab transport; userwakeup hanya availability dan pemeriksaan berikutnya menunjukkan Awake. Rawfailed runs dipertahankan, kasus independen diteruskan melalui safe runner. Salah nama file pada daftar retry (`dv-native-retry.log`) gagal sebelum build/install dan dicatat sebagai kesalahan orchestration.

**TEST-FRAME-02 — fixture UI lama dan frame starvation intermiten.** ManagementUI emulator semula timeout5menit; cashierUI timeout5menit lalu binding cascade. Fixture kini membuat surface pertama sebelum persiapan dan membungkus IO SQLite persiapan dalam `tester.runAsync`; management1PASS/00:33, cashier2PASS/00:34, localization1PASS/00:23. File terkait: `integration_test/management_ui_test.dart`, `cashier_ui_test.dart`, `localization_ui_test.dart`, `wholesale_packaging_ui_test.dart`; gate/KDF dan seluruh assertion bisnis tetap. Wholesale masih timeout7menit baik warm-only maupun warm+real-IO; diagnosis kelas widget menunjukkan ProductForm/Inventory sudah dibangun, sehingga failure itu tidak terbukti berhenti pada first pump. Phase markers aman ditambahkan untuk pump/wait/tap/fill. Kasus yang sama kemudian PASS/00:40 dan repeatPASS/00:41 (`emulator-wholesale-phase-repro.log`, `emulator-wholesale-repeat.log`), tetap dihitung satu kasus unik. Mitigasi urutan fixture dan dua repeat terbukti; penyebab internal frame starvation intermiten belum ditetapkan. Tidak menonaktifkan exception, mengubah validasi produk atau menyimpulkan GPU/engine rusak.

**ENV-ADB-02 — penyelesaian kasus DV.** Pagination dan migration retest terfokus masing-masing1PASS melengkapi14kasus management unik. CashierSQL30PASS/00:39 dan database11PASS/00:12 selesai. LocaleUI gagal missing Cari saat Dreaming (`dv-locale-ui-final.log`); pengguna mengaktifkan layar melalui remote, ownactivity uji dibawa ke depan tanpa mengganti sistem/screensaver. Retest1PASS/01:22 (`dv-locale-ui-retest.log`). Satu antrean sebelumnya kedaluwarsa20menit menunggu runner emulator sebelum build/install DV, bukan failed native assertion; requeue berhasil. WholesaleUI1, M31gaps4 dan M4UI2 lulus. Konfirmasi layar aktif hanya availability, bukan manual acceptance skenario.

## Cakupan akhir dan keputusan arsitektur

Tujuh file aplikasi pada FIX-01–05 berubah. Provider tetap memiliki state layar; commit dan otorisasi tetap di service/coordinator SQL. CAS menjaga credential race tanpa menahan transaksi selama KDF. Pembacaan terproteksi memeriksa akses di batas antrean dan sesudah IO. Slivers/dialog scrollable menjaga kontrol terlihat tanpa memuat seluruh katalog. Tidak ada perubahan skema, rumus uang/HPP, aturan stok, checkout/reversal, harga grosir/dus atau pagination; regresi memeriksa snapshot, integer precision, atomisitas, retry, saldo, FK dan cursor tetap. Baseline90file:81 sama,7filelib diperbaiki,2delta routing Android berasal dari pengujian DV sebelumnya (`source-change-audit.json`). `tools/test_android.ps1` hanya menambah NameFilter satu suite; isolasi package/flag/AAPT/--no-uninstall tetap.

Windows173kasus dan Poco128 mencakup suite fungsi lengkap yang tersedia pada masing-masing target. DV74 merupakan validasi baru terpilih, bukan pengulangan seluruh118PASS historis; reportsSQL24, wholesaleSQL14, localizationSQL6 dan storageSQL10 tidak diulang penuh pada DV dalam audit ini, tetapi diregresikan Windows/Poco. Emulator30 juga subset. Semua15kasus syntheticUI akhir tercakup pada Poco/DV/emulator. Angka lintas platform tidak dijumlah sebagai kasus unik produk; focused/repeat bukan tambahan kasus.

Masing-masing bukti waktu/exit/retry tercantum di `suite-evidence-index.json` dan README folder evidence. Log source/PID dibatasi dan jalur auth VM sementara disunting dari bukti baru; tidak ada PIN/token/data pengguna disalin ke laporan. Ordinary DB hanya dibaca metadata/hash; tidak direset, dihapus, diinstall ulang, dibuka atau diinisialisasi dalam audit ini. Hash cocok membuktikan byte retention pada baseline itu saja. Insiden kehilangan data lama M3.1 tetap missing/unrecovered; cleanup fixture bukan restore.

## Batas yang masih terbuka dan pekerjaan berikutnya

- MAN-USER-01: alur emulator/HP dilaporkan berjalan baik oleh pengguna sebelum audit, tanpa rincian skenario. Ini bukti manual historis, bukan hasil otomatis baru.
- UNVERIFIED: keyboard OEM/clipboard/scanner fisik, TalkBack (DV package absent/BLOCKED), seluruh alur runtime release, reboot/powerloss, peakRAM dan seluruh dataset/perangkat. Build release memakai signing pengembangan dan bukan acceptance Play/release.
- OPEN diagnosis lingkungan: penyebab ADBoffline DV dan frame starvation/handshake emulator intermiten belum terbukti. Retest kasus tersedia lulus; raw kegagalan tidak dihapus dan stabilitas semua kondisi tidak diklaim.
- OUT OF SCOPE: printer Bluetooth, Google Drive, backup/restore operasional dan pekerjaan M5/M6. Tidak ada keputusan produk baru yang diperlukan untuk lima perbaikan ini.

Audit/perbaikan yang dapat diverifikasi selesai; berhenti untuk review dan tambahan pengujian pengguna. Hardware atau acceptance yang belum diuji tetap memerlukan bukti terpisah sebelum dinyatakan lulus.
