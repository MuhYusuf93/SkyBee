# Hasil manual Realme C11 — 16 Oktober 2026

Pengujian tambahan M1–M4/M3.1 pada Realme RMX3231, serial
`0062112V2210F9B3`, Android11/API30/ARM32. Hasil fisik berikut **dilaporkan
pengguna**, bukan rekaman sentuhan atau observasi langsung agen. Pengguna
menetapkan jawaban “ya” mengonfirmasi semua expected pada instruksi aktif;
klarifikasi sesudahnya mengoreksi cakupan bukti tersebut. Riwayat lengkap:
[manual-findings.md](evidence/realme-c11-manual-20261016/manual-findings.md).

APK selama manual: `com.example.kasir_app.integration`, label kasir_app tests,
release development signing, SHA256
`969bccdda9605a2e82d137957316f1dbb848075f314532eb479befca21f709f7`.
Database sintetis dipertahankan: `realme_restart_20261015.db`. Aplikasi biasa
tidak terpasang pada preflight; tidak ada DB pengguna untuk diklaim preservation
atau restore. Bahasa Indonesia, Gboard; roundtrip Inggris dicoba pada form aktif.

## Hasil fisik yang dilaporkan

| Skenario | Expected dan actual pengguna | Status / batas bukti |
| --- | --- | --- |
| Barcode/Enter | Hanya000123 menemukan produk; tiga Enter menghasilkan satu barisqty1→2→3 | PASS reportedmanual. Initial tidak ditemukan; ownUI mengamati prefiks `barcode `, lalu retest angka saja sesuai. Payload setiap percobaan awal tidak direkam |
| Harga grosir/eceran | Qty3 total30000 lalu36000 | PASS reportedmanual untuk total; qty sesudah toggle tidak disebut ulang eksplisit |
| Quantity/hapus/undo | Plus4/48000, minus3/36000, hapus+Urungkan memulihkan3/36000 | PASS reportedmanual pada rangkaian ini |
| Input uang/Gboard |10000→10.000; Backspace tengah→1.000; seleksi digit→2.000; Salin/hapus/Tempel12.000; ketik cepat10000/Done menutup IME tanpa submit | PASS reportedmanual. Paste berasal field terformat sendiri; bukan plaintext/desimal/currencylain atau timingbenchmark |
| Bahasa pada form aktif | ID→EN→ID mempertahankan partialform/12000/total36000/debt24000 dan grouping sesuai | PASS reportedmanual; bukan seluruh localization/restart/currencychange |
| PIN fisik |0001/showon0001/offmasked/unlock Kelola | PASS reportedmanual. WrongPIN/lockout/rotasi tetap bukti otomatis sebelumnya, bukan manualbaru |
| Gudang dus/scroll/IME |5dus×40=200pcs/harga per dus120000→120.000, form dapat digulir | PASS reportedmanual preview saja, tidak menyimpan penerimaan. Harga awal12.000 dikoreksi pengguna yang kurang satu nol. Default40 dari konfigurasi diterima; usulan selalu kosong ditarik dan rollback, tidak pernah dipasang |
| Checkout sebagian | Qty3/36000/paid10000/debt26000 untuk pelanggan sintetis baru; satu struk, Nextbasket kosong, stok17→14 | PASS reportedmanual untuk output. Nama aktual DB `uji realme 16`, instruksi menyebut kapitalisasi `Uji Realme 16` |
| Dua ketukan Simpan fisik | Pengguna mencoba dua ketukan cepat, tetapi layar sudah berganti sesudah pertama | **BELUM TERVERIFIKASI** kedua tap mengenai tombol/handler. Jangan menyamakan satu struk dengan bukti dua submit diterima |
| Piutang bertahap | Preview10000/konfirmasi→saldo16000; preview16000/konfirmasi→0; nominal kosong, pelanggan baru hilang dari daftar aktif; pelanggan lama tetap26000 | PASS reportedmanual. Dua pelanggan awal berasal fixturelama+checkoutbaru. “HP belum dicatat” berarti nomor telepon opsional kosong |
| Laporan Bulan ini/Semua pelanggan | Penjualan72000/HPP54000/laba18000/pembayaran46000/checkout20000/pelunasan26000/piutang26000/persediaan126000/stok14/kedaluwarsa0/sales2/pembatalan0 | PASS reportedmanual sesuai model. Tidak ada snapshot laporan langsung sebelum pelunasan; audit DB dipisahkan |
| Riwayat lunas | Transaksi pelanggan baru tetap tersedia qty3/36000/debt0 | PASS reportedmanual. Kode MV8YAQO0-7541C750 diklarifikasi pengguna sebagai nomor penjualan di detail pelanggan lama, bukan pelanggan tambahan; daftar aktif hanya1 |
| Home dan kunci layar fisik | Kelola terbuka→Home/kembali terkunci; PIN membuka lagi. Tombol daya/lock/unlock→Kelola terkunci. Kasir tanpaPIN/draft1pcs12000 utuh setelah kedua rangkaian | PASS reportedmanual. Query Cari barang kosong tidak menghilangkan draft. Bukan reboot/force-stop/powerloss |
| TalkBack kasir/form/error/dialog | Fokus labelCariBarang/produk/plusminus/total/Bayar dapat dijangkau/dibaca. Partial0 ditolak, pesan dapat difokuskan/dibaca, formtetap/tanpastruk. Preview pelunasan1000 pelanggan lama terbaca, Batal menutup/saldo tetap26000 | PASS reportedmanual subset yang dicoba. Tidak mengklaim pengumuman error otomatis atau seluruh accessibilityacceptance |
| Pemulihan TalkBack | Pengguna menonaktifkan TalkBack dan kembali kasir/draft1pcs12000 | PASS reportedmanual; probe otomatis juga TalkBackfalse/font1,0/APKhashcocok. Fontperangkat tidak diubah pada sesi ini; font2× bukti sintetis sebelumnya |

