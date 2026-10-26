# Spesifikasi pengembangan aplikasi kasir Flutter

26 Oktober — klarifikasi pengguna: Back terkunci dengan form berubah tetap
memunculkan peringatan generik. Tetap terkunci atau buang dan kembali ke Kasir;
tidak commit, tidak membuka data tanpa autentikasi, cart/tender tetap.
[Keputusan dan acceptance](decisions/M53_LOCKED_BACK.md).

26 Oktober 2026 — M5.3 aktif sesuai [kontrak pengguna](decisions/M53_REQUEST.md).
Cakupan A–H mencakup onboarding/preferensi/stok/biaya, akses terpisah, kasir/member,
kas fisik, gudang/supplier/utang/jadwal, output/laporan dan keselamatan data.
M5.4/M5.5/M6 tetap terpisah. Ketentuan lama yang bertentangan digantikan kontrak
ini; data eksplorasi wajib dipertahankan. Progres dan batas pada [checkpoint](M53_CHECKPOINT.md).

Koreksi langsung25Oktober2026: profil tanpa footerFeedVersion yang membawa feed6 (default lama) dibaca sebagai3, termasuk sesudah restart. Nilai lama selain6 tetap. Simpan berikutnya menandai versi sehingga pilihan manual0–8, termasuk6, tetap berlaku. Snapshot job yang sudah disiapkan tidak dinormalisasi; tidak ada rewrite SQL/data bisnis. Data lama tidak membedakan default6 dan pilihan manual6; aturan kompatibilitas ini khusus mengikuti koreksi pengguna. Menggantikan kebijakan mempertahankan bottom6 lama pada catatan sebelumnya.

Tambahan langsung25Oktober2026: sesudah perbaikan cetak, pengguna meminta
feed sebelum header manual/default3 dan pilihan protokol seperti referensi
OpenLabel. Implementasikan ESC/POS Raster/Kolom, TSPL dan CPCL sesuai kontrak
[dukungan protokol](PRINTER_PROTOCOLS_20261025.md). Tidak mengklaim seluruh
merek/protokol proprietary/BLE pada screenshot. Ini perluasan yang diminta
langsung, bukan aktivasi otomatis milestone lain. Profil/snapshot/transaksi
lama dipertahankan, hardware tambahan dicatat unverified.

Tindak lanjut bug25 Oktober2026: output 80 mm MHT-P29L Bluetooth harus mengirim
seluruh raster dan footer dalam satu dokumen tanpa ekor dari job sebelumnya.
Kontrol laju/finalisasi tidak boleh menjadi retry, cutter, pergantian codepage,
atau perubahan transaksi. Profil/lebar/feed tersimpan tetap milik pengguna.
Keberhasilan transport tetap bukan bukti kertas; kalibrasi fisik dicatat terpisah.
Dukungan banyak printer mengikuti protokol/kemampuan, bukan daftar merek.
Tidak ada cabang encoder berdasarkan MHT-P29L. ESC1/ESC2 OpenLabel belum diuji
oleh pengguna dan bukan pemetaan protokol terverifikasi; CPCL/TSPL/BLE tidak
ditambahkan pada scope bugfix awal. Sesudahnya pengguna mengotorisasi
TSPL/CPCL sebagaimana kontrak lanjutan di atas; BLE tetap belum ditambahkan.
Tambahan25Oktober sesudah hasil cetak utuh: ruang kosong akhir struk dapat
diketik manual0–8baris atau−/+, tersimpan per printer;0tanpa tambahanfeed.
Default baru/reset template3baris mengikuti instruksi langsung pengguna.
Kebijakan kompatibilitas legacy6 mengikuti koreksi langsung di atas;
jarak fisik kepala cetak tidak dijanjikan dapat dihilangkan oleh feed0.

Penutupan validasi 24-10-2026 00:19 WIB: verifikasi sesudah temuan Realme dibatasi pada perubahan yang relevan. DV/Poco masing-masing satu kasus migrasi PASS; source fitur dan kebutuhan tetap. Tidak ada fitur dihapus atau downgrade. Batas audit DV terdahulu dicatat pada [Laporan lengkap](REALME_C11_RESUME_20261023.md).

Klarifikasi24Oktober2026: ketersediaan DV/Poco untuk verifikasi berarti hanya
kasus yang terdampak perbaikan temuan Realme, bukan pengujian ulang suite lama.
Tidak memperluas fitur atau tahap. Poco suite60 tidak dijalankan.

Verifikasi tambahan23Oktober: DV8910 dan Poco F6 tersedia sesudah perubahan
Realme. Pengujian terisolasi mempertahankan data/aplikasi Skybee uji mandiri;
tidak mengubah kebutuhan fitur atau mengaktifkan tahap berikutnya.

Instruksi pengujian23 Oktober2026: Realme C11 dilanjutkan dari checkpoint lama
sampai perubahan M5.2 terbaru, otomatis tanpa acceptance manual. Pengguna
menangani izin/setting/reboot bila dibutuhkan; jangan menghapus fitur atau
downgrade demi tes. Bila alternatif tersebut diperlukan, cukup laporkan hasil
dan alasan di laporan akhir. Kebutuhan fitur tetap; M5.3–M6 belum dimulai.

Penutupan22 Oktober2026: implementasi/pemeriksaan tersedia M5.2 A–H dan handoff
Skybee0.5.2+9 selesai. Scope/keputusan tetap mengikuti kontrak22request, tidak
mengaktifkan M5.3–M6. Data eksplorasi dipertahankan; pengguna mengonfirmasi
fingerprint Kelola berhasil. Konfigurasi biometrik tetap aktif, tidak dihapus
untuk smoke PIN; hanya route debug sementara menonaktifkan auto-biometrik.
Lihat [hasil aktual dan batas](M52_REPORT.md).

Audit upgrade debug Skybee memegang satu lease dari pembacaan schema lama,
prepared proof, migrasi sampai verifikasi selesai. Worker debug tidak membuka
DB sebelum seed/foreground proof lengkap. Untuk insiden upgrade pertama M5.2,
pemulihan terarah hanya menerima perubahan monotonik pada
`m5_store.alert_generation` dan `alert_state.evaluation`, setelah ciphertext
snapshot asli cocok dengan seluruh prepared proof. Seluruh baris dan kolom
lama lainnya wajib identik. Proof membedakan fakta bisnis yang cocok dari dua
metadata berubah; tidak reset, mengubah preferensi, atau menulis ulang data.
Aturan ini khusus launcher debug Skybee, bukan kelonggaran restore umum.

Keputusan kalibrasi22 Oktober2026: setelah sampel Iware58 Bluetooth feed6/2
utuh dan feed3dicetak sekali atas permintaan tambahan, pengguna memilih **feed3
yang terbaik**. Opsi coba pada profil58mm menjadi Iware58/3baris; perubahan
hanya mengisi form profil saat diketuk, tetap memerlukan Simpan. Default aman6
untuk profil umum dan seluruh saved profile tidak dimigrasikan otomatis.

Catatan implementasi M5.2: nama rak diselesaikan melalui ID stabil saat write;
rename menaikkan revision produk agar draft lama tidak menimpa label baru.
Migrasi13→14 tetap aditif, label/snapshot historis tidak dinormalisasi ulang.
Calendar memakai `showDatePicker` bawaan Flutter (tanpa plugin kalender baru).
Output telepon mencakup detail piutang; input kontak tetap editor. Lihat
[laporan dan batas pemeriksaan](M52_REPORT.md).

Tambahan langsung pengguna22 Oktober2026: output nomor telepon dapat diketuk
untuk membuka WhatsApp pada nomor kanonik; outputwebsite membuka browser pada
URLhttp/https tervalidasi. Input tetap editor, tanpa membuka app/website saat
mengetik. Hanya tap eksplisit membuka tujuan, tidak mengirim pesan otomatis.

Syarat handoff terbaru22 Oktober2026: uji DV8910 sebelum commit/push dan
pemasangan update debug Skybee terpisah. Pengguna memperbaiki otorisasi DV;
implementasi serta pemeriksaan host/Poco dapat berlanjut.

**22 Oktober2026 — M5.2 AKTIF berdasarkan instruksi unggahan pengguna:**
M5.2 kini perbaikan operasional A–H, bukan redesign. M5.3 planned/scope belum
ditetapkan, M5.4 masukan penggunaan nyata, M5.5 desain visual, M6 rilis/legal.
Kontrak lengkap [M52_REQUEST](decisions/M52_REQUEST_20261022.md), checkpoint
[CURRENT_HANDOFF](CURRENT_HANDOFF.md). Data eksplorasi `.skybee` dipertahankan;
input jumlahawal kosong menyimpan999+flag untracked, biaya acuan snapshot, promo
quantity hanya retail. Commit/push biasa origin/main dan update Skybee setelah
pemeriksaan diotorisasi; tidak force-push/reset/reseed. Checkpoint lama tentang
M5.2 menunggu desain dipertahankan sebagai histori.

Addendum21 Oktober2026 — handoff demo terpisah yang diminta pengguna:
`skybee kasir` memakai package debug `com.example.kasir_app.skybee`, toko
`toko skybee`, PIN dummy pilihan pengguna,100barang dengan variasi kondisi dan
fakta pendukung melalui service. Tidak mengganti identitas ordinary. Seed hanya
sekali di sandbox baru, tidak menimpa data pengujian selanjutnya. Pengguna
menguji mandiri; tidak menunggu laporan hasil atau menjadwalkan follow-up.
[Kontrak/implementasi/bukti](SKYBEE_DEMO_HANDOFF_20261021.md).
Bukan M5.2/M6 atau perubahan identitas rilis.

## Addendum aktif M5.1 / M5.2 — 19 Oktober 2026

Klarifikasi printer20 Oktober2026: pengguna meminta ruang kosong agar footer
mencapai area sobek/potong. Source default feed profil baru menjadi6baris;
kalibrasi tersimpan tetap dipakai (saved3 tidak diubah diam-diam). Footer
diagnostik terlihat setelah tambahan3LF, sebelumnya dilaporkan belum tercetak;
posisi versus flush belum dipastikan. Regresi host/native feed6 kini PASS;
build debug/release0.5.1+8 dan handoff ordinary Poco selesai21 Oktober2026.
Paper baru default6 belum diuji. Lihat [laporan akhir](M51_FINAL_REPORT_20261021.md).
Bukan redesign M5.2.

Kebutuhan baru setelah acceptance M5: [kontrak lengkap A–G](decisions/M51_REQUEST_20261019.md).
M5.1 mencakup metadata ukuran desimal eksak/rak/catatan (bukan penjualan timbang),
biometrik Class3 dan kebijakan sesi, cetak recovery nonpersisten, numpad/tender/
kembalian, ekspor CSV/XLSX, transport USB Host, dan maintenance SQLCipher saat
idle setelah backup valid. Pada19Oktober M5.2 masih planned; kontrak22Oktober
mengaktifkan operasional A–H dan memindahkan desain ke M5.5. M6 tetap rilis/
legal/identitas/Play. Aturan baru menggantikan bagian lama hanya dalam cakupan
tersebut. M5 tidak dibuka kembali atau dinyatakan gagal oleh kebutuhan baru.

Checkpoint A: schema9 menambah size_milli (thousandths, positif sampai
999999999999), size_unit g/kg/ml/l, shelf_location80 dan product_note1000
karakter Unicode. Nilai/unit kosong bersama menjadi null. Input desimal ID koma/
EN titik, maksimal3digit pecahan tanpa grouping. Metadata hanya keterangan,
stok/harga/HPP tetap pcs. Snapshot nullable pada sale_transaction_items menjaga
fakta lama; catatan/rak tidak masuk payload struk. Kontrak lain A–G tetap aktif
meskipun belum diimplementasikan, lihat laporan checkpoint.


