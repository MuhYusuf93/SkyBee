# Referensi pembelajaran dan protokol pengujian

Tambahan validasi M5 setelah reboot: hasil picker Android dapat tiba setelah route disposed; hapus salinan temporary milik aplikasi ketika tidak ada lagi pemilik, jangan file sumber pengguna. Preview logo harus memakai threshold/alpha composite yang sama dengan thermal encoder, bukan sekadar geometri yang sama. Driver SQLCipher dapat mengembalikan PRAGMA sebagai string; verifikasi kontrak nilai aktual dan plaintext-handle negatif. Safe exception aplikasi berbeda dari exception driver lama: adapter test boleh memetakan boundary yang tepat tanpa menghapus assertion rollback/data. Closed snapshot lintas nama DB memerlukan export ke key target, bukan asumsi key Keystore sama. Logcat dapat memotong JSON hasil benchmark; simpan private flushed result dan pulihkan artefak itu sebelum menyimpulkan pengukuran gagal. Reboot Realme oleh pengguna diikuti88 PASS hanya membuktikan retest, tidak membuktikan penyebab internal load sebelumnya. Angka PASS host/native/mock/manual/hardware dan lintas key/perangkat wajib tetap dipisah.

Tambahan M5 16 Oktober: bekukan satu kelompok source sebelum native build; perubahan renderer yang belum lengkap dapat membuat build berikut gagal dan tidak boleh disebut bug runtime. Verifikasi APK semua ABI yang diiklankan, bukan library custom saja: Flutter3.44 dapat menimpa ndk filter dan dependency AAR lalu memasukkan ABI tanpa engine. WorkManager bisa memakai proses foreground; catat PID sebelum/sesudah dan status native untuk bukti headless. Memanggil SystemNavigator.pop dapat mematikan Dart engine sebelum Timer exit dijalankan, sehingga callback tersebut bukan proof proses mati. APK fixture versi lama memerlukan install-r-d ketika kembali dari versionCode lebih tinggi; hanya target sandbox terverifikasi, jangan uninstall atau downgrade aplikasi operasional. DB manual lama tidak dimigrasikan untuk regresi M5; gunakan nama baru dan fingerprint DB/sidecar sebelum/sesudah. APK release non-debuggable membatasi pre-install run-as: sebutkan gap bukti, jangan mengarang hash.

13 Oktober 2026; pengalaman M1–M3.1. Acuan insiden: INCIDENT-M31-ANDROID-TEST. Dokumen ini berlaku untuk pekerjaan berikutnya; tidak berarti M4–M6 sudah dikerjakan.

## Konfirmasi terbaru pengguna

Pengguna menjelaskan data yang dimasukkan adalah dummy, mengizinkan menghapus DB yang tersisa dan membuat DB baru, serta belum akan mengisi data penting sampai M6 selesai. Reset kali ini diotorisasi, bukan pemulihan data lama. Tetap pisahkan package test dan ordinary app; status dummy bukan alasan memakai workflow yang dapat menghapus data produksi kelak. Reset berikutnya harus eksplisit dan scoped; jangan menerjemahkan catatan ini menjadi izin umum menghapus semua data/perangkat.

## Pelajaran yang harus diterapkan

1. Periksa default CLI pada SDK aktual. Flutter3.44.7 `flutter test` integration mempunyai `--uninstall=true`; `--no-uninstall` wajib, tetapi install-failure fallback masih dapat mencoba uninstall. Jangan berasumsi install-r atau DB fixture berbeda melindungi package.
2. Pisahkan applicationId/sandbox. APK test `com.example.kasir_app.integration`, label tests, flag KASIR_INTEGRATION_TEST=true; APK biasa `com.example.kasir_app`. Verifikasi aapt dan metadata installed package sebelum melakukan aksi berikutnya. Shared DB file names hanya memisahkan dataset di dalam satu sandbox.
3. Generated test listener membuat deteksi target-path tidak andal. Pakai flag eksplisit, fail-closed Gradle guard dan tools/test_android.ps1. Native suite berhenti pada error pertama agar failure instalasi tidak disusul cleanup/mutasi tak teramati.
4. Discovery perangkat bukan izin atau asumsi koneksi. Pilih ID HP fisik dari flutter devices/adb setelah user siap; unauthorized/offline/daftar kosong adalah blocked, bukan hasil test. Jangan diam-diam pindah emulator.
5. Reset dummy hanya file DB tepat dan sidecars, sesudah force-stop serta verifikasi sandbox. tools/reset_dummy_android_db.ps1 memerlukan ConfirmDummyData dan whitelist path, tanpa recursive delete/uninstall/pm clear. Database baru dibuat jalur startup/migration aplikasi, bukan SQL fixture palsu yang diklaim produksi.
6. Buktikan isolasi end-to-end: force-stop ordinary app, hash DB baseline konsisten sebelum full native run, hash ulang sesudahnya. Hash cocok membuktikan byte retention pada baseline tersebut; tidak mengesahkan backup/restore, seluruh dataset/migration, atau multi-device. Jangan menyalin DB aktif sambil mengabaikan WAL.
7. Test bermakna menilai invariant, bukan banyaknya file/count. Ulang satu suite aman/coherent untuk menggantikan hasil native yang terpotong/ambigu, tanpa menjumlahkan duplikasi sebagai kasus unik. Raw exit1/interruption tetap ada; expected SQL fault injection dibedakan dari assertion failure.
8. UI driver harus menangani lazy fields di atas maupun bawah, BackButton terlokalisasi, focus/caret scroll dan input Done. Perbaiki helper; jangan menambah debug copy pada UI atau mengurangi assertion bisnis hanya untuk membuat finder lulus. SQL/KDF di fake widget clock perlu real async drain; jangan dianggap berhasil sebelum commit teramati.
9. Snapshot log harus punya package/PID yang terbukti dan rentang yang disebut. Process selesai tidak berarti log hilang: exit-info dapat memberikan historical PID. Hindari global logcat berisi aplikasi pribadi. 0 fatal pada snapshot bukan semua log bersih; catat InputConnection/Spannable/vendor messages.
10. Input Flutter sintetis bukan keyboard/clipboard/scanner OEM atau TalkBack. Build release bukan release runtime/performa/Play signing. Copy DB tertutup/migration fixture bukan restore operasional. Nyatakan verified/partial/blocked/unverified terpisah.
11. Reset yang diizinkan sekarang tidak membuat insiden lama menjadi bukti preservation. Simpan histori dengan klarifikasi bahwa datanya dummy; database baru bukan recovery. Setelah M6, larangan reset tanpa instruksi eksplisit tetap berlaku.
12. Saat beralih debug/integration ke release, jalankan regenerasi dependency/plugin resmi Flutter. Build release dengan `--no-pub` sempat gagal karena registrant masih menyebut IntegrationTestPlugin; `flutter build apk --release` berhasil sesudah metadata mode release diperbarui. Sebaliknya debug native membutuhkan registrasi plugin integration kembali. Jangan mengedit GeneratedPluginRegistrant secara manual; tools/test_android.ps1 kini menjalankan pub otomatis tanpa meng-upgrade lockfile.
13. Jika tool berikutnya gagal karena peninjauan izin/kuota, periksa session dan raw exit sebelum mengulang test. Runner yang sudah disetujui dapat tetap berjalan: pada recheck ini seluruh84kasus selesai exit0 dan hash cocok saat sesi dilanjutkan. Tidak melewati approval review; probe metadata berikutnya baru dijalankan setelah review berhasil kembali.
14. Logcat adalah buffer terbatas. Snapshot PID UI terakhir setelah jeda hanya43baris/rentang28detik, walaupun suite47detik lulus; 0fatal pada snapshot tidak membuktikan seluruh fase bebas warning. Simpan rentang/baris dan batas cakupan. Startup release dicek pada package terpisah; probe awal salah mengharapkan judul Kasir padahal UI menampilkan nama toko. Perbaiki assertion berdasarkan UI aktual, simpan failure, jangan mengubah produk untuk memenuhi asumsi harness.

