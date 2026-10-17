# Temuan manual Realme, 16 Oktober 2026

**Checkpoint aktif: manual yang dicoba dan pemeriksaan otomatis penutup selesai untuk review dengan batas bukti.** Physicaldouble-submit belum terverifikasi sesuai klarifikasi pengguna. NativeSQL1/cleanUI2/strictaudit1 dan Windows1PASS; audit3pengulangan sukses digestidentik,2sales/4payments/stock14/debt26000/draft1barang12000. Rawfailure helpercase/lint dan semanticsawal disimpan; precisehandlecauseUNVERIFIED_CAUSE. TalkBackfalse/font1,0/releaseAPKhashsama/owndraftUI/ordinaryabsent verified. Ringkasan terstruktur docs/REALME_C11_MANUAL_RESULTS_20261016.md dan final/verification.json. Tidak ada jobtes/buildaktif, fixture/APK dipertahankan; tidak memulai M5/M6. Catatan pending di bawah adalah histori urutan uji, bukan status terbaru.

**Checkpoint historis rollback:** usulan isi dus selalu kosong ditarik dan dirollback; manual sempat dijeda. Lihat RM-MAN-08 untuk klarifikasi serta bukti.

## RM-MAN-01 — barcode tidak ditemukan (retest pending)

- Dilaporkan pengguna: setelah tiga kali mencoba, barang tidak ditemukan.
- Bukti otomatis terpisah: read-only own-app EditText pada
  `barcode-not-found-ui.json` berisi `barcode 000123`, bukan enam angka saja.
  Cart masih kosong/IDR0. Tidak merekam keyboard predictions/screenshot atau
  input payload historis. `pid-barcode-not-found.log` berasal ownPID3680.
- Source: cashier_screen menggunakan label ARB Cari barang, bukan barcode;
  ProductSearchService.scan melakukan exact barcode/SKU setelah trim.
- Hipotesis: kata barcode ikut masuk sehingga tidak sama dengan fixture000123.
  Observasi sesudah laporan tidak membuktikan isi pada semua submit sebelumnya;
  belum menyimpulkan bug aplikasi, datafixture, OEM keyboard atau sistem.
- Instruksi pembeda: pengguna menghapus seluruh isi Cari barang, memasukkan
  hanya `000123` tanpa kata/spasi lalu submit sekali lewat Gboard. Tunggu apakah
  satu barang masuk. Belum ada hasil retest.
- Tindakan: inspeksi UI dan log read-only; tanpa input/deploy/reset/SQLwrites.
  Validasi exactmatch tidak dilemahkan, tidak ada patch aplikasi.
- Hasil ulang dilaporkan pengguna: pencarian hanya000123 menemukan Realme C11
  fixture goods, IDR12.000, stok layak jual17. Ini mengonfirmasi lookup produk
  berhasil pada input yang diperjelas menurut laporan pengguna; tidak ada
  pembacaan DB atau input otomatis baru. Belum jelas apakah Enter menambahkan
  barang atau pengguna baru melihat suggestion. Ditanyakan apakah sudah masuk
  Daftar belanja dengan jumlah1 atau masih hasil pencarian.
- Status: initial FAIL tetap historis; exact-query lookup berhasil dilaporkan
  pengguna. Submit/penambahan cart/scan berulang belum terverifikasi, OPEN.

### Konfirmasi Enter pertama

Pengguna kemudian menjawab: "aku enter daftar belanja hanya 1". Dicatat sebagai
manual dilaporkan pengguna: lookup000123 dan satu Enter menambahkan satu unit ke
Daftar belanja. Ini menjelaskan hasil sebelumnya bukan sekadar suggestion.
Tidak ada pembacaan log/DB/input otomatis baru untuk konfirmasi ini.

Pengguna diminta melakukan dua input000123+Enter lagi, tanpa mengetuk suggestion
atau checkout. Expected satu baris qty3; hasil scan berulang masih menunggu.
Input uang/paste/grosir/touch/lifecycle/TalkBack belum diberi PASS.

