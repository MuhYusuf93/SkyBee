# Checkpoint aktif M5.4

6 November 2026, WIB. Kontrak: [M54_REQUEST](decisions/M54_REQUEST.md).

Baseline aktual `c94a2a2`, main, 0.5.3+13/schema37; perubahan lokal awal
hanya delapan berkas `gemini2_` untracked. Jangan menyentuhnya. M5.3 ditutup;
riwayat pengujian lama bukan perintah mengulang seluruh suite.

## Urutan pekerjaan

1. Audit/kontrak/matriks — kontrak asli disalin utuh; audit berlangsung.
2. Keamanan/recovery compatibility/gate/input/form/arsip/kebijakan kas.
3. Retur penjualan/garansi/karantina/refund/QRIS manual/split/rounding.
4. Gudang/supplier/reservasi/lampiran/member/favorit.
5. Recovery PDF/grafik/output/Drive/portable backup.
6. Host lalu acceptance fixture DV/Poco, perbaikan dan regresi terdampak.
7. Beri kabar dan jeda sebelum handoff untuk koordinasi Realme C11. Uji
   M5.3 dan M5.4 dengan fixture terisolasi, lalu perbaiki temuan.
8. Sesudah arahan lanjut, handoff `.skybee` in-place dan APK Uji Teman.
9. Finalisasi source/APK/manifest/dokumentasi/commit/push biasa.

## Temuan awal

- ADB read-only: Poco `7f0edea0` model24069PC21G; DV `192.168.0.101:5555`
  modelAX810/DV8947-KIX authorized. Realme belum terlihat. Tidak ada instalasi,
  reset, perubahan PIN, seed atau transaksi pada data eksplorasi.
- `PinBoxes` memakai dua pembatas panjang4; commitText barcode panjang dapat
  berubah menjadi PIN4digit. Auto-submit langsung juga menerima prefix burst.
- `CashierLockNavigator` menyisipkan opaque lock di atas setiap route,
  termasuk Kelola; dibutuhkan prioritas route tanpa menghapus lock kasir.
- Lock existing persisten tetapi memakai cooldown eksponensial5detik, belum
  kontrak3/5/8. Recovery PIN32hex terpisah dari backup256bit/64hex.
- Validasi harga master memakai `>` sehingga harga sama masih diterima.
- Signing release existing masih debug certificate; trial membutuhkan signing
  lokal stabil dan tidak boleh membawa source controller debug.

Status belum selesai: seluruh acceptance M5.4 dan handoff M5.4 belum dijalankan.
M5.5 khusus multi-device, belum dikerjakan. Redesign menyeluruh ditunda.


## Lanjutan 7 November 2026, fondasi native ditutup

Host85kasusunik melalui runs/retest; native Poco23unik melalui20awal+3review,
DV23/23PASS08:22. Semua oldprotectedhash unchanged; DVawake exact restored;
controlOff, process exit dan manifest3 verified. Laporan mencatat run gagal,
bukan menghilangkannya. FixtureAPK arm64 saja, bukan APK handoff.

Source dibuka kembali sesudah audit untuk tahap2 kebijakan/sesi kas. Draft9file
diterapkan dengan semua preimage SHA diperiksa. Pisahkan rawpolicy dari mode
sesi aktual; Off boleh Buka sukarelaNotes tanpaubahraw; perubahan owner dengan
open session harus eksplisit berlaku sesi berikutnya. Open/close ikut menaikkan
revisionCAS atomik dan retry tidak menggandakan. UIstatus/clean baseline dan
regresi cash/supplier/portable48/48PASS01:26. UIbaru2PASS00:31,
analyzerfinal104s bersih, l10n1552/947/245, PIN106match; semua fail awal disimpan.
Native7kasus kas PocoPASS04:04 lewat retained-packagewrapper, oldhashsama/
controlOff/trueexit0. DV7/7PASS04:51 pada revisi sama; oldhashsama/awakeexact/controlOff/trueexit0. Manifest4 frozen
889file2ae2e9e160de4083aec52bddca88737587160be85b78f33546b3605d24084ca0;
preflightPoco/DV0pending. Kedua wrapper dan audit
hashlama/awake/controlOff/trueexit ditutup; manifest4 terakhir verified. Laporan M54_CASH_POLICY_REPORT.