## Pembelajaran M4 — 14 Oktober 2026

15. Widget FakeAsync dengan FFI/KDF memerlukan real-IO drain. Finder dapat menemukan teks parent selama route transition; tunggu loading/frame selesai. Unmount dan close/delete fixture harus selesai dalam finally body ketika test binding masih aktif, bukan pumping dari global teardown setelah inTest false.
16. Timestamp sama diurutkan UUID BINARY, bukan urutan insert. Fixture FIFO yang memerlukan urutan tertentu memakai timestamp berbeda; kasus tie tetap diuji tersendiri. Hindari mengganti semua literal versi: quantity6 bukan schema6. Ubah assertion PRAGMA saja menjadi Schema.version.
17. Benchmark query production yang sama dengan EXPLAIN, bukan SQL disederhanakan. Fixture 10k/100k memperlihatkan continuation jauh ~9ms Windows karena broad period bound mengalahkan tuple seek. Dua batas redundan belum memperbaikinya; satu effective end=min(period end,cursor timestamp+tie allowance) menurunkan median jauh ~0.55–0.59ms. Assertion pagination/tie/boundary tetap dipertahankan dan diregresikan. Angka ini tidak menjamin semua perangkat/dataset atau SUM/ranking O(1).
18. Pisahkan waktu seed/index/anchor lookup dari latency query (warmup1/samples5). Fixture konsisten mencakup detail/batches/ledger/payments, bukan hanya header. Batch250 membatasi objek sementara tetapi tidak membuktikan peak RAM. Configure PIN tidak berarti unlock capability; benchmark harus unlock fixture eksplisit.
19. Migration biasa akan mengubah whole-file hash. Buktikan isolasi fixture dengan byte hash sebelum/sesudah native, lalu bukti upgrade dengan old-column row-multiset fingerprints, FK/quick_check dan versi. Hanya metadata/digest disimpan; jangan menulis PIN/customer row ke bukti. Main-file copy WAL ditolak, bukan diklaim konsisten. Ini bukan fitur backup/restore M5.

20. Header file rollback SQLite tidak membedakan DELETE/TRUNCATE/PERSIST. Native benchmark aktual memakai persist; probe ordinary tidak boleh menyimpulkan delete dari header01. Tolak WAL/nonzero rollback journal header pada pemeriksaan main-file dan simpan batasnya; salinan read-only tetap bukan fitur backup. UIAutomator Flutter perlu text serta content-desc; assertion text saja sempat gagal walau Kelola tersedia. Probe FTS5 Android dapat mencatat SQLiteLog no such module lalu fallback term-index bekerja; bedakan expected capability probe dari crash/query gagal.

## Pembelajaran pengujian DV8910 — 14 Oktober 2026

21. Target Android TV/ARM32 memerlukan pengukuran terpisah. KDF600k debug sekitar20,8detik membuat beberapa operasi credential melampaui timeout30detik. Perpanjang batas test secara eksplisit; jangan mengurangi KDF/assertion. Parameter mediumfixture1k/2k boleh ditambahkan pada helper test dengan mempertahankan default10k/100k dan menguji kedua ukuran.
22. `IntegrationTestWidgetsFlutterBinding.defaultTestTimeout` pada SDK ini adalah None. CLI `--timeout` saja tidak membatasi `testWidgets`; pasang batas5menit pada binding/UI. FullyLive dan real-IO drain membantu native frame/SQL, tetapi hasil wajib diretest. Ketika UI stuck, periksa visible/focused ownactivity dan Awake/Dreaming read-only; jangan mematikan sistem screensaver atau menyimpulkan diagnosis tanpa bukti. Konfirmasi user menyalakan layar hanya availability.
23. UIAutomator Android11 dapat mempunyai EditText tanpa label dan `dumpsys window windows` tidak menunjukkan currentfocus. Gunakan class/hint/observedbounds dan full dump dalam memory lalu filter ownfocus, tanpa menyimpan konten aplikasi lain. Screenshot ownapp tidak membuktikan input berfungsi. Enter ADB named/numeric pada Leanback yang menjadi `t` adalah temuan jalur tersebut; belum membuktikan sumber kesalahan atau scanner fisik.
24. Form yang pendek/keyboard terbuka memerlukan helper unfocus/ensureVisible/drain sebelum tap. Simpan miss/no-element dan overflow sebagai kegagalan; jangan menonaktifkan hit-test/error atau mengurangi assertion agar lulus. Bila productionlayout bermasalah, laporkan reproduksi dan tunggu scope perbaikan terpisah sesuai instruksi pengujian.
25. Ordinary package absent berarti tidak ada baseline DB untuk dihash. Buktikan absence awal/akhir serta sandbox fixture, bukan klaim preservation DB yang tidak ada. Restart PID nyata sebelum/setelah commit membuktikan skenario force-stop tersebut; tidak sama dengan reboot, powerloss, atau restore. Sample release/profile1sale bukan benchmark1k/2k atau releaseacceptance penuh.
26. Jika runner berhenti pada failure, jalankan suite independen berikutnya melalui safe runner baru dan simpan hasil perfile. Hitung uniquecase hanya dari suite assertions yang benar-benar pass; jangan menjumlahkan retry/partialcounts. Cleanup hanya nama fixture tepat dari sandbox uji setelah log disimpan, tanpa wildcard/pmclear/root/systemsetting; ledger dan keadaan APK akhir wajib dicatat.

27. Pada TV yang otomatis Dreaming, synthetic Flutter taps tidak selalu menjadi aktivitas input sistem. Window khusus APK.integration dapat memakai FLAG_KEEP_SCREEN_ON tanpa wake lock/permission/settings. Source class hanya masuk ketika flagisolasi, launcherordinary diverifikasi tetapMainActivity dan classuji tidak masuk DEXordinary. Userwakeup hanyalah availability; flag tidak boleh dijadikan alasan mengubah layanan screensaver. ADB masih bisa transientoffline walaupun Awake/flagaktif; simpan rawexit/finalizationfailure dan jangan mengarang sebab.
28. Saat memindahkan persiapan SQL sebelum lifecycleProvider, serviceunlock tidak mengisi stateUI Provider. Autentikasi Provider tetap melalui unlockasli; jangan setstate/bypassgate. PartialsetUp harus melacak provider mana yang benar-benar dibuat agar cleanup tidak double-dispose statekasus sebelumnya. Setelah helperbersama berubah, focusedWindows diperiksa lagi sebelumnative.
29. Selalu gunakan encodingUTF8 eksplisit untuk membaca/menulis dokumen Windows. Audit glyph/IDrequirement setelah patchberulang; jangan membiarkan mojibake atau renumber. Filter log severity pada kolomlog, bukan substring engine/Flutter dalamURL, dan tetap laporkan assertionfailures dari runner walaupun PIDbuffer tidakmemuatfatal.