### Retest tiga Enter selesai — manual dilaporkan pengguna

Pengguna melaporkan Enter berikutnya menaikkan jumlah menjadi2, lalu percobaan
terakhir dikonfirmasi "ya menjadi 3" atas pertanyaan apakah baris yang sama
berjumlah3. Subkasus lookup000123/Enter berulang/akumulasi satu baris **PASS
manual dilaporkan pengguna**, urutan1→2→3. Tidak ada bukti log/DB baru dan tidak
ditambahkan ke hitungan163kasus otomatis. InitialFAIL tetap historis; pengamatan
prefiks pada field dan retest exact-query mendukung klarifikasi input, tanpa
menyimpulkan payload semua submit awal atau adanya bug aplikasi yang diperbaiki.

Berikutnya RM-MAN-02: toggle Grosir on→qty3/totalIDR30000, off→qty3/IDR36000;
harga fixture retail12000/grosir10000 per pcs, bukan aturan baru. Ditanyakan
hasil dan apakah kontrol terlihat; belum ada hasil. Tidak melakukan checkout,
kontrol HP otomatis, reset atau patch aplikasi.

## RM-MAN-02 — perubahan total grosir/eceran

Pengguna melaporkan total menjadi30.000 sesudah mengaktifkan harga grosir,
kemudian menjadi36.000 sesudah diminta menonaktifkan Grosir. Peralihan total
grosir/eceran **PASS manual dilaporkan pengguna** pada keranjang yang sebelumnya
berjumlah3; jumlah/baris setelah toggle tidak disebut ulang secara eksplisit.
Angka sesuai fixture10000/12000 per pcs, tanpa pembacaan DB/log baru atau input
otomatis. Tidak mengklaim submit/receipt snapshot transaksi atau semua M3.1
lulus dari peralihan total ini. Berikutnya uji satu ketukan plus: qty4/total48000;
hasil belum diterima. Checkout tetap belum dilakukan pada rangkaian manual ini.

## RM-MAN-03 — tombol tambah/kurang jumlah

Pengguna melaporkan setelah satu plus: qty4/total48000; setelah satu minus:
qty3/total36000. Kedua perubahan sesuai harga retail12000 per pcs, **PASS manual
dilaporkan pengguna**. Tidak mengklaim ketukan cepat berulang, batas stok17,
snapshot checkout atau semua touchflow lulus. Tidak ada input/log/DB otomatis
baru; hitungan163test otomatis tetap. Berikutnya hapus baris lalu segera
Urungkan dan periksa pemulihan qty3/total36000; hasil belum diterima.

## RM-MAN-04 — hapus baris dan Urungkan

Pada instruksi hapus baris via tempat sampah lalu segera Urungkan (expected
barang pulih qty3/total36000), pengguna menjawab "ya". Pengguna sekaligus
menetapkan untuk langkah berikutnya "ya" berarti sesuai semua expected pada
langkah aktif; bila tidak akan menjelaskan. **PASS manual dilaporkan pengguna**
untuk hapus/restore qty3/36000; tanpa input otomatis/log/DB baru. Tidak mengklaim
uji undo kedaluwarsa/clearall/checkout. Konvensi berlaku pada langkah aktif
saja dan dicatat pada panduan manual. Berikutnya form Sebagian hutang,
input10000/expectedformat10.000 dan sisa26.000 tanpa commit; hasil pending.

## RM-MAN-05 — preview pembayaran dan input uang

Pengguna menjawab"ya" pada Bayar→Sebagian hutang→Nominal dibayar10000,
expectedformat10.000/sisa26000, instruksi belum menekan Simpan penjualan.
**PASS manual dilaporkan pengguna** untuk subkasus input/grouping/preview itu.
Tidak ada pembacaan DB/log baru, tidak mengklaim checkout sudah commit atau
kecepatan pengetikan tertentu karena instruksi hanya meminta ketik10000.