Lanjut kas/HID/modal/acceptance arsip, kemudian tahap3–9 berurutan. Tidak ada
izin berhenti di checkpoint. Tidak ada packageuser diupdate/reset/reseed.

Draft input routing berada di build/m54/input-routing-draft/ dan audit
build/m54/input-routing-audit.md. Belum diterapkan/ditest; caller kamera sudah diadaptasi secara sintaks di draft,
belum typechecked. Scope lanjut/renewal setelah dialog dan include-only pending. README berisi urutan reproduksi
dan batas. Jangan copy draft secara buta Source kini boleh dilanjutkan; mulai reproduksi field/scope kecil dahulu.

## Routing input — native source5 aktif

Source guardedlookup/SQL/route/field dan rawPIN setup/rotasi aktif. Reproduksi
field1PASS2FAIL lalu7PASS; rawPIN4FAILprefix lalu4PASS. Regresi akhir77PASS+
4fixtureerror02:03, retest14PASS00:09 =81unik (overlap tidak dijumlah ulang).
Analyzer110,8s bersih; formatter84/0; l10n1553/948/245; PIN106match.
Kas source4 native kedua perangkat sudah ditutup. Routing12kasus Poco sedang
berjalan melalui safe wrapper, DV setelahnya. Source894file dibekukan pada
manifest5 SHA6bf9750dc7d093d2537734beea1e9c5a5975fe28c585cd4255388a556819f94a.
Jangan edit maintainedsource selama wrapper aktif. Hashlama/controlOff/exit0,
DVawakeexact dan manifest harus diverifikasi sebelum lanjut arsip/navigasi.
Draft input-routing-draft kini historis; source aktual telah diperbaiki, jangan
copy ulang. Laporan M54_INPUT_ROUTING_REPORT merinci bukti/failure/batas.

## Native routing review6 — aktif

Filter NameFilter adalah literal --plain-name. Runregex0kasus=FAILED, hash lama
sama/controlOff/exit1; jangan ulang regex. FullPoco21 =19PASS2FAIL02:04, hanya
dua rotasiPIN helpergulir (native switchlazy), semua real assertion lain lulus.
Audit oldhashsama/controlOff/trueexit1. Revisi6 hanya helpervertical jump ke min,
strict switchpresence tetap; host4PASS00:08. Produksi identikmanifest5; diff persis
test/support/m54_pin_setup_suite.dart. Source894file frozen manifest6
882365ca194b0a8ec19a9bfb5d980f92b3f0d886caa2221aab89e07ded888467.
Retest2Poco berjalan, laluDVfull21 tanpafilter. Jangan editsource hingga semua
wrapper/hash/awake/controlOff/exit ditutup. Draft arsip di build/m54/archive-draft
belum diterapkan/ditest; meliputi scopes/Undoexpired dan dugaan reloadhilangkanerror.

Poco menutup 21 kasus unik setelah retest dua rotasi lulus. DV pertama berhenti
setelah 17 kasus lulus karena ADB offline. Kode keluar aktual 1. Pemulihan
manual dari snapshot awake berhasil setelah koneksi kembali dan audit susulan
menemukan 1.264 hash cocok. Result.json asli disimpan karena finally gagal
memublikasikan status akhir. Bukti susulan ada pada folder run
`m54-input-routing-dv-all-20261107-051101`. DV kedua menjalankan 21 kasus dari
manifest 6. Draft arsip berisi tujuh kasus dan kandidat perubahan. Jalankan
tes terhadap source sebelum perbaikan untuk mengonfirmasi diagnosis.

Full run DV kedua lulus 21 kasus dalam 2:48. Audit hash dan awake ditutup,
kontrol otomatis berhenti dan kode keluar aktual 0. Manifest 6 diverifikasi
sebelum source dibuka untuk repro arsip.

## Operasional tahap 2 selesai di host

