# Pengujian M5 — ledger aktif

**C22 compact layout checkpoint17Oktober:** nama ekspor sekarang di dialog aplikasi/PIN gate sebelum Android picker; source tidak mengubah sistem. Clipping dialog baru ditemukan di native dan diperbaiki (helper terpisah/action Lanjut). Retest bersih Windows19PASS54s/analyzerNoissues11s/Poco native10PASS1:00; JVM11PASS, 517key/244ID. Private sebelum update:2arsip SHA cocok katalog, fakta finansial/stok2sales/integrity/legacy/ordinary PASS. Berkas ekspor publik ditemukan/hash awal dicatat. DV10/build sedang berjalan; belum deploy ke Poco atau menganggap keyboard fisik lulus. C21+C22 digabung dalam update aman, manual dijeda. B-MAN05 ekspor PASS reported; restore/alerts/Drive/closing/M6 belum selesai/dimulai sesuai tahap. Detail M5_EXPORT_FILENAME_C22.md.

**B-MAN05 PASS manual17Oktober2026; C22 nama ekspor:** pengguna mengonfirmasi SAF Save/teks berkas ditulis dan diverifikasi kembali/dua kartu tetap; berkas diberi nama yang disarankan. Nama pada picker Android tertutup keyboard menurut laporan pengguna, harus menutup keyboard berulang untuk melihat input. Source memakai ACTION_CREATE_DOCUMENT milik Android; penyebab layout internal OEM belum ditrace. Implementasi app-side: dialog nama sebelum picker, keyboard-aware/PIN-gated, nama sebagai EXTRA_TITLE bukan path. Host awal1PASS untuk IME/PIN/payload; kasus before pertama terhalang pumpAndSettle/busy helper, bukan repro bug Android. Regresi host/JVM berjalan; belum deploy Poco. Manual dijeda untuk update terisolasi C21+C22 dan audit metadata/dua arsip. Tidak mereset/menghapus data; M6 tidak dimulai.

**C21 checkpoint17Oktober:** manual B-MAN03 status backup dan B-MAN04 cancel ekspor PASS reported. Klarifikasi expectation dialog berarti posisi pesan awal pada Poco tidak terbukti bermasalah; repro scroll otomatis tetap1FAIL→perbaikan source layout. Host16PASS44s/focused kasus sama1PASS4s/analyzerNoissues7s, nativeDV9PASS1:55; awake restored/readback. Build release hanya di komputer berjalan; belum deploy/control Poco. B-MAN05 menunggu ekspor berkas nyata ke Download/nama baru dan konfirmasi teks inline verifikasi, bukan dialog. Dua backup dipertahankan; SAF restore/alerts/Drive/closing belum selesai. Detail M5_BACKUP_FEEDBACK_C21.md; M6 tidak dimulai.

**Klarifikasi B-MAN03 + B-MAN04 PASS manual17Oktober2026:** pengguna mengonfirmasi cancel ekspor menghasilkan teks Dibatalkan (bukan sukses) dan dua kartu tetap. Pengguna menjelaskan semula mengira pesan backup berupa dialog; pesan inline mungkin sudah ada tetapi belum dibaca. Instruksi sebelumnya kurang tegas. Temuan manual tidak membuktikan pesan tidak muncul/proses backup gagal atau viewport awal offscreen. Catatan C21 direvisi: perbaikan visibilitas berdasarkan repro layout otomatis scroll, bukan diagnosis pasti kejadian manual. Host16PASS44s + focused1PASS4s (kasus sama), analyzer No issues7s; native DV berjalan, source belum deploy Poco. B-MAN05 kini diminta ekspor backup teratas ke Download dengan nama baru, cek teks status verifikasi ekspor; hasil pending. Tidak ada kontrol otomatis Poco, M5 berjalan/M6 tidak dimulai.

**B-MAN03 create/status PASS manual reported17Oktober2026; C21 feedback UI terbukti:** pengguna menemukan pesan Backup lokal tervalidasi tersedia setelah menggulir paling atas. Dua kartu backup tetap dipertahankan (klik kedua dilaporkan tidak sengaja); status UI/create reported bukan bukti ekspor/restore. C21: status/progress di header ListView terlepas dari viewport aksi, direproduksi1FAIL widget. Source layout diperbaiki dengan status/progress tetap terlihat di dalam PIN gate; regresi host berjalan, belum deploy Poco. B-MAN04 diminta: Ekspor salah satu kartu lalu Batal pemilih Android/PIN ulang bila perlu, expected Dibatalkan di atas/kedua kartu tetap; hasil pending. Tidak ada kontrol otomatis Poco; M5 berjalan/M6 tidak dimulai.

**B-MAN03 PARTIAL manual17Oktober2026:** pengguna melaporkan kartu backup berisi ID, waktu/schema8/IDR muncul; tombol Buat backup lokal tertekan kedua kali secara tidak sengaja sehingga total dua backup. Pesan sukses belum terlihat. Jangan simpulkan backup gagal atau data keuangan ganda dari dua kartu; dua aksi create terpisah dilaporkan, integritas/ekspor/restore manual belum dibuktikan. Source menaruh s.message di atas ListView; diminta gulir paling atas tanpa membuat backup lagi untuk memastikan pesan ada/offscreen atau memang tidak muncul. Kedua arsip dipertahankan. Tidak ada kontrol otomatis Poco; M5 berjalan/M6 tidak dimulai.

**B-MAN02 PASS manual reported17Oktober2026:** pengguna mengonfirmasi kode recovery existing dapat ditampilkan, salinan pribadi disimpan di luar Poco, lalu disembunyikan dan tidak terlihat lagi. Tidak menerima/menyimpan nilai kode atau screenshot. Ini bukti reveal/private-copy/hide reported, bukan hasil restore atau backup. B-MAN03 diminta: Buat backup lokal sekali, tunggu selesai; expected pesan Backup lokal tervalidasi tersedia dan kartu baru schema8/IDR/waktu. Hasil pending, belum ekspor/restore/Google. Tidak ada kontrol otomatis perangkat; M5 berjalan/M6 tidak dimulai.

**B-MAN01 PASS status manual17Oktober2026:** pengguna membaca Kode recovery backup sudah disiapkan. Kode existing dipertahankan; tidak merotasi/mengganti hanya karena database acceptance baru. Ini bukti status UI, belum bukti pengguna memegang kode/backup atau restore berhasil. B-MAN02 diminta: Tampilkan kode tersimpan, simpan pribadi di luar Poco, Sembunyikan kode pemulihan; laporkan hanya keberhasilan tanpa kode/screenshot rahasia. Hasil pending; belum buat arsip/Google. Tidak ada kontrol otomatis Poco, M5 berjalan/M6 tidak dimulai.

**P-MAN29 PASS manual reported17Oktober2026:** pengguna mengonfirmasi tidak ada permintaan PIN berulang pada dua percobaan paired setelah denial; izin Nearby dipulihkan Allow dan daftar Bluetooth kembali muncul. C20 berstatus fixed/automated+manual validated pada jalur Poco tersebut; P-MAN28 FAIL historis dipertahankan. Ini bukan klaim seluruh model/izin OEM lulus. Tidak ada cetak atau kontrol otomatis. Langkah B-MAN01 diminta: buka Backup & Google Drive, laporkan status recovery required/configured sebelum membuat atau merotasi kode; hasil pending. SAF/restore/notifikasi/Drive dan closing M5 masih tersisa; M6 tidak dimulai.

**P-MAN29 sebagian teramati, dicatat17Oktober2026:** pengguna menekan Perangkat berpasangan dua kali dan melaporkan tidak ada aksi selain pesan Izin Bluetooth belum diberikan; profil RPP02N tetap pada Printer tersimpan. Pesan denial sesuai expected, profil lokal tersimpan bukan hasil enumeration Bluetooth. Tidak menyimpulkan loop PIN sudah hilang dari kalimat tidak terjadi apa-apa; konfirmasi eksplisit no-repeat-PIN dan tahap4 regrant/list diminta. Full retest C20 masih PENDING, izin Allow perlu dipulihkan. Tidak ada kontrol otomatis Poco atau cetak; M5 berlanjut/M6 tidak dimulai.