Berikutnya edit tengah: kursor sesudah10/sebelum titik pada10.000, Backspace
sekali; expected1.000/sisa35000/kursor tidak meloncat ke akhir. Hasil pending.
Paste/selection/language switch/IME Done pembayaran belum diuji.

### Edit tengah, seleksi sebagian, dan paste terformat

Dengan konvensi"ya" pada expected langkah aktif, pengguna mengonfirmasi:

- 10.000: kursor sesudah10/sebelum titik, Backspace1→1.000/sisa35000,
  kursor tidak melompat ke akhir.
- 1.000: seleksi digit1 saja, ganti2→2.000/sisa34000.
- Ganti seluruh nominal dengan12000; pilihsemua/Salin/hapus/Tempel kembali
  →12.000/sisa24000, tidak ada digit/nominal terduplikasi.

Ketiganya **PASS manual dilaporkan pengguna**, tanpa inspeksi clipboard,
keyboard predictions, input/log/DB otomatis. Paste memakai teks hasil Salin
field yang sudah terformat12.000; bukan bukti paste plaintext12000 atau
pemisah/desimal currency lain. Rapidtyping dan tombolDone uang belum diuji.
Form masih pada Sebagian hutang nominal12000/total36000, instruksi belum
Simpan penjualan. Berikutnya switchEnglish pada formaktif, expected12,000/
Remainingdebt24000(ENgrouping24,000)/total36,000, nilai/draft/mode terjaga.

## RM-MAN-06 — bahasa saat form pembayaran aktif

Pengguna"ya" pada ID→English: nominal12,000/debtIDR24,000/totalIDR36,000,
pembayaransebagian tetap terpilih dan isian tidak hilang. Kemudian"ya" pada
EN→Indonesia: nominal12.000/debtIDR24.000/totalIDR36.000 dengan mode/isian utuh.
**PASS manual dilaporkan pengguna** untuk roundtrip ini; currency tetap IDR
sesuai tampilan, bukan uji currencychange/seluruh terjemahan/persistensi restart.
Tidak ada input/DB/log otomatis baru atau checkout. Saat ini form Indonesia,
paid12000/debt24000/total36000. Berikutnya ketikulang10000 dengan cepat dan
tombolselesai keyboard; expected10.000/sisa26000/IMEtertutup/formtetapaktif,
belumSimpanpenjualan. Hasil pending; kecepatan tidak diukur secara stopwatch.

### Ketik cepat dan tombol selesai uang

User"ya" pada hapussemua→ketik10000cepat→Selesai/centang keyboard,
expected10.000/sisa26000/keyboardtertutup/formtetapterbuka/belum menekan
Simpanpenjualan. **PASS manual dilaporkan pengguna**, tanpa timingobjektif,
clipboard/logDB/input otomatis atau bukti commit. Form terakhir Sebagianhutang
paid10000/total36000/debt26000. Berikutnya kembali kasir→Kelola/PIN0001,
uji TampilkanPIN on/off lalu Buka pengelolaan. Hasil pending.

## RM-MAN-07 — PIN fisik nol di depan dan visibility

User"ya" pada kembali kasir(expectedqty3/36000)→Kelola→PINfixture0001,
TampilkanPINon menampilkan0001/off menyamarkan, lalu Buka pengelolaan membuka
menu tanpa kesalahan. **PASS manual dilaporkan pengguna** untuk rangkaian itu,
tanpa pembacaan credential/log/DB atau input otomatis baru. Bukan uji manual
PIN salah/lockout/timeout/rotasi; skenario otomatis terdahulu tetap terpisah.
Berikutnya Gudang/fixturegoods/Barangmasuk formdus5×40 dan harga120000 per dus,
expectedpreview200pcs/labelharga120000perdus serta scroll dengan IME terbuka tanpa overflow;
instruksi tidak menyimpan stok, hasil pending.

## RM-MAN-08 — default isi dus dan harga pada form Gudang