Arsip/Undo/stale checkout, navigasi kategori/supplier/rak dan bahasa promo
lulus dalam regresi host 75/75 pada schema 38. Analyzer bersih. APK fixture
terkompilasi dengan area fokus kamera belakang, dan diverifikasi package/ABI/
16 KiB. Fixture build belum dipasang. Uji native arsip dan optik/HID fisik
terbuka. Runner kini menyimpan hasil terminal ketika pemulihan awake gagal.
[Laporan](M54_OPERATIONAL_REPORT.md). Lanjut tahap 3 dari snapshot garansi,
kode struk dan retur transaksi. Data perangkat belum diubah untuk handoff.


## Tahap 3 · skema 43

Garansi snapshot, kode struk Code 128/QR, retur parsial, pengurangan
piutang, refund dengan sesi kas aktual, dan pengaturan gambar QRIS privat
telah melalui regresi host 64/64 dalam 1:25. Analyzer bersih. Tes UI ID/EN
320 px pada skala 2 mencatat refund eksternal tanpa mutasi laci. Dua run
driver awal dihentikan saat menunggu I/O. Run berikutnya memperbaiki
navigasi field lazy dan status hasil yang sempat muncul ganda. Gambar
sintetis diuji tanpa pembayaran nyata. Split checkout dan pembulatan
masih dalam pengerjaan. Paket pengguna belum dipasang ulang.

## Tahap 3 · skema 44 · 8 November 2026

Checkout memvalidasi ulang revision draft, nominal, metode eksternal, dan
revision kebijakan pembulatan dalam transaksi. Konfirmasi manual gugur ketika
nominal atau metode berubah. Draft menyimpan nominal dan metode. Konfirmasi
kasir harus diulang saat membuka draft. Pembulatan opsional berlaku pada
checkout yang memakai tunai dan disimpan per baris untuk retur. Dalam kasus
Rp86.750 menjadi Rp86.500, QRIS Rp50.000 tercatat sebagai pembayaran eksternal
dan laci mencatat tunai bersih Rp36.500. Transfer murni tidak membuat event laci.
Retur penjualan lama bisa dicari dengan tanggal toko dan hasil berpaginasi.

Regresi awal mencatat 70 lulus dan dua kegagalan harness UI yang masih
mengasumsikan mode hitung manual. Tes ulang UI lulus 9/9 dalam 53 detik,
termasuk kedua kasus tersebut dan kasus baru invalidasi konfirmasi transfer.
Totalnya 73 kasus host unik. Audit lokalisasi 1626/1011/245 dan audit PIN 106
lulus. APK debug biasa 0.5.4+14 terkompilasi dan terverifikasi untuk
`com.example.kasir_app`, tiga ABI, 13 pustaka native, dan alignment 16 KiB.
APK tersebut disimpan sebagai bukti build tanpa instalasi. Pengujian native
skema 44, alur karantina lanjutan dan cetak fisik tetap terbuka.

Tahap 4 berikutnya dimulai dari reproduksi burst scan pada draft penerimaan.

## Tahap 4 · input penerimaan · 8 November 2026

Reproduksi pada layar penerimaan semula menyimpan satu dari 27 scan IME.
Antrean terikat route menerima input beruntun dan menunggu revisi sebelumnya
sebelum menulis berikutnya. Form menyisakan stok di saldo awal nol setelah
registrasi Sunco, lalu meminta jumlah sebelum membuat baris penerimaan.
Pencarian manual berpaginasi, tombol kurang dan Undo mempertahankan basis
harga dan unit. Konfirmasi akhir menyimpan 15 Marie Roma, 12 Hit dan 20 Sunco
sekali saat diulang. Semua scan uji berasal dari driver IME host.

Regresi 37/37 lulus dalam 1:15. Pada run sebelumnya, fixture overflow lama
memakai harga beli setara harga jual. Koreksi fixture mempertahankan overflow
yang diuji dan mengikuti aturan harga M5.4. Audit lokalisasi 1629/1013/245.
Capability pembayaran pada konfirmasi penerimaan, relasi banyak supplier,
reservasi, lampiran, dan acceptance perangkat tetap terbuka.

## Tahap 4 · pembayaran awal gudang · skema 45