30. Helper scroll harus menangani field lazy yang belum dibangun, bukan memanggil ensureVisible lebih dulu pada finder kosong. Tunggu frame sesudah scroll; jangan unfocus autocomplete sebelum option dipilih. Binding live tidak merender ketika lifecycle paused: periksa servicegate segera, resume, lalu periksa UI yang disembunyikan. Ini penjadwalan test, bukan perubahan kebijakan session atau bukti semua OEMbackground.
31. Native PID snapshot dapat tidak tersedia setelah runner sudah berhenti; simpan pesan absent dan pakai rawrunner, bukan hash/log kosong yang dianggap bersih. Bedakan bug foreground (dialogpelunasan51px terulang) dengan overflow underlay/disposedmasterlist yang masih butuh diagnosisvisual. Masalah testhelper, sourceproduksi, firmware/IME dan transport tidak boleh disamakan.

32. UIAutomator dapat hanya mengembalikan windowapp aktif dan tidak memuat nodeIME meskipun keyboard terlihat/viewportshrunk. Jangan menamai flag itu ime_visible; pisahkan ime_nodes_in_dump dan system mInputShown. SesudahBack, mIsInputViewShown pada service masihtrue walaupun mInputShownfalse/viewportpulih; jangan memakai staleviewflag untuk kesimpulan. Guard screenshot menolak mInputShowntrue/unknown, tanpa menyimpan prediction atau inputprivate. Nodeskey kosong berarti directvirtualkeyboardprobe blocked, bukan keyboard tidak tersedia.

## Checkpoint sebelum data penting

Selesaikan M4–M6 sesuai instruksi pengguna, termasuk backup konsisten/restore safety dan release/accessibility/hardware yang diperlukan. Audit requirement satu per satu; berikan daftar risiko/config/unverified. Jangan menyarankan memasukkan data penting hanya karena test/debug build lulus. Tidak publish atau mengirim data keluar tanpa instruksi.

## Pembelajaran audit/perbaikan M1–M4 (14 Oktober 2026)

33. Hasil commit finansial harus tetap benar ketika route/Provider disposed. Refresh UI setelah commit tidak boleh mengubah sukses menjadi gagal. Uji dengan barrier SQL sebelum commit, disposal, lalu release; periksa saldo, jumlah sale, stok, FK, rollback dan retry idempotent. Jangan membatalkan penulisan yang sudah diterima hanya karena halaman dilepas.
34. Mutex boolean pada satu instance tidak menyerialkan instance layanan lain. Untuk rotasi kredensial dengan KDF di luar SQL, verifikasi identitas kredensial dan compare-and-swap saat replacement. Jangan mengurangi putaran KDF atau menghapus audit untuk mengatasi race; hanya satu rotasi dapat commit menggunakan salt lama yang sama.
35. Pemeriksaan capability sebelum antrean DB tidak cukup untuk pembacaan terproteksi. Recheck saat eksekusi dan setelah IO sebelum mengembalikan HPP/pengaturan. Uji revoke saat request menunggu barrier; kemudian unlock dan uji jalur normal agar validasi tidak berubah menjadi penolakan permanen. Visibility gate bukan pengganti guard service.
36. Viewport Windows tanpa safe area tidak merepresentasikan perangkat. Poco mengungkap tab overflow4/14px setelah inner list sudah scrollable. Uji safe area, keyboard dan teks besar bersamaan; semua header/footer yang dapat melebihi ruang perlu ikut scroll. Nested sliver header dapat keluar dari finder onstage setelah scroll: reveal header lalu assert tab terpilih, bukan menganggap tap warning berhasil.
37. Simulasi TextInputAction, hardware key framework, Enter melalui ADB/IME dan scanner fisik adalah bukti berbeda. Jika IME memilih karakter, jangan membersihkan suffix secara heuristik atau mengubah validasi barcode. Isolasi IME-visible vs hidden dengan fixture unik dan catat event/jumlah keranjang; hardware yang belum diuji tetap unverified.

## Runbook singkat

- Baca AGENTS/SPEC/PLAN/STATUS/REQUIREMENTS dan catatan ini.
- Konfirmasi milestone dan kesiapan HP; `flutter devices`, target fisik eksplisit.
- `tools/test_android.ps1 -DeviceId <ID> -AndroidSdkRoot <SDK> -TestFiles @(...)` untuk native, tanpa bare flutter test integration.
- Ordinary app: verified APK, direct adb install-r tanpa fallback otomatis. Reset dummy hanya authorized switch/scoped script, tidak menjadi bagian test runner biasa.
- Baseline/hash, tests/log, formatter/analyze/build sesuai perubahan, update STATUS/REQUIREMENTS. Berhenti di milestone aktif.

38. Emulator first-frame timeout tidak cukup untuk menyalahkan GPU, metrik global, atau aplikasi. Bandingkan minimal MaterialApp, metrics lama/lokal, dan urutan autentikasi nyata. Pada audit ini first-pump dua varian timeout; minimal cold1PASS, lalu credential/seed di regular setUp membuat7regresi PASS. Simpan failed evidence dan pertahankan gate/KDF/business assertions; ini perbaikan fixture, bukan perubahan aturan aplikasi.
39. Runner yang tertahan sebelum reporter bukan failed business assertion atau PASS. VMResume/stack kosong serta Awake/focus hanya membatasi diagnosis. Hentikan secara bounded, catat interruption asli/anotasi, lanjut suite independen; port diagnostik sementara dibersihkan. ADBoffline sesudah12kasus DV dan retry3 bukan14PASS atau kegagalan migration/PIN yang telah terbukti. Serialize native APK builds agar target fixture tidak tertukar.


## Finalisasi audit — 15 Oktober 2026

40. Pada fixture native lama, tampilkan surface pertama sebelum seed dan jalankan IO nyata persiapan di `tester.runAsync`; regular setUp helper bersama dapat lebih tepat untuk autentikasi sebelum widget body. Jangan menerapkan satu pola secara buta. Management/cashier pulih, tetapi wholesale tetap sempat timeout7menit setelah kedua perubahan; diagnosis kelas widget membuktikan form sudah dibangun. Phase markers dan dua repeatPASS tidak membuktikan penyebab first-frame/GPU/engine. Pertahankan status diagnosis intermiten dan rawfailedruns.
41. Antrean serial native yang kedaluwarsa sebelum build/install bukan native assertion gagal. Catat timeout antrean terpisah, kemudian requeue suite independen. LocaleDV missingCari saat Dreaming juga bukan bukti terjemahan hilang; userwakeup hanya availability, retest1PASS memberi bukti kasus.
42. Setelah interupsi, cleanup memakai nama fixture/nonce/timestamp milik run yang sudah diverifikasi, package.integration dan ledger sebelum setiap penghapusan. Delapan file tepat emulator dibersihkan tanpa wildcard/pmclear/uninstall; ordinary hash tetap. Build guard negatif harus menolak sebelum install; APK biasa disalin dan package/launcher/seluruhDEX diperiksa. Bukti ini terbatas pada baseline/run yang diuji, bukan izin reset data masa depan atau klaim restore.

## Tambahan pengujian Realme — 15 Oktober 2026

Tambahan manual16Oktober2026: dua ketukan fisik yang dicoba tidak membuktikan
dua tap diterima tombol bila navigasi terjadi sesudah tap pertama. Klarifikasi
pengguna harus menurunkan klaim awal menjadi belum terverifikasi; receipt tunggal,
tes handler sintetis, concurrent service submit, dan keunikan ledger adalah bukti
berbeda. Jangan mengulangi checkout pada fixture manual untuk mengejar tapganda
atau memperlambat produksi secara spekulatif. Nama fixture yang diketik pengguna
juga dapat berbeda kapitalisasi; diagnosis read-only membuktikan nilai actual
sebelum mengoreksi assertion helper, tanpa mengubah identitas/validasi pelanggan.