Checkpoint B: schema10 management_policy legacy/1m/5m/15m/immediate.
Upgrade menjaga kunci background+idle5menit; fresh install immediate+idle5menit.
Timed grace memakai idle termasuk background, resume tidak memperpanjang;
keyguard/manual lock/restart/PIN/restore tidak dilampaui. Fresh proof sensitif
terikat purpose dan60detik, scoped dialog juga dibatasi generation/deadline.
Class3 CryptoObject per-use/binding lokal terpisah dari SQLCipher/backup;
PIN aplikasi tetap alternatif, tidak menerima weak face/device credential.
Biometrik fisik belum diuji; kode/hasil otomatis dirinci pada checkpoint.


Checkpoint C: cetak kode tersimpan opsional sesudah konfirmasi penyimpanan awal,
melalui fresh auth dan konfirmasi printer/rahasia. Claim60detik satu operasi,
antrean output satu dokumen tanpa persist payload recovery. Mutex output juga
melindungi koneksi manual dan restore; tidak auto retry/fallback. Snapshot struk
pelanggan tidak membawa kode. Key64hex/arsip M5 tetap kompatibel. UI catatan
salinan tersimpan hanya event konfirmasi tanpa isi. QR/mnemonik belum dibuat.


Checkpoint F: schema11 menambah transport profil default Bluetooth untuk data
lama, cursor50 terfilter transport/BINARY. USB Host optional memakai printer
class7/subclass1/protocol1/2/BULK_OUT, izin dan perangkat eksplisit, identitas
attachment/serial unik yang tidak ambigu, output gate lintas engine dan tanpa
retry/fallback otomatis pada hasil ambigu. Adapter di source; diagnostik USB DV
81byte lulus otomatis dan lima baris kertas PASS dilaporkan pengguna. Raster
41717byte/11chunk kemudian diterima; logo/barang/nominal sesuai reported,
footer baru terlihat setelah tambahan3LF. Default6 hanya teruji otomatis;
paper default6/fault fisik belum terverifikasi. Hasil DV0target lama tetap historis,
bukan PASS cetak. Detail/bukti:
[USB Android](M51_USB_ANDROID.md).

Checkpoint D/E/G,20 Oktober2026: implementasi schema12/13 tersedia. D memakai
numpad internal/raw canonical dan CashTender received/applied/change/debt;
konfigurasi maksimum8nominal per currency, input kosong ditolak, tindakan hutang
nol eksplisit. Tender immutable atomik bersama checkout, legacy tidak dibackfill.
E mengekspor snapshot laporan M4 dalam satu read transaction, keyset100row,
CSV UTF8BOM aman formula dan XLSX identifiers/uang sebagai text eksak. SAF laporan
dua fase, PIN setelah pemilih lokasi lalu aksi Tulis eksplisit/readback digest;
cancel mencapai native stream. G menunggu backup valid, idle+charging/delay6jam,
lease backup-work→DB tanpa menunggu, threshold1024free pages/25%, cooldown7hari
sukses/1hari attempt, ruang2×DB+32MiB. VACUUM tidak prune/rekey; checkpoint WAL
tanpa menunggu reader dan ukuran berkas fisik diverifikasi. Status lokal/reset
sesudah restore. Kontrak/bukti dan batas fisik pada
[D/E/G](M51_CASH_REPORT_EXPORT_MAINTENANCE.md). Catatan saat itu M5.2 menunggu
desain; scope aktif22Oktober mengikuti kontrak operasional di atas.

Bangun proyek Flutter lengkap untuk aplikasi kasir, persediaan barang, dan pencatatan piutang pelanggan. Saya seorang programmer dan menggunakan Android Studio. Saya akan memakai aplikasi ini di toko pribadi, memperbaikinya berdasarkan penggunaan nyata, lalu mempertimbangkan rilis di Google Play.

Prioritas produk adalah kemudahan penggunaan: buka aplikasi, cari/scan barang, susun belanja, dan selesaikan transaksi. Fitur opsional muncul saat diperlukan. Aturan data dan perhitungan harus tetap benar tanpa membebani pengguna dengan istilah teknis.

Target utama adalah toko kecil dan minimarket. Toko besar atau supermarket boleh menggunakan aplikasi jika menerima kemampuan dan batasannya. Jangan membatasi penggunaan berdasarkan ukuran toko, menambahkan hard limit jumlah produk/transaksi tanpa alasan teknis, atau mengklaim aplikasi mempunyai kemampuan enterprise yang belum tersedia.

Dokumen ini adalah spesifikasi lengkap hasil akhir, untuk disimpan sebagai `docs/SPEC.md` di proyek. Instruksi eksekusi singkat menentukan tahap yang sedang diminta; spesifikasi keseluruhan tetap menjadi acuan untuk menghindari keputusan yang menyulitkan tahap berikutnya. Jika diminta satu tahap, selesaikan implementasi dan pemeriksaan tahap tersebut lalu laporkan hasilnya, tanpa otomatis mengerjakan tahap lain. Jika diminta seluruh proyek, gunakan milestone dan checkpoint, bukan satu keluaran kode panjang di chat.

Kerjakan implementasi nyata dalam file workspace. Jangan berhenti pada rencana ketika tugasnya meminta implementasi, contoh satu file, pseudocode, atau daftar saran. Pertahankan pekerjaan dan data yang sudah ada. Untuk informasi yang belum tersedia, pilih default yang aman dan dokumentasikan; lanjutkan bagian yang tidak bergantung pada informasi tersebut. Minta informasi hanya jika benar-benar menghalangi keputusan penting. Jangan menganggap integrasi atau pengujian berhasil jika belum dapat dijalankan.

## 1. Teknologi dan batas operasional

- Gunakan Flutter dan Dart dengan versi stabil yang kompatibel, Provider untuk state management, dan SQLite terenkripsi SQLCipher melalui adapter kompatibel `sqflite` untuk Android (keputusan M5, 16 Oktober 2026). Cantumkan versi SDK dan dependency yang dipilih beserta alasan pentingnya.
- Target implementasi dan pengujian pertama adalah Android. Struktur UI dan aturan bisnis disiapkan agar dapat digunakan kembali untuk iOS/web, tetapi kemampuan plugin pada platform lain harus dinyatakan sesuai hasil pemeriksaan. Jangan menjanjikan semua fitur lintas platform sudah bekerja.
- Satu toko menggunakan satu perangkat aktif untuk transaksi dan pengelolaan. Beberapa orang boleh bergantian menggunakan perangkat yang sama. Tidak ada sinkronisasi stok antardevice pada versi ini.
- Aplikasi tetap dapat menjalankan fitur kasir dan gudang tanpa internet, akun aplikasi, server, atau akun Google.
- Google Drive adalah backup/restore opsional, bukan database pusat atau sarana sinkronisasi. Tidak menghubungkan Google tidak boleh menghalangi penggunaan aplikasi.
- Bahasa UI Indonesia/Inggris melalui localization resmi Flutter, dengan pilihan tanpa PIN dan persistensi; ikuti perangkat id/en pada awal, fallback Inggris. Mata uang default IDR scale 0 (kebijakan rupiah bulat), pilihan USD/MYR/EUR scale 2 melalui Pengaturan terproteksi hanya sebelum ada data keuangan. Number locale mengikuti bahasa secara eksplisit id_ID/en_US, terpisah dari currency dan zona waktu. Jumlah barang tetap unit bulat tanpa konversi dus/kilogram/pecahan. Rincian kontrak ada pada bagian 18.
- Zona waktu toko dapat dikonfigurasi, default Asia/Jakarta. Simpan waktu transaksi secara konsisten dan gunakan zona waktu toko untuk laporan, batas hari, kedaluwarsa, dan jadwal backup. Tanggal kedaluwarsa adalah tanggal kalender, bukan timestamp yang bergeser karena konversi UTC.

## 2. Struktur kode dan dokumentasi pemeliharaan

Pisahkan UI/widget, Provider, aturan bisnis/service/use case, repository, serta implementasi database dan integrasi perangkat. Gunakan struktur modular yang sesuai ukuran proyek. Hindari satu `main.dart` atau satu Provider raksasa, tetapi jangan membuat abstraksi yang tidak mempunyai kegunaan nyata.

Provider menyimpan keadaan layar dan menghubungkan UI dengan service. Checkout, restock, pelunasan, dan pembatalan transaksi dikerjakan oleh aturan bisnis yang dapat diuji. SQL dan akses plugin tidak ditanam langsung di widget. Gunakan `Consumer`, `Selector`, atau mekanisme Provider yang sesuai untuk membatasi rebuild.

### Batas tanggung jawab Provider

Larangan satu Provider raksasa merupakan aturan arsitektur, bukan sekadar anjuran tentang panjang file. Jangan membuat `AppProvider`/`StoreProvider` yang sekaligus mengurus keranjang, pencarian, master barang, transaksi, hutang, laporan, PIN, printer, dan backup. `MultiProvider` boleh digunakan sebagai composition root untuk dependency injection; itu tidak berarti semua state digabung menjadi satu object.

Pemisahan berikut menjadi acuan. Nama dapat disesuaikan dengan alasan yang terdokumentasi, tetapi batas tanggung jawabnya harus dipertahankan:

| State/controller | Tanggung jawab |
| --- | --- |
| `CartProvider` | Keranjang/draft, quantity, total tampilan, dan undo perubahan keranjang |
| `ProductSearchProvider` | Query, debounce, hasil suggestion terbatas, loading/error, dan penolakan hasil async usang |
| `CheckoutProvider` | Form pembayaran, pelanggan terpilih, status submit, dan hasil checkout |
| `InventoryProvider` | State layar gudang, filter, cursor halaman, dan pemanggilan operasi persediaan |
| `ReceivablesProvider` | Daftar/detail piutang dan state pencatatan pelunasan |
| `SaleHistoryProvider` | Filter, halaman, dan detail transaksi penjualan |
| `ReportsProvider` | Periode/filter laporan, ringkasan, dan halaman rincian |
| `ManagementSessionProvider` | Status akses pengelolaan dan kedaluwarsa sesi |
| `SettingsProvider` | State formulir pengaturan toko dan konfigurasi fitur |

- Satu state memiliki satu pemilik; jangan menduplikasi keranjang di CheckoutProvider atau seluruh katalog di beberapa Provider.
- Gunakan scope/lifecycle yang sesuai: state kasir/draft bertahan sesuai alurnya; state layar riwayat/laporan dapat dilepas saat layar ditutup. Buka Provider yang diperlukan secara lazy, bukan seluruh fitur aktif sejak startup.
- SQL, pembukaan transaksi database, rumus valuasi/HPP, hashing, upload, dan transport Bluetooth menjadi tanggung jawab service/repository. `CheckoutService` dapat mengoordinasikan beberapa domain dalam satu transaksi database; koordinasi itu tidak dipindahkan ke Provider global.
- Dependensi shared seperti koneksi database, repository, atau service tidak dilarang. Hindari circular dependency antar-Provider dan efek notifikasi yang memicu loop.
- Widget hanya berlangganan state yang diperlukan. Perubahan teks pencarian tidak membangun ulang seluruh keranjang; perubahan quantity tidak menjalankan ulang laporan/gudang. Pastikan nilai yang dipilih Selector dapat dibandingkan dengan benar, misalnya snapshot immutable.
- Setelah commit, lakukan refresh/invalidation pada data yang terdampak secara terarah. Provider bukan sumber kebenaran stok atau piutang; database dan aturan bisnis tetap menjadi sumber kebenaran.

