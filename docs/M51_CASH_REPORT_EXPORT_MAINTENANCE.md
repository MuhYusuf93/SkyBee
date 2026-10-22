# M5.1 D / E / G — pembayaran, ekspor dan pemeliharaan

**Penutupan21 Oktober2026:** [laporan akhir](M51_FINAL_REPORT_20261021.md)
memuat hasil terbaru dan handoff ordinary Poco0.5.1+8. Host77PASS66s mencakup
D/E/G/queue/corrections/money/USB/metadata, migration8→13terarah1PASS terpisah,
reader csv/openpyxl129rowPASS. Formatter275/0changed dan analyzer bersih. Native
queue Poco1PASS16s memakai output fake/default6/saved3/fakta keuangan;392hashcocok.
Debug/release3ABI/16KiB/signature PASS, debug in-place/dua startup kasir PASS,
kontrol Off. WAL native Poco2/DV2PASS dan backup DV2PASS99s sebelumnya tetap.
Raster41717byte/11chunk sudah submitted, logo/nominal sesuai reported; footer
terlihat sesudah3LF, sebab belum pasti. Paper baru default6 belum diuji dan
marker lama tidak diulang. Audit jeda lama390/391cocok/ordinary DB berbeda,
pengguna mengonfirmasi pemakaian dummy; interval baru strict cocok, tidak reset.
M5.2/M6 tidak dimulai. Checkpoint pending berikut historis, bukan status terbaru.

Checkpoint 20 Oktober 2026, verifikasi akhir berlangsung. A–C dan F tidak dibuka ulang.

**Handoff chat baru:** [NEXT_SESSION_M51](NEXT_SESSION_M51.md) menyimpan titik
berhenti aktual. Backup final DV2PASS99s, raster USB1PASS6s/41717byte+feed-only
1PASS4s/3byte. Footer terlihat sesudah feed menurut pengguna; penyebab belum
dipastikan. Default feed6 untuk profil baru (saved3 tetap) belum regresi akhir.
Formatter/analyze/host/build/handoff berikutnya belum lengkap, jangan klaim M5.1
ditutup dari judul log lama bernama final.
M5.2 menunggu desain; M6 tidak dimulai. Realme tetap dijeda untuk penggunaan
pribadi; endpoint worker historisnya belum terverifikasi. Acuan:
[permintaan A–G](decisions/M51_REQUEST_20261019.md).

## Keputusan implementasi

**D, schema12.** `TenderDigits` menyimpan digit/desimal canonical, terpisah dari
format ID/EN; IDR bulat, USD/MYR/EUR dua digit pecahan. Numpad internal tidak
memakai EditableText/IME; kolom pelanggan tetap memakai keyboard biasa. Uang pas
dan tombol cepat mengganti nominal. Daftar per currency maksimal delapan,
deduplikasi/urut/penyaringan nonpositif, tidak boleh menjadi kosong. Konfigurasi
terproteksi; pemakaian tombol harian publik. Kegagalan baca konfigurasi opsional
memakai default berlabel jelas dengan feedback; bukan menghalangi kasir.

`CashTender` memisahkan received/applied/change/debt dengan integer minor units.
Checkout memakai applied untuk payment/allocation; uang lebih bukan pendapatan.
Tender kosong ditolak, seluruh hutang tindakan eksplisit, identitas pelanggan
wajib hanya bila masih berhutang. `checkout_tenders` adalah fakta immutable/FK
RESTRICT dalam commit checkout yang sama, dengan trigger pencocokan header.
Draft menyimpan raw/nominal/mode. Provider menserialkan persist, menolak generation
lama setelah restore, dan membekukan checkout sesuai barrier keranjang lama.
Hash payload legacy tetap; sale lama tidak memperoleh tender/kembalian rekaan.
Snapshot struk membawa tender/change awal; pelunasan berikutnya tidak menulis
ulang snapshot atau membuat penjualan/HPP baru.