UIAutomator dump juga bukan observasi tanpa efek pada testWidgets: aksesibilitas
platform dapat membuat SemanticsBinding mengambil SemanticsHandle. Pada nativeUI
16Oktober, probe bertumpang dengan akhir kasusUSD yang gagal pemeriksaan handle;
kasusIDR sudahPASS. Jangan menyimpulkan app leak/OS rusak atau mematikan assertion.
Simpan failure/timestamp, ulang suite tanpa UIAutomator selama tes, dan bedakan
hasil retest dari penyebab internal yang belum dibuktikan. Pembacaan file log/PID
tidak memerlukan dump semantics; tunggu suite selesai untuk UIAutomator/screenshot.

43. KDF yang sudah dipindah dari UI isolate masih dapat terlalu lambat bagi pengguna. Ukur algoritma/putaran yang sama pada perangkat aktual. Pada Realme, Dart600k sekitar26s, dua alternatif OS Java18–21s, dan Mbed TLS terpin sekitar3,1s. Jangan mengurangi putaran, mengganti salt/verifier, atau memakai hasil dummy. Wajib buktikan vektor independen/UTF8/domain recovery/parameter, worker thread dan pembukaan verifier lama tanpa rewrite sebelum regresi alur terlindungi. Angka ini belum menggantikan profile/release dan perangkat lain.
44. Backend native baru membutuhkan sumber rilis resmi terpin/checksum/lisensi, dependensi header transitif, konfigurasi minimal, semua ABI/minSdk tetap, serta uji JNI release. Dua build Mbed TLS awal gagal pada header yang belum disalin; runner berhenti sebelum install. Ini kegagalan integrasi build, bukan bug runtime atau alasan melemahkan gate APK.
45. Selesaikan build/install dan verifikasi exit sebelum menjalankan probe perangkat yang bergantung padanya. Probe pertama Realme sempat berjalan sebelum install selesai dan tidak menemukan PID; timestamp membuktikan overlap workflow. Percobaan tersebut tidak membuktikan crash aplikasi. Simpan rawfailure, ulang berurutan, jangan mengubah sistem untuk mengatasi kesalahan orkestrasi.
46. Windows PowerShell5 dapat menghasilkan logUTF16LE dan mengubah stderr child menjadi NativeCommandError. Deteksi BOM; jangan rewrite log yang masih ditulis. Outer queue boleh menyimpan exit asli dan melanjutkan suite independen, tetapi tidak boleh mengubah failedexit menjadi PASS atau menjumlah retry. Serialisasi APK builds/deploy, flatten ledger Value/Count secara terverifikasi setelah writer berhenti.
47. Pointermiss helper UI M3.1 mempertahankan assert bisnis/mode. Retest dengan hitTestable/ensureVisible/boundedwait PASS tanpa marker wait tidak membuktikan cabang scroll tersebut dieksekusi atau penyebab internal overlay sudah pasti. Catat test-target/timing dan batas diagnosis, jangan mengklaim bug grosir, keyboard OEM, atau OS terselesaikan. Kesediaan pengguna menguji fisik juga bukan bukti Gboard/touch/TalkBack lulus.
48. CMake baru dapat membuat APK narrow-target mengiklankan ABI yang tidak mempunyai engine Flutter. Build sukses saja tidak cukup: profile ARM32 pertama memuat KDF tiga ABI tetapi engine hanya ARM32; AAPT gate menolak sebelum install. Cocokkan CMake abiFilters dengan properti target-platform Flutter, pertahankan tiga ABI pada build universal, lalu periksa keduanya. Debug/release ordinary universal dan profile ARM32 sesudah perbaikan lulus identitas/JNI/ELF/license/zipalign; hasil ini tidak membuktikan runtime ARM64 tanpa perangkat.
49. Aplikasi/PID tetap hidup dan Awake tidak berarti aplikasinya menerima input. Saat profile Realme, mFocusedApp masih paket uji tetapi mCurrentFocus adalah NotificationShade. Simpan pengukuran parsial, hentikan input, minta pengguna menutup panel, lalu ulang tanpa mengubah sistem. Retest empat cold/tiga warm PASS. Ini gangguan fokus TEST/ENV; tidak membuktikan crash, kerusakan OS, atau alasan SKIPPED_SYSTEM.
50. Pada helper M2, hit-test pointer Save gagal meski widget ditemukan; snapshot sesudah gagal menunjukkan form edit masih terbuka. Bounded hitTestable wait kemudian benar-benar menghasilkan marker M2_HIT_WAIT dan retest menyelesaikan save/undo/background lock. Bukti tersebut mendukung masalah kesiapan target pengujian, tetapi tidak mengidentifikasi overlay internal secara pasti. Jangan mengubah validasi atau implementasi Save yang belum terbukti rusak.
51. Timer pada helper belum menjadi bukti jika fase hasilnya tidak disimpan. Baseline checkout Realme tidak mempunyai sampel tersimpan yang cukup; jangan mengisi angka dari ingatan. Probe release baru memakai DBnonce sendiri, satu warmup/lima sampel submit SQL, seed/cart di luar stopwatch, lalu memeriksa enam sale unik/fullperiod/stok/piutang dan menghapus hanya DBnonce pemiliknya. Lima sampel62,668–72,849ms adalah latensi layanan pada fixture kecil, bukan render/keyboard atau perbandingan before/after.
52. Pertahankan first-start outlier dan bedakan am start TotalTime, observation bound UIAutomator, cold pipeline dengan KDF, serta warm yang memakai state/PID sama. Actualrelease Realme firstcold6077ms lalu1011/861ms; itu tidak boleh diringkas seolah ketiganya1s. PSS tiga siklus52.595/53.245/51.911KiB dan akhir kasir40.877KiB bukan peakRAM, retained-heap proof atau jaminan tidak ada leak. Jangan menutup aplikasi lain atau melakukan forcedGC untuk memperbaiki angka.
53. Pemeriksaan integrity sebelum manual dan sesudah routecycles membuktikan checkpoint otomatis, bukan hasil sesudah pengguna bertransaksi. Serahkan APK release yang sama (hash/identity/JNI diverifikasi ulang), dokumentasikan fixture/tanggal/PIN publik dan TalkBack/font awal, lalu hentikan input otomatis selama manusia memakai HP. Tunggu laporan langkah nyata, lakukan integrity pascamanual dan restore APK fixture sesudahnya; jangan menandai manual PASS dari kesiapan HP atau screenshot.

## Tambahan M5 —16 Oktober2026

54. Limit/putus ADB dapat menghentikan finally hash dan restore APK. Catat hasil parsial apa adanya dan jangan menjumlah kasus did-not-complete sebagai PASS. Saat perangkat kembali, bandingkan endpoint hash dengan baseline run yang terputus lalu pulihkan exact original APK tanpa uninstall. Keberhasilan endpoint tidak membuktikan seluruh interval yang tidak teramati.
55. Proses release hidup dan nol baris FATAL tidak membuktikan layar berhasil dibangun. Flutter release dapat melaporkan stack error pada prioritas I/flutter; wrapper Banner memerlukan layoutDirection di luar MaterialApp. Reproduksi widget dan smoke own-UI release setelah perbaikan, jangan menyalahkan driver/TV dari layar kosong saja.
56. Keyset/list lazy: finder yang belum mounted setelah helper scroll bukan bukti data profil hilang. Periksa PIN/data/scroll state; bounded reveal dan strict hitTestable tetap wajib sebelum tap. Programmatic reveal membuktikan akses layout/selection, bukan gesture fisik atau keyboard OEM.
57. Backoff tanpa budget tahan restart masih retry tanpa batas. Simulasikan instance scheduler baru pada setiap kegagalan, simpan jumlah claim atomik lintas engine dengan generation+target, dan jangan mengubah last_success saat exhausted. Mock/host PASS belum membuktikan worker/Keystore lintas PID atau OAuth nyata.
58. Package integration melindungi ordinary tetapi belum memisahkan beberapa kampanye manual dalam sandbox yang sama. Gunakan DBnonce baru melalui guard compile-time khusus fixture, berlaku juga untuk worker production composition. Pertahankan DB default sandbox lama; jangan membuka/migrasikannya hanya untuk menyerahkan APK manual.