**C20 update selesai17Oktober — retest manual belum:** loop PIN pada penolakan izin P-MAN28 tetap tercatat FAIL historis. Guard prompt native dan feedback printer telah diperbaiki tanpa melonggarkan PIN: Windows15PASS42s/JVM3+arsip6/Poco native8PASS51s/DV8PASS1:44/analyzer bersih. DV awake pulih/readback1/900000/0. Release ordinary+fixture/bridge build terverifikasi (min24,3ABI,16KiB,lisensi,sertifikat sama); hanya fixture C20 dipasang Poco. Audit post_printer sebelum/sesudah masing-masing1PASS3s, seluruh digest tabel sama: dua nomor struk berbeda, sale42000/HPP36000/payment22000/debt20000/stok18/value150000/jobs sesuai; legacy default hash baseline dan ordinary hash endpoint sama. Ini dua fase satu kasus audit, bukan dua fitur unik atau restore backup. Startup fixturePID28792/banner terlihat/0marker pada buffer yang diperiksa. P-MAN29 kini menunggu uji OEM denial→retry→regrant, tanpa cetak; kontrol otomatis Poco dihentikan. OriginalAPK6/cleanup logo/closing akhir/SAF/alerts/Drive tetap pending; M6 tidak dimulai. Rincian: M5_PERMISSION_FIX_C20.md.

**P-MAN27 PASS manual, dicatat17Oktober2026:** pengguna menjawab ya: Kasir terbuka normal saat Bluetooth mati tanpa menambah barang/penjualan; Bluetooth dipulihkan ON, RPP02N dihubungkan eksplisit dan status connected tanpa cetak otomatis. Pemulihan Bluetooth ON terkonfirmasi pengguna; bukti terbatas pada UI/jendela observasi tersebut, bukan checkout baru atau audit SQL. P-MAN28 diminta: pengguna menolak izin Perangkat di sekitar hanya pada kasir_app tests, mencoba Perangkat berpasangan dan melaporkan pesan/kelangsungan UI. Hasil belum ada; izin perlu dipulihkan sesudah uji. Tidak ada kontrol otomatis perangkat, M5 berjalan/M6 tidak dimulai.

**P-MAN26 PASS manual, dicatat17Oktober2026:** pengguna menjawab ya untuk Bluetooth Poco mati: Periksa koneksi menampilkan pesan Bluetooth mati dan pemuatan berhenti. Ini bukti UI pada jalur tersebut, bukan checkout atau seluruh error Bluetooth. P-MAN27 diminta: buka Kasir saat Bluetooth masih mati tanpa perubahan keranjang/penjualan, lalu pulihkan Bluetooth ON dan hubungkan RPP02N secara eksplisit; cek connected tanpa cetak otomatis. Hasil kasir/pemulihan ON/reconnect masih pending. Tidak ada kontrol otomatis perangkat; audit SQL/SAF/notifikasi/Drive dan penutupan tetap tersisa, M6 tidak dimulai.

**P-MAN25 PASS manual, dicatat17Oktober2026:** pengguna menjawab ya untuk pembatalan discovery: pencarian berhenti, indikator pemuatan hilang dan tombol Perangkat berpasangan dapat ditekan kembali. Tidak menyimpulkan fresh pairing, timeout scan atau semua izin Android lulus. Pengguna menegaskan ya berarti seluruh kondisi pertanyaan sesuai; detail berbeda akan dijelaskan. P-MAN26 diminta: Bluetooth Poco dimatikan oleh pengguna, pilih profil RPP02N lalu Periksa koneksi; expected pesan Bluetooth mati dan pemuatan berhenti. Hasil pending; tidak mencetak/tidak ada kontrol otomatis perangkat. Bluetooth perlu diaktifkan kembali sesudah skenario ini. M5 tetap berlangsung; M6 tidak dimulai.

**Lanjutan dicatat 17 Oktober 2026 — P-MAN23/24 PASS manual dilaporkan pengguna:** laporan sesudah pemulihan cetak menunjukkan penjualan 42.000, HPP 36.000, laba kotor 6.000, pembayaran 22.000, piutang 20.000, dua penjualan dan nol pembatalan; stok gabungan 18 (16 utama + 2 sekunder), kedaluwarsa 0, nilai persediaan 150.000. Tanggal/jam observasi tidak dikarang; ini pencatatan jawaban pengguna pada rangkaian sebelumnya, bukan audit SQL otomatis. Perbandingan dua nomor struk, audit akhir/preservasi, backup SAF/restore, notifikasi dan Drive nyata masih belum selesai. P-MAN25 diminta: Cari perangkat lalu Batal selagi scan; verifikasi pemuatan berakhir dan tombol Perangkat berpasangan dapat dipakai lagi, tanpa mencetak. Hasil pending. Tidak ada kontrol otomatis Poco; M6 tidak dimulai.

## P-MAN22 recovery copy PASS reported

User confirms explicit retail12000 SALINAN after printer-off failure/reconnect, matching screen and no HPP/Grosir. Same-screen number is not prior-vs-new unique-number comparison. P-MAN23/24 request post-recovery financial/inventory model42000/36000/6000/22000/20000/count2/cancel0/stock18/expired0/value150000. Await both user readings; SQL audit still separate. No automated device actions.

## P-MAN21 reconnect/no auto-print PASS reported

User confirms reconnect succeeds without automatic receipt. This is observed interval, not indefinite guarantee or automatic retry. P-MAN22 requests explicit recovery SALINAN of retail12000 sale from history; same number/qty1/paid12000/debt0/noGrosir/noHPP9000. No new sale or device automation; result pending. Distinct receipt-number comparison promised for history/SQL remains open.

## P-MAN20 powered-off print handled

User reports unchanged12000/12000/0 and exact Not sent message. **PASS expected negative test manual**, not failed application test or automatic SQL/log evidence. Partial-send unknown path remains separate. P-MAN21 requests power-on+explicit reconnect with observation windows/no automatic receipt, no print; pending. Distinct receipt number still unverified pending history/SQL, no device control.

## P-MAN19 granular result; P-MAN20 pending

Save while printer off and12000/12000/0 PASS user-reported. Distinct receipt number UNVERIFIED because user cannot recall old number; verify via history/SQL later, no invented comparison. “No printer error” clarified as unblocked save, not literal-label/log cleanliness claim. P-MAN20 asks powered-off print1x/wait~20s/exact status/still12000/12000/0, no retry or power-on. No device control.

## P-MAN18 printer-off setup PASS

User confirms powered-off Iware/new retail1×12000 cart. P-MAN19 requests Lunas/Save1x while printer remains off, verify new receipt12000/12000/0 without printer error. No print/power-on requested. Commit/aggregate/stock still expected pending report/audit, no device automation.

## P-MAN16/17 financial/inventory reports PASS

User separately confirms all financial report model values30000/27000/3000/10000/20000/count1/cancel0 and inventory19/expired0/value159000. UI manual reported; SQL final reconciliation remains pending. P-MAN18 asks power-off physical printer and prepare new retail1×12000 cart, no Pay yet. Future offline checkout/failure/reconnect scenario is planned, not passed. No automated device actions.

## P-MAN15 SALINAN physical PASS

User confirms single copy with SALINAN/same details/no HPP on paper. No SQL conservation inferred. P-MAN16 report financial model30000/27000/3000/10000/20000/count1/cancel0 and P-MAN17 inventory19/expired0/value159000 requested as separate questions. Combined stock includes17main+2secondary. Await reports; no device automation.

## P-MAN14 cancel copy PASS reported

User confirms cancel warning/no print/unchanged detail. SQL no-new-job/financial counts not assumed from UI. P-MAN15 requests one actual confirmed SALINAN from history, same receipt fields and no private HPP on paper; pending. No automation or new sale action.

## P-MAN13 all-time history PASS reported