Saya ingin mudah memahami dan mengelola kode:

- Tambahkan catatan singkat pada file/modul utama: tujuan, tanggung jawab, dependensi penting, dan aliran data.
- Gunakan Dartdoc `///` untuk API publik dan operasi bisnis penting; jelaskan parameter, hasil, validasi, exception, serta efek pada data jika relevan.
- Beri komentar pada logika yang tidak jelas: transaksi atomik, snapshot HPP, pembulatan, FEFO, idempotensi, undo, migration, hashing PIN, backup konsisten, dan recovery restore.
- Jelaskan alasan suatu aturan, bukan mengulang setiap baris kode. Tidak perlu komentar pada operasi trivial.
- Tandai lokasi konfigurasi tema, format rupiah, printer, backup, PIN, identitas pengembang, dan dokumen legal. Jangan hardcode rahasia atau konfigurasi produksi di widget.
- Buat README dengan struktur proyek, setup Android Studio, cara run/build/test, dan panduan perubahan umum. Tambahkan dokumentasi skema/aturan bisnis, pemeliharaan/migration, integrasi printer/Google Drive, serta persiapan rilis.
- Jelaskan cara menambah kolom melalui migration, mengubah ambang peringatan, memperbarui dokumen legal, dan mengganti integrasi tanpa merusak data.

Siapkan kontrak repository yang wajar untuk API di masa depan, termasuk hasil pagination dan cursor bertipe. Jangan membuat backend atau sinkronisasi palsu pada versi ini.

### Penamaan domain transaksi

Gunakan tabel `sale_transactions` dengan model/domain `SaleTransaction`, serta tabel detail `sale_transaction_items` dengan model `SaleTransactionItem` dan foreign key `sale_transaction_id`. Repository domainnya bernama `SaleTransactionRepository` atau nama setara yang jelas. Gunakan nama yang sama secara konsisten pada SQL, migration, DTO, alokasi pembayaran, alokasi batch, history, test, dan dokumentasi. Jangan memperkenalkan entitas berbeda bernama `Sale`, `Sales`, dan `SaleTransaction` untuk fakta transaksi yang sama.

`SaleTransaction` adalah transaksi bisnis penjualan. Objek transaksi sqflite adalah transaksi database dan harus dibedakan melalui nama variabel/alias seperti `dbTxn`. Penerimaan gudang tetap `StockReceipt`, stok `StockBatch`/`StockMovement`, dan pembayaran `Payment`. Pemisahan domain berasal dari tanggung jawab dan kontrak, tidak hanya nama tabel; checkout boleh mengubah penjualan, persediaan, dan pembayaran secara atomik.

Jika belum ada database produksi, gunakan nama tersebut sejak migration awal. Jika database lama sudah ada, rename/migrate dengan mempertahankan data dan semua relasi/index; jangan drop-recreate tabel secara destruktif.

## 3. Penggunaan pertama dan mode akses

Ada dua mode penggunaan, bukan dua akun yang wajib login:

1. Kasir terbuka tanpa PIN untuk penjualan dan pencatatan pelunasan.
2. Pengelolaan melalui PIN untuk Gudang, Pengaturan, laporan HPP/laba, backup/restore, dan tindakan koreksi penting.

Hanya pada penggunaan pertama, tampilkan penyiapan singkat untuk persetujuan pengguna, informasi toko, dan pembuatan PIN. Nama toko cukup diisi sekali; alamat, WA, logo, dan footer boleh dilengkapi kemudian. Buat PIN baru dengan konfirmasi, jangan memakai PIN default produksi. Setelah penyiapan, setiap pembukaan aplikasi langsung menuju kasir.

PIN:

- Empat digit, diperlakukan sebagai string agar nol di depan tetap berlaku. Input numerik dan checkbox `Tampilkan PIN`, default tersamarkan.
- Simpan hash dengan salt acak memakai KDF yang sesuai, misalnya PBKDF2-HMAC-SHA256 atau Argon2id dengan parameter yang diperiksa terhadap panduan terkini dan diuji pada perangkat target. Jangan menyimpan PIN plaintext atau hanya SHA-256 cepat.
- Terapkan pembatasan percobaan/jeda progresif. State pembatasan tidak boleh hilang hanya karena aplikasi ditutup.
- Verifikasi hak pengelolaan di service/tindakan penting, bukan hanya menyembunyikan tombol. Kunci kembali saat aplikasi masuk latar belakang atau setelah tidak aktif, dengan default sesi pengelolaan lima menit.
- Ubah PIN memerlukan PIN lama atau mekanisme pemulihan yang sah. Sediakan kode pemulihan acak yang kuat, ditampilkan saat penyiapan dan dapat diperbarui setelah verifikasi. Simpan verifikatornya, bukan kode plaintext; jelaskan penyimpanan kode di luar perangkat. Jangan membuat tombol reset PIN tanpa pemeriksaan.
- Dokumentasikan batas perlindungan PIN pendek dan prosedur jika PIN/kode pemulihan hilang. Jangan menyamakan hash PIN dengan enkripsi database.
- Audit pada versi ini mencatat mode/instalasi dan tindakan, bukan mengklaim identitas individu karena PIN digunakan bersama.

## 4. Desain antarmuka

Gunakan Material 3 dengan dark mode default. Latar arang gelap, permukaan sedikit lebih terang, teks berkontras jelas, dan hijau mint untuk tindakan utama. Contoh arah warna: latar `#14191C`, permukaan `#1E262B`, aksen `#69DBC3`. Verifikasi contrast pairing, jangan hanya mengikuti warna contoh.

- Tulisan isi sekitar 16 sp; nominal total sekitar 28–32 sp. Pesan kesalahan harus terbaca, tidak dibuat sangat kecil.
- Area sentuh utama minimal 48 × 48 dp. Gunakan label untuk tindakan penting; status mempunyai teks/ikon selain warna.
- Mendukung TalkBack, keyboard, pembesaran tulisan, SafeArea, layar sempit, dan orientasi berbeda. Formulir tidak tertutup keyboard dan tidak overflow.
- Tata letak mengikuti lebar ruang aplikasi, bukan sekadar nama perangkat. Pada layar sempit, susun vertikal. Pada ruang lebar yang cukup, pencarian/katalog di kiri dan keranjang di kanan. Pertahankan total/Bayar mudah dijangkau.
- Jangan tampilkan navigasi bawah, dashboard, laporan, HPP, atau menu gudang pada awal kasir.
- Header kasir: nama toko, tombol `Hutang`, dan `Kelola` dengan ikon kunci. Kelola meminta PIN sebelum memperlihatkan pilihan pengelolaan.
- Di Gudang, gunakan bagian `Barang`, `Kategori`, dan `Supplier`, pencarian, serta tombol tambah yang jelas. Riwayat, laporan, dan pengaturan berada dalam pengelolaan.
- Gunakan istilah sehari-hari: `Harga beli`, `Harga jual`, `Barang masuk`, `Sisa hutang`. Identitas internal, nama tabel, dan detail protokol tidak ditampilkan sebagai pekerjaan pengguna.

## 5. Identitas dan master barang

Pisahkan `id` internal, kode toko/SKU, dan barcode:

- `id` wajib, stabil, otomatis oleh lapisan data, unik, dan tidak dapat diedit pengguna. Pilih format yang terdokumentasi dan sesuai kemungkinan migrasi.
- SKU boleh diisi manual atau dibuat otomatis. Tombol `Buat kode` opsional, tetapi menyimpan tanpa mengisinya tetap menghasilkan kode unik. Terapkan constraint unik dan tangani benturan; jangan mengandalkan timestamp saja.
- Barcode kemasan opsional, disimpan sebagai teks untuk mempertahankan nol di depan. Nilai kosong adalah `NULL`. Barcode yang terisi tidak boleh ambigu antarproduk, termasuk produk arsip; arahkan pemulihan jika kode sudah dimiliki produk arsip.
- Nama, harga jual, kategori, alias pencarian, stok minimum, dan pengaturan kedaluwarsa disimpan pada produk sesuai kebutuhan. Jumlah stok default nol, tidak `NULL` dan tidak negatif.
- Simpan nominal jual/bayar dalam integer minor units sesuai currency_code/currency_scale; IDR tetap integer rupiah tanpa x100. Money membawa metadata dan memeriksa mismatch/overflow. Biaya rata-rata memakai fixed-point 10^6 per minor unit terpisah dari scale mata uang; hindari floating point biner dalam bisnis uang. Contoh rupiah pada bagian 10 tetap berlaku untuk IDR.

CRUD Barang, Kategori, dan Supplier:

- Relasi kategori menggunakan `category_id`; UI memilih/mencari nama. Izinkan barang tanpa kategori dengan tampilan `Belum dikategorikan` agar input awal tetap mudah.
- Supplier opsional: `id` otomatis, `name` wajib hanya jika record supplier dibuat, `contact_number` opsional berbentuk teks, serta metadata/arsip internal.
- Supplier aktual terutama dicatat pada penerimaan/restock; `supplier_id` boleh `NULL`. Produk yang sama bisa diterima dari supplier berbeda. Tidak perlu membuat supplier dummy atau mewajibkan pengguna menyimpan sales yang hanya datang sekali.
- Dropdown suggestion untuk relasi dan tambah cepat jika pengguna ingin menyimpan master baru.
- Pencarian pada masing-masing bagian. Daftar produk minimal menampilkan nama, harga jual, stok, dan peringatan relevan. Detail memungkinkan restock, perubahan harga, dan arsip.
- Saat membuat barang, tampilkan nama dan harga jual sebagai input utama. Bagian `Stok awal & harga beli`, `Kode, barcode & kategori`, serta `Peringatan stok & kedaluwarsa` dapat dibuka sesuai kebutuhan. Jika stok awal lebih dari nol, harga beli wajib agar HPP dapat dihitung.

## 6. Kasir, pencarian, dan keranjang

Layar pertama: `Cari barang → Daftar belanja → Total → Bayar`.

Pencarian:

- Satu kolom menerima nama, SKU, atau barcode. Exact match barcode/SKU tidak boleh diganti fuzzy match secara diam-diam.
- Support scanner yang mengirim input seperti keyboard, termasuk akhiran Enter. Pemindaian berhasil langsung menambahkan satu unit dan menyiapkan input berikutnya. Kamera bukan syarat versi ini.
- Scan barang sama menambah quantity pada baris yang sama, bukan membuat baris baru.
- Pencarian nama menggunakan suggestion; pengguna memilih hasil untuk menambahkan barang. Jangan memilih hasil pertama otomatis hanya karena pengguna mengetik.
- Contoh `Le Minerale` dapat ditemukan melalui `mineral`, `lemineral`, `le`, serta `air`/`minum` jika kategori, tag, atau aliasnya relevan.
- Gunakan normalisasi nama, bentuk tanpa spasi, pencarian awalan token, kategori, dan alias. Jangan hanya memuat seluruh tabel lalu menjalankan `contains()` di Dart. Tidak perlu AI untuk pencarian ini.
- Prioritas hasil: kode/barcode tepat, nama tepat, awalan nama/token, alias, kemudian kategori.
- Gunakan debounce sekitar 250–300 ms untuk ketikan; scanner exact match diproses segera. Batasi suggestion dan abaikan hasil query lama yang datang terlambat.
- Pilih index/FTS sesuai kemampuan SQLite target; periksa FTS5 dan sediakan fallback. Index B-tree biasa jangan diklaim otomatis mempercepat `LIKE '%kata%'`. Parameterize SQL dan sanitasi sintaks pencarian.
- Tombol X hanya membersihkan pencarian. Barang tidak ditemukan atau stok habis menampilkan pesan dekat input. Produk habis dapat terlihat di hasil, tetapi tidak dapat ditambahkan.