59. Transkripsi kertas bukan byte-identik hasil cetak. Pada M5, salinan pengguna tampak kehilangan0 dan mengganti koma/€; pemeriksaan ulang kertas memastikan semua benar tanpa reprint. Bedakan wrap sah, clipping dan salah transkripsi sebelum mengubah formatter. Sebaliknya screenshot Connected tidak meniadakan bug feedback: row tanpa selected state dan status jauh dari tombol direproduksi2FAIL, diperbaiki dengan feedback dekat aksi, lalu host/native UI lulus. Jangan menyebut masalah SPP bila buktinya hanya status offscreen.

60. Dialog izin Android dapat memicu lifecycle non-resumed meski permintaan ditolak cepat. Jangan memperbaiki loop PIN dengan pengecualian global penguncian. C20: hentikan permintaan OS berulang setelah denial, baca grant aktual tiap aksi, simpan riwayat prompt lokal instalasi dan arahkan pemulihan lewat Settings. Uji grant/deny/regrant serta notice yang tetap terlihat saat tombol di tepi viewport; helper wajib mem-pump frame sebelum assert lock. Model JVM dan mock lifecycle tidak menggantikan retest dialog OEM.

61. Instruksi manual harus membedakan teks status inline, dialog dan toast. Pengguna mengira sukses backup berbentuk dialog; laporan belum melihat pesan lalu menemukannya di atas tidak membuktikan viewport awal offscreen. Revisi diagnosis berdasarkan klarifikasi, simpan raw report, dan bedakan repro layout otomatis dari bukti fisik. Perbaikan feedback tidak boleh diam-diam mengubah identitas operasi/backup atau memunculkan dialog baru tanpa kebutuhan.

62. Rect widget di atas batas IME tidak membuktikan seluruh baris edit terlihat: ancestor scroll viewport dapat memotong bagian bawah. C22: bedakan InputDecorator (helper/counter) dan EditableText, periksa hit-test tepi atas/bawah serta bounds keyboard; jangan menghapus assertion untuk meluluskan native. Setelah tepi EditableText gagal, ringkas layout/helper/label aksi lalu ulang regresi. Mock insets bukan bukti keyboard OEM fisik.

63. Streaming AEAD dapat membungkus kegagalan autentikasi sebagai IOException, bukan GeneralSecurityException. C23 repro native wrong64hex mengembalikan platform_io_failed; pesan umum izin/koneksi/PIN menyesatkan. Petakan kegagalan pada konteks inspeksi arsip ke pesan yang mencakup kode/arsip/tidak terbaca, tanpa menyimpulkan wrong-key dari semua IO atau melemahkan pemeriksaan. Invalidasi preview sebelum dispose/revalidasi agar kegagalan tidak mempertahankan hasil lama. Permintaan input recovery visible dibatasi flag fixture/package terverifikasi, bukan melepas penyamaran produksi atau izin logging rahasia.

64. Pada integration_test, registerTestTextInput default false. Jangan mencampur tester.enterText dan fake viewInsets dengan callback IME nyata lalu menyimpulkan PIN menghapus controller. C23: pre-lock diagnostic sudah menunjukkan nama awal, sehingga failure post-unlock bukan bukti kehilangan saat PIN. Untuk testcase simulasi, daftarkan kanal TestTextInput secara eksplisit dan pulihkan state semula; pertahankan assertion sebelum/sesudah lock, hit-testing dan retest native. Bukti keyboard fisik tetap dari manual, mekanisme callback OEM yang tepat tidak boleh dikarang.

65. Baseline sebelum jeda limit bukan baseline beku bila pengguna membuka fixture/PIN. Jangan menghapus audit/attempt metadata atau mengabaikan tabel agar tes lolos. C23:4 hash berbeda dijelaskan dengan audit append-only, counter evaluasi alert dan counterfactual digest credential di memori (tanpa rahasia/log/SQL writes); semua tabel lain sama. Waktu attempt ditangkap sebelum KDF, waktu audit sesudahnya. Simpan FAIL awal; baseline nonce baru dan strict reinstallation comparison hanya membuktikan interval baru, bukan mengubah histori interval lama.

66. Resource yang dipanggil plugin melalui string dapat dibuang pada release meskipun debug/native worker pernah berhasil. C24: ikon tidak ada pada tabel resource AAPT dan probe release Poco mengembalikan invalid_icon. Retensi resource spesifik membuat probe initialize sukses dengan seluruh hash DB tetap. Periksa resource pada APK final, bukan hanya file sumber atau build exit0. Status setup generik baru boleh dibersihkan sesudah semua inisialisasi sukses; jangan menghapus error Drive lain atau menandai OS permission/delivery sudah diuji.

67. Serialisasikan seluruh perintah Flutter dalam workspace, termasuk host test/analyze yang dapat menjalankan pub dan mengubah metadata plugin. Pada C24, host test bertumpang tindih dengan akhir build fixture yang gagal karena registrant merujuk IntegrationTestPlugin yang tidak ada pada classpath. Kegagalan sebelum install disimpan; jangan mengedit GeneratedPluginRegistrant manual atau menghapus plugin untuk meluluskan build. Ulang build serial dari sumber final dan bedakan hasilnya dari diagnosis mekanisme internal yang belum ditrace.

68. Containment path harus membandingkan parent dan child yang sama-sama canonical. Audit logo C24 gagal setelah semua3arsip terautentikasi karena hanya child di-resolve. Retest rootAliasChanged:true/containedInCanonicalRoot:true serta SHA logo cocok membuktikan alias Android pada kasus ini; tidak perlu memindahkan berkas produksi. Tetap periksa containment dan hash, jangan mengganti assertion dengan file-exists saja. Safety queue juga harus mencakup kalibrasi dan sale-linked jobs: bandingkan seluruh hash tabel terhadap snapshot sebelum swap, bukan jumlah empat sale jobs dianggap seluruh antrean.

69. Pembatalan SDK Google mempunyai enum canceled yang berbeda dari interrupted/configuration error. C25 mereproduksi canceled menjadi pesan izin/koneksi/PIN yang menyesatkan. Petakan canceled pada konteks pemilih akun menjadi Dibatalkan; jangan menyamakan semua error dengan cancel. Invalidasi kandidat sementara sebelum pemilihan ulang, sambil mempertahankan tujuan/consent yang sudah tersimpan. Uji keadaan disconnected dan existing account/autoOn, PIN gate, seluruh fingerprint DB, serta kontrol konfirmasi lama yang harus hilang. SDK mock/native bukan bukti consent/API Google nyata. Instruksi manual harus menyebut tombol/teks konkret; tiga baris jadwal bukan bukti akun terhubung atau tidak.

70. Inisialisasi SDK yang di-cache antar widget test sebaiknya dibuat melalui tester.runAsync, di luar fake clock per testcase. C25 first-case repro mapping valid; tiga failure lanjutan tertahan di helper/cleanup. Retest setelah perbaikan source/helper lulus, tetapi kontribusi tiap perubahan belum diisolasi; jangan mengklaim mekanisme internal semua failure tertrace. Pertahankan rawfailure, assertion bisnis/consent dan hit-testing. Focused5 adalah subset regresi43, bukan48kasus unik. Serialisasikan Flutter test/analyze/build agar registrant tidak bertabrakan.