User confirms one synthetic sale30000 and protected detailHPP27000/paid10000/debt20000. Distinguish UI report from SQL audit/stock proof. P-MAN14 requests cancel copy warning dialog, inspect no new paper/unchanged values. No actual SALINAN yet and no device automation.

## P-MAN12 first-print retry PASS reported

User confirms no second paper/unchanged screen totals after repeat once when completed. Label this completed-repeat test, not simultaneous accepted events. P-MAN13 asks all-time history one sale/customer and protected HPP27000/paid10000/debt20000; pending. SQL audit/stock/copy remain separate, no tool device actions.

## P-MAN11 physical receipt/font18 PASS

User confirms real sale receipt matching logo/number/customer/grosir quantities/prices/payment/debt and readable complete18dot text. **PASS manual reported** on Iware58. Font24/calibration/logo and32/calibration prior samples remain separate; not all models/geometries. P-MAN12 requests first-print repeated press after completed print, wait10s/no new paper/unchanged screen totals. Not simultaneous doubletap/SQL audit. No tool-based device control or new checkout.

## P-MAN10 saved receipt PASS reported

User confirms Sale saved and requested details after one Save. Scope is reported post-commit UI; SQL ledger1sale/stock17/HPP27000/payment10000/debt20000 remains expected pending actual audit, not automatically verified. P-MAN11 requests first physical sale receipt1x (not copy), matching number/logo/customer/grosir3×10000/30000/10000/20000 and18dot readable complete text. Do not Next sale/retry if uncertain; no automatic device control.

## P-MAN09 form PASS; single commit requested

User confirms partial-debt preview30000/10000/20000. This does not establish financial commit/customer creation/stock17. P-MAN10 requests Save sale once and verify post-commit receipt fields/customer/grosir, stop before print/Next sale. Await actual report, then physical18dot receipt and copy/finance invariants. No device control.

## P-MAN08 cart PASS; P-MAN09 preview pending

User confirms synthetic wholesale qty3/total30000. No checkout yet requested; old financial0 audit remains historical endpoint, not assumed current result from absence of user report. Font18 paper still pending. Next manual sets partial payment10000/customerUji M5 Printer/phoneblank and verifies total30000/remaining20000 before Save sale. No device automation or invented sale/customer/stocks changed.

## P-MAN07 font32 PASS dan persiapan struk

User confirms larger32dot text clear/complete, only font changed on same58mm profile. **PASS manual reported**, not automated paper analysis. P-MAN08 requests save18dot profile without print, add synthetic M5-000123 qty3/wholesale to cart, expected30000; no checkout requested yet. Future partial-debt receipt/copy tests not performed. Do not reuse calibration-only finance0/all-table equality audit as a closing expectation after intended manual financial transactions. No device control active.

## P-MAN06 physical logo PASS

User reports logo and text printed as expected on one calibration sheet, same58mm/default profile with logo enabled. **PASS manual reported**, not machine-inspected paper or all profiles. P-MAN07 requested only24→32dot font change and one print, all other parameters retained. Check complete digits/symbols, extra line wrapping permitted. Result pending; no device commands or code changes on this step.

## P-MAN05 logo import/preview PASS

User completed synthetic file selection/apply and subsequently reported “M5 hitam putih muncul”. **PASS manual reported SAF/apply/monochrome preview**. Initial Preview lookup difficulty resolved without patch; not a proven rendering crash/missing-feature bug. Actual PIN prompt/relock not explicitly reported. P-MAN06 requested one physical calibration with logo enabled and same default58mm profile; inspect logo and text. Paper result pending; no device control or extra print from tools.

## P-MAN04 manual UI PASS

User confirms saved RPP02N retained, row active and Connected near Connect on releasec8f08688…; **PASS manual reported** for C19/persistence across update, distinct from native before/after digests and settings7 tests. No reprint. P-MAN05 requested actual SAF import of owned synthetic Download/M5_logo_1792156485701.png→apply→preview, including PIN re-entry if locked. Result pending; no physical logo or font change verified yet, no device automation.

## C19 deployment dan audit before/after selesai

Build `release-artifacts-20261016-200823` ordinary/fixture/bridge verified; fixtureSHA256c8f086885212e49e25e155f178179ea5c9a9f3f3b6571b9796d049682bf3640d. Ordinary build-only. `poco-manual-update-before-1792156485701-20261016-201446` **1PASS2s**, `poco-manual-update-after-1792156485701-20261016-201639` **1PASS2s**, safe runner/flag/no-uninstall. Read-only existing DB guard; all table hashes identical before/after APK replacement, integrity/FK8, products2/selected printer1/submitted calibration>=1/financial sales0/payments0. OlddefaultDB+sidecars streamed hash match initial handover (main556c6a5c…103e, WAL/SHM absent/journal076a27…36560), never opened. Ordinary bytehash unchanged both wrappers. Audit does not seed/authenticate PIN/print/reset. Native test snapshots only digests privately, not raw keys/customer rows. Two executions of same case/roles, not new unique feature counts.

`poco-manual-update-1792156485701`: verified release restored after audit, startup PID13558/synthetic UI confirmed/0error markers in scoped buffer, am-start510ms single observation (not performance comparison). Originalv6APK unchanged in original handover, closing restore pending. Control handed back for P-MAN04 saved profile/selected state/near-button connection feedback; result pending. No device test/control active. A new owned Download PNG160B M5_logo_1792156485701.png copied/hashchecked, ledger public-logo-fixture.json; no other files overwritten, exact-file cleanup pending. Paper/basic glyphP-MAN03 passed by user recheck; no extra print during update.

## P-MAN03 detail PASS dan pembaruan UI

Pengguna mengonfirmasi ketiga item di kertas asli sesuai: UJI COBA, digit0 lengkap, -12,34 €. **PASS manual reported kalibrasi dasar Poco/Iware**; perbedaan terdahulu merupakan transkripsi, bukan bug glyph/renderer terbukti. Tidak ada cetak ulang. Skenario hardware lain tetap terpisah/pending.

`release-artifacts-20261016-200823` ordinary+fixture+debug bridge build/verifikasi PASS, ordinary tidak dipasang. Update Poco sedang berjalan setelah pesan jeda manual, memakai read-only existing-fixture audit melalui safe runner sebelum/sesudah APK replacement; expected DB harus sudah ada, tidak seed/PINauth/print/reset, legacy defaultDB hanya hash file. Audit membandingkan seluruh fingerprint tabel, integrity/FK, finance0 dan selected profile/submitted calibration. Hasil belum dinyatakan sampai run selesai. Raw analyzer audit1lint avoid_print dipertahankan; debugPrint diperbaiki dan retest No issues7,4s. Closing originalAPK6 tetap untuk akhir manual.

## P-MAN03 fisik pertama — hasil pengguna

Pengguna melaporkan Cetak UJI COBA berhasil pada Poco+Iware58, menyertakan transkripsi baris profil/margin/huruf/IDR/USD/minus (PRINTER_TEST_REPORT_M5). **PASS manual output fisik dasar**, bukan pengamatan otomatis atau semua karakter benar. Judul/angka0/koma/€ belum jelas dari transkripsi; pertanyaan pemeriksaan kertas yang sama masih pending, tidak meminta cetak ulang. Wrap tidak disamakan clipping, belum menyimpulkan renderer/human error. Tidak ada kontrol Poco. Build-only terbaru untuk C19 dimulai sesudah Windows14/nativeDV7PASS/analyzer No issues; belum deploy. APK987c534c… tetap untuk manual, closing audit/restore originalAPK pending.

## C19 native retest selesai

`printer-selection-feedback-20261016-200419`: **7PASS1:29** pada DV SQLCipher/fixture, paired selection/connection feedback dan UI regresi. Native Bluetooth tetap mock, tidak mengirim kertas. Awake restored/readback dan ordinary absent pada ledger wrapper. Windows14PASS/analyzer No issues63,8s/format2files0changed/audit511keys361refs244IDs. Patch belum release/deploy Poco; user masih memakai987c534c…. Tidak ada tes/kontrol perangkat aktif; menunggu inspeksi kertas P-MAN03 dari pengguna.