Keranjang:

- Baris berisi nama, harga satuan, quantity, total baris, tombol minus/plus, dan hapus. Quantity dapat diketuk untuk input angka banyak; unit bulat positif dan validasi stok.
- Total/harga hasil perhitungan tidak diedit langsung oleh kasir. Tambahan barang melampaui stok layak jual ditolak.
- Daftar dapat digulir; total dan tombol Bayar tetap tersedia. Tombol `Kosongkan` meminta konfirmasi jika berisi barang dan memberikan undo yang sesuai.
- Simpan draft keranjang lokal agar restart/crash tidak langsung menghilangkan belanja. Draft belum merupakan penjualan atau pengurangan stok. Validasi ulang draft ketika dibuka.
- Jika harga berubah sejak masuk keranjang, beri tahu dan minta penerimaan harga terbaru sebelum checkout; jangan mengubah total diam-diam. Stok juga selalu diperiksa ulang saat checkout.

## 7. Checkout dan piutang pelanggan

Panel pembayaran memuat total serta pilihan `Lunas`, `Sebagian hutang`, dan `Hutang semua`. Lunas menjadi default.

- Lunas tidak meminta nama/HP, uang yang diserahkan, atau kembalian. Pembayaran yang dicatat sama dengan total; aplikasi tidak mengklaim telah memverifikasi uang fisik atau memproses payment gateway.
- Sebagian hutang menampilkan nominal dibayar, nama pelanggan, HP opsional, dan sisa hutang otomatis. Nominal dibayar harus lebih dari nol dan kurang dari total.
- Hutang semua mencatat dibayar nol dan meminta nama pelanggan; HP tetap opsional.
- Hutang melekat pada transaksi, bukan pada setiap baris barang. `Hutang = total − pembayaran yang dicatat`.
- Gunakan `customer_id`, bukan nama sebagai primary key atau unique key. Nama sama memunculkan suggestion pelanggan untuk dipilih, bukan otomatis menggabungkan semua orang dengan nama sama. Pengguna dapat membuat pelanggan berbeda dengan nama sama.
- HP disimpan sebagai teks dan hanya diminta ketika relevan. Jangan membaca phonebook perangkat.

Daftar hutang adalah halaman dengan pencarian nama, saldo aktif, detail transaksi, dan `Catat pembayaran`. Satu pembayaran dapat dialokasikan ke beberapa transaksi; default lunasi transaksi tertua dahulu dan tampilkan rinciannya sebelum konfirmasi. Pembayaran tidak boleh melampaui saldo yang akan dilunasi. Simpan pembayaran dan alokasinya secara atomik.

Jangan mengedit saldo atau menghapus hutang lunas langsung. Saldo dihitung dari penjualan dan pembayaran; data lunas tidak muncul di daftar aktif tetapi tetap tersedia di riwayat. Koreksi pembayaran dilakukan dengan reversal yang dapat ditelusuri dan perlindungan PIN.

## 8. Atomisitas dan pencegahan transaksi ganda

Semua perubahan checkout berada dalam satu transaksi database:

1. Verifikasi akses/data keranjang dan periksa stok layak jual terbaru.
2. Periksa status produk, harga, biaya, serta batch.
3. Kurangi stok dengan update bersyarat dan periksa jumlah baris yang berubah.
4. Simpan `sale_transactions` dan `sale_transaction_items` dengan snapshot nama/kode, harga jual, quantity, dan HPP saat itu.
5. Simpan alokasi batch dan `stock_history`.
6. Simpan pelanggan bila diperlukan, pembayaran/alokasi, serta referensi piutang.
7. Tandai draft sudah diselesaikan dan commit seluruh perubahan.

Jika satu langkah gagal, rollback seluruh transaksi. Gunakan objek transaksi sqflite secara konsisten. Tambahkan constraint stok nonnegatif dan validasi bisnis; jangan hanya memeriksa angka dari Provider sebelum transaksi.

- Nonaktifkan konfirmasi selama penyimpanan; berikan identitas unik satu upaya checkout dan constraint/idempotensi agar tap ganda atau retry tidak membuat penjualan baru.
- Draft ditandai selesai/dihapus secara konsisten dengan commit. Jika aplikasi mati setelah commit tetapi sebelum UI dibersihkan, pembukaan berikutnya mengenali transaksi sudah selesai, bukan menjual draft lagi.
- Jika checkout gagal, keranjang dan input pembayaran dapat dipulihkan untuk koreksi.
- Hanya setelah commit tawarkan cetak struk. Stok dikurangi tepat sekali; tidak diperbarui lagi setelah cetak.
- Gagal cetak tidak membatalkan penjualan. Cetak ulang membaca transaksi tersimpan dan tidak membuat penjualan/HPP/pengurangan stok baru.
- Pencegahan stok minus berlaku untuk operasi pada database lokal yang sama. Jangan mengklaim ini menyelesaikan checkout serentak pada dua perangkat terpisah.

## 9. Restock, stok opname, dan kedaluwarsa

Restock memasukkan jumlah positif dan harga beli per unit, dengan supplier opsional. Catat penerimaan, detail, batch bila relevan, pembaruan stok/valuasi, dan riwayat dalam satu transaksi. Nilai stok tidak boleh diubah bebas melalui edit produk.

- Stok minimum per produk, default awal 5 dan dapat diubah. Peringatan jika stok layak jual `< min_stock`; sediakan cara menonaktifkan peringatan per produk.
- Produk mempunyai opsi `Pantau kedaluwarsa`. Tanggal dicatat per penerimaan/batch, bukan satu tanggal pada master produk.
- Tanggal boleh tidak dicatat agar pengguna tetap dapat memasukkan barang; tampilkan status `Tanggal belum dicatat` dan jangan menganggap tanggal yang hilang pasti aman atau menghasilkan notifikasi kedaluwarsa palsu.
- Alokasikan penjualan FEFO untuk batch yang bertanggal; tentukan perlakuan batch tanpa tanggal secara konsisten dan dokumentasikan. Jangan tampilkan pengelolaan batch sebagai tugas tambahan pengguna.
- Bedakan stok fisik, stok layak jual, dan stok kedaluwarsa. Default barang tidak layak jual mulai tanggal kedaluwarsa yang dicatat; aturan batas tanggal dijelaskan konsisten pada UI dan pengujian.
- Barang kedaluwarsa tidak otomatis dianggap sudah dibuang. Pengeluaran karena rusak/kedaluwarsa dicatat sebagai penyesuaian stok dan nilai persediaan dengan alasan.
- Notifikasi mendekati kedaluwarsa hanya untuk batch bertanggal dengan jumlah tersisa, dalam rentang lima hari kalender sebelum batasnya.
- Stok opname membandingkan jumlah fisik dengan catatan dan membuat penyesuaian selisih dengan alasan, waktu, serta valuasi. Perlindungan PIN berlaku. Jangan menimpa history atau mengubah transaksi lama.

`stock_history` mencakup stok awal, restock, penjualan, penyesuaian, rusak/kedaluwarsa, dan reversal. Simpan referensi sumber serta delta jumlah/nilai yang cukup untuk rekonsiliasi. Riwayat bersifat append-only; koreksi menambah entri pembalik.

## 10. HPP, harga, dan laporan

Gunakan moving weighted average:

`biaya rata-rata baru = (nilai stok lama + biaya barang masuk) / jumlah stok setelah penerimaan`.

- Average cost berubah karena penerimaan/penyesuaian valuasi yang sah, bukan karena harga jual diedit.
- FEFO memilih batch fisik, sedangkan moving average menentukan HPP. Keduanya digunakan dengan konsisten.
- Simpan nilai persediaan dan presisi biaya; dokumentasikan pembulatan/alokasi residu agar persediaan yang benar-benar habis tidak meninggalkan nilai sisa hanya karena pembulatan.
- HPP setiap penjualan disimpan sebagai snapshot. Restock atau edit harga kemudian tidak menghitung ulang laba transaksi lama.
- Simpan `price_history` untuk perubahan harga jual dengan nilai sebelum/sesudah dan waktu. Harga beli aktual terdapat pada penerimaan; perubahan biaya persediaan tetap dapat ditelusuri.
- Hutang dan pelunasannya tidak mengubah HPP. Pelunasan bukan penjualan atau laba baru. Piutang tak tertagih, jika kelak ditambahkan, bukan HPP barang.

Laporan yang tersedia: penjualan, HPP, laba kotor bulan ini, pembayaran yang dicatat pada periode, saldo piutang, serta ringkasan persediaan. Gunakan label `Laba kotor`, karena biaya operasional belum dicatat. Pisahkan pembayaran piutang lama dari penjualan baru. Pembatalan memperhitungkan pembalikan pada periode yang didokumentasikan, tanpa menghapus fakta transaksi asli.

Contoh wajib benar: stok 10 × Rp8.000 ditambah 10 × Rp10.000 menghasilkan biaya rata-rata Rp9.000. Penjualan 3 × Rp12.000 menghasilkan penjualan Rp36.000, HPP Rp27.000, laba kotor Rp9.000. Jika dibayar Rp10.000, saldo piutang Rp26.000; pelunasan berikutnya tidak menambah penjualan atau laba kotor.

## 11. Undo, pembatalan, dan arsip

- Hapus keranjang: snackbar `Urungkan` sekitar lima detik. Undo memulihkan perubahan tersebut tanpa menimpa perubahan lain yang dilakukan sesudahnya.
- Kosongkan keranjang: konfirmasi dan undo dengan aturan yang sama.
- Arsip barang: konfirmasi, ubah `is_deleted`, dan sediakan undo/pemulihan. Barang arsip tidak dapat dijual lagi tetapi transaksi lama tetap terbaca.
- Edit harga: undo hanya jika belum ada perubahan lanjutan yang membuat pemulihan tidak sah; simpan riwayat pemulihan.
- Restock salah: reversal atomik hanya jika belum ada pergerakan stok/valuasi berikutnya yang bergantung padanya. Jika sudah ada, arahkan koreksi melalui penyesuaian yang benar; jangan mengembalikan average lama secara naif.
- Jangan menahan transaksi database terbuka selama menunggu batas waktu undo.
- Penjualan/pembayaran yang sudah commit dikoreksi melalui operasi pembatalan resmi dengan PIN, alasan, dan riwayat. Jangan hard-delete transaksi.
- Untuk versi pertama, pembatalan penjualan penuh hanya diizinkan jika barang benar-benar kembali dan tidak ada pelunasan piutang lanjutan yang membuat pembatalan pembayaran ambigu. Kondisi lain ditolak dengan penjelasan sampai alur koreksinya tersedia.
- Pembatalan penjualan membalik stok, valuasi menggunakan biaya snapshot yang sesuai, HPP, dan catatan pembayaran/piutang secara atomik. Perhitungan rata-rata saat ini diperbarui sesuai nilai stok hasil pembalikan; jangan mengubah HPP transaksi lain yang sudah selesai. Batch kedaluwarsa yang kembali tetap tidak layak jual. Pembalikan catatan pembayaran tidak otomatis memindahkan uang fisik; konfirmasi pengguna harus menjelaskan bahwa pengembalian barang/dana yang relevan ditangani di toko.
- Barang dengan stok tersisa memerlukan penanganan stok sebelum arsip. Kategori yang masih digunakan harus dipindahkan ke kategori pengganti atau pengarsipannya ditolak dengan penjelasan. Supplier arsip tetap dapat dibaca pada penerimaan lama.
- Jangan menghapus riwayat keuangan otomatis demi mengecilkan database. Hindari gambar/riwayat duplikat dan batasi ukuran logo serta retensi backup.