Pengguna melaporkan preview5×40=200pcs/layoutscroll selain dua pertanyaan sesuai.
Angka40 terisi karena konfigurasi master fixture sudah40 dari setup otomatis;
perilaku ini sesuai SPEC sebelumnya. Pengguna sempat meminta semua operasi baru
mulai kosong. Kode3file/UI, tes3file dan SPEC/catatanM31 sempat diubah di repo,
tanpa build/deploy/DB. Focused eksperimen10PASS; firsthelper2FAIL akibatquery ke
headerstock_receipts alih-alihstock_receipt_items diperbaiki pada helper saja.

Tentang harga: ownUIpack-form-price-ui.json memperlihatkan12.000. Pengguna
mengonfirmasi kekurangan satu digit0 saat mengetik; retry120000 tampil120.000
sesuai. Dicatat sebagai koreksi input dilaporkan pengguna, bukan bug formatter.
Tidak ada patch harga/pelemahan parser/input otomatis. Preview200pcs/scroll dan
harga120.000 sesudah koreksi PASS dilaporkan pengguna pada versi yang terpasang;
restock tidak diinstruksikan commit, bukan bukti receipt/valuasi manual.

Setelah meminta jeda, pengguna mengklarifikasi: pada Tambahbarang isi per dus
awalnya kosong, lalu diisi manual; nilai tersimpan menjadi default Barangmasuk.
Pengguna menarik usulan baru dan meminta rollback. Rollback selektif selesai:

- Controller kembali menerima optionalpackSize; operasi memakai konfigurasi.
- Stokawal kembali dapat memakai konfigurasi form jika isianoperasi masihkosong.
- Tes/newhelpers usulan ditarik, tes/framework/hitguard15Oktober dipertahankan.
- SPEC §19.4 dan M31-NOTES kembali ke kontrak sebelumusulan; tanpa schema/datawrites.
- Tujuh file dengan fingerprint cocok byte-identik snapshot15Oktoberakhir;
  empat file earlierfixes PIN/ABI/helperM2 tetapcocok.
- Formatter6files0changed/analyzeNoissues3,1s/focusedWindows7PASS00:20/exit0,
  audit367bilingualkeys/287refs/244stableIDs PASS.

Versi usulan tidak pernah dibuild/dipasang ke HP. Rollback hanya repo/tes/docs,
tanpa aksesHP/DB. Proposal sebelumrollback diarsipkan8file.txt+SHA256manifest
pada withdrawn-empty-pack/; raw hasil eksperimen tetaphistoris, bukan kebutuhan
aktif atau kasusbaru untuk ditambahkan ke163native sebelumnya. Manual tetap
dijeda sampai pengguna meminta lanjut; checkout/piutang/lifecycle/TalkBack dan
integritas pascamanual masih belum selesai.

## Lanjut setelah rollback — persiapan checkout manual

Pengguna meminta melanjutkan dan menyatakan pemeriksaan terakhir semuanya
sesuai harapan. Dicatat sebagai konfirmasi manual formGudang yang sebelumnya
diminta: konversi5×40=200pcs, inputharga120000→120.000 dan scroll/layoutIME.
Defaultkonfig40 telah diklarifikasi dan diterima; usulan kosong setiapoperasi
dibatalkan/rollback, bukan bug aplikasi. Belum bukti restockcommit/receipt/HPP.

Langkah berikut: Batal form Barangmasuk tanpaSimpan, kembali kasir(expectedqty3/
total36000), Bayar/Sebagianhutang(10000/sisa26000), nama sintetis baru
Uji Realme 16. Persiapan saja; belum diperintahkan Simpan atau doubletap.
Hasil persiapan menunggu. Konvensi user"ya" tetap semuaexpected langkahaktif.

## RM-MAN-09 — checkout sebagian dan konfirmasi ganda

User"ya" pada Batal Barangmasuk/kembali kasirqty3total36000/Bayar/Sebagian
hutang/input10000/nama Uji Realme 16/HPbolehkosong/sisa26000/belumSimpan.
Persiapan **PASS manual dilaporkan pengguna**; bukan bukti commit/stockwrites.
Nominal diminta diisi ulang; tidak mengklaim otomatis persist saat formditutup.