Capability gudang hanya berlaku pada pembayaran awal tagihan yang dibuat
dalam transaksi konfirmasi draft penerimaan. Uji membuktikan retry tidak
menggandakan pembayaran, sesi laci yang salah membatalkan seluruh konfirmasi,
dan pembayaran bank tidak menggerakkan laci. Pelunasan tagihan yang sudah
terbit dan koreksi tetap memerlukan pemilik. Skema menambah peran pencatat
aktual secara aditif dan pembaca pembayaran menampilkan peran tersebut.

Sebanyak 43 kasus host unik lulus melalui regresi dan tes ulang. Run pertama
mencatat 40 lulus, satu path suite portable keliru, dan satu fixture migrasi
yang menyalin kolom garansi baru ke skema lama. Fixture diperbaiki untuk
memeriksa seluruh kolom asli. Migrasi lulus dan dua kasus portable lulus.
Analyzer bersih. Audit lokalisasi 1630/1012/245. APK debug biasa
terverifikasi untuk tiga ABI dan alignment 16 KiB tanpa instalasi.
Lanjut ke relasi produk dengan beberapa supplier.

## Tahap 4 · relasi produk dan supplier · skema 46

Migrasi 45→46 mengisi relasi utama lama dan mempertahankan baris produk.
Satu produk dapat memiliki beberapa relasi master, termasuk tanpa supplier
utama. Filter gudang dan potensi memeriksa semua relasi. Pengelompokan
potensi memakai satu supplier utama opsional per produk, sehingga nilai
total tetap unik. Supplier aktual penerimaan tetap pada nota.

Regresi mencakup 23 kasus host unik melalui run dan tes ulang. Kasus SQL
membuktikan nilai stok tunggal, migrasi, relasi arsip dan penolakan backup
yang kehilangan relasi utama. Tes UI 320 px skala 2 memverifikasi pemilihan
dan pelepasan supplier lewat chip. Perbaikan fixture mempertahankan harga
beli di bawah eceran, versi uji 36→37, dan tombol Edit eksplisit. APK debug
biasa lulus verifikasi tiga ABI dan alignment 16 KiB tanpa instalasi.
Reservasi retur, karantina, lampiran, acceptance dan handoff masih terbuka.

## Tahap 4 · reservasi batch dengan nota · skema 47

Draft yang bersumber dari nota menahan kapasitas sumber dan batch, tanpa
mengurangi stok fisik atau nilainya. Checkout dan pengeluaran umum memakai
unit bebas. Migrasi menyimpan draft lama yang tumpang tindih dan meminta
review untuk membuat reservasi. Batal melepaskan reservasi. Konfirmasi
melepaskan reservasinya dan mengurangi stok dalam transaksi yang sama.
Untuk barang untracked, UI meminta jumlah fisik yang disiapkan.

Regresi 26 kasus host lulus sebelum satu tes fixture migrasi opname lama
diulang dan lulus pada target yang dimaksud, skema 29. Dua kasus reservasi
dan migrasi draft juga lulus dalam tes ulang terfokus. Analyzer bersih.
Audit lokalisasi 1635/1016/245. Build debug biasa
lulus verifikasi tiga ABI dan alignment 16 KiB tanpa instalasi. Draft
karantina lintas supplier, asal belum diketahui, penyerahan parsial dan
acceptance perangkat masih terbuka.

## Tahap 4 · karantina dan penyerahan parsial · skema 48

Supplier tujuan dapat berbeda dari supplier pada nota. Sumber unit dibatasi
oleh batch, karantina retur pelanggan, atau hasil hitung fisik yang tersimpan.
Lima unit karantina terbagi menjadi tiga untuk supplier A dan dua untuk
supplier B. Penyerahan parsial menahan sisa di draft atau melepasnya saat
ditolak. Reversal memulihkan kapasitas dan memeriksa perubahan stok dependen.
Asal yang belum diketahui tetap tidak membuat nota atau tagihan baru.
Klaim kredit jalur tanpa nota tersimpan sebagai tertunda. Persetujuan dan
alokasi klaim ini ke ledger belum tersedia. Retur berbasis nota tetap memakai
alur kredit supplier yang sudah ada.