## 12. Struk dan printer

Implementasikan dukungan Android untuk printer thermal Bluetooth ESC/POS yang kompatibel. Pisahkan transport printer dan format struk. Target utama Iware MP-581RL/RPP02N 58 mm melalui Bluetooth Classic SPP; gunakan adapter native yang sesuai versi Android/Flutter, dokumentasikan kemampuan aktual dan uji kertas nyata. BLE/USB serta hardware 80 mm belum didukung atau dibuktikan oleh profil generik saja. Jangan mengklaim semua printer dapat digunakan.

- Pengaturan pencarian/pemilihan perangkat, koneksi, printer tersimpan, test print, profil lebar kertas 58/80 mm, dan lebar cetak aktual yang sesuai printer.
- Izin Bluetooth sesuai versi Android, diminta saat fitur dipakai. Tangani izin ditolak, Bluetooth mati, perangkat terputus, dan timeout. Kegagalan printer tidak menghalangi penjualan. Setelah permintaan izin ditolak, aksi berikutnya memberi petunjuk pengaturan izin aplikasi tanpa mengulang dialog Android terus-menerus; PIN tetap terkunci saat lifecycle meninggalkan resumed dan tidak dibuka otomatis oleh hasil izin.
- Pengaturan font bawaan yang didukung, ukuran normal/besar, tebal, dan logo. Jangan menjanjikan font bebas tanpa jalur raster dan pengujian yang benar.
- Struk memuat logo opsional, nama toko, alamat/WA jika diisi, nomor transaksi, waktu, nama barang, quantity, harga satuan, total baris, total transaksi, pembayaran dicatat, sisa hutang/pelanggan jika relevan, dan footer ucapan terima kasih.
- Preview struk dan cetak ulang dari riwayat. Salinan ditandai `SALINAN`. Jangan menyatakan printer pasti telah mencetak hanya karena data berhasil dikirim; tangani keterbatasan status perangkat dan risiko cetak ganda secara jujur.
- Logo dioptimalkan untuk thermal dan tidak disimpan ulang pada setiap transaksi.

## 13. Backup dan restore

Klarifikasi UI M5,18 Oktober2026: sesudah konfirmasi tujuan Google berhasil atau
akun diputus, daftar versi/cursor milik tujuan sebelumnya diinvalidasi dan status
target jadwal dimuat ulang dari service. Pembatalan/penolakan pemilihan tidak
mengubah tujuan dan persetujuan yang telah tersimpan. Ini penerapan pemisahan
konteks akun, bukan perubahan retensi, aturan restore atau sinkronisasi.

Riwayat pengiriman backup di perangkat ditampilkan sebagai catatan lokal semua
akun dengan penanda tujuan saat ini, tujuan lain/sebelumnya, atau tujuan tidak
tercatat. Pisahkan dari daftar arsip akun Drive tujuan; jelaskan halaman kosong
setelah permintaan daftar berhasil. Retensi arsip Drive tidak menghapus riwayat
pekerjaan lokal.

Kegagalan percobaan backup otomatis terakhir yang tersimpan tetap ditampilkan
saat Pengaturan dibuka kembali, termasuk bila gagal sebelum baris pekerjaan
dibuat. Label menjelaskan bahwa ini riwayat perangkat yang mungkin berasal dari
akun tujuan sebelumnya; tampilkan pesan lokal yang aman, bukan kode internal.

Sediakan ekspor/restore berkas lokal, serta Google Drive opsional. Nama berkas ekspor dapat diisi di dialog aplikasi yang menyesuaikan keyboard sebelum memilih lokasi Android; nama diteruskan sebagai isian awal tanpa mengubah arsip internal. Gunakan snapshot SQLite konsisten; jangan hanya menyalin `.db` aktif dan mengabaikan WAL. Pilih metode yang benar-benar tersedia pada plugin/runtime; bila perlu, hentikan penulisan sebentar melalui koordinator database dan buka kembali dengan aman.

Paket backup memuat database, logo, metadata versi skema/aplikasi, identitas toko, timestamp, dan checksum. Jangan memasukkan token Google, rahasia aplikasi, kode pemulihan plaintext, atau kunci perangkat. Jelaskan bahwa backup memuat data toko/pelanggan. Arsip wajib terenkripsi dan terautentikasi sesuai keputusan M5: recovery kuat yang portable, terpisah dari PIN empat digit dan key Keystore instalasi. Tidak ada fallback arsip plaintext; kehilangan recovery dapat membuat backup tidak dapat dipulihkan.

Saat kode recovery baru atau tersimpan ditampilkan melalui pengelolaan ber-PIN, sediakan tombol Salin ke papan klip pada aplikasi utama maupun paket uji. Salin kode lengkap sebagai 64 karakter heksadesimal tanpa spasi/tanda hubung; tolak kode tidak valid. Penyalinan merupakan tindakan eksplisit, tidak membaca clipboard, tidak membuat/menyimpan kode baru atau mengonfirmasi salinan secara otomatis. Beri feedback Indonesia/Inggris tanpa menampilkan nilai kode di pesan/log dan gunakan penanda clipboard sensitif Android. Pilihan penampilan teks input khusus fixture tidak berlaku pada fitur Salin ini.

Google Drive:

- Hubungkan akun dari Pengaturan dengan izin minimum sesuai kebutuhan. Default gunakan `appDataFolder` untuk backup aplikasi; jelaskan file tersebut dikelola dari aplikasi dan ekspor lokal tersedia untuk file yang ingin disimpan sendiri.
- Backup otomatis mempunyai switch terpisah, default mati. Sebelum aktivasi, jelaskan jenis data yang diunggah dan akun tujuan; pengguna memberikan persetujuan nyata. Mematikan atau memutus akun menghentikan pekerjaan berikutnya.
- Jika aktif, jadwalkan target harian pukul 21.00 zona waktu toko melalui mekanisme background Android yang sesuai. Jangan menjanjikan tepat pukul 21.00; lakukan retry dan pemeriksaan backup terlewat saat aplikasi dibuka. Perubahan switch otomatis memperbarui status target yang ditampilkan dari hasil penjadwalan tersimpan tanpa memerlukan refresh manual; label memakai waktu toko.
- Backup manual, status terakhir berhasil/gagal, retry dengan backoff, dan batas retensi yang terdokumentasi, default tujuh versi berhasil. Jangan menghapus versi baik sebelum backup baru terverifikasi.
- Gunakan nama/metadata unik untuk versi dan asal instalasi. Meskipun tidak mendukung sinkronisasi, jangan menimpa berkas backup dari instalasi lain secara diam-diam.
- Dokumentasikan konfigurasi Google Cloud/OAuth, signing certificate, scope, dan konfigurasi build yang diperlukan tanpa mengarang credential. Fitur yang belum dikonfigurasi memberikan penjelasan dan ekspor lokal tetap bekerja.

Restore:

- PIN, pemilihan versi, ringkasan backup, dan konfirmasi karena data aktif diganti.
- Validasi format, checksum, integritas database, foreign key, skema, dan kompatibilitas migration sebelum penggantian. Cegah path traversal saat membaca arsip.
- Buat backup keselamatan lokal sebelum restore. Hentikan transaksi sementara, lakukan penggantian yang aman, dan pulihkan data lama jika gagal.
- Restore penuh, bukan merge dua database. Jangan menyebut restore sebagai sinkronisasi.
- Draft transaksi aktif ditangani dengan konfirmasi yang jelas. Setelah restore, mode pengelolaan terkunci; jelaskan penerapan PIN/kode pemulihan dari backup.
- Acceptance dokumen legal per instalasi dan token Google tidak dianggap otomatis disetujui/dipulihkan dari perangkat lama. Koneksi Google di perangkat baru dilakukan lagi.

## 14. Notifikasi, performa, dan skema

- Gunakan `flutter_local_notifications` untuk stok rendah dan batch mendekati kedaluwarsa. Pemeriksaan kondisi dibuat terpisah dari penayangan notifikasi.
- Minta izin notifikasi saat pengguna mengaktifkannya. Jika ditolak, daftar peringatan dalam aplikasi tetap berfungsi.
- Hindari spam: notifikasi stok ketika memasuki keadaan rendah, rearm setelah stok pulih; untuk kedaluwarsa gunakan deduplikasi dan jadwal yang dapat diperbarui/dibatalkan setelah stok habis atau tanggal berubah. Jangan tampilkan nominal piutang/identitas pelanggan pada notifikasi layar kunci.
- Daftar besar menggunakan keyset/cursor pagination sesuai aturan berikut, lazy loading, urutan deterministik, dan index sesuai query. Jangan memuat seluruh katalog/riwayat ke Provider.
- Aktifkan foreign key, gunakan parameterized query dan migration versi. Uji upgrade data lama tanpa uninstall.
- Tabel konseptual: products, categories, suppliers, customers, sale_transactions, sale_transaction_items, stock_receipts, stock_receipt_items, stock_batches, sale_batch_allocations, payments, payment_allocations, stock_history, price_history, store_settings, audit_log, serta metadata draft/persetujuan yang diperlukan. Sesuaikan detail skema dengan alasan yang jelas; penamaan transaksi penjualan tetap mengikuti bagian 2. Jangan membuat saldo ganda tanpa aturan rekonsiliasi.
- Simpan snapshot transaksi dan referensi sumber untuk rekonsiliasi jumlah stok, nilai persediaan, penjualan/HPP, dan piutang.
- Error UI mengikuti bahasa Indonesia/Inggris yang dipilih, dengan langkah perbaikan. Log teknis tidak membocorkan PIN, token, nama/HP pelanggan, isi backup, atau data transaksi sensitif. Data contoh hanya untuk development/test, tidak disuntikkan ke database produksi.

### Keyset pagination untuk daftar besar