## Manual koneksi dan perbaikan C19 —16Oktober

Laporan pengguna “tidak terpilih/rantai tanpa aksi/Connect delay tanpa hasil” belum membuktikan transport gagal. Screenshot kemudian menunjukkan **Terhubung ke printer** dan alamat cocok RPP02N. P-MAN02 **PASS manual/screenshot untuk status aplikasi**, bukan bukti kirim/kertas/permission denial/discovery baru. Tidak mengarsipkan gambar berisi daftar perangkat pribadi lain atau menyalin identitasnya ke fixture. P-MAN03 diminta cetak UJI COBA1x/profil58default/inspeksi kertas, hasil pending.

`printer-selection-feedback-reproduction.log` **2FAIL** (row.selected tetapfalse sesudah tap; Connected tidak hitTestable dari posisi Connect). `printer-selection-feedback-retest.log` **14PASS35s**, settings7+queue7. Patch produksi hanya printer_settings_screen.dart; indikasi pilihan dan live status/error/outcome di dekat tombol, guard PIN/pending/timeout/denial/finance tetap. `printer-selection-feedback-analyze.log` No issues63,8s. Native DV wrapper sedang berjalan; patch belum dibuild/deploy Poco, manual tetap release987c534c…. Tidak ada kontrol otomatis Poco.

## Manual Poco/Iware16Oktober — hasil daftar perangkat

Pengguna menjawab **“RPP02N muncul”** setelah instruksi Perangkat berpasangan/Cari perangkat. **PASS manual dilaporkan pengguna** hanya untuk perangkat target terlihat; metode paired/discovery belum dibedakan, permission dialog/pairing/socket/kertas belum terbukti. Langkah koneksi berikutnya: pilih RPP02N, default58, Hubungkan, periksa status Terhubung ke printer. Hasil pending. Tidak ada tindakan ADB/input/test otomatis pada Poco selama rangkaian manual ini; data/state tetap untuk langkah berikutnya. Closing defaultDB audit/restore originalAPK belum dilakukan.

## Handover manual19:18WIB

`dv-release-smoke-20261016-191717`: **PASS startup release ARM32**, synthetic own UI teramati pada bounded probe kedua. Own PID log5000byte tidak memuat marker FATAL/Unhandled/Directionality/E-flutter pada pencarian yang dilakukan. Ini buffer/cakupan startup, bukan log semua proses/waktu. DefaultDB+sidecar hash sebelum/sesudah identik; original debug worker fixtureAPK dipulihkan install-r-d, awake1/900000/0 restored/readback. Tidak melakukan OAuth/Bluetooth/cetak di DV. C14 banner terbukti pulih pada checkpoint release terbaru.

`poco-manual-20261016-191759`: release fixture SHA987c534c…54ed3b dipasang install-r, fresh acceptance DB yang sebelumnya absent, ordinary bytehash+sidecar sama sebelum/sesudah install, original fixturev6 APK+hash dan defaultDB baseline disimpan. Startup ownPID20495, synthetic screen terlihat dan0marker error pada buffer startup diperiksa. am-start Cold TotalTime8040ms mencakup first start/seed/key/setup; bukan benchmark cold median atau perbandingan baseline. **Default sandbox hash sesudah release belum terverifikasi (run-as unavailable); penutupan melalui same-version debug bridge7→audit→exact original6 belum dilakukan.** Tidak mengklaim ordinary migration/deployment, reset/uninstall atau preservation interval yang belum diaudit.

Pengguna mengonfirmasi printer/kertas siap. Native tests dan kontrol otomatis Poco sudah selesai sebelum pertanyaan manual: Kelola/PIN0001/Pengaturan/Printer Bluetooth, Perangkat berpasangan atau Cari perangkat, laporkan RPP02N. **Hasil masih pending; tidak ada PASS kertas, permission fisik, pairing/SPP, SAF, notification delivery/tap, OAuth/Drive nyata.** Selama manual tidak mengendalikan Poco; dokumentasi host boleh dilanjutkan. APK/manual state tetap tersedia untuk sesi lanjutan.

## Checkpoint 16 Oktober, sesudah 19:00 WIB

Hasil tambahan19:10: `poco-printer-layout-reveal-final-20261016-190522` **6PASS/40s**, hash ordinary+sidecar unchanged/originalAPK restored; menutup C18 pada cakupan helper/UI native. `backup-logo-reversal-final-20261016-190813` **1PASS/58s**: source/target directory berbeda, logoPNG/receipt_assets terisi, logo_path direlokasi ke target, sale reversal+payment reversal terisi dan digest seluruh tabel yang diperiksa sama snapshot; stok11/debt11000/reconcile/safety/stale-intent tetap sesuai. Bukan tambahan kasus unik terhadap roundtrip1 sebelumnya. Awake restored/readback1/900000/0. Budget worker terbaru masih berjalan pada checkpoint ini.

Hasil tambahan19:13: `worker-1792152628551` **reader1PASS/1s**, setupPID17237 → workerPID17386 → readerPID berbeda, SQLCipher4.19.0/Keystore/notification initialization, arsip607197byte. Budget nyata lintas proses dibuka pada attempt2; reader mengklaim attempt3 lalu null/exhausted. Status WorkManager succeeded diperiksa. Dispatcher fixture memakai layanan nyata, bukan seluruh production Google task, OAuth/reboot/Doze/force-stop. Awake restored/readback. Latest release ordinary+fixture dan debug audit bridge sedang dibuild, tanpa deploy ordinary.

Build latest `release-artifacts-20261016-191327` **PASS**: ordinary release63,4MB dan isolated release terverifikasi package/label/minSdk24/3ABI/12native libraries/ELF LOAD+ZIP16KiB/license assets/signature. Isolated release SHA256 `987c534c975ac3e148be6c0da69fbc99d42907eae79f47423f874eccd554ed3b`, SHA1 certificate tetapD4:EE:1A:96:8D:DC:4D:11:30:72:C5:A5:C8:CC:1F:5F:B0:55:84:03. Development signing tetap, bukan signing final M6. Negative guard build tanpa integration flag **expected refusal sebelum install**, bukan build regression. Debug audit bridge v7 terverifikasi tiga ABI/13libs (termasuk debug validation library), dipertahankan untuk penutupan hash audit dan pemulihan originalv6 tanpa reset. Ordinary tidak dipasang. Smoke startup DV/Poco dan manual masih berjalan/belum dinyatakan PASS sampai ledger selesai.

Audit akhir sumber: formatter209files/0changed; localization511keys/361staticrefs/244originalIDs; PowerShell tools syntax PASS; PythonAST18PASS. Baseline hash304files:272unchanged/32changed/0missing/90new scoped; ini bukan Git diff pra-Realme. FullWindows226PASS/2SKIP mencakup revisi produksi terakhir; tambahan sesudahnya fixture/helper/Dartdoc/workflow, dengan focused UI6PASS/analyzer Noissues7,9s dan native focused evidence di atas. Warning Workmanager KGP menyebut kompatibilitas Flutter masa depan; build versi sekarang selesai, tidak mengganti dependency secara spekulatif.