Regresi host 28/28 lulus, termasuk checkout, backup portable, barcode dan
UI 320 px skala 2. Tes UI awal gagal menemukan field atau baris yang belum
terbangun pada daftar lazy. Tes akhir menggulir dan memeriksa data aktual.
Analyzer bersih, lokalisasi 1660/1031/245. APK debug biasa tiga ABI dan
alignment 16 KiB lulus verifikasi tanpa instalasi. Kamera fisik, acceptance
dan handoff terbuka. Pekerjaan berikutnya foto nota dan sisa tahap 4.

## Tahap 4 · foto nota supplier · skema 49

Gudang mengelola halaman draft dalam revisi penerimaan yang sama. Pembatalan
menghapus halaman draft secara atomik. Setelah posting, pemilik dapat membaca
halaman yang sudah final. SQLCipher menyimpan JPEG langsung di database.
Kamera memakai seluruh frame preview berorientasi dari jalur kamera privat,
dengan maksimal 8 halaman dan 768 KiB per halaman. Rotasi tersimpan sebagai
metadata, dan validasi backup memeriksa format, dimensi, ukuran dan hash per
halaman. Fixture portabel kini memiliki satu halaman foto.

Dua tes foto dan dua tes fixture portabel lulus pada run ulang 45 detik.
Run regresi terkait meluluskan 16 kasus sebelum dua kegagalan kompilasi pada
fixture portabel. Referensi skema fixture diperbaiki sebelum run ulang.
Analyzer bersih, formatter tanpa perubahan, audit lokalisasi 1674/1044/245
dan audit PIN 106 cocok. APK biasa 0.5.4+14 terverifikasi untuk tiga ABI dan
alignment 16 KiB. APK belum dipasang. Keterbacaan kamera fisik dan restore
native berfoto tetap terbuka untuk acceptance.

## Tahap 4 · histori pembelian dan regresi opname · skema 50

Detail produk membuka histori pembelian terpisah. Sumber tanggal dan jam
adalah header nota dalam zona toko. Baris menampilkan jumlah dan satuan
input, konversi pcs, harga per unit input, supplier, serta detail total dan
batch/kedaluwarsa. Stok awal, opname dan perubahan tracking bukan pembanding
pembelian. Tren membandingkan total dibagi pcs secara eksak dengan penerimaan
berbiaya diketahui sebelumnya dalam currency yang sama. Dokumen reversal
tetap terlihat. Indeks turunan ditambahkan tanpa mengubah fakta lama, dan
backup memeriksa indeks tersebut terhadap nota. ID baris memecahkan timestamp
yang sama secara deterministik.

Sebanyak 24 kasus host unik lulus melalui regresi dan tes ulang. Run awal
meluluskan 23 dan satu fixture backup mencapai timeout 30 detik. Kedua mode
fixture backup kemudian lulus dalam 38 detik pada run terpisah dengan batas
dua menit per tes. Tes mencakup migrasi 49 ke 50 serta regresi opname service
dan widget, termasuk 0 eksplisit, input manual, scan simulasi dan batch.
Audit lokalisasi 1685/1046/245 lulus. APK biasa 0.5.4+14 lulus verifikasi
tiga ABI dan alignment 16 KiB tanpa dipasang. Scanner fisik dan acceptance
native tetap terbuka.
Analyzer lulus tanpa masalah dalam 126,7 detik.

## Tahap 4 · sort Gudang dan Favorit Kasir · skema 51

Gudang mempertahankan Prioritas stok sebagai default. Nama, Terakhir diubah,
dan Paling laku memiliki arah dan cursor sendiri. Filter tetap digabung.
Gudang dan Kasir berbagi cache rolling 30 hari. Retur mengurangi unit, dan
struk yang tidak menyisakan unit produk keluar dari hitungan frekuensi produk.
Reversal lama tetap dikecualikan. Migrasi menandai cache lama untuk dibangun
ulang. Tes query plan 1.000 produk dan 2.000 penjualan memeriksa indeks periode
penjualan dan lookup baris retur.