- Default halaman 50 baris. Ambil `pageSize + 1` untuk menentukan `hasMore`; jangan menjalankan COUNT seluruh tabel pada setiap load-more. Return items, next cursor, dan hasMore melalui kontrak repository yang jelas.
- Riwayat penjualan: urutkan `created_at DESC, id DESC`, dengan kedua nilai sebagai cursor; timestamp sama tetap mempunyai tie-breaker unik. `id` tidak boleh dianggap sebagai urutan waktu jika berbentuk UUID. Cursor berikutnya memilih tuple lebih kecil dari baris terakhir.
- Katalog alfabetis: urutkan nama yang sudah dinormalisasi lalu `id`, dengan collation yang sama pada ORDER BY, index, dan kondisi cursor. Nilai sort wajib mempunyai penanganan NULL yang eksplisit. Jangan menggunakan `id > lastId` jika urutannya berdasarkan nama atau waktu.
- Gunakan index komposit yang sesuai query nyata, misalnya `(created_at DESC, id DESC)` untuk riwayat serta `(is_deleted, normalized_name, id)` untuk katalog aktif. Nama kolom boleh mengikuti skema, tetapi semantik sort/cursor harus sama.
- SQL keyset dapat menggunakan pembandingan row-value bila SQLite target mendukungnya, atau predikat leksikografis yang ekuivalen dengan query plan yang diverifikasi.
- Reset cursor/hasil lama ketika query, filter, urutan, atau konteks periode berubah. Cegah load-more bersamaan dan page async usang masuk ke query baru. Jika data yang mengubah sort/filter diedit saat daftar dibuka, invalidasi sesi terkait dan refresh; jangan menjanjikan snapshot sempurna pada dataset mutable tanpa mekanisme snapshot.
- Untuk riwayat append-only, gunakan batas atas sesi jika diperlukan agar transaksi baru tidak menggeser hasil yang sedang ditelusuri; transaksi baru tersedia melalui refresh. Timestamp dan identitas transaksi asli tidak diedit bebas.
- Gunakan cache halaman yang terukur dan terbatas. Batas cache bukan batas jumlah data toko. Jangan mengumpulkan semua baris yang pernah ditelusuri ke satu Provider tanpa batas.
- Jangan memakai OFFSET besar pada katalog, riwayat, ledger, atau rincian laporan. OFFSET hanya boleh untuk daftar kecil yang benar-benar terbatas dengan alasan terdokumentasi. Navigasi langsung ke nomor halaman tidak diperlukan; gunakan scroll/load-more atau berikutnya/sebelumnya sesuai kemampuan cursor.

### Pencarian berperingkat dan ringkasan laporan

- Suggestion kasir dibatasi, default 20 hasil paling relevan per query, tanpa OFFSET. Ini berbeda dari pagination seluruh katalog. Pemindaian kode/barcode memakai exact indexed lookup.
- Jika menyediakan daftar hasil pencarian berperingkat yang panjang, tetapkan strategi paging khusus ranking. Jangan menerapkan cursor nama/ID secara buta pada ORDER BY skor FTS. Konteks query/ranking dan tie-breaker harus konsisten; jelaskan biaya ranking/sorting dan perilaku saat data berubah.
- Keyset mengurangi biaya melewati baris, tetapi tidak membuat semua filter, FTS, GROUP BY, atau SUM otomatis murah. Periksa jalur query masing-masing.
- Total penjualan/HPP/laba/pembayaran dihitung di SQL terhadap seluruh rentang/filter laporan, bukan menjumlahkan halaman rincian yang sedang dimuat. Gunakan batas waktu setengah terbuka `[start, end)` yang dikonversi dari zona waktu toko; hindari fungsi pembungkus timestamp yang membuat index tak terpakai tanpa alasan.
- Rincian laporan dapat menggunakan keyset. Laporan agregat yang diurutkan berdasarkan SUM/ranking mungkin membutuhkan agregasi lebih dahulu; jangan mengklaim index pada tanggal/ID menghilangkan seluruh biaya itu. Tambahkan cache/ringkasan materialisasi hanya bila profiling membuktikan kebutuhan dan invalidation/reconciliation jelas.
- Gunakan `EXPLAIN QUERY PLAN` untuk query penting dan dokumentasikan penggunaan index/sort yang benar. Jangan menganggap setiap tulisan SCAN selalu salah; perhatikan virtual table FTS, covering index, selektivitas, dan biaya nyata.
- Benchmark fixture di database pengujian terpisah, misalnya 10.000 produk dan 100.000 transaksi beserta detailnya. Ukur halaman awal/lanjutan/jauh, pencarian umum, dan ringkasan bulanan. Laporkan ukuran fixture, platform, mode build, query plan, serta latency aktual; jangan mengarang angka atau mengklaim O(1) untuk semua operasi. Jika lingkungan tidak memungkinkan pengukuran perangkat nyata, tandai batas hasilnya.

## 15. Persetujuan pengguna dan kebijakan privasi

Implementasikan `Persetujuan Pengguna` dan `Kebijakan Privasi` berbahasa Indonesia/Inggris mengikuti pilihan UI, dapat dibaca offline. Pisahkan isi dokumen dari widget, beri versi/tanggal efektif, dan sediakan identitas aplikasi/pengembang/kontak/URL sebagai konfigurasi yang harus saya lengkapi. Jangan mengarang identitas atau kontak.

Persetujuan pengguna menjelaskan penggunaan yang sah, keterbatasan satu perangkat aktif, tidak adanya sinkronisasi/cloud database, kebutuhan backup, kemungkinan ketidakcocokan printer, backup otomatis yang waktunya dapat tertunda, dan laporan laba kotor yang belum mencakup biaya operasional. Ukuran toko tidak dibatasi; pengguna menilai kesesuaian kemampuan aplikasi. Klausa tanggung jawab harus wajar dan tidak mengklaim dapat menghapus seluruh hak pengguna atau menjamin bebas kesalahan.

Kebijakan privasi mengikuti implementasi aktual: data toko, produk, supplier, pelanggan/HP, transaksi, piutang, pengaturan, data autentikasi Google yang benar-benar digunakan, tujuan pemrosesan, penyimpanan lokal, backup opsional ke akun Google pengguna, pencetakan, retensi, dan penghapusan. Nyatakan data apa yang dapat diakses pengembang dan layanan pihak ketiga secara tepat. Versi awal tidak menambahkan iklan, analytics, tracking, crash-upload otomatis, atau server pengembang yang mengirim data tanpa kebutuhan dan persetujuan.

- Penyiapan pertama menampilkan ringkasan dan tautan dokumen. Checkbox persetujuan syarat tidak dicentang otomatis; membaca kebijakan privasi bukan persetujuan umum untuk semua transfer data di masa depan. Simpan versi syarat yang diterima dan waktu secara lokal.
- Persetujuan Google Drive/backup otomatis terpisah dari persetujuan awal. Izin Android diminta sesuai fitur, bukan semuanya saat startup.
- Dokumen dapat dibuka lagi dari `Tentang/Persetujuan & Privasi`, termasuk melalui tautan pada dialog Kelola sebelum PIN. Pembaca dokumen tidak memperoleh akses pengelolaan.
- Perubahan material dokumen/aliran data mempunyai mekanisme pemberitahuan dan persetujuan ulang bila diperlukan; jangan meminta persetujuan setiap pembukaan.
- Jelaskan arsip master/retensi riwayat, pemutusan Google, penghapusan backup, dan penghapusan data lokal yang benar-benar tersedia. Reset data melalui PIN, konfirmasi yang jelas, dan kesempatan ekspor; tidak menghapus backup Drive diam-diam. Jika data pribadi dapat dianonimkan tanpa merusak riwayat keuangan, implementasikan tindakan terproteksi yang mencakup seluruh salinan lokal terkait, termasuk snapshot/arsip yang relevan; jelaskan salinan backup lama tetap perlu dikelola terpisah.
- Periksa Android Auto Backup/data extraction rules agar database, PIN, dan berkas toko tidak ikut terkirim lewat backup sistem yang bertentangan dengan penjelasan produk. Dokumentasikan batas kendali aplikasi dan aturan platform.
- Siapkan salinan kebijakan untuk halaman publik yang dapat dipasang pada URL aktif, bisa diakses tanpa login, bukan PDF, serta daftar hal yang perlu saya isi sebelum rilis. Jangan memublikasikan halaman atau aplikasi tanpa instruksi saya.
- Buat panduan Data safety berdasarkan aliran data dan SDK aktual, termasuk penggunaan Drive. Jangan otomatis menyatakan `tidak mengumpulkan data` hanya karena penyimpanan utama lokal.
- Periksa ketentuan Google Play/Google OAuth terkini dari sumber resmi sebelum menulis panduan rilis. Dokumen adalah draf yang perlu disesuaikan identitas dan penggunaan sebenarnya; jangan mengklaim kepatuhan hukum atau kelulusan review terjamin.

## 16. Pengujian dan hasil yang harus diserahkan

Utamakan pengujian bermakna untuk aturan data/keuangan, serta pemeriksaan UI dan integrasi. Minimal buktikan:

1. Scan barang sama tiga kali menghasilkan satu baris quantity tiga; barcode nol di depan tetap benar.
2. Simpan barang tanpa SKU/barcode berhasil dengan kode unik. Supplier kosong tidak menghalangi restock.
3. Pencarian contoh Le Minerale bekerja melalui normalisasi/alias/kategori yang relevan; hasil lama tidak menggantikan query terbaru.
4. Stok habis atau quantity melebihi stok ditolak; stok dan batch tidak menjadi negatif.
5. Dua operasi checkout pada database yang sama memperebutkan satu stok terakhir: hanya satu berhasil. Tidak ada klaim jaminan lintas perangkat.
6. Kegagalan salah satu tahap checkout membatalkan sale_transactions, detail, stok, history, serta pembayaran sekaligus.
7. Tap ganda/retry tidak membuat transaksi ganda. Recovery setelah commit sebelum UI selesai tidak menjual draft dua kali.
8. Contoh moving average/HPP/laba/piutang pada bagian 10 benar, termasuk pembulatan dan stok yang habis.
9. Harga/restock baru tidak mengubah snapshot transaksi lama; perubahan harga ketika draft aktif tidak diterapkan diam-diam.
10. Pembayaran sebagian, seluruh hutang, pelunasan bertahap, dan pelanggan bernama sama tercatat benar. Pelunasan tidak menambah penjualan/HPP/laba.
11. Dua batch bertanggal berbeda dialokasikan FEFO; batch habis tidak memunculkan peringatan; tanggal kosong dan batas hari ditangani konsisten.
12. Undo tidak menimpa perubahan lain. Reversal restock ditolak setelah ada dependensi; pembatalan keuangan tetap meninggalkan riwayat dan nilai persediaan yang benar.
13. Arsip produk/kategori/supplier tidak merusak riwayat. Rekonsiliasi stok, nilai, dan piutang cocok.
14. Gagal cetak tidak mengubah penjualan; cetak ulang tidak mengurangi stok. Uji hardware nyata ditandai terpisah jika perangkat belum tersedia.
15. Backup/restore benar-benar mengembalikan stok, HPP, penjualan, piutang, pengaturan, dan logo. Arsip rusak/versi tidak kompatibel ditolak tanpa kehilangan data aktif; restore gagal dapat dipulihkan.
16. Migration instalasi lama berhasil tanpa kehilangan data. Google/notifikasi/Bluetooth ditolak atau belum dikonfigurasi tidak membuat kasir crash.
17. Dokumen legal terbaca offline, consent tidak otomatis, dan backup tidak berjalan sebelum diaktifkan. PIN/mode terkunci dan pembatasan percobaan bekerja.
18. UI dapat dipakai pada HP kecil dan tablet, dengan keyboard/pembesaran teks, tanpa overflow atau tindakan utama tersembunyi. Loading, kosong, gagal, serta sukses mempunyai keadaan yang jelas.
19. Riwayat/katalog dengan timestamp/nama yang sama dipaginasi tanpa kehilangan/duplikasi pada dataset tetap; reset query/filter dan respons async usang ditangani. Mutasi selama sesi mengikuti aturan invalidation yang didokumentasikan.
20. Total laporan tetap mencakup seluruh periode walaupun rincian baru dimuat satu halaman. Query plan dan pengukuran halaman jauh mengikuti strategi keyset, bukan OFFSET yang disembunyikan.
21. Batas Provider sesuai bagian 2: state tidak diduplikasi, pencarian tidak memicu checkout/reload laporan, dan operasi bisnis atomik dapat diuji tanpa widget/Provider global.
22. Model, tabel, foreign key, migration, DTO, test, dan dokumentasi konsisten memakai SaleTransaction/sale_transactions serta SaleTransactionItem/sale_transaction_items. Migration data lama, jika ada, mempertahankan relasi dan riwayat.