Instruksi selanjutnya: dua ketukan cepat Simpan penjualan; expected satu hasil
penjualan untuk Uji Realme16,qty3/total36000/paid10000/debt26000/satu nomor.
Hasil belum diterima. Receipt UI saja tidak membuktikan database jumlahsale1;
periksa ledger/DB terisolasi sesudah pengguna selesai. Baseline fixture sebelum
manual sudahsatu sale/stock17/debt26000pelangganlama, sehingga sesudah satu
checkoutbaru expectedtotalsale2/stock14/globaldebt52000, bukan totalsale1/debt0.
Semua ini expected, belum hasil observasi atau pembacaan DB baru.

### Hasil dua ketukan Simpan

User"ya" pada doubletapcepatSimpan→satu layarhasil untuk Uji Realme16,
qty3/total36000/paid10000/debt26000, tetaplayarhasilbelumNextbasket. **PASS
manual dilaporkan pengguna** untuk output UI itu. Nomor sale tidak ditranskrip;
tidak ada pembacaan DB/log baru, sehingga jumlahsaleDB/idempotensiDB belum
ditutup dari satu receiptUI. Berikutnya Nextbasket(expectedemptytotal0), ketik
000123 tanpaEnter/tapresult, expectedstoklayakjual14 pada suggestion. Pending.

### Keranjang baru dan stok setelah checkout

Pengguna menjawab “ya” untuk Belanja berikutnya → daftar belanja kosong/total
IDR0; ketik000123 tanpa Enter atau mengetuk hasil → stok layak jual14 dan
keranjang tetap kosong. **PASS manual dilaporkan pengguna**, sesuai penurunan
17→14. Belum pembacaan DB/log baru; satu receipt dan stok UI bukan pengganti
verifikasi jumlah sale/idempotensi/rekonsiliasi DB pascamanual. Tidak ada
input otomatis atau perubahan kode. Berikutnya buka Hutang/detail pelanggan
Uji Realme 16, expected saldo26000; belum instruksi Catat pembayaran.

## RM-MAN-10 — daftar piutang dan label nomor HP

Pengguna menjawab “ya sesuai”, lalu melaporkan dua baris: Synthetic Realme C11
customer dan Uji Realme 16, masing-masing IDR26.000. **PASS manual dilaporkan
pengguna** untuk daftar/saldo tersebut. Pelanggan pertama milik fixture otomatis
lama, kedua checkout manual; kemunculan keduanya sesuai model, bukan bukti
transaksi ganda. Jumlah sale/rekonsiliasi DB tetap menunggu pemeriksaan akhir.

Pertanyaan “HP belum dicatat” dijawab dari kode receivables_screen.dart:
customer.phone null memakai terjemahan m3NoPhone. Artinya nomor telepon
pelanggan belum diisi, sesuai field HP opsional SPEC §7, bukan status HP fisik
atau pembayaran. Tidak ada perubahan aplikasi/kontrol HP/DB baru.

Berikutnya pilih Uji Realme 16, isi nominal pelunasan10000 dan Catat pembayaran
untuk memeriksa dialog preview10000; belum menekan konfirmasi. Hasil pending.

### Preview pelunasan sebagian

Pengguna menjawab “ya” untuk Uji Realme 16/input10000/Catat pembayaran →
dialog rincian IDR10.000, belum menekan “Catat pembayaran ini”. **PASS manual
dilaporkan pengguna** untuk preview saja; belum bukti commit pembayaran.
Berikutnya konfirmasi sekali, expected dialog tertutup/sisa hutang16000/kolom
nominal kosong. Hasil pending; tidak ada kontrol HP/pembacaan DB/tes otomatis.

### Hasil konfirmasi pelunasan sebagian