Favorit menampilkan paling banyak delapan produk dari cache yang sama setelah
menyaring arsip, kedaluwarsa, stok habis dan reservasi. Tombol ada di bawah
pencarian. Satu pilihan menambah satu pcs melalui keranjang aktif dan kembali
ke tombol Favorit sesudah panel ditutup. Draft dan teks pencarian dipertahankan.

Regresi dan tes ulang mencakup 30 kasus host unik. Fixture sort diperbaiki agar
mengakui struk sebelum penjualan berikutnya. Uji widget awal menemukan kolom
pencarian di luar viewport dan fokus kembali terlalu dini setelah menutup panel.
Posisi tombol, helper scroll yang mengenali elemen di luar area lukis, dan
waktu pemulihan fokus diperbaiki. Kedua locale lulus tes ulang dalam 9 detik.
Audit lokalisasi 1693/1049/245 dan audit PIN 106 cocok. Acceptance perangkat
untuk skema ini terbuka.
Analyzer akhir bersih. APK biasa 0.5.4+14 dengan perbaikan fokus terverifikasi
pada tiga ABI dan alignment 16 KiB tanpa instalasi.

## Tahap 4 · pencarian, daftar dan histori member · skema 52

Checkout mencari prefix nama atau nomor HP dan membersihkan saran yang
tertunda ketika pilihan member berubah. Daftar pemilik menambah filter
saldo piutang efektif dan sort Nama, Terakhir ditambahkan, Kunjungan
terbanyak, dan Utang terbanyak. Nama membuka histori. Edit dan Pulihkan
memiliki aksi terpisah.

Histori mengurutkan penjualan, reversal, retur, refund, dan pembayaran
piutang berdasarkan waktu dan ID. Ringkasan pembelian bersih mencakup
seluruh periode penjualan yang dipilih, memperhitungkan retur terhadap
penjualan tersebut, dan menampilkan saldo piutang saat ini. Pelunasan
tidak menambah kunjungan.

Regresi gabungan mencatat 42 eksekusi lulus termasuk kasus yang sama pada
runner berbeda. Empat kegagalan widget berasal dari dua kasus locale yang
dijalankan pada dua runner. Finder dibatasi pada layar histori dan harness
menunggu I/O reload sesudah keluar dari form. Kedua kasus lulus tes ulang
dalam 17 detik. Analyzer bersih, audit lokalisasi 1708/1055/245 dan APK
biasa tiga ABI/alignment 16 KiB lulus tanpa instalasi. Acceptance native
terbuka.

## Tahap 4 · hapus permanen arsip terproteksi · skema 53

Barang, kategori, supplier, dan member yang sudah dimuat memiliki mode
pilih dengan cakupan eksplisit. Pemilik meninjau nama dan alasan per item
sebelum konfirmasi dan PIN ulang. SQL memeriksa semua foreign key yang
mengarah ke master serta audit terkait di dalam transaksi. Alias, relasi
master milik produk, dan cache produk terpilih dapat dilepas saat produk
eligible dihapus. Fakta dan audit historis dipertahankan. Rak dan promo
memiliki layar aktif tersendiri tanpa daftar arsip pada UI saat ini.

Regresi host 11/11 lulus. Tes fokus service dan widget 2/2 lulus, dengan satu
kasus service merupakan pengulangan. Bukti mencakup batal sebelum PIN,
cakupan halaman, saldo member nol dengan sejarah penjualan, perubahan
dependensi, FK dan rollback. Audit lokalisasi 1721/1066/245 dan audit PIN 106
cocok.

Arahan 8 November 2026 memindahkan Realme C11 M5.3 dan M5.4 ke sebelum
handoff. Beri kabar dan jeda pada batas sebelum memasang `.skybee` atau
membuat APK eksternal. Gunakan paket fixture terisolasi di serial Realme
yang telah dikonfirmasi.
Analyzer akhir bersih. APK biasa 0.5.4+14 terverifikasi pada tiga ABI dan
alignment 16 KiB. APK belum dipasang.

## Tahap 4 · persetujuan kredit penyerahan · skema 54