Jalankan formatter, `flutter analyze`, dan test relevan. Build Android debug/release atau AAB jika lingkungan mendukung. Laporkan perintah, hasil aktual, dan pemeriksaan yang terhalang; jangan menulis `semua lulus` tanpa bukti.

Hasil akhir: proyek lengkap dengan dependency/build configuration yang diperlukan, migration, test, dokumentasi pemeliharaan, draf dokumen legal, panduan integrasi, serta panduan build dan persiapan Play Store. Jelaskan perubahan, lokasi kode utama, batas kemampuan, konfigurasi yang masih perlu saya isi, dan pengujian hardware/rilis yang tersisa. Berikan penilaian singkat aplikasi berdasarkan implementasi yang benar-benar selesai. Lanjutkan langkah rutin yang diperlukan untuk menyelesaikan tahap aktif tanpa meminta persetujuan ulang; cakupan akhir dokumen tidak mengubah batas tahap yang sedang diminta.

## 17. Alur kerja Codex dan pemeliharaan konteks proyek

- Simpan spesifikasi lengkap ini sebagai `docs/SPEC.md`. Jangan menyalin seluruhnya ke `AGENTS.md`: file itu berisi aturan kerja ringkas dan referensi dokumen, bukan seluruh backlog fitur.
- Pada awal kerja, baca aturan proyek, spesifikasi, serta `docs/PLAN.md` dan `docs/STATUS.md` jika tersedia. Baca ulang bagian relevan sebelum mengubah domain penting atau melanjutkan konteks/session; jangan mengandalkan ingatan chat saja.
- Tulis kode langsung dalam file proyek. Chat berisi ringkasan, bukti validasi, dan keputusan penting; jangan mencoba mengeluarkan seluruh proyek sebagai satu jawaban teks yang dapat terpotong.
- Buat rencana milestone berurutan dengan dependensi, ruang lingkup, kriteria selesai, dan perintah validasi. Satu tahap merupakan hasil yang dapat diperiksa, bukan sekadar kumpulan file bernama benar.
- Buat `docs/REQUIREMENTS.md` sebagai matriks keterlacakan: persyaratan ber-ID stabil, bagian sumber SPEC, milestone, lokasi implementasi, test/bukti, dan status. Status awal pending. Jangan menandai terpenuhi hanya karena judulnya disebut pada README; jangan menandai hardware terverifikasi tanpa pengujian nyata.
- `SPEC.md` menjadi acuan kebutuhan produk; `PLAN.md` adalah rencana yang bisa disesuaikan tanpa mengurangi kebutuhan; `STATUS.md` mencatat hasil aktual. Ketiganya mempunyai peran berbeda. Jika instruksi pengguna mengubah kebutuhan, perbarui keputusan dan dokumen terkait agar konsisten.
- Setelah checkpoint, jalankan pemeriksaan yang relevan, perbaiki kegagalan sebelum melanjutkan bagian yang bergantung padanya, dan perbarui status/requirement matrix. Jika alat atau hardware menghalangi pemeriksaan, catat blocked/unverified dan lanjutkan pekerjaan independen yang masih berada dalam tahap aktif.
- Jika harus berhenti karena batas sesi/tool/lingkungan, simpan file dalam keadaan yang jelas, catat apa yang selesai/belum, perintah terakhir, kegagalan, dan langkah berikutnya. Jangan mengganti kode yang belum dikerjakan dengan placeholder yang diklaim selesai.
- Tahap yang direkomendasikan: (1) fondasi/arsitektur/skema/pagination, (2) pengelolaan/PIN/persediaan/HPP, (3) kasir/checkout/piutang/recovery, (4) laporan/riwayat/koreksi/performa, (5) printer/notifikasi/backup/restore, (6) dokumen legal/penyiapan pertama/validasi rilis menyeluruh. Tahap selanjutnya menggunakan hasil sebelumnya dan menjalankan regresi yang relevan.
- Bila instruksi aktif meminta hanya tahap 1, kerjakan sampai kriterianya selesai dan laporkan untuk review. Menyelesaikan tahap yang diminta merupakan penyelesaian tugas saat itu; tidak perlu mengimplementasikan seluruh backlog atau meminta izin untuk setiap file.


## 18. Localization dan mata uang — perubahan kebutuhan setelah M2

Pekerjaan terpisah sebelum M3, diotorisasi pengguna 12 Oktober 2026. M1–M2 dan database dipertahankan; tidak memperluas tugas ini menjadi M3. Aturan berikut mengubah asumsi Indonesia/IDR saja pada spesifikasi awal; contoh perhitungan rupiah tetap contoh IDR.

1. Flutter resmi flutter_localizations/intl/gen-l10n, ARB app_id/app_en dan l10n.yaml. Semua teks UI yang tersedia termasuk validasi/dialog/snackbar/tooltip/accessibility/loading/error menggunakan key semantik, metadata, placeholder/ICU plural. Generated files tidak diedit manual; nama/data pribadi/footer pengguna tidak diterjemahkan.
2. Pilihan Bahasa Indonesia/English dengan ID/EN, tanpa PIN, berlaku langsung dan tersimpan. Pertama ikuti perangkat id/en, fallback en. Perubahan tidak melepas navigasi, input/draft atau management session. LocaleProvider hanya preferensi bahasa/currency read-only, SettingsProvider tetap form toko.
3. Currency_code string default IDR dan currency_scale metadata dari katalog aplikasi: IDR0 (kebijakan rupiah bulat), USD/MYR/EUR2. Dropdown nama/kode jelas dan terproteksi PIN. Bahasa UI, number locale id_ID/en_US, currency dan timezone terpisah; Inggris tidak memilih USD.
4. Currency berubah hanya tanpa nilai/fakta keuangan terkait, termasuk harga/valuation produk/arsip, receipt, sale, receivable/payment, draft berharga dan ledger/history. Tolak dengan penjelasan migration/konversi khusus; jangan relabel, konversi otomatis atau menghapus data. Bahasa selalu tetap boleh diganti.
5. Money(amountMinor,currencyCode,scale) integer; penjumlahan/pengurangan menolak mismatch, quantity×harga/total memeriksa overflow dengan batas nominal terdokumentasi. USD/MYR15.50 = 1550, IDR12000 = 12000. Biaya presisi 10^6 per minor terpisah dari currency_scale, tanpa double dalam bisnis. Header fakta snapshot menyimpan metadata immutable, detail mewarisi header; laporan/cetak ulang memakai metadata tersimpan.
6. Formatter terpusat intl.NumberFormat dengan locale/code/decimalDigits eksplisit, label kode/simbol tidak ambigu dan form tanpa simbol. Double hanya display boundary dengan batas presisi teruji; legacy 64-bit di luar boundary ditampilkan via digit integer dan simbol locale tanpa kehilangan nominal. Formatting tidak menjadi sumber bisnis/persistensi.
7. MoneyTextInputFormatter mengetik unit utama: 12000 → 12.000 id atau 12,000 en, USD15 → 15.00, USD15.50 en/15,50 id. Pertahankan kosong/trailing decimal/fraction sementara; normalisasi akhir blur/submit. Paste/grouping, backspace/Delete separator, insertion/selection/cursor, composing dan locale switch menjaga nilai tanpa controller-loop. Tolak negatif/desimal berlebih/invalid/overflow/clipboard ambigu. Quantity/PIN/barcode/HP tidak memakai formatter uang.
8. Parser digit/string/integer eksak memvalidasi pemisah/grouping locale dan scale. Kosong bukan nol; repository menerima Money/integer tervalidasi, bukan teks. Saat bahasa berubah, format ulang kanonik memakai codec lama sebelum codec baru; composing ditunda sampai selesai, input sementara dijaga.
9. Migration berversi/atomik dengan integrity/FK, pertahankan driver/enkripsi aktual. M2 aktual sqflite biasa dan integer rupiah/micro-rupiah; backfill IDR0 tanpa x100. Metadata ikut kontrak backup/restore; arsip lama dimigrasi di staging, schema lebih baru/invalid ditolak tanpa mengganti DB aktif. Lihat LOCALIZATION-MONEY dan BACKUP-CONTRACT.
10. Uji persistensi/fallback, round-trip semua locale/currency termasuk 0.01/15/15.50/12000/batas besar, mismatch/overflow, clipboard/cursor/selection/delete/composing, live form locale, larangan currency semua fakta, migration M2 tanpa perubahan stok/HPP/nilai, rollback, teks Inggris panjang dan regresi M1–M2. Jalankan gen-l10n/format/analyze/tests/build relevan; tandai hardware/rilis yang belum diuji. M3–M6 wajib meneruskan Money/localization pada layar/draft/fakta/struk/laporan/notifikasi/legal nanti.


## 19. M3.1 — harga grosir dan input kemasan (13 Oktober 2026)

Perubahan kebutuhan diotorisasi pengguna setelah M3 selesai. M1–M3 dipertahankan; milestone ini tidak mencakup M4. Isi lampiran pengguna berikut merupakan kebutuhan aktif; unit dasar saat ini pcs. Harga grosir pilihan manual, bukan harga kemasan. Backup/restore operasional dan pembatalan penjualan tetap M5/M4 yang belum tersedia; M3.1 memperbarui kontrak dan pelestarian snapshotnya tanpa mengklaim fitur tersebut selesai. Driver saat ini sqflite biasa, tanpa SQLCipher. HP sedang dipakai pribadi: tunggu kesiapan pengguna sebelum pengujian perangkat.

### 1. Harga grosir opsional

Tambahkan harga grosir nullable pada produk, mengikuti representasi Money, currency_code, dan scale yang sudah digunakan. NULL berarti tidak tersedia. Harga yang diisi harus positif.

Di Gudang, tampilkan bagian “Harga grosir — opsional”. Perubahan memerlukan akses pengelolaan dan tercatat pada price_history dengan jenis harga yang jelas.

Berikan peringatan jika harga grosir melebihi harga eceran atau berada di bawah HPP. Jangan mengubah harga otomatis.

### 2. Checkbox Grosir pada kasir

Checkbox “Grosir” hanya muncul pada baris produk yang memiliki harga grosir. Default tidak dicentang dan menggunakan harga eceran.

Ketika dicentang, gunakan harga grosir per satuan dasar barang dan hitung ulang total baris, total transaksi, serta sisa piutang. Ketika dilepas, kembali ke harga eceran.

Checkbox berlaku untuk seluruh quantity pada baris tersebut. Pertahankan satu baris per produk: scan ulang menambah quantity dan mempertahankan mode harga terpilih.

Fitur grosir menggunakan pilihan manual, tanpa minimum quantity atau harga bertingkat pada tahap ini. Harga grosir bukan harga per dus.

### 3. Konfigurasi dus/box opsional

Produk boleh mempunyai konfigurasi kemasan berisi:
- Label dus/box.
- Jumlah satuan dasar per dus/box, berupa integer positif.

Konfigurasi boleh kosong. Produk yang tidak memakai kemasan tetap menggunakan alur input satuan dasar seperti sebelumnya.

Pertahankan satu satuan dasar persediaan per produk, default pcs atau satuan dasar yang sudah digunakan proyek. Jangan membuat produk atau saldo stok terpisah untuk dus dan pcs dari barang yang sama.

Mengubah isi dus pada konfigurasi produk tidak mengubah stok, harga, HPP, atau riwayat yang sudah tersimpan.