- Windows `final-m5-windows.log`: **226 PASS, 2 SKIP benchmark opt-in**; analyzer final No issues. Analyzer sesudah tambahan fixture logo/reversal/worker juga No issues (7,9s). `printer-layout-reveal-retest.log`: **6 PASS** setelah helper lazy-list diperbaiki.
- Poco SQLCipher: run terputus sebelumnya 70 PASS, dilengkapi `poco-reports-after-disconnect-20261016-183711` **24 PASS** dan `poco-locale-after-disconnect-20261016-184240` **6 PASS**. Semua **88 kasus domain unik** telah lulus lintas run; ini bukan satu run penuh bersih dan jumlah retry tidak dijumlahkan.
- Poco `poco-cipher-backup-ui-final-20261016-184610`: encryption **3 PASS**, archive **1 PASS**, checkout idempotent **1 PASS**; settings UI **5 PASS/1 FAIL**. Diagnosis ulang `poco-printer-ui-diagnostic-20261016-185451` tetap 5/1: profil ada, PIN terbuka, list ada, tetapi target lazy belum mounted pada offset400/max570. Kegagalan terjadi pada helper pencarian elemen, bukan bukti profil hilang/bug finansial. Helper kini reveal deterministik lalu tetap mensyaratkan target hit-tested; native retest masih berjalan pada checkpoint ini. Tidak mengklaim swipe fisik.
- Poco management/lifecycle `poco-native-management-lifecycle-final-20261016-185741`: **1 PASS/41s**, setup PIN, barang/penerimaan/HPP dan background lock. Hash ordinary+sidecar identik; original APK fixture dipulihkan. Tidak reset/uninstall.
- **Lintas perangkat nyata DV→Poco:** source `cross-source-1792150309449-20261016-183149` **1 PASS**, target `poco-cross-device-target-1792150309449-20261016-183453` **1 PASS**. Arsip607195byte, SHA256 `2a375c059a5399164186d681f12658e2782d0bbe9bbd6876b396182562d3219d`; hash18tabel cocok, key instalasi berbeda, PIN relock, safety archive/rekonsiliasi/stock11/debt9000/grosir10000/pack40 diverifikasi. Fixture ini tidak berisi logo/reversal terisi; tes tambahan domain tersebut dipisahkan. Transfer hanya arsip terenkripsi dan digest fakta sintetis, bukan raw key.
- Retry otomatis tak terbatas ditemukan lewat tes: 5 pemanggilan melampaui batas3. Budget Keystore tahan restart ditambahkan; `retry-budget-reproduction.log` **1 FAIL** → `retry-budget-final.log` **16 PASS** (retry3+calendar2+Drive mock11). Native worker lintas PID untuk budget terbaru belum selesai; tidak membuktikan Google nyata.
- Pemilihan DB fixture manual kini compile-time guarded (`KASIR_FIXTURE_DATABASE` hanya dengan integration flag), dipakai sama oleh foreground/headless. `fixture-database-guard-retest.log` **3 PASS**; ordinary mengabaikan override. APK manual berikut memakai DB baru `m5_acceptance_1792150309449.db`, bukan membuka default DB sandbox lama.

Pengguna menyatakan printer Iware dan kertas siap. **Belum ada hasil cetak kertas, OAuth/API Google, SAF fisik atau notification tap terbaru.** APK manual terbaru belum diserahkan. Build lama disupersede, M6 tidak dimulai. Checkpoint lama di bawah tetap histori.

## Lanjutan18:33 WIB sesudah limit

Poco `poco-arm64-pin-cipher-retest-20261016-150635` menyelesaikan KDF4PASS, kemudian SQLCipher **70PASS sebelum ADB terputus**. Reporter menandai sisa kasus “did not complete”; ini bukan failure assertion keuangan yang terbukti maupun full88PASS. File cipher/backup setelahnya tidak dijalankan. APK fixture restore dan ordinary-after sempat gagal karena device missing. Sesudah reconnection, `resume-poco-isolation-20261016-183242` mengonfirmasi endpoint DB/sidecar byte hashes sama baseline dan install-r-d exact original fixture berhasil. Tidak ada reset/uninstall/ordinary migration. Koneksi ulang yang dilaporkan pengguna sempat belum tampak ADB; bukti aktual18:32 menampilkan7f0edea0.

Requirement gap koneksi eksplisit printer direproduksi1FAIL: UI belum memiliki Connect walau send transport bisa connect otomatis. Kini PrinterSettingsService/Provider/status native btStatus dan UI Connect/Check/Disconnect tersedia. `printer-connect-retest.log` **14PASS** (settings6+queue7+banner1), meliputi pending connect/doubletap/denial/Bluetoothoff/connectionfail/no btWrite/no finance rows. Native SPP/paper tetap UNVERIFIED sampai hardware. Analyzer/full Windows/rebuild/native UI terbaru sedang berjalan. `m5_cross_device_test` source DV nonce1792150309449 mulai dijalankan; target Poco belum diuji.

## Pembaruan setelah reboot Realme — 16 Oktober 2026

Checkpoint tambahan15:10 WIB: `restore-ui-native-retest-20261016-143726` **15 PASS/6file** (restore4, settingsUI5, cipherprobe1, encryption3, checkout1, backup1); DV awake restored/readback dan ordinary absent. Actual provider LibTomCrypt1.18.2/core4.19.0. `domain-migration-adapter-final-20261016-144749` **4 PASS**, `domain-snapshot-adapter-final-20261016-144914` **1 PASS**, menutup empat failure adapter terdahulu; bukan rerun penuh88 latest. `realme-portable-cipher-final-20261016-145027`: **3 PASS/52s encryption +1 PASS/63s archive**; manualDB+sidecars unchanged/originalAPK restored. Satu sampel memori saat archive: PSS229994KiB/RSS306888KiB/swapPSS254KiB, **bukan peak/leak/baseline comparison**. User kemudian mencabut Realme dan menyediakan Poco.

Windows final `final-windows.log`: **219 PASS/2 SKIP opt-in benchmark/1:39**; analyzer Noissues7,8s; format204files0changed; localization501keys/358refs/244IDs; vendor106unchanged. Inventory sumber baseline304:273unchanged/31changed/0missing/79new scoped pada checkpoint itu (bukan diff Git atau baseline pra-Realme).

Release `release-artifacts-20261016-145515`: ordinary+fixture build/identitas/signature/minSdk24/3ABI/12nativeELF/ZIP16KiB/lisensi PASS; **fixture release ini disupersede perbaikan banner sebelum diserahkan**. Smoke DV150358 membaca UI kosong terlalu awal; bounded retry150647 mereproduksi stack `Directionality.of → _BannerState.build` pada PID13913. Ini bug wrapper fixture, bukan bukti SQLCipher/driver/render hardware gagal. Widget `acceptance-banner-reproduction.log`1FAIL → `acceptance-banner-retest.log`1PASS setelah layoutDirection eksplisit. Ordinary main tidak memakai banner itu. Rebuild/release smoke terbaru masih pending pada checkpoint ini; awake kedua run restored.

Poco7f0edea0/24069PC21G/API36/ARM64 disediakan pengguna. `poco-arm64-pin-cipher-financial-20261016-150136`: KDF3PASS/1FAIL karena tes lama mengasumsikan DB khusus Realme ada. Tidak ada credentials di sana; bukan mismatch verifier/native. Adapter kini men-seed verifier Dart600k ke DB nonce terpisah, menutup dan membuka lewat backend native tanpa rewrite. Retest `poco-arm64-pin-cipher-retest-20261016-150635`: KDF **4 PASS/26s**, backend MbedTLS3.6.7/mainThreadfalse, old-verifier preserved/unlock1352873µs. Full SQLCipher88 dan file berikut sedang berjalan, jangan klaim lulus sebelum runner final. Ordinary hash baseline989aa556…e76e22+sidecar unchanged pada run pertama; run aktif wajib diverifikasi pada finally.

Fixture lintas perangkat `m5_cross_device_test.dart` disiapkan untuk DV→Poco: arsip terenkripsi+hash18tabel sintetis, key Keystore independen, PIN backup dan rekonsiliasi. Belum dijalankan; tidak mengklaim lintas perangkat dari tes cross-key sebelumnya.