71. Akun dalam OAuth Testing audience dan pemilih akun yang berhasil belum membuktikan Drive API aktif. D-MAN03 gagal generik, pemilik menemukan API belum Enabled, lalu D-MAN03R berhasil pada APK C25 yang sama sesudah aktivasi: pisahkan konfigurasi lingkungan dari perbaikan feedback C26. Tanpa respons HTTP lama jangan mengarang reason aktual. Pesan API-disabled hanya boleh diturunkan dari reason terstruktur yang dikenal, bukan substring pesan bebas; jangan menulis respons/identitas/token ke log. Aktivitas melihat-lihat/PIN selama jeda bukan baseline beku: buat interval pembandingan baru tanpa menghapus hasil lama.

72. Git yang baru tersedia tidak otomatis memberi diff historis sebelum baseline commit pertama. C26 source awal sudah ada di HEAD yang disediakan pengguna; pakai juga hash/evidence sebelum/sesudah, bukan menyimpulkan source tidak berubah dari git diff kosong. Artefak APK/backup perangkat perlu di-ignore sebelum masuk index. Ignore tidak menghapus file tracked/riwayat publik; pertahankan salinan APK lokal sampai closing restoration selesai dan pisahkan pembersihan repository dari penghapusan disk.

73. Tombol Salin recovery harus menyalin nilai canonical lengkap, bukan hasil seleksi visual pengguna: normalisasi whitespace/hyphen, validasi64hex dan gate PIN lagi sebelum aksi. Pisahkan kemampuan produksi dari flag input-visible fixture. Uji sink dengan nilai publik agar clipboard OS pengguna tidak dibaca/ditimpa; native build atau sink mock bukan bukti paste/preview OEM. Tandai clip sensitif tanpa mengklaim enkripsi atau auto-clear, jangan mencentang konfirmasi salinan/merotasi key dari aksi copy.

74. Hasil Salin/Tempel berhasil tidak membuktikan redaksi panel clipboard. C27 pengguna melaporkan panel kecil Android menampilkan kode meski source memakai flag resmi; pisahkan temuan tersebut dari input fixture yang sengaja visible. Reproduksi memakai nilai publik yang ditap eksplisit lewat handler produksi dan baca metadata ClipDescription saja di kelas fixture (tanpa Item/text/URI atau clipboard dump). Jangan menyimpulkan penyebab OEM, mengubah format kunci, menambah flag sistem tersembunyi, atau mengklaim fixed sebelum metadata/perilaku nyata diketahui. Pertahankan APK/data dan tutup interval dengan hash serta pemulihan exact APK.

75. Klarifikasi dapat membatalkan atribusi failure, bukan mengubah hasil itu menjadi PASS. C27 setelah probe3booleantrue, pengguna menjelaskan teks terlihat adalah64hex di halaman sesudah Reveal, bukan pengamatan panel OS yang dapat dipercaya. Pertahankan laporan awal dengan anotasi koreksi: redaksi UNVERIFIED, metadata native PASS, copy/paste manual PASS. Instruksi harus membedakan teks permanen halaman dari overlay sementara setelah tap; jangan meminta perbandingan sebelum menyalin yang tidak diperlukan. Jangan memperbaiki masking halaman yang memang diminta pengguna hanya demi dugaan preview OS.

76. Arsip yang dipertahankan dapat berasal dari checkpoint draft berbeda. Audit restore Drive pertama gagal karena3arsip lama dibandingkan dengan C27; jangan membuang tabel draft atau mengubah data aplikasi. Tetapkan asal lewat set digest/katalog historis, bandingkan semua23tabel ke checkpoint yang tepat, dan log hanya role/nama tabel/boolean. Retest membuktikan arsip lama hanya beda dua tabel draft terhadap C27 dan cocok historis; newest safety/upload cocok C27. Bedakan snapshot upload running dari safety sukses serta live run yang dibersihkan. Tanpa baseline baru tepat sebelum human restore jangan mengklaim seluruh metadata safety identik dengan checkpoint lama.

77. Mutasi backend dan job registration bukan bukti projection route sudah diperbarui. C28 host persisted target21 namun overview null; muat ulang melalui service, jangan menjadwalkan ulang/ubah zona demi label. Pertahankan manual D-MAN14 PASS sebagai bukti terpisah. Helper perlu scrollable form ber-key karena notice sukses menambahkan scrollable lebih awal; StateError/lazy0 bukan failure produk baru. Uji ON/registration dan OFF/cancel/target-clear, seluruh tabel lain sama, tanpa Google/job OS pada widgettest.

78. Job terjadwal/ready belum membuktikan worker mulai atau OAuth headless berhasil. Simpan baseline baru, PID setup keluar normal dan PID worker berbeda. Bila perlu pemicu shell, cocokkan nonce ke job ID hanya package uji dan gunakan run -s dengan syarat aktif; laporkan controlled trigger, bukan natural21/reboot/Doze. Delapan upload nyata/retensi7 tidak membuktikan origin lain aman bila baseline scope lain0. Log SDK dihitung tanpa menyimpan payload akun. Parameter package pada dumpsys dapat tetap memuat statistik global; saring di memori/retensi hanya blok sendiri. Context manager sqlite Python tidak menutup koneksi; close eksplisit sebelum menghapus salinan scratch Windows, bukan menyentuh DB perangkat.

79. Konfirmasi akun baru tidak otomatis menginvalidasi route lama. C29 dua repro host menunjukkan remote A di bawah tujuan B dan cursor tersisa sesudah disconnect. Bersihkan page/cursor hanya sesudah operasi akun berhasil, muat ulang projection target sesudah scheduler refresh, dan pertahankan consent serta seluruh tabel lain. Mock service/HTTP/SDK tidak membuktikan akun Google B nyata; serahkan build terverifikasi dan uji akun manusia terpisah. Salah path file retry pada full regression bukan bug aplikasi: simpan47PASS+1loadingFAIL dan ulang enam file benar, hitung50kasus final tanpa menjumlah retry/subset.

80. Delapan status sukses lokal dan tujuh arsip cloud adalah himpunan berbeda. D-MAN16 B kosong/8status bukan bukti kebocoran akun: telusuri history SQL vs API, beri heading/konteks tujuan, jangan hapus/filter sejarah agar angka sama. Pesan kosong hanya sesudah respons list sukses dan berlaku halaman. Uji label id/en literal, akun saat ini/lain/tidak tercatat, semua fingerprint tetap. Audit B memakai baseline baru sesudah PIN publik dengan hanya metadata credential/audit berubah; B0/A-ID unavailable/Off guard bukan bukti readback A serentak atau cancel job OS. Jangan mencetak payload metadata ketika negative assertion gagal; assert boolean dan kode error terbatas.

81. HTTP401 coverage does not prove silent Google SDK coverage. Official SDK null means interaction required when prompts are disabled. A StateError with the right text still misses typed UI/scheduler mapping. Reproduce the actual SDK boundary, map only a specific payload-free exception, preserve unknown configuration failures, assert no interactive calls/HTTP and no false success or repeated same-day attempt. Test before stopped at UI; do not claim scheduler before evidence that never ran. Host fixtures are not real revoked-token proof, and editing source does not update the C30 APK handed to the human.

82. Suite host yang dibagikan ke native harus memenuhi kontrak nama/path adapter SQLCipher. C31 memakai fixture.db sehingga guard fixturePathRequired menolak sebelum open; perbaiki nama disposable ke m5_regression_nonce.db, jangan melonggarkan adapter. Simpan3PASS/1FAIL awal beserta bukti ordinary hash/exact APK restoration; ulang host focused dan native. Fullhost sebelum koreksi nama tetap bukti source produksi yang sama, tetapi jelaskan perubahan helper/focused subset dan analyzer final agar tidak menjumlah retest sebagai kasus baru.