### 4. Input stok awal dan restock

Sediakan pilihan unit input: satuan dasar atau dus/box.

Jika memilih satuan dasar, tampilkan input jumlah seperti sebelumnya.

Jika memilih dus/box, tampilkan:
- Jumlah dus/box.
- Jumlah pcs/satuan dasar per dus/box.
- Preview jumlah satuan dasar hasil konversi, hanya baca.

Contoh: 5 dus × 40 pcs menghasilkan 200 pcs.

Isi per dus mengambil default dari konfigurasi produk jika tersedia, tetapi boleh dikoreksi untuk penerimaan tersebut. Koreksi penerimaan tidak otomatis mengubah konfigurasi produk.

Quantity dan isi kemasan menggunakan input digit-only serta validasi integer. Tolak input negatif, pecahan, notasi ilmiah, dan overflow; jangan membersihkan input tidak valid menjadi angka lain secara diam-diam.

Restock memerlukan jumlah positif. Stok awal nol tetap mengikuti aturan pembuatan produk yang sudah ada.

### 5. Harga beli mengikuti unit input

Label harga beli harus jelas:
- Input pcs: “Harga beli per pcs”.
- Input dus/box: “Harga beli per dus/box”.

Untuk penerimaan dus:
quantityBase = jumlahDus × isiPerDus
totalPurchaseCost = jumlahDus × hargaBeliPerDus

Contoh: 5 dus, isi 40 pcs, harga beli Rp120.000 per dus menghasilkan 200 pcs dan total biaya Rp600.000.

Gunakan total biaya tersebut untuk memperbarui nilai persediaan dan moving weighted average. Jangan mengalikan harga per dus dengan jumlah pcs.

Biaya per pcs dapat mempunyai pecahan meskipun mata uang memakai nominal bulat. Pertahankan presisi internal HPP dan aturan residu yang sudah ada; jangan membulatkan biaya per pcs terlalu awal.

### 6. Snapshot penerimaan dan riwayat

Simpan quantity satuan dasar sebagai angka yang digunakan perhitungan stok.

Pada detail penerimaan, simpan juga:
- Jumlah yang dimasukkan pengguna.
- Unit input.
- Isi kemasan saat penerimaan.
- Harga beli beserta unit acuannya.
- Total nilai penerimaan.
- Metadata mata uang/skala yang sesuai.

Gunakan snapshot isi kemasan. Jangan menghitung ulang penerimaan lama dari konfigurasi produk terbaru.

stock_history mencatat perubahan jumlah dalam satuan dasar dan merujuk penerimaan sumber. Penyimpanan penerimaan, batch, stok, valuasi, serta history tetap atomik.

### 7. Stok opname dan tampilan stok

Jika input dus digunakan pada stok opname, konversikan jumlah fisik ke satuan dasar sebelum menghitung selisih. Jumlah fisik nol diperbolehkan; isi kemasan tetap harus positif.

Stok opname tetap memakai aturan penyesuaian valuasi yang ada, bukan diperlakukan sebagai pembelian baru.

Tampilkan stok satuan dasar secara jelas. Jika menambahkan tampilan ekuivalen dus dan sisa pcs, beri label “setara”; hasil pembagian tersebut bukan bukti jumlah dus tertutup secara fisik.

Penjualan pada tahap ini tetap menggunakan quantity satuan dasar. Konversi input gudang tidak otomatis menambahkan penjualan per dus, barcode dus, atau konversi harga jual kemasan.

### 8. Draft, checkout, dan laporan

Simpan pricing_mode grosir/eceran dalam draft. Validasi ulang harga saat draft dibuka dan checkout.

Jika harga berubah atau harga grosir tidak lagi tersedia, tampilkan penjelasan dan minta koreksi. Jangan mengganti mode/harga secara diam-diam.

SaleTransactionItem menyimpan pricing_mode dan snapshot harga satuan yang digunakan. HPP tetap mengikuti biaya persediaan, bukan harga eceran/grosir.

Integrasikan dengan checkout atomik, idempotensi, pembatalan, dan recovery yang sudah tersedia. Perubahan keranjang dinonaktifkan saat checkout disimpan.

Detail transaksi dan struk dapat memberi penanda “Grosir”. Cetak ulang menggunakan snapshot transaksi lama.

### 9. Migration dan kompatibilitas

Buat migration berversi tanpa menghapus atau membuat ulang database. Pertahankan enkripsi yang sudah digunakan.

Default data lama:
- Harga grosir NULL.
- Konfigurasi dus/box kosong.
- Mode transaksi/draft lama retail.
- Quantity stok tetap mengikuti satuan dasar sebelumnya.

Untuk penerimaan lama, isi metadata konversi hanya berdasarkan informasi yang benar-benar tersedia. Jangan mengarang bahwa penerimaan lama menggunakan dus.

Perbarui backup/restore agar konfigurasi serta snapshot baru ikut tersimpan. Undo/reversal restock tetap mengikuti batas dependensi stok/valuasi yang sudah ditetapkan.

### 10. Localization, arsitektur, dan pengujian

Tambahkan seluruh label, bantuan, dan validasi ke ARB Indonesia/Inggris. Jelaskan satuan harga dan preview konversi dengan bahasa pengguna.

Gunakan helper/value object konversi yang dapat diuji dan service persediaan yang ada. Jangan menambahkan Provider global atau menaruh operasi persistensi dalam widget.

Uji minimal:
- Produk tanpa grosir/kemasan tetap bekerja.
- Toggle grosir, scan ulang, perubahan quantity, dan persistensi draft.
- Harga grosir berubah/dihapus ketika draft aktif.
- 5 dus × 40 menghasilkan tepat 200 satuan dasar.
- Harga beli per dus menghasilkan total biaya/HPP yang benar.
- USD/MYR dan biaya per satuan dasar yang mempunyai pecahan.
- Isi dus berubah tanpa mengubah stok atau penerimaan lama.
- Input tidak valid, nol sesuai konteks, dan overflow.
- Penjualan, stok opname, undo/reversal, serta rekonsiliasi setelah penerimaan dus.
- Migration dan backup/restore mempertahankan seluruh nilai lama.

Perbarui SPEC, PLAN, STATUS, REQUIREMENTS, dan dokumentasi pemeliharaan. Jalankan formatter, analyze, test relevan, serta regresi M1–M3 yang terdampak. Laporkan hasil aktual dan berhenti setelah M3.1; jangan otomatis melanjutkan M4.

### Catatan eksekusi/retensi data M3.1

Insiden native runner default-uninstall dicatat di INCIDENT-M31-ANDROID-TEST. Test wajib package fixture terpisah, explicit KASIR_INTEGRATION_TEST=true, --no-uninstall, aapt identity sebelum install dan fail-closed Gradle guard. Fixture DB pada package yang sama tidak melindungi data pengguna. Database operasional lama tidak ditemukan dan user tidak mempunyai backup; preservation tidak dipenuhi oleh workflow awal, tidak ada recovery yang diklaim. Ordinary APK dipasang tanpa launch/initialization baru. Kebutuhan produk/pelestarian data tetap berlaku; catatan insiden tidak mengurangi persyaratan.


### Klarifikasi data pengembangan setelah pemeriksaan M3.1

Pengguna mengonfirmasi data yang dimasukkan dummy, mengizinkan reset DB/create baru untuk pengujian ulang, dan belum akan memasukkan data penting hingga M6 selesai. Perlindungan/pelestarian data tetap kebutuhan akhir. Reset kali ini bukan restore; kontrol isolasi package/no-uninstall dan batas bukti tetap wajib. Referensi pembelajaran LESSONS-LEARNED.

Checkpoint tindak lanjut 13 Oktober 2026:128Windows/84native exit0 melalui workflow terpisah, startup/reopen DB baru V6/integrity/FK dan hash retention baseline dummy terbukti. Tidak ada file DB lama yang tersisa pada reset; bukan recovery. Build release dan isolated empty-cashier startup smoke lulus memakai development signing. OEM/TalkBack/full release/performance/actual restore masih unverified, M4–M6 belum diimplementasikan. Bukti VALIDATION-M31-RECHECK/STATUS/REQUIREMENTS; kebutuhan akhir tetap berlaku tanpa dikurangi oleh hasil pengujian ini.


## 20. Kebijakan implementasi M4 (14 Oktober 2026)

M4 diotorisasi pengguna. Koreksi dicatat pada waktu pembalikan, dengan nilai negatif pada periode pembalikan; periode transaksi asli tidak ditulis ulang. Saldo piutang dan persediaan pada layar adalah snapshot saat ini, terpisah dari angka penjualan/pembayaran periode; persediaan seluruh toko tidak dipersempit filter pelanggan.

Pembatalan penjualan penuh memerlukan attestation barang kembali dan penanganan pengembalian dana di toko, PIN serta alasan. Tolak pelunasan lanjutan yang masih aktif; pengguna dapat membalik pembayaran tersebut dahulu jika memang keliru, lalu membatalkan penjualan. Pembalikan pembayaran mandiri membuka kembali piutang pelanggan tanpa mengubah sale/HPP/stok. Receipt tanpa pelanggan tidak boleh dibalik mandiri karena saldo baru tidak mempunyai pemilik; pembayaran checkout anonim dibalik dalam pembatalan penjualan penuh. Asal receipt lama yang tidak dapat dibuktikan ditandai unknown; fakta/snapshot lama tidak direkayasa. Kondisi fakta tidak konsisten ditolak/ditampilkan rekonsiliasi, tidak diperbaiki diam-diam.

Stream commit database hanya menginvalidasi reader/cursor route-scoped; tidak menjadi Provider global atau menggabungkan state fitur. Ringkasan seluruh rentang SQL, rincian keyset50+1/cache3pages, nilai negatif/profit memakai presisi integer/BigInt. SQL integer overflow dilaporkan, tidak dialihkan ke floating point. Benchmark memakai DB fixture terpisah; ukuran/platform/mode/plan/latency aktual dilaporkan. Google Cloud/printer yang disiapkan pengguna tetap tahap M5. M5-M6 tidak diimplementasikan pada M4.


## 21. Keputusan M5 — 16 Oktober 2026

Permintaan terbaru lengkap disimpan pada [M5_REQUEST_20261016.md](M5_REQUEST_20261016.md); keputusan tersebut mengatasi konflik dengan asumsi awal. Database operasional wajib SQLCipher, key acak instalasi terpisah PIN dan dilindungi Keystore. Backup portable wajib terenkripsi dan terautentikasi, recovery kuat terpisah PIN, snapshot konsisten dan safety backup/restore recovery wajib. Drive tetap opsional appDataFolder, bukan sinkronisasi. Printer utama Iware MP-581RL/RPP02N ESC/POS, generic58/80 sesuai capability, pengiriman setelah commit dan status ambigu tidak diulang otomatis. Notifikasi memakai flutter_local_notifications; scheduler best effort/inexact. ApplicationId/nama/signing/aturan bisnis tidak diganti. M6 tidak dimulai.


### Penyesuaian fixture M5 —17 Oktober2026

Atas permintaan pengguna, kolom input recovery backup pada paket uji terisolasi dapat menampilkan teks biasa untuk memeriksa input. Perilaku ini wajib dibatasi compile-time KASIR_INTEGRATION_TEST=true yang identitas APK-nya diverifikasi; paket operasional tetap menyamarkan input. PIN gate dan larangan logging/penangkapan recovery tetap berlaku, tidak menambah autofill rahasia atau mengubah recovery tersimpan.