## Pemeriksaan otomatis penutup

**Selesai pada pemeriksaan yang tersedia, dengan batas bukti di bawah.** Bukti
disimpan di [final/](evidence/realme-c11-manual-20261016/final/), dirangkum dalam
[verification.json](evidence/realme-c11-manual-20261016/final/verification.json).

| Pemeriksaan | Actual / status | Bukti |
| --- | --- | --- |
| Format/analyzer | Helper Dart terformat. Analyzer awal1lint helper diperbaiki; retest Noissues3,0s dan sesudah koreksi nama5,7s/exit0 | analyze.log (rawFAIL), analyze-retest.log, analyze-after-fixture-name.log |
| Windows concurrent checkout |1PASS/exit0: dua request sama menghasilkan saleID sama, hanya satu sale/payment; perubahan payload ditolak | windows-checkout-idempotency.log |
| Native concurrent checkout Realme | Kasus yang sama1PASS/00:05/exit0 di database nonce terpisah | native-checkout-idempotency.log |
| Native UI Realme | Run pertamaIDR PASS/USD FAIL pada finalisasi SemanticsHandle; cleanretest tanpa UIAutomator2PASS/01:06/exit0. Synthetic Flutter taps, bukan ketukan fisik | native-cashier-ui.log (rawFAIL), native-cashier-ui-clean-retest.log, native-clean-retest-ledger.json |
| Audit fixture manual | Strictaudit1kasus PASS pada3pengulangan sukses (00:04/00:05/00:05); gagal lookup kapitalisasi sebelumnya tetap disimpan. Tidak menjumlah pengulangan sebagai kasus baru | native-exact-ledger.log (rawFAIL), native-exact-ledger-retest.log, native-exact-ledger-after-regression.log, native-exact-ledger-final.log |
| Rekonsiliasi/ledger | Schema7/FKclean/quick_checkOK/reconciled; tepat2sale/4payment/4allocation/2customer; olddebt26000/newdebt0; currentdraftactive1pcs12000 | REALME_POST_MANUAL_AUDIT pada log final dan verification.json |
| Isolasi selama audit/regresi | Hash kanonik15tabel fakta keuangan/pelanggan/draft sama sebelum/sesudah audit dan sesudah regresi:5c4ffc6ac71e808539f66ffcf7ed716ae2054d47978ebaf3035b79465424bed4 | Tiga metadata audit identik. Bukan hash seluruhDB; autentikasi dapat menambah auditlog. Tidak ada backup/restore DB diklaim |
| Sumber/dependency |221fingerprint kode aplikasi/skema/Android/pubspec/SPEC sama dengan baselineakhir15Oktober;367ARBkeys/287refs/244requirementIDs;106vendorfiles/lisensi identik; PythonAST3PASS | source-check.json, verification.json, localization-audit.log, vendor-audit.log |
| APK release/draft smoke | APKimmutable di atas diverifikasi AAPT/ABI ARM32/JNI/ELF16KiB/lisensi, dipasang dengan install-r tanpa uninstall/reset. Hash terpasang sama sebelum/sesudah; kasir membuka draft1pcs12000. Singlecoldlaunch TotalTime5714ms, bukan benchmark | release-apk-verification.json, restore-release.json/logs, ui-release-restored.json |
| Pengaturan/ordinarypackage | TalkBackfalse/font1,0 sebelum/sesudah; ordinarypackage absent sebelum/sesudah. Tidak ada ordinaryDBhash/preservation/restore untuk diklaim | runtime-before.json, runtime-release-restored.json |
| Log scoped |2snapshot ownPID berisi2dan23baris,0fatalmarkers pada pola yang diperiksa; exit-info16record sebelum dan16sesudah semuanya reason10 USER REQUESTED. Retention/buffer terbatas, bukan seluruh sesi bebas error | runtime-*.pid.log/json; kegagalan assertion raw tetap dipertahankan; VMauthredaction0file |