83. Status error sebelum pembuatan backup_runs tetap perlu projection dari backup_schedule setelah route dimuat ulang. Jangan mengandalkan pesan foreground atau mengatribusikan error historis kepada akun baru. Pisahkan bug rendering dari finder lazy: pump/scroll ke anchor yang sudah ada, reproduksi omission dengan helper final, lalu pulihkan source sendiri byte-identik. Jeda/pemilih akun batal bukan baseline beku; tutup dengan baseline sesudah PIN, seluruh hash selama inspeksi, autentikasi arsip dan pemeriksaan work milik fixture saja.


84. USB tersambung ke PC membuktikan jalur berbeda dari Android OTG. Catat
SetupAPI instance, VID/PID, kelas dan driver lalu satu pengiriman publik terarah;
bytes accepted tidak membuktikan kertas. Default probe read-only, one-shot marker
sebelum write, timeout ambigu tanpa retry; jangan memasang driver/queue atau
mengganti perangkat secara otomatis. Pengguna mengonfirmasi kertas terpisah.
Bergantian kabel menjelaskan Poco hilang ADB, bukan otomatis gangguan debugging.

85. Widget FakeAsync tidak boleh menyisakan database tail dari event saat cleanup
real IO berjalan. setUp/tearDown real-async, scoped callbacks dan pump frame yang
benar mengatasi helper timeout/reentrant dan stale visibility finder. Jangan
menaikkan timeout atau melemahkan authorizer. Valid RAM grant juga harus diperiksa
terhadap persisted credential epoch di lease DB; rotasi PIN service lain membatalkan
protected reads/writes meskipun UI belum menerima notifikasi proses lain.

86. Fixture Keystore harus konsisten di seluruh dependency dan PID. Restore-fault
Realme key_missing mendahului fault yang diminta karena EncryptedDatabase memakai
platform default sedangkan BackupService namespaced. Suntikkan platform yang sama,
assert faultReached dan ulang keempat fase. Mock USB juga harus dilepas sebelum
DB terenkripsi kedua dibuka. Jangan melonggarkan key guard atau menandai fault
teruji dari exception yang ternyata terjadi lebih awal.

87. Panggilan privacy window bukan permintaan Bluetooth. Helper native memasukkan
protectedScreen ke raw calls sehingga empty/sequence assertion salah; tangani
void lifecycle dan filter hanya operasi itu pada assertion printer, lalu baca
FLAG_SECURE native terpisah. Retest terfokus bukan full final run. Cancel notifikasi
mengirim perintah OS; baca metadata sampai absent dengan batas singkat, tanpa
cancel ulang. Immediate-read fail/retest7ms absent bukan trace penyebab internal OS.

88. Android TV API30 menaruh mCurrentFocus di dumpsys window displays; windows-only
dump tidak cukup untuk watcher izin. UIAutomator exit137 dan screenshot hitam tidak
membuktikan dialog hilang atau app crash. Dialog izin sendiri dapat diverifikasi
melalui Activity view hierarchy dan posisi tombol positif resource button1 plus
offset window; jangan menebak koordinat atau menekan checkbox/default. Catat grant
UID sesuai package. Readiness probe harus menggambar frame dan membaca fokus
native; guard aplikasi tidak dilemahkan. Keberhasilan native root USBFS adalah
bukti berbeda dari adapter Android normal dan paper tetap perlu manusia.

89. Saat pengguna mengambil perangkat pribadi, hentikan antrean baru dan catat
interval yang belum ditutup. Realme worker nonce1792404362140 sempat scheduled,
kemudian ADB hilang: hash sebelum bukan bukti endpoint preservation, setup marker
bukan worker PASS, dan finally yang gagal terhubung bukan cleanup sukses. Saat
tersedia lagi audit nonce lama sebelum setup baru, pertahankan namespace root
recovery/retry serta hanya retire task sendiri. Jangan meminta reboot untuk
kegagalan helper atau perangkat yang sengaja tidak tersedia.

90. Widget FakeAsync yang membuka DB/IO nyata perlu mount dan drain tail melalui
real-async yang tepat. Jangan meninggalkan save/load tail saat tearDown menutup
DB, atau menganggap timeout helper sebagai kegagalan domain. Uji clipboard
harus mengarah ke keyed form Scrollable, memastikan tombol hitTestable; sticky
status dapat menjadi firstScrollable dan membuat tap di luar layar.

91. Query ekspor baru harus memakai nama kolom skema aktual (base_unit_label),
bukan label domain yang diasumsikan. Buktikan snapshot penuh/periode/filter,
reversal dan presisi melalui pembaca CSV/XLSX independen; file dibuat bukan
bukti nilainya benar. Money64bit/identifier sebagai text menghindari pembulatan
Excel; CSV tetap perlu import kolom sebagai text karena tidak mempunyai tipe.

92. SQLCipher cipher_page_size dapat dikembalikan TEXT oleh driver Android.
Parser strict integer/power-of-two diperlukan, bukan cast int atau parse double.
Metode tryAcquire yang dikenal dapat sah mengembalikan null untuk lease sibuk;
jangan memetakannya ke MethodNotImplemented/MissingPlugin. Uji juga pelepasan
lease dan retry berikutnya, bukan hanya jalur sukses pertama.

93. VACUUM pada WAL dapat mengecilkan page_count tanpa langsung mengecilkan
mainfile saat koneksi masih terbuka. Repro M5.1: status634880bytes, berkas17444864.
Checkpoint/TRUNCATE sebelum/sesudah dan File.length sebelum close membuktikan
reklamasi fisik. busy_timeout0 sementara mencegah menunggu reader eksternal,
timeout/journal mode harus dipertahankan. Fixture reader memakai BEGIN DEFERRED;
sqflite transaction(exclusive:false) masih dapat mengambil reservasi writer dan
menghasilkan kegagalan setup, bukan bug checkpoint. Tidak menghapus WAL manual.

94. Tombol Batal pada write SAF harus mencapai token/stream native, bukan hanya
flag snapshot. Repro UI cancelCalls0→fixed; hasil setelah cancel tidak boleh
menjadi ekspor terverifikasi. Pilih tujuan dan tulis data laporan terproteksi
dipisah agar kembali dari pemilih sistem tidak melewati PIN/epoch. Digest
readback dan timeout tetap diperlukan; provider/keyboard OEM nyata memerlukan
bukti tersendiri.

95. Pisahkan seluruh pekerjaan maintenance opsional, termasuk menulis kandidat,
dari hasil backup yang sudah diautentikasi dan terindeks. Fault trigger SQLite
pada UPDATE space_maintenance mereproduksi backup valid yang keliru dilaporkan
gagal. Catch hanya tahap maintenance sesudah artifact/index selesai; jangan
menelan kegagalan pembuatan/validasi/index backup. Hindari retry upload hanya
karena metadata maintenance gagal, dan autentikasi kembali arsip pada retest.

96. Poco dan printer memakai kabel USB bergantian. Catatan ini harus dibaca
sebelum menafsirkan Poco hilang ADB sebagai gangguan atau meminta debug ulang.
Urutan yang diminta pengguna: cetak DV→verifikasi kertas→pindah kabel Poco→audit
endpoint/handoff. Tidak meminta kedua perangkat tersambung sekaligus. Hash awal
yang belum ditutup karena kabel dipindah tetap unverified sampai endpoint ada.