| Run / lapisan | Hasil aktual | Batas bukti |
| --- | --- | --- |
| realme-after-reboot-cipher-domains-20261016-141530 | **88 PASS / 16:26** | Management/PIN, kasir, grosir/dus, laporan/koreksi/pagination, localization/uang pada SQLCipher ARM32. Bukan printer, real Drive atau interaksi manusia. |
| realme-stable-cipher-regression-20261016-134816 | **BLOCKED LOAD, 0 kasus** | Activity/Splash tersedia tetapi proses aplikasi belum berjalan; tidak ada assertion bisnis atau bukti crash aplikasi. Pengguna reboot, retest di atas lulus. Penyebab internal belum terbukti. |
| stable-cipher-financial-20261016-135418 | Backup **1 PASS**; migration setup **5 FAIL** | Backup native membuktikan WAL/barrier writer/safety/validasi staging/ruang kurang/stale intent. Fixture migrasi lupa created_at; diperbaiki tanpa mengubah aturan aplikasi. |
| migration-financial-retest-20261016-135739 | Migration **5 PASS**, domain **84 PASS / 4 FAIL** | 3 matcher mengharapkan exception driver lama, 1 salinan fixture memakai key sumber pada nama DB berbeda. Adapter baru mempertahankan seluruh assertion data; Realme88 PASS, DV focused retest masih diperlukan. File selanjutnya tidak dijalankan. |
| worker-1792132489423 | Reader **1 PASS** | Proses setup8680 keluar normal; worker8850 membuka key/SQLCipher/FLN, membuat arsip607197byte; WorkManager succeeded. Dispatcher fixture memakai layanan nyata. Bukan OAuth/Drive atau pembuktian reboot/Doze/force-stop. |
| performance-profile-1792135269138 | **Selesai**, hasil JSON privat dipulihkan utuh | Profil ARM32 DV, 1.000 produk/250 sale; parser logcat awal gagal karena pesan terpotong, bukan kegagalan pengukuran. Artefak result.json/result-recovery.txt dipertahankan. |
| portable-archive-junit-retest.log / .xml | **6 PASS** | ZIP berbahaya benar-benar dienkripsi Tink valid: traversal, duplikat, missing/unknown/directory, budget, wrong-code/tamper/truncate dan destination preservation; JVM host, bukan perangkat. |
| picker-disposal-reproduction / retest | **2 FAIL → 4 PASS** | Bug aplikasi: hasil picker tiba sesudah Provider disposed meninggalkan file temp. Cleanup hanya file privat hasil salinan, bukan file sumber pengguna. |
| logo-preview-monochrome-reproduction / retest | **1 FAIL → 12 PASS** | Bug aplikasi: preview logo berwarna sedangkan encoder monokrom. Decoder sekarang komposit putih dan threshold yang sama; 12 mencakup subset queue, bukan 12 temuan baru. |
| copy-ui-retest.log | **12 PASS** | Dialog copy/cancel dan SALINAN, queue serta cleanup picker. Timeout pumpAndSettle awal adalah harness menunggu indikator busy yang sengaja aktif; bounded route pumps mempertahankan assertion. |

**Realme preservation:** manual DB SHA-256 `26af480608a920edff2c798cd7cf12d3e92cf9977e542fe73fde79cfeda9d887` dan sidecar identik selama interval native tes. Original release fixture disalin sebelum instalasi; restore exact APK install-r-d sukses. Tidak membuka/migrasikan DB manual schema7. Pre-install release sandbox tidak dapat dihash melalui run-as: jangan memperluas klaim interval. Ordinary package tidak tersedia, bukan preservation DB ordinary.

### Pengukuran profile SQLCipher DV

Dataset sama diekspor/fingerprint cocok, 1 warm-up + 5 sampel, PIN KDF dikecualikan. SQLite diukur sebelum SQLCipher, urutan tidak diacak. Angka median mikrodetik:

| Operasi | SQLite biasa | SQLCipher |
| --- | ---: | ---: |
| Open termasuk startup integrity | 31.138 | 846.006 |
| Halaman katalog awal | 10.584 | 8.943 |
| Halaman katalog jauh | 8.775 | 9.145 |
| Pencarian | 50.843 | 58.935 |
| Ringkasan laporan | 34.073 | 34.700 |
| Checkout termasuk cart add/submit/next | 121.876 | 187.133 |

Snapshot portable cipher 10.558ms, arsip3.963.663byte; DB biasa4.096.000byte/cipher4.005.888byte. MaxRSS proses kumulatif236.793.856byte mencakup Flutter/seed/kedua backend, **bukan** perbandingan peak masing-masing. Bukan benchmark kapasitas10k/100k, Poco, Realme, render atau keyboard. APK profile ARM32 lengkap dengan ELF/ZIP16KiB diverifikasi.

Status pengujian akhir dicatat pada checkpoint berikutnya; semua ledger lama di bawah dipertahankan.

Belum laporan acceptance final. Bukti raw berada di evidence/m5-20261016; pengulangan bukan kasus unik baru. Histori163fungsiRealme+1benchmark/DV17subset tetap berada di laporan lama dan tidak dihitung sebagai rerunM5.

| Run | Hasil aktual | Batas |
| --- | --- | --- |
| foundation-windows |6PASS | Checkout1+promotion5; helpergetterawal salah diperbaiki, rawfaildisimpan |
| alerts-retest-windows |3PASS | Memperbaiki cancelnotification setelahrecovered; fake OSsink |
| print-generation-windows |8PASS | Print7+generation1; tidakpaper |
| m5-windows-combined |**30PASS/31s** | 7suite, includesDriveMock11/kalender2, bukan realGoogle/headlessAndroid |
| cipher-retest-20261016-051729 |3PASS/33s nativeDV | Freshencryptedfinance/PIN/reopen, sebagianbesarschema7kosong export, stream1,25MiB. Sourcecheckpointawal |
| backup-roundtrip-20261016-052258 |1PASS/48s nativeDV | Crosskey satusandbox, berisifinancialfacts; oldrestoreworkflow sebelumreviewgap diperbaiki |
| security-restore-retest |BUILDFAIL | O_DIRECTORY bukanpublicAndroidconstant; sebeluminstall |
| security-restore-retest2 |LOADFAIL,0businesscases | WebSocketclosed; layarAsleep, PIDexitUSERREQUESTED. Penyebabtepatbelumterbukti |
| security-restore-awake-retest |2FAIL/1PASS cipher suite | GuardbarumenolakString1; streamPASS. Filelanjutan tidakdijalankan |
| cipher-status-probe |1FAILreproduksi | Nilaiinitial/read/writtenString1, core4.19.0community; bukti kontrakdriver |
| cipher-contract-retest-20261016-061739 |AKTIF saat checkpoint | Guarddiperbaiki tepat; baca rawrunneruntukhasilakhir, jangan mengarang |

`current-analyze.log`: Noissues12,1s pada checkpoint; pemeriksaan final setelahsemuaperubahan tetapdiperlukan. Formatter/genl10n dijalankan bertahap. ARB baru harusdilengkapi metadata/audit sertaUIbuktinyata. Debugbuild terisolasi berhasil setelahAPIconstantfix; release/profile/ABI/16KiB/M5license audit/performance/fullM1–M4regression masihpending.

## Isolasi dan DV awake

Semuanative melalui test_android.ps1, flagisolasi dan--no-uninstall. Wrapper test_m5_dv.ps1 menyimpan3nilai asli dantry/finallyrestore/readback. FirmwareDV8947-KIX/modelADBAX810/IP192.168.0.102 diterima sesuai laporan lama. Usermengizinkan temporaryawake; KEYCODE_WAKEUP hanyauntuklayar. Ordinarypackageabsentawal/akhir runyangsudahfinal: bukan buktipreservationDBexisting. Tidak clear/uninstall/reset/mainDBuser/firmware/CCTV/applain.

Setiaprunpunya awake-original.json danawake-restored.log. Runaktifharusdiperiksahingga Restoredtrue; biladisconnect, restorationPENDING, bukanPASS. Nilaiasli1/900000/0 tersimpan. NoUIAutomatordumpketikatestWidgetsaktif. OwnPID4118redactedlog hanya membatasidiagnosisload, bukanjaminan crashfree selama seluruhcampaign.

## Acceptance yang belum boleh diasumsikan

NativeSQLCipher richmigration/WAL/sequence/fault/source-retention/diskfull/newerschema; latestrestorelease/concurrentwrites/rootalldatareset; headlessworker/plugin/key/taskrestart/Doze/reboot; physicalPocoARM64PIN/printer/realDrive; Realme regresi tersediabelakangan; actualSAF/OEM/TalkBack/release; hardware80mm; crossdevicebackup. Setiapbarisakan diperbarui sesudahtesaktual. M6/publication tidakdimulai.