Pengguna menjawab “ya” untuk satu tap “Catat pembayaran ini”: dialog tertutup,
sisa hutang Uji Realme 16 menjadi IDR16.000, kolom nominal kembali kosong.
**PASS manual dilaporkan pengguna** untuk hasil UI pembayaran10000. Belum
pembacaan ledger/jumlah pembayaran/rekonsiliasi DB atau laporan pascapelunasan.
Tidak ada kontrol HP atau tes otomatis baru. Berikutnya input16000, periksa
preview16000, lalu konfirmasi sekali; expected saldo0 dan nominal kosong.
Pelanggan fixture lama dengan hutang26000 tetap terpisah. Hasil berikut pending.

### Hasil pelunasan sisa

Pengguna menjawab “ya” untuk input16000/Catat pembayaran/preview IDR16.000/
satu tap Catat pembayaran ini → sisa hutang Uji Realme 16 sebesar IDR0 dan
kolom nominal kosong. **PASS manual dilaporkan pengguna** untuk UI; pembayaran
bertahap10000+16000 sesuai saldo awal26000. Belum pemeriksaan ledger/jumlah
pembayaran/rekonsiliasi DB atau laporan pascapelunasan. Tidak ada kontrol HP
atau tes otomatis baru. Berikutnya kembali ke daftar Hutang tanpa filter,
expected Uji Realme 16 tidak muncul pada daftar aktif dan Synthetic Realme C11
customer tetap IDR26.000; hasil pending. Riwayat lunas tetap harus dipertahankan.

### Daftar aktif sesudah lunas

Pengguna menjawab “ya” untuk kembali ke daftar Hutang tanpa filter: Uji Realme 16
tidak muncul di daftar aktif, Synthetic Realme C11 customer tetap IDR26.000.
**PASS manual dilaporkan pengguna** untuk daftar aktif. Ini bukan bukti penghapusan
atau pelestarian riwayat; riwayat lunas dan ledger DB masih perlu diperiksa.
Tidak ada kontrol HP/tes otomatis baru. Berikutnya Laporan/Bulan ini/Semua
pelanggan pada jam fixture Oktober expected penjualan72000/HPP54000/laba18000;
hasil pending.

## RM-MAN-11 — laporan setelah pelunasan

Pengguna menjawab “ya” untuk Kelola/Laporan/Bulan ini/Semua pelanggan:
penjualan bersih IDR72.000, HPP tersimpan IDR54.000, laba kotor IDR18.000.
**PASS manual dilaporkan pengguna**, sesuai model dua penjualan, masing-masing
36000/HPP27000/laba9000, tanpa tambahan penjualan/HPP/laba dari pelunasan.
Tidak ada snapshot laporan langsung sebelum pelunasan atau pembacaan ledger DB
baru; pemeriksaan otomatis akhir masih diperlukan. Tidak ada kontrol HP/tes baru.
Berikutnya laporan yang sama: pembayaran bersih46000/checkout20000/pelunasan26000/
saldo piutang26000; hasil pending.

### Rincian pembayaran dan jumlah laporan

Pengguna menjawab “ya” untuk pembayaran bersih periode IDR46.000/pembayaran
saat checkout IDR20.000/pelunasan piutang IDR26.000/saldo piutang IDR26.000.
Pengguna menambahkan eksplisit: stok fisik14, kedaluwarsa0, jumlah penjualan2,
jumlah pembatalan0. **PASS manual dilaporkan pengguna** untuk semua angka ini,
sesuai model dua penjualan dan pelunasan pelanggan baru. Belum audit ledger DB,
benchmark, atau bukti seluruh periode/perangkat. Tidak ada kontrol HP/tes baru.
Berikutnya nilai persediaan expected126000 dan riwayat Uji Realme 16 expected
qty3/total36000/sisa hutang0; hasil pending.

### Nilai persediaan dan riwayat pelanggan lunas

Pengguna menjawab “1. ya, 2. ya” untuk nilai persediaan IDR126.000 dan riwayat
Uji Realme 16 tetap tersedia, qty3/total IDR36.000/sisa hutang IDR0. **PASS manual
dilaporkan pengguna**; belum audit DB pascamanual. Tidak ada kontrol HP/tes baru.
Berikutnya buat draft1pcs/12000 tanpa checkout, buka Kelola lalu Home/kembali;
expected akses pengelolaan terkunci. Hasil pending, draft akan diperiksa sesudahnya.