Angka DB akhir: penjualan72000/HPP54000/laba18000/pembayaran46000 (checkout20000+
pelunasan26000)/piutang26000/stok14/nilai126000/kedaluwarsa0/sale2/pembatalan0.
Sesuai laporan manual, dengan draft1pcs12000 tetap belum checkout. Tidak ada
penjualan tambahan akibat inputnol yang ditolak atau preview1000 yang dibatalkan.
Seluruh native run memakai tools/test_android.ps1/serial eksplisit/flagisolasi/
APKidentitygate/--no-uninstall. Cleanup hanya database nonce pemilik suite;
fixture manual dan APK release dipertahankan. Paket/data/aplikasi lain tidak diubah.

Penutup ini memuat4kasus native berbeda (SQL1/UI2/audit1) dan1kasus Windows;
sebagian mengulang baseline yang sudah lulus. **163fungsi unik baseline15Oktober
tidak dijalankan ulang seluruhnya**, dan pengulangan/hasil manual tidak ditambahkan
ke angka tersebut. Pada discovery penutup hanya Realme terhubung; tidak mengklaim
regresi Poco/DV/emulator baru.

## Temuan dan koreksi workflow penutup

| Temuan | Gejala / penyebab dan dampak | File / bukti sebelum–sesudah | Status |
| --- | --- | --- | --- |
| RF-01 kapitalisasi fixture | Audit awal `No element` pada lookup nama. Diagnosis read-only menemukan `uji realme 16`; nama ini valid dan dipertahankan. Helper mengasumsikan kapitalisasi instruksi, bukan aturan bisnis aplikasi | `integration_test/realme_post_manual_audit_test.dart`: expected nama dikoreksi; `final/native-exact-ledger.log` FAIL → `native-exact-ledger-retest.log` PASS. `fixture-name-diagnosis.json` menyimpan metadata sintetis, tanpa salinan DB | CLOSED TEST/FIXTURE; tidak ada perubahan data/validasi aplikasi |
| RF-02 semantics saat nativeUI | Run awalIDR PASS, USD gagal pemeriksaan akhir `A SemanticsHandle was active`. UIAutomator dump bertumpang akhirUSD (logprobe dibuat03:44:22–29, runnerUSD selesai03:44:27). Flutter3.44.7 membuat handle untuk request semantics platform; tidak ada `ensureSemantics`/SemanticsHandle pada kode aplikasi | `native-cashier-ui.log` exit1 dipertahankan; `native-cashier-ui-clean-retest.log`2PASS/01:06/exit0 tanpa probe selama test. Assertion/source aplikasi tidak diubah. `tools/realme_device_probe.py` ditambah catatan workflow dan LESSONS diperbarui | Regresi fungsional retest PASS; **UNVERIFIED_CAUSE** untuk mekanisme tepat kenaikan handle, dugaan TEST/ENVIRONMENT. Bukan SKIPPED_SYSTEM atau app leak terbukti |
| RF-03 bukti dua tap fisik | Pengguna mencoba dua tap, layar berpindah sesudah pertama. Tidak ada bukti tap kedua mengenai tombol; tidak boleh menyimpulkan pencegahan double-submit dari satu struk | Klarifikasi pengguna dipertahankan; tes concurrentSQL Windows/Realme dan syntheticUI dipisahkan dari manual. Tidak memperlambat produksi atau menjual ulang fixture manual | Physical double-submit BELUM TERVERIFIKASI; bukti otomatis dilaporkan terpisah |
| RF-04 nomor penjualan disangka pelanggan | Pengguna memastikan kode MV8YAQO0-7541C750 berada dalam detail Synthetic Realme C11 customer; daftar utama hanya1pelanggan aktif | `receivables_screen.dart` menampilkan receipt.number/sisa per transaksi; SaleReceipt.number memakai formatwaktu/ID. Tidak ada patch atau penghapusan pelanggan | CLOSED klarifikasi; bukan bug/duplikasi data terbukti |

## Batas dan kelanjutan

Belum ada bug aplikasi baru yang terbukti dari rangkaian manual ini. Klarifikasi
input barcode/harga/defaultdus/nomorpenjualan dan kapitalisasi helper bukan
alasan mengubah aturan bisnis. Kode aplikasi/schema tidak diubah dalam finalisasi
manual; tambahan hanya audit/helper/dokumentasi.

Doubletap fisik tetap belum terverifikasi meskipun tes idempotensi otomatis
lulus. Airplane/radiooffline fisik, fontperangkat besar, reboot/powerloss, peakRAM/
longduration/leak proof, seluruh releaseflow/production signing/Play, runtime
ARM64 terbaru serta printer/Drive/backuprestore M5 dan acceptance M6 tidak boleh
diklaim lulus. Riwayat benchmark/debug/profile/release dan regresi DV/Poco/emulator
sebelumnya tetap berlaku hanya pada cakupan yang tercatat di laporan utama.

Pengujian yang tersedia dan finalisasi laporan selesai untuk review, dengan
physicaldouble-submit dan penyebab internal failure semantics awal tetap belum
terverifikasi. Ini bukan seluruh tugas/acceptance aplikasi PASS. Berhenti setelah
pemeriksaan penutup dan laporan untuk review; tidak memulai
M5/M6. Pertahankan APK release fixture dan database sintetis untuk pemeriksaan
berikutnya; tidak clear/reset/uninstall atau menimpa DB pengguna.