Pemilik dapat menyetujui nilai kredit pada penyerahan dengan klaim tertunda,
termasuk asal yang belum diketahui. Persetujuan menambah saldo kredit.
Alokasi tagihan atau pencatatan uang diterima tetap aksi terpisah. Reversal
fisik memerlukan pembalikan kredit aktif beserta transaksi turunannya.
Migrasi mengganti kolom referensi asal dengan FK opsional ke retur lama dan
FK opsional ke penyerahan, dengan tepat satu asal serta ID ledger tetap.

Tes migrasi populasi skema 53 lulus. Regresi 27/27 lulus dan skenario UI
dites ulang dengan klaim dan persetujuan eksplisit. Fixture backup membawa
kredit penyerahan dan reservasi tersisa. Analyzer bersih, lokalisasi
1724/1067/245 lulus. APK debug biasa 0.5.4+14 lulus tiga ABI dan alignment
16 KiB. Tahap 4 selesai di host. Tahap 5 dimulai dari lembar pemulihan PDF.

### Tahap 5 dan sambungan perangkat

Pada 8 November, ADB SDK dan `C:\platform-tools\adb.exe` sama-sama
menampilkan Poco F6 dan DV8910 `192.168.0.101:5555`. Model DV dilaporkan
`AX810` dan identitas perangkat `DV8947-KIX`. SELinux kedua perangkat
`Enforcing`. Cuplikan awal hanya mencatat Poco sesaat setelah daemon
ADB mulai. Penyebab transport TCP belum muncul saat itu belum terbukti.
Tidak ada perubahan konfigurasi koneksi. Realme C11 belum muncul dalam
daftar saat pemeriksaan ini.

PDF memakai Android `PdfDocument` dengan layout A4 serta FileProvider
privat. Pilihan simpan memverifikasi hasil tulis dan pilihan bagikan
memberi izin baca sementara. Keduanya memerlukan PIN pemilik khusus.
Pemindai QR pemulihan hanya tersedia di alur pemulihan dan UUID toko
diperiksa terhadap manifest arsip terautentikasi. Uji pertama di Poco
menemukan buffer balikan kanal Android tidak dapat diubah. Salinan
milik aplikasi kini digunakan untuk pembersihan buffer. Audit uji
pertama mencatat semua hash berkas yang dilindungi tetap sama.

Tren laporan memakai bucket zona waktu toko, awal minggu Senin,
agregat SQL berindeks, dan cache halaman berdasarkan revisi. Grafik,
tabel, ringkasan dan ekspor memisahkan kerugian karantina dari HPP
dan memakai tanggal posting retur. Profil label menyimpan pilihan
QR atau Code 128. Barcode lama tetap literal, termasuk nol di depan.
Media Code 128 ditolak bila tidak muat pada dua titik per modul.

Regresi terfokus Windows lulus 40 kasus. Pembacaan mandiri CSV dan
OpenXML memverifikasi 132 baris fixture dasar, presisi nominal, nol
di depan barcode, dan sel formula literal. Kasus tambahan memeriksa
ekspor tren lintas halaman, periode kosong, biaya tidak lengkap, serta
batas minggu/bulan/tahun dan DST. Analyzer bersih, 1.767 kunci ID/EN
sesuai, dan 106 hash lisensi/sumber PIN cocok.

Fixture keluaran Poco lulus 13 kasus. Dua PDF sintetis A4 dirender
masing-masing satu halaman, diperiksa visual pada 144 dpi dan
payload-nya dibaca tepat oleh ZXing. Raster ESC/POS QR dan Code 128
58/80 mm dibaca oleh ZXing Android. Rencana SQL berindeks, ekspor,
pembatalan dan SDK Drive tiruan juga lulus. Kontrol otomatis ditutup
dan semua hash berkas terlindungi yang sudah ada tetap sama. Manifest
sumber 974 berkas cocok sebelum dan sesudah uji
`35d0a7282cff127bf5a3180a54c2ee87db6f4241585219a891d28697db454f3a`.
Cadangan lintas kunci, keluaran DV, uji fisik dan Drive nyata masih
terbuka. Uji host pengaturan lama diulang secara terfokus sesudah
koreksi fixture retensi, pesan validasi kode, dan waktu tunggu.
Cakupan fisik dan portable restore native akan diuji pada acceptance.