## RM-MAN-12 — Home, relock, dan draft

Pembaruan akhir rangkaian: sesudah lockscreen/relock, pengguna “ya” untuk kembali
kasir tanpa PIN/scan ulang, draft tetap1barang/IDR12.000 dan kasir terbuka.
**PASS manual dilaporkan pengguna** untuk akses publik/draft pascalockscreen;
bukan reboot/powerloss atau audit DB baru. Berikutnya TalkBack fisik label/fokus
kasir tanpa mengubah keranjang/checkout, hasil pending. Kondisi awal TalkBack
nonaktif; pulihkan sesudah pengujian. Tidak ada kontrol HP/tes otomatis baru.

Pengguna menjawab “ya sesuai” pada draft1pcs/12000→Kelola→Home→kembali,
expected Pengelolaan terkunci/Masukkan PIN kembali. Lalu pengguna memasukkan
PIN dan berhasil masuk menu pengelolaan lagi. **PASS manual dilaporkan pengguna**
untuk Home/relock/unlock; bukan pengujian lockscreen/reboot/powerloss.

Tambahan pengguna: saat kembali kolom Cari barang masih000123; sesudah Home/
PIN/Kelola dan kembali ke kasir kolom kosong. Titik pengosongan tidak diamati.
Kode _SearchPane membersihkan input sesudah add berhasil; query pencarian
berbeda dari draft keranjang. Belum bukti bug/kehilangan draft atau perlunya patch.
Berikutnya konfirmasi Daftar belanja tetap1pcs/total12000 tanpa scan ulang atau
checkout. Belum hasil eksplisit untuk draft pascaHome; tidak ada kontrol HP/DB/tes baru.

### Draft setelah Home dan kembali dari Kelola

Pengguna menjawab “ya” untuk Daftar belanja tetap1barang/total IDR12.000 setelah
Home/PIN/Kelola/kembali kasir, tanpa scan atau add ulang. **PASS manual dilaporkan
pengguna** untuk draft pada rangkaian tersebut. Kolom pencarian kosong tidak
menghilangkan draft di sini; bukan bukti force-stop/reboot/powerloss/recovery DB.
Berikutnya Kelola terbuka lalu kunci layar dengan tombol daya/buka seperti biasa,
expected Pengelolaan terkunci/Masukkan PIN kembali. Hasil pending, tidak ada
kontrol HP/DB/tes otomatis baru.

### Kunci layar fisik dan relock

Pengguna menjawab “ya” untuk Kelola terbuka, tombol daya mengunci layar,
buka kunci seperti biasa dan kembali kasir_app tests → Pengelolaan terkunci/
Masukkan PIN kembali, belum memasukkan PIN lagi. **PASS manual dilaporkan
pengguna** untuk lockscreen/relock pada rangkaian ini, bukan reboot/powerloss.
Berikutnya kembali kasir tanpa PIN/scan ulang/checkout, expected draft1barang/
total IDR12.000; hasil pending. TalkBack dan audit DB akhir masih belum selesai.
Tidak ada kontrol HP/DB/tes otomatis baru.

## RM-MAN-13 — TalkBack fisik pada kasir

Pengguna menjawab “ya” untuk mengaktifkan TalkBack melalui aksesibilitas,
kembali kasir dan menjelajahi fokus Cari barang/nama produk/tambah-kurang/
total IDR12.000/Bayar. Semua terbaca/dapat dijangkau tanpa mengubah keranjang.
**PASS manual dilaporkan pengguna** untuk label/fokus tersebut, bukan seluruh
form/error/dialog atau full accessibility acceptance. Berikutnya Bayar/Sebagian
hutang/input0/Simpan penjualan sekali untuk validasi penolakan nominal nol;
expected tetapform/pesan dapat dijangkau dan dibaca TalkBack/tidak ada receipt.
Hasil pending, tidak ada kontrol HP/tes otomatis baru. TalkBack harus dipulihkan
nonaktif sesudah pengujian; audit DB akhir belum dijalankan.