97. Probe printer harus mengikuti kontrak transport produksi, bukan melewati
antrean lalu mengirim seluruh raster sebagai satu chunk. UsbPrinterIo membatasi
4096bytes dan menolak usb_invalid_chunk sebelum Link.transfer; PrintQueueService
sudah memotong4096. Probe awal gagal karena helper, bukan batas yang perlu
dilonggarkan. Pertahankan marker percobaan lama, buktikan pre-transfer rejection,
lalu gunakan marker revisi untuk satu dokumen berpotongan dalam satu output
lease. Hitung attempted writes/accepted bytes terpisah dari kertas; hentikan
tanpa retry pada error setelah transfer yang ambigu.

98. Koreksi manusia mengalahkan dugaan posisi footer. Pengguna mula-mula menduga
footer di dalam printer, lalu setelah3LF menyebut sebelumnya belum tercetak.
Catat footer kini terlihat, tanpa menyimpulkan hidden-versus-buffering dari byte
accepted. Default6 dapat diuji, saved calibration tetap. Log bernama final juga
bisa stale: periksa timestamp/run/source, simpan failure lama, dan jangan klaim
analyze/build sudah dijalankan jika pipeline berhenti lebih awal di formatter.
Saat pindah chat simpan source/hasil/batas/marker/perintah benar dalam repository.

99. Audit tertunda tidak boleh ditutup dengan asumsi baseline beku. Resume M5.1:
390/391hash cocok, hanya ordinary DB berubah; pengguna mengonfirmasi sempat
memakai dummy. Simpan late-after terpisah dan hasil BLOCKED lama, lalu gunakan
baseline baru (392/392cocok) untuk interval native selanjutnya. Izin menghapus
dummy bukan kewajiban reset. Handoff in-place memakai signature/version/hash
APK aktual, closed snapshot/key sebelum install, lalu semantik kasir dan clean
reopen yang menjalankan bootstrap integrity sesudah migrasi. Jangan menuntut
DB byte-identik pascamigrasi, mengklaim readback SQL yang tidak dilakukan,
akses PIN pribadi dari startup kasir, atau menyamakan snapshot Keystore lokal
dengan arsip portable. Paper default6 tetap perlu bukti fisik meski host/native
fake6LF lulus.

100. Demo bernama lain memerlukan sandbox/applicationId sendiri, bukan sekadar
label. Skybee memakai entrypoint+flag berpasangan, native activity khusus yang
memverifikasi package/debuggable sebelum DB dibuka, dan seed lewat service pada
DB kosong. Marker complete tidak memvalidasi ulang jumlah barang saat startup
agar perubahan uji pengguna tidak ditimpa. Marker parsial tidak auto-reset.
Bedakan setup aplikasi debug dari integration tests; safe runner integration
tetap wajib. Simpan stdout/stderr installer gagal, periksa package dan hash APK
sebelum resume; jangan mengarang sebab exit1 atau replay seed. Hash package lama
ditutup pada kedua interval. Pengguna yang memilih uji mandiri tanpa laporan
tidak diberi pekerjaan menunggu atau automation follow-up.

101. Injeksi `WidgetTester.enterText` pada integration_test dapat bersaing dengan
IME asli. DV M5.2: sesudah dialog, hanya field nama berbeda dari nilai yang
diinjeksi; dirty guard benar menolak keluar. Dokumentasi TestTextInput lokal
memperingatkan kondisi ini. Daftarkan keyboard tes untuk suite injeksi deterministik,
pertahankan assertion nilai/dirty/Back, dan catat OEM keyboard sebagai scope
terpisah. Native final24PASS membuktikan perbaikan harness, bukan klaim bug IME
produksi sudah direproduksi/diperbaiki.

102. `pumpAndSettle` tidak menggantikan penantian IO database nyata. Indikator
loading yang menunggu IO dapat menghabiskan waktu virtual, sedangkan pump0ms
tidak menyelesaikan animasi route. Helper bounded memakai runAsync untuk IO dan
frame16ms untuk transisi; tunggu Provider daftar yang benar-benar selesai reload,
bukan nama pada route lama yang masih keluar. Finder `.first` melempar saat belum
ada elemen, sehingga uji readiness pada finder asal sebelum mengambil first.
Regresi form publik mempertahankan saldo8500 dan assert stay/discard/root.

103. Windows1224 dapat menolak truncate formatter pada berkas yang dipetakan.
Jangan menghapus berkas atau menyatakan format sukses dari tulisan “Formatted”.
Gunakan output format non-writing lalu patch, pertahankan Unicode melalui JSON
ASCII-escaped saat melewati shell/codepage, dan ulangi `--output=none
--set-exit-if-changed`. M5.2 receivables akhirnya0changed; source tidak diganti
dengan keluaran shell yang sudah merusak karakter.

104. Audit lokalisasi lama juga perlu diverifikasi terhadap baseline aktual:
HEAD sudah245requirement unik, bukan konstanta244 yang tertinggal di script.
Tidak menghapus requirement agar count cocok. Literal parser tidak boleh
menangkap potongan interpolasi status maintenance sebagai kunci statis.
Deskripsi144pesan dilengkapi dan tiga kunci UI/error yang benar-benar hilang
ditambah beserta mapping. Gen-l10n/format/audit/analyze diulang; jangan menyebut
build sudah berjalan jika pipeline berhenti lebih dulu pada audit.

105. Bedakan file dikeluarkan index dari file yang memang belum pernah tracked.
Manifest M5.2 mencakup275artefak lokal, tetapi274deletion index+1dump baru yang
di-ignore. Verifikasi `git ls-tree HEAD` dan diff index, bukan menyimpulkan
force-remove sukses berarti file tadinya tracked. Hash seluruh salinan lokal
tetap diperiksa; cleanup normal tidak menghapus history atau file pengguna.

106. Preflight upgrade harus memegang lease lintas engine sampai proof selesai.
Melepas lease untuk menulis prepared marker memberi periodic worker kesempatan
migrasi dan menambah penghitung alert sebelum verifikasi foreground. Pada
Skybee, snapshot asli cocok 43 tabel; hanya alert_generation/evaluation berubah.
Pemulihan tidak mengecualikan seluruh tabel: verifikasi snapshot terhadap proof,
semua rowset/kolom lain dan monotonisitas dua penghitung, lalu catat scope
sebenarnya. Worker debug menunggu seed/proof lengkap sebelum membuka DB.

107. ADB stdin biner pada Windows dapat terpotong pada Ctrl-Z. Untuk ciphertext
snapshot tambahan di cache sendiri, gunakan encoding ASCII lalu decode dan
verifikasi SHA256 di perangkat; jangan menulis DB utama. Diagnosis VM read-only
memerlukan compiler attach, tanpa reload/restart; URI autentikasi debugger dan
log tetap privat. Bandingkan hash berkas bisnis/key sebelum dan sesudah diagnosis.

108. HyperOS dapat mengizinkan ADB dan read-only hierarchy tetapi menolak input
INJECT_EVENTS. Catat batasnya; jangan mengubah OS untuk membuat smoke lulus.
Own debug widget callbacks melalui DDS WebSocket dapat memeriksa navigasi,
namun bukan bukti sentuhan fisik. HTTP DDS hanya proxy ke VM dan dapat melewati
compiler ekspresi Flutter. Biometric unlock yang dilakukan pengguna ketika
smoke berjalan bukan bypass PIN: konfirmasi konteks pengguna, uji Kunci/redaksi
dan route PIN-only sementara tanpa menghapus binding. Pertahankan failure raw,
buat completion terpisah, detach debugger dan verifikasi kembali key/biometrik/
seed/package lain serta startup tanpa cache salinan audit.