B-MAN12 PASS manual dilaporkan pengguna17Oktober2026: actual restore pada kasir_app tests dikonfirmasi sekali; pesan Pemulihan selesai/Gunakan PIN dari backup muncul dan membuka Kelola meminta PIN lagi. Ini bukti hasil UI/PIN gate, bukan audit safety archive atau rekonsiliasi penuh. Berikut B-MAN13/14 unlock PIN fixture dan laporan setelah restore (42000sales/36000HPP/6000profit/22000paid/20000debt/2sales/0reversal; stock18/expired0/value150000). Safety/printer/Drive/alerts sanitation serta audit post_restore masih pending. Kontrol otomatis nonaktif; jangan memakai pre-restore all-table equality atau old2backup/selected-printer assertions. M5 belum selesai/M6 tidak dimulai.

B-MAN13/14 PASS manual dilaporkan pengguna17Oktober2026: backup PIN0001 berhasil membuka Kelola; laporan Bulan ini/Semua pelanggan setelah restore sesuai sales42000/HPP36000/profit6000/pay22000/debt20000/count2/cancel0, physicalstock18/expired0/inventoryValue150000. Bukti UI laporan/PIN, bukan audit full ledger/safety-file. Berikut B-MAN15 daftar local backup expected3 (2lama+calon safety baru) dan B-MAN16 Drive disconnected UI; jangan membuat backup baru atau menghubungkan Google. Native safety/digests/sanitization tetap pending. M5 belum selesai/M6 tidak dimulai; otomatis HP tetap nonaktif.

B-MAN15/16 PASS manual dilaporkan pengguna17Oktober2026: katalog setelah restore menampilkan3 kartu schema8/IDR dengan satu timestamp baru sekitar restore; bagian Google Drive hanya pilihan akun tanpa akun tujuan/upload/disconnect/automatic switch. Ini bukti UI katalog/disconnected controls, bukan dekripsi safety archive atau OAuth nyata/izin sistem. Berikut B-MAN17 saved printer reset dan B-MAN18 notifikasi Off/in-app low-stock warning; jangan menghubungkan/cetak/aktifkan notifikasi dulu. Native audit post_restore masih pending. Kontrol otomatis nonaktif; M5 belum selesai/M6 tidak dimulai.

B-MAN17/18 PASS manual dilaporkan pengguna17Oktober2026: Printer tersimpan kosong setelah restore; notifikasi persediaan Off/pengingat5hari dan in-app low-stock card2/min5 tetap berfungsi. Ini bukti UI reset/aplikasi tanpa notifikasi, bukan permission denial/OS delivery atau integritas safety. Manual dijeda untuk native post_restore audit (hard-scoped existing DB, no reseed/reset, PIN fixture adds one expected verification audit, current recovery stays entirely inside device process). Formatter/analyzer first helper static-reference error corrected; finalNoissues6,1s. Native audit active, no result yet. M5 unfinished/M6 not started.


**C24 selesai pada cakupan perbaikan17Oktober2026:** ikon release hilang direpro invalid_icon lalu initPASS Poco/DV; keep.xml dan gate APK mencegah pengulangan. Host10PASS15s, analyzerbersih, ordinary/fixture/bridge verified; ordinary tidak dipasang. Strict install before/after masing-masing1PASS3s: semua tabel+3arsip identik. Actual post_restore audit1PASS: integrity/FK/cipher/reconcile, 23business hashes/2receipts/keuangan-stok, autentikasi3arsip termasuk safety pre-swap/profil+fullqueue, logo dan reset device defaults/Drive PASS; setup error null setelah startup produksi tanpa SQL repair/reset/restore ulang. Ordinary/default/public2exports unchanged pada checkpoint. DV priorAPK dan awake1/900000/0 restored/readback. B17/18 tetap PASS reportedmanual. Kontrol otomatis Poco berhenti; N-MAN01 deny notification berikutnya. Sisa3kelompok: notifikasi, real Drive, closing. M5 belum selesai/M6 tidak dimulai. Detail [C24](M5_NOTIFICATION_RELEASE_C24.md).**

**N-MAN01 PASS manual dilaporkan pengguna17Oktober2026:** pengguna menjawab ya untuk switch notifikasi On/Simpan sekali→dialog izin Android ditolak→pesan inline Izin belum diberikan. Peringatan di dalam aplikasi tetap tersedia., pemuatan berhenti dan low-stock card2/min5 tetap. PIN dimasukkan bila diminta; tidak mengklaim PIN benar-benar diminta dari instruksi kondisional. Ini bukti manual denial/feedback/in-app warning, bukan otomatis/OS delivery/tap/DB audit baru. Kontrol otomatis tetap nonaktif. Berikut N-MAN02: izinkan notifikasi paket uji melalui Settings Android, kembali/PIN dan Simpan, periksa status serta notifikasi generik tanpa mengetuknya. M5 belum selesai/M6 tidak dimulai.

**N-MAN02 belum selesai17Oktober2026:** pengguna melaporkan Simpan sekali memunculkan dialog izin Android dan halaman ditutup UI PIN; keputusan izin/hasil status/notifikasi belum dilaporkan. Tidak menyimpulkan grant Settings sebelumnya berhasil, bug aplikasi, atau PASS delivery. Instruksi diperjelas: pilih Izinkan pada dialog notifikasi aktif, masuk PIN0001 bila diminta, jangan Simpan ulang, lalu periksa teks status dan notifikasi generik. Kontrol otomatis perangkat tetap nonaktif; N-MAN01 PASS reported tetap.

**N-MAN02 PASS manual dilaporkan pengguna17Oktober2026:** setelah instruksi diperjelas, pengguna memilih Izinkan pada dialog notifikasi aktif, masuk PIN bila diminta dan tidak Simpan ulang; menjawab ya untuk status Pengaturan disimpan/pemuatan selesai dan satu notifikasi Pengingat persediaan dengan isi Buka peringatan persediaan melalui PIN., tanpa nama barang/pelanggan/nominal hutang. Ini delivery/content single-event pada Poco berdasarkan laporan pengguna; bukan bukti grant melalui Settings sebelumnya, dedup lintas restart, lockscreen atau notification-tap PIN. Catatan dialog/PIN sebelumnya dipertahankan. Berikut N-MAN03 Home→tap notifikasi→gate sebelum rincian, belum memasukkan PIN. Kontrol otomatis tetap nonaktif; M5 belum selesai/M6 tidak dimulai.

**N-MAN03 PASS manual dilaporkan pengguna17Oktober2026:** Home lalu tap notifikasi Pengingat persediaan sekali membuka gate pengelolaan/PIN sebelum rincian barang terlihat; pengguna belum memasukkan PIN sesuai instruksi. Bukti warm/background notification tap menuju gate, bukan cold-start notification launch, unlock/isi halaman atau seluruh lockscreen. Berikut N-MAN04: PIN0001 lalu periksa halaman peringatan, pengaturan5hari/On, card2/min5 dan pesan/status aktual. Kontrol otomatis tetap nonaktif; M5 belum selesai/M6 tidak dimulai.

**N-MAN04 PASS manual dilaporkan pengguna17Oktober2026:** PIN0001 setelah warm notification tap membuka halaman Peringatan persediaan; pengingat5hari/notifikasiOn/cardstok2/min5 sesuai dan tidak ada pesan gagal. Bukti unlock/isi halaman setelah gate, bukan cold launch/lockscreen atau dedup. Tidak ada Save/transaksi/perubahan pengaturan baru. Berikut N-MAN05: Muat awal dua kali bergantian tanpa perubahan kondisi, lalu cek notifikasi tidak muncul kembali. Kontrol otomatis tetap nonaktif; M5 belum selesai/M6 tidak dimulai.