### Input dan pesan validasi dengan TalkBack

Pengguna menjawab “ya” untuk Bayar/Sebagian hutang/input0/Simpan penjualan
sekali: pesan pembayaran sebagian harus lebih dari nol dan kurang dari total
dapat dijangkau/dibaca TalkBack, form tetap terbuka dan tidak muncul struk.
**PASS manual dilaporkan pengguna** untuk input/penolakan/pesan yang difokuskan;
bukan bukti pengumuman otomatis atau audit jumlah sale DB. Tidak ada kontrol HP,
patch, atau tes otomatis baru. Berikutnya kembali kasir/Hutang/pelanggan lama
Synthetic Realme C11 customer/preview pelunasan1000, periksa fokus dialog lalu
Batal saja, expected saldo tetap26000. Tidak mengonfirmasi pembayaran baru.
Hasil berikut pending; pemulihan TalkBack nonaktif dan audit DB akhir belum selesai.

### Dialog preview dan pembatalan dengan TalkBack

Pengguna menjawab “ya sesuai” untuk preview pelunasan1000 pelanggan lama:
judul/nominal IDR1.000/tombol Batal dan Catat pembayaran ini dapat dibaca serta
dijangkau. Batal menutup dialog dan saldo tetap IDR26.000. **PASS manual
dilaporkan pengguna**; bukan audit ledger atau bukti seluruh dialog aplikasi.

Tambahan pengguna menyebut satu “pelanggan” MV8YAQO0-7541C750/sisa26000.
Lokasi belum jelas. Kode detail hutang menampilkan receipt.number dan sisa per
transaksi di bawah form, sedangkan daftar utama menampilkan customer.name.
Hipotesis nomor penjualan perlu dibedakan dari baris pelanggan tambahan dengan
konfirmasi lokasi; belum kesimpulan bug/data duplikat. Tidak ada input otomatis,
pembacaan UI/DB, atau patch. TalkBack masih aktif, audit akhir/pemulihan pending.

### Klarifikasi nomor penjualan selesai

Pengguna memastikan kode MV8YAQO0-7541C750 berada di halaman detail Synthetic
Realme C11 customer, daftar Hutang hanya1pelanggan. Cocok format SaleReceipt.number
(waktu base36 dan delapan karakter ID); bukan pelanggan tambahan atau saldo baru.
Klarifikasi selesai tanpa bug duplikasi terbukti, patch, atau kontrol HP.

Berikutnya pengguna menonaktifkan TalkBack melalui aksesibilitas (kondisi awal
nonaktif), kembali kasir dan memeriksa draft1barang/12000. Pemulihan belum
dikonfirmasi. Sesudah pengguna selesai, jalankan pemeriksaan otomatis akhir
ledger/integrity/log pada paket terisolasi dan pulihkan APK release fixture;
hasil otomatis akhir belum ada. Jangan menyentuh HP selama pemulihan manual.

## Koreksi akhir pengguna — dua ketukan dan pemulihan TalkBack

Pengguna mengonfirmasi TalkBack nonaktif/kembali kasir dengan draft1barang12000.
**PASS manual dilaporkan pengguna** untuk pemulihan tersebut, belum verifikasi
settings read-only baru. Pengguna mengklarifikasi tap pertama Simpan segera
mengganti layar; tap kedua belum terbukti mengenai tombol. **Physicaldouble-submit
BELUM TERVERIFIKASI**, menggantikan interpretasi awal; jangan klaim kedua tap
diterima handler. Receipt tunggal/stok14/laporan2sales tetap bukti output sesuai
laporannya, bukan penerimaan dua submit. Mulai audit otomatis akhir terisolasi
sesudah manual selesai, tanpa reset/clear/uninstall/menimpa data.