**E.** `ReportExportService` membekukan lima bagian dalam satu read transaction:
summary, sales/reversals, payments/reversals, original sale items, current
inventory. Agregat menggunakan query laporan M4 yang sama; customer filter dan
UTC [start,end) dipertahankan. Piutang/persediaan berlabel current, bukan posisi
historis. Sales dan payments tidak dijumlah menjadi pendapatan ganda. Item
original dan status reversal disajikan terpisah dari signed events.

Query keyset maksimum100 baris; file di-flush per halaman dan dapat dibatalkan.
Tidak ada seluruh dataset dalam Provider. CSV UTF-8 BOM/koma/quoted/CRLF,
formula-like text diberi apostrof. Import barcode/ID/uang sebagai **text** pada
Excel; CSV tidak memiliki tipe sel. XLSX memakai lima worksheet SpreadsheetML,
inlineStr untuk identifiers/money dan angka hanya untuk integer <=15 digit.
Nominal/decimal/cost-micros tetap string eksak; tidak menggunakan double atau
formula. Batas worksheet Excel1.048.576 baris menolak file parsial; CSV menjadi
pilihan untuk data lebih besar. Archive4.5.2 menulis file ZIP streaming store
di isolate terpisah. ZIP/XML staging privat, dibersihkan pada selesai/batal/gagal
dan disposal normal; crash-process cleanup belum diklaim.

Ekspor laporan berbeda dari backup terenkripsi. SAF laporan dua fase: native
CREATE_DOCUMENT mengembalikan token tujuan kosong tanpa menulis data laporan.
Pengguna kembali/PIN, lalu aksi Tulis berkas memeriksa persisted epoch/session.
Token engine-local/sekali pakai/120detik; expired/dispose membatalkannya. Native
write ditutup dan dibaca ulang/digest dibandingkan sebelum sukses. Tidak meminta
izin penyimpanan luas. Jalur SAF backup terenkripsi lama tetap dipertahankan.

**G, schema13.** Backup lokal yang benar-benar tervalidasi mencatat kandidat
sesudah indeks arsip berhasil; catalog recovery tidak membuat kandidat baru.
Maintenance terpisah dari hasil backup: gagal/skip bukan kegagalan arsip atau
alasan upload ulang. WorkManager delayed6jam, idle+charging, Keep; worker membaca
PowerManager noninteractive/charging lagi. Natural idle/reboot/Doze belum diuji.
Fixture otomatis tidak mendaftarkan job maintenance OS pada database kampanye
lain; batas registration diuji dengan sink scheduler.

Urutan lease sama lintas engine: backup-work → database. Backup lokal/pembuatan
arsip, upload Drive dan restore mempunyai lease backup-work; nested safety
snapshot memakai lease yang sudah dimiliki. Maintenance mencoba keduanya tanpa
menunggu kasir/backup aktif. `tryIdle` tidak mengganti generation atau memicu
navigasi restore. Ambang1024free pages dan >=25%, free disk >=2×DB+32MiB,
cooldown7hari sesudah sukses dan1hari antarpemeriksaan. Satu baris status
attempt/success/skipped/error; tidak menghapus fakta untuk menghemat ruang.

VACUUM in-place di luar SQL transaction, codec/key SQLCipher dipertahankan.
Quick/FK, envelope HMAC, rekonsiliasi dan fingerprint sebelum/sesudah wajib sama;
ukuran halaman dibaca eksak dari cipher_page_size (TEXT pada driver Android).
Tidak VACUUM INTO/plaintext, rekey atau hard-delete histori. Hasil before/after
diukur dari File.length sesudah checkpoint WAL/TRUNCATE, bukan hanya page_count.
Checkpoint memakai busy_timeout0 sementara lalu mengembalikan timeout semula;
reader eksternal sibuk langsung skip, journal mode tidak diubah. Status running
yang tersisa saat restart menjadi interrupted; menunggu
backup valid berikutnya. Restore mengosongkan state/kandidat lokal ini.
Sesudah VACUUM mulai, statement atomik tidak dibatalkan jika layar mendadak aktif;
operasi DB menunggu lease sampai statement/check selesai.