**N-MAN05 PASS manual dilaporkan pengguna17Oktober2026:** Muat awal dua kali bergantian/tunggu sekitar10detik tanpa perubahan kondisi tidak memunculkan kembali notifikasi yang sudah diketuk. Bukti no-repost pada interval/skenario fisik Poco ini; bukan seluruh restart/Doze/reboot, threshold rearm atau notifikasi kedaluwarsa. Berikut N-MAN06 Off/Simpan lalu On/Simpan, periksa warning tetap dan satu notifikasi baru; jangan tap/hapus. Kontrol otomatis nonaktif; M5 belum selesai/M6 tidak dimulai.

**N-MAN06 PASS manual dilaporkan pengguna17Oktober2026:** Off/Simpan selesai dengan pesan disimpan dan warningstok2/min5 tetap; On/Simpan kembali selesai dan satu notifikasi generik baru terlihat, pengingat5hari. Izin/PIN hanya kondisional bila diminta, tidak menyimpulkan dialog baru benar-benar muncul. Bukti toggle opt-in/delivery, bukan physical threshold recovery/rearm atau cancel pending notification (sebelum Off tidak ada notifikasi). Berikut N-MAN07 periksa notifikasi pada layar terkunci tanpa mengubah pengaturan sistem; lalu cancel melalui switch Off dengan notif masih pending. Kontrol otomatis nonaktif; M5 belum selesai/M6 tidak dimulai.

**N-MAN07 OBSERVASI manual17Oktober2026:** pengguna memilih Notifikasi tidak terlihat pada layar terkunci. Tampilan/isi lockscreen aplikasi tetap UNVERIFIED (tidak ada konten untuk diperiksa), bukan PASS privacy/FAIL aplikasi atau bukti penyebab pengaturan OEM. Tidak mengubah kebijakan layar kunci. Delivery/shade N-MAN02/06 dan warm PIN N-MAN03/04 tetap PASS pada scope sebelumnya. Berikut N-MAN08: pastikan notifikasi masih ada di panel setelah unlock, lalu Off/Simpan membatalkannya tanpa menghilangkan warning2/min5. Jika baseline notifikasi sudah tidak ada, stop dan laporkan tanpa menganggap cancel lulus. Kontrol otomatis nonaktif; M5 belum selesai/M6 tidak dimulai.

**N-MAN08 PASS manual dilaporkan pengguna17Oktober2026:** baseline notifikasi masih ada pada panel setelah unlock; Off/Simpan menampilkan disimpan, warningstok2/min5 tetap dan notifikasi hilang setelah sekitar10detik tanpa dihapus manual. Tambahan pengguna: izin notifikasi layar kunci kasir_app tests aktif. Ini keterangan izin, bukan bukti konten lockscreen terlihat; N-MAN07 tetap UNVERIFIED/cause unknown. Notifikasi aplikasi kini Off berdasarkan alur manual. N-MAN01–06/08 PASS hanya scope dilaporkan; cold/reboot/Doze/expiry/threshold-rearm fisik tidak diasumsikan. Berikut D-MAN01 buka lalu batalkan pemilih akun Google, laporkan status aktual tanpa identitas akun. Kontrol otomatis nonaktif; M5 belum selesai/M6 tidak dimulai.

**D-MAN01 PARTIAL/temuan C25 manual17Oktober2026:** pemilih akun Google terbuka dan pengguna membatalkannya. Status kembali berupa Operasi belum berhasil. Periksa izin, koneksi, atau masuk kembali melalui PIN, sehingga feedback pembatalan gagal. Pengguna membaca3baris jadwal belum terjadwal; ini tidak membuktikan kontrol akun tersembunyi atau koneksi OAuth. Identitas/izin/upload/API belum dipilih/dibuktikan. Manual dijeda; reproduksi SDK-canceled dan kandidat akun lama sedang diuji pada host, belum perubahan/deploy aplikasi. Kontrol perangkat otomatis nonaktif sampai antrean scoped berikut; M5 belum selesai/M6 tidak dimulai.


**C25 siap retest manual17Oktober2026:** cancel Google sekarang dipetakan khusus canceled→Dibatalkan, kandidat sementara diinvalidasi sebelum retry; tujuan/consent tersimpan tetap. Host43PASS97s (focused5 subset), analyzerNoissues6,6s; Poco18PASS; DV 18PASS; exact prior APK/default sandbox hashes and awake restored. Ordinary/fixture/bridge universal/ikon/min24/16KiB/licenses/signature/negativeguard verified; ordinary tidak dipasang. Strict before/after masing-masing1PASS: seluruh tabel+3archiveSHA sama, fakta2sale/stok/HPP/legacy/ordinary/public2exports dan localDrivePolicy disconnected/off/no identity PASS pada checkpoint. C25 installed hash cocok dan startup own cashier/0marker PASS. Kontrol otomatis dihentikan. D-MAN01 feedbackFAIL historis tetap; D-MAN01R actual Google cancel belum. Tidak memilih akun/upload/reset/restore ulang. OriginalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Detail [C25](M5_GOOGLE_CANCEL_C25.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-google-cancel-update-1792226124001\update.json


**D-MAN01R PASS manual dilaporkan pengguna, 17 Oktober 2026:** pemilih Google nyata dibatalkan pada APK C25; teks halaman kini Dibatalkan. dan tombol Pilih atau ganti akun Google tetap tersedia di bawah tiga baris jadwal. Feedback C25 terkonfirmasi pada Poco; D-MAN01 gagal sebelumnya tetap riwayat. Belum memilih akun/membuktikan consent, tujuan tersimpan, API atau upload; dialog PIN kondisional tidak diasumsikan terjadi. Berikut D-MAN02: pilih akun uji hingga pratinjau Pilihan akun belum disimpan/Gunakan akun ini, tanpa konfirmasi tujuan atau unggah. Kontrol otomatis nonaktif; original APK v6/closing pending. M5 belum selesai, M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man01r-user-report.json).**


**D-MAN02 PASS manual dilaporkan pengguna, 17 Oktober 2026:** pemilihan akun Google nyata kembali dengan status Pilihan akun siap, akun yang benar diperiksa secara pribadi, Pilihan akun belum disimpan dan tombol Gunakan akun ini. Belum konfirmasi tujuan tersimpan atau membuktikan Drive identify/API/upload; kemunculan dialog consent/PIN kondisional tidak diasumsikan. Berikut D-MAN03: Gunakan akun ini sekali lalu periksa status tersimpan, akun tujuan yang benar dan Backup Drive otomatis masih Off, tanpa unggah. Kontrol otomatis nonaktif; original APK v6/closing pending; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man02-user-report.json).**


**D-MAN03 FAIL manual dilaporkan pengguna, 17 Oktober 2026:** konfirmasi Gunakan akun ini pada dua akun uji menghasilkan Operasi Drive belum selesai. Periksa jaringan, otorisasi, dan konfigurasi akun. Pengguna menyatakan kedua akun terdaftar pada audience; identitas tidak disalin. Penyebab belum ditentukan; tujuan tersimpan/API/upload tidak diklaim berhasil. Manual retry dijeda; inspeksi klasifikasi error dan konfirmasi Google Drive API Enabled berjalan. D-MAN01R/02 tetap PASS pada cakupan sebelumnya. Kontrol otomatis perangkat nonaktif; M5 belum selesai/M6 tidak dimulai. Bukti: [laporan pengguna](evidence/m5-20261017/d-man03-user-report.json).**


**D-CONFIG01 konfigurasi belum siap, 17 Oktober 2026:** pengguna memeriksa dan melaporkan Google Drive API belum Enabled pada project aplikasi. Diarahkan memilih Google Drive API oleh Google pada skybee-cf8b9 lalu Enable. Aktivasi/hasil retry belum dilaporkan; exact HTTP/reason D-MAN03 tidak ditangkap sehingga belum menyimpulkan satu-satunya penyebab. C26 memperjelas feedback terstruktur API-disabled vs forbidden tanpa membocorkan respons mentah; tes host berjalan, belum native/build/deploy. APK Poco tetap C25. Berikut D-MAN03R setelah API aktif; otomatis perangkat tetap Off, jangan upload/auto dulu. M5 belum selesai/M6 tidak dimulai.**