## Bukti yang sudah tersedia pada checkpoint

| Pemeriksaan | Hasil aktual |
| --- | --- |
| Host D/layout/metadata awal |16PASS28s; run pertama dihentikan pada helper FakeAsync/IO, tidak disebut seluruh suite PASS |
| Host E/G awal |7PASS18s; CSV/openpyxl independen129baris/total/formula/barcode PASS |
| Regresi10file |71PASS+1FAIL69s; query baru memakai base_unit padahal kolom aktual base_unit_label; diperbaiki |
| E/G/config retest |9PASS20s; tambahan XLSX integer64bit literal; independent reader PASS |
| G final host |6PASS46s termasuk gate backup sibuk, fault, restart, page-size ketat; FFI17.44MB→0.63MB82ms |
| UI/metadata ID–EN |12PASS24s; termasuk forged tender raw/minor dan kebijakan |
| Clipboard |4FAIL offscreen di run38PASS/4FAIL203s; helper first-scrollable mengarah ke status, diperbaiki ke form+hitTestable; focused4PASS28s |
| Poco D/E pertama |10PASS/5FAIL177s: D7 dan E3PASS; G4/gate1FAIL, semua hash lama sama |
| Poco G diagnosis |1FAIL12s, failure:pageSize:_TypeError; bukan kelulusan VACUUM |
| Poco G final |6PASS81s, cipher page-size String,17.78MB→638976bytes4683ms, semua hash lama sama/controlOff |
| Host D/E/metadata/settings final |49PASS208s; termasuk clipboard4focused PASS dalam jumlah tersebut |
| Cancel ekspor saat native write |repro UI1FAIL5s (cancelCalls0), perbaikan UI/native token; UI+E5PASS19s |
| DV D/E/G |17PASS302s; D8/E3/G5/nativegate1, seluruh hash lama sama/awake pulih exact/controlOff |
| Portable backup terbaru |Poco1PASS60s dan DV1PASS80s, tender overpay/config USD/fakta/restore lintas key; seluruh hash lama sama, DV awake pulih |
| WAL physical before |1FAIL4s: after_bytes634880 tetapi berkas17444864 saat koneksi masih terbuka; bukan korupsi data |
| WAL physical after |host7PASS25s lalu tambahan reader busy8PASS29s (subset); ukuran fisik17444864→634880, mode WAL/timeout tetap. Reader test awal salah memakai transaksi reservasi writer, diperbaiki BEGIN DEFERRED;7PASS/1FAIL34s historis dipertahankan |
| WAL native final |Poco2PASS42s/DV2PASS60s, DELETE dan WAL masing-masing17780736→638976bytes sebelum close; fakta/generation/timeout/mode terjaga, seluruh hash lama sama; DV awake pulih exact |
| USB raster/cash terbaru |SKIPPED/BLOCKED4s: host tersedia tetapi0target/0byte, bukan cetakan/PASS. Seluruh hash lama sama/awake pulih/controlOff; menunggu sambungan printer |
| USB setelah tersambung |request izin normal timeout24s/0byte lalu grant UID10115; berikut helper FAIL5s usb_invalid_chunk karena raster satu blok >4096. Guard native menolak sebelum transfer; queue produksi sudah4096. Marker v1 dipertahankan, helper v2 bounded sedang diuji |
| Kegagalan kandidat maintenance |DV repro1FAIL19s→backup final2PASS99s (restore normal + fault kandidat, arsip/index tetap valid dan terautentikasi ulang); semua hash lama sama/awake pulih |
| Poco candidate percobaan awal |BLOCKED sebelum test dimulai karena kabel dipindah sengaja ke printer; APK fixture terpasang, endpoint hash belum tersedia. Bukan bug aplikasi/USB debugging; audit akhir menunggu kabel kembali |
| Build / ordinary handoff akhir |SELESAI21 Oktober pada cakupan tersedia: debug/release0.5.1+8 verified, debug in-place Poco dan dua startup PASS; lihat laporan akhir |

Log detail privat ada di ignored build/. Retest/subset tidak dijumlah sebagai
kasus unik tambahan. USB81byte lima baris adalah PASS paper historis terpisah.
Baris0target/invalid_chunk di atas adalah percobaan awal; raster v2 kemudian
submitted41717byte dan feed-only3byte. Kedua marker submitted tetap disimpan dan
tidak boleh diulang. Logo/barang/nominal sesuai reported; paper baru default6
belum diuji. Laporan akhir menjelaskan batas footer dan bukti terbarunya.

## Temuan dan perbaikan yang dapat ditinjau

| Gejala | Penyebab / dampak | File / bukti / status |
| --- | --- | --- |
| G native gagal sebelum VACUUM |cipher_page_size adalah String pada driver, cast int gagal; tidak ada pemadatan |space_maintenance_service.dart parser integer ketat; Poco diagnosis1FAIL→G6PASS, DV17PASS; FIXED |
| Try gate sibuk menjadi MissingPlugin |hasil null metode dikenal dipetakan notImplemented; menghalangi skip aman |KasirPlatformPlugin.java explicit null success; native gate Poco/DV PASS; FIXED |
| Backup valid dilaporkan gagal ketika kandidat maintenance tak tersimpan |UPDATE kandidat di luar catch scheduler, exception naik sesudah artifact/index selesai; dapat memicu retry upload tak perlu |backup_service.dart catch seluruh tahap maintenance opsional setelah index; m51_maintenance_backup_test.dart repro DV1FAIL19s→full portable+fault2PASS99s; FIXED |
| WAL status ukuran tidak mencerminkan berkas fisik |VACUUM hanya mengurangi logical pages sebelum checkpoint; status sukses terlalu dini |space_maintenance_service.dart checkpoint nonblocking+File.length, m51_space_suite.dart repro1FAIL→host8PASS; Poco2/DV2PASS; FIXED |
| Cancel saat tulis SAF tidak mencapai native |tombol hanya mengubah control snapshot, stream berjalan dan dapat menampilkan sukses |report_export_screen.dart cancel token/native + statuscancel; report_destination_service.dart timeout2menit; UI1FAIL→5PASS; FIXED otomatis, OEM/provider nyata belum diuji |
| Ekspor gagal karena kolom base_unit |nama aktual base_unit_label; query baru keliru, bukan aturan bisnis |report_export_service.dart; broad71PASS/1FAIL→E/G/config9PASS dan native E3per perangkat; FIXED |
| Clipboard widget offscreen |helper firstScrollable memilih status, bukan form; bukan clipboard aplikasi |m5_settings_widget_suite.dart keyed form/hitTestable,4FAIL→4focused/full49PASS; FIXED helper |

Kegagalan helper bukan bug aplikasi tambahan. Retest subset tidak dijumlah
sebagai kasus baru; kegagalan dan hasil awal tetap tersedia di build privat.

Referensi primer: [SpreadsheetML](https://learn.microsoft.com/en-us/office/open-xml/spreadsheet/structure-of-a-spreadsheetml-document),
[archive writer](https://pub.dev/documentation/archive/latest/archive_io/ZipFileEncoder-class.html),
[SQLite VACUUM](https://www.sqlite.org/lang_vacuum.html),
[SQLite WAL checkpoint](https://www.sqlite.org/pragma.html#pragma_wal_checkpoint),
[SQLCipher API](https://www.zetetic.net/sqlcipher/sqlcipher-api/).
