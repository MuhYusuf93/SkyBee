# Prompt Codex — SkyBee M5.3

Ralat langsung pengguna 29 Oktober: §8 output label memakai QR code;
[ketentuan QR](M53_QR_LABEL_AMENDMENT.md). Setelah **seluruh** M5.3 selesai,
handoff `.skybee` pada kondisi pertama dibuka: backup lama terverifikasi dahulu,
reset database paket tersebut, seed100produk beragam/beberapa supplier/pelanggan
dan50transaksi, onboarding pending. Ini menggantikan larangan reset `.skybee`
pada handoff akhir saja; data lama tetap dilindungi sampai tahap itu.
[Ketentuan handoff baru](M53_FRESH_EXPLORATION_AMENDMENT.md). Dokumen lampiran
asli di Downloads tidak diubah.

Tanggal penyusunan: 26 Oktober 2026, WIB.
Dasar: catatan pengguna `milestone 5.3` dan `STATUS(8).md` yang dilampirkan.
Revisi 26 Oktober 2026: ditambahkan tagihan/pembayaran supplier, tempo, jadwal kedatangan, pengingat H-1 dan laporan utang supplier. Seluruh bagian di bawah sudah disesuaikan; gunakan dokumen lengkap ini sebagai pengganti versi sebelumnya.

## Permintaan aktif — langsung kerjakan

Implementasikan M5.3 dalam proyek SkyBee yang sedang terbuka. Ini instruksi kerja aktif: audit kode dan status terkini, buat rencana bertahap, implementasikan, jalankan pengujian yang relevan, langsung perbaiki masalah, lalu siapkan handoff aplikasi agar saya dapat mencobanya. Jangan berhenti hanya dengan rencana atau pertanyaan apakah dokumen ini perlu dijalankan.

Saya mengutamakan aplikasi kasir yang nyaman untuk toko kecil, tetapi tetap fleksibel. Perbaiki kata-kata antarmuka dan keputusan teknis yang keliru dalam catatan awal tanpa memperluasnya menjadi ERP. Gunakan keputusan yang sudah diperjelas dalam dokumen ini. Jika terdapat persoalan implementasi rutin, putuskan dan dokumentasikan; tanyakan hanya hambatan nyata yang memerlukan informasi atau keputusan saya.

Multi-device, sinkronisasi LAN/Wi-Fi Direct/Drive, dan pengujian/porting iPhone DITUNDA. M5.4 untuk masukan teman, M5.5 untuk perombakan visual menyeluruh, M6 untuk kesiapan rilis. M5.3 mencakup perapian UI yang diperlukan oleh fitur ini, bukan redesign keseluruhan.

## 1. Baseline dan aturan kerja

1. Baca `AGENTS.md`, `SPEC.md`, `PLAN.md`, `STATUS.md`, handoff aktif, dan laporan terbaru yang benar-benar tersedia di repository. Riwayat lama bukan instruksi untuk mengulang pekerjaan yang sudah ditutup. Periksa source, working tree, branch, paket terpasang dan versi aktual sebelum mengubahnya.
2. Baseline pada status lampiran: SkyBee **0.5.2+12/schema 14**, koreksi printer tanggal 25 Oktober selesai. Jangan menurunkan versi ke +9, mengembalikan footer lama, atau membuang perbaikan printer setelah penutupan M5.2. Jika source aktual lebih baru, gunakan keadaan aktual yang sah dan catat bedanya.
3. Proyek sudah memakai **SQLCipher**, bukan migrasi awal dari sqflite biasa. Pertahankan enkripsi, wrapped key, KDF/PIN, backup portable, integritas dan migrasi yang sudah ada. Tidak boleh fallback ke database plaintext atau melemahkan parameter keamanan demi performa.
4. Flutter + Provider tetap modular per fitur/tanggung jawab. Perhitungan uang, stok, hak akses dan transaksi berada di domain/service/repository, bukan ditumpuk dalam widget atau satu Provider raksasa. Komentar kode menjelaskan aturan bisnis, invariant dan alasan yang tidak jelas; hindari komentar setiap baris yang hanya mengulang kode.
5. Semua UI, validasi, struk, bantuan dan ekspor mendukung ID/EN lewat berkas lokalisasi. Mata uang mengikuti pengaturan toko; bahasa, locale dan currency adalah konsep berbeda. Nilai uang tetap integer minor unit, perhitungan biaya mempertahankan presisi internal proyek, tidak memakai floating point sebagai sumber kebenaran.
6. Pertahankan penjualan atomik/idempotent, snapshot harga/HPP, grosir/promo, kemasan, expiry, piutang, soft delete, undo/reversal, pagination/keyset, debounce dan indeks yang sudah benar. Jangan menghapus kemampuan demi mengoptimalkan satu perangkat.
7. Jangan reset/uninstall/reseed data aplikasi yang sudah dipakai. Jangan menimpa perubahan lokal yang tidak terkait. Gunakan paket dan data sintetis terisolasi untuk pengujian mutasi. Snapshot tertutup atau snapshot konsisten harus mengikuti mekanisme aman proyek; jangan menyalin main DB sembarang ketika WAL masih aktif.
8. Susun `docs/decisions/M53_REQUEST.md` atau padanan sesuai struktur proyek, matriks cakupan dan checkpoint. Lanjutkan bertahap tanpa meminta persetujuan di setiap tahap. Bila konteks/sesi habis, simpan checkpoint spesifik agar dapat dilanjutkan tanpa mengulang seluruh suite.

## 2. Keputusan pengikat untuk mengatasi ambiguitas catatan

| Catatan awal | Keputusan implementasi M5.3 |
|---|---|
| Jumlah karyawan 1/2/3 | Ini **pola pembagian tugas/hak akses**, bukan batas karyawan, akun online, atau jumlah perangkat. Tidak menambahkan sinkronisasi. |
| Tiga karyawan | Gunakan label “3 atau lebih / tugas dipisahkan”: Kasir, Gudang, Pemilik/Laporan. Mode stok aktif diwajibkan dalam pola ini sesuai permintaan saya; perubahan toko lama harus melalui rekonsiliasi yang aman. |
| Mode stok parsial | Diaktifkan kembali hanya sebagai **sebagian produk dilacak, sebagian tidak**. Bukan resep, produksi, bahan baku, atau restoran. |
| 999 | Pertahankan representasi kompatibel `999 + flag tidak dilacak`; jangan pernah menentukan mode hanya dari angka 999. |
| Harga beli/jual pada bantuan fitur | Yang opsional untuk ditampilkan adalah **harga beli/biaya**, bukan harga jual. Harga jual tetap diperlukan. Biaya tidak diketahui berbeda dari biaya nol. |
| ID pelanggan nomor telepon | Telepon adalah kunci pencarian/unik untuk member baru; primary key internal tetap ID stabil agar nomor bisa diperbaiki tanpa merusak riwayat. |
| Supplier diketuk | Buka barang yang terkait **supplier**, bukan kategori; itu salah tulis dalam catatan. |
| Retur dalam sub-menu supplier | Implementasikan **retur barang ke supplier**. Jangan menambahkan modul retur pelanggan/refund penjualan baru di luar kemampuan yang sudah ada. |
| Total pembayaran supplier dan HPP | Pisahkan nilai pembelian, pembayaran, utang supplier dan biaya persediaan/HPP. Pelunasan supplier mengurangi utang/kas, bukan membebankan HPP untuk kedua kalinya. |
| Tempo dan kedatangan supplier | Tanggal jatuh tempo melekat pada tagihan; jadwal kedatangan melekat pada rencana kunjungan supplier. Keduanya memakai kalender dan pengingat H-1 yang berbeda. |
| Proyeksi omzet/laba | Tampilkan **potensi penjualan stok saat ini**, dengan asumsi yang jelas; bukan ramalan penjualan per bulan atau laba bersih terjamin. |
| Hapus database lebih dari 3 bulan | Ini **retensi berkas cadangan lama**, bukan penghapusan transaksi/barang/database aktif berdasarkan umur. |
| Hapus akun | Karena aplikasi offline tanpa akun toko online, gunakan istilah **“Hapus seluruh data toko di perangkat ini”**. Jangan membuat akun online baru untuk memenuhi istilah ini. |

## 3. onboarding, preferensi fitur dan mode stok

### 3.1 Onboarding instalasi baru

Hanya tampil pada toko baru yang belum selesai penyiapan. Update toko lama tidak boleh tiba-tiba dianggap instalasi baru. Tombol bahasa **ID / EN** tetap tersedia di bagian atas setiap langkah; pergantian bahasa tidak menghapus isian. Simpan kemajuan secara aman agar proses dapat dilanjutkan setelah aplikasi ditutup. PIN mentah tidak boleh disimpan dalam draft.

Urutan:

1. **Identitas toko**: nama toko wajib; alamat dan WA/telepon opsional, tetap menggunakan validasi nomor yang benar. Tombol “Selanjutnya”.
2. **Pembagian tugas**: judul “Bagaimana toko Anda dikelola?”; pilihan 1, 2, 3 atau lebih. Checkbox “Saya mengelola toko sendiri” mengisi 1 dan menonaktifkan dropdown. Penjelasan:
   - 1: pemilik menjalankan kasir dan pengelolaan.
   - 2: kasir dan pengelola; pengelola menangani gudang serta laporan/pengaturan.
   - 3 atau lebih: kasir, petugas gudang, dan pemilik/pengelola laporan dipisahkan.
   - Ini pembagian akses pada aplikasi/perangkat yang sama, bukan akun pribadi setiap pegawai.
3. **Pengamanan pengelolaan**: buat dan konfirmasi PIN empat digit; perilaku empat kotak, auto-submit dan tombol manual tetap ada. Untuk pola 1/2 satu PIN pengelolaan. Pola 3 dua PIN berbeda: Gudang dan Pemilik/Laporan. Jangan mengizinkan keduanya sama dalam mode terpisah, karena tujuan pemisahan akses akan hilang. Jelaskan PIN mengamankan pengelolaan; kasir tetap terbuka kecuali kunci kasir opsional diaktifkan. Sarankan biometrik untuk pemilik/pengelola; pada mode terpisah biometrik tidak dipakai untuk identitas gudang.
4. **Pelacakan stok**: pola 1/2 memilih “Tidak melacak stok”, “Melacak sebagian barang”, atau “Melacak semua barang”. Pola 3 melewati pertanyaan ini dengan ringkasan “Pelacakan stok aktif untuk pembagian tugas gudang”. Sediakan bantuan mengenai kewajiban pencatatan transaksi dan HPP. Jangan memakai klaim “realtime antardevice”.
5. **Fitur yang ditampilkan**: checkbox harga grosir, kemasan dus/box, harga beli/biaya, barcode, pelacakan kedaluwarsa. Setiap opsi memiliki bantuan “?”. Toko baru dapat memakai preset sederhana dengan fitur tambahan belum aktif; ringkasan tetap dapat ditinjau sebelum selesai. Pengguna lama mempertahankan pilihan/kemampuan yang sudah digunakan, bukan dipaksa mengikuti preset baru.
6. **Printer**: “Apakah Anda ingin menyiapkan printer struk sekarang?” pilihan “Lewati”/“Siapkan printer”. Jika ya, pilih profil/transport, hubungkan dan tawarkan test print melalui jalur yang sudah ada. Gagal atau batal test tidak menghalangi penyelesaian onboarding. Simpan profil hanya setelah pengguna menyimpannya. Jelaskan dapat diatur nanti.
7. **Ringkasan dan selesai**: validasi seluruh penyiapan, commit konfigurasi dengan aman, baru tandai selesai. Onboarding tidak memerlukan internet atau akun Google. Pengaturan currency yang sudah ada tetap tersedia; IDR default toko baru.

Untuk toko lama: identitas/PIN/config yang valid dipertahankan. Isi field baru dengan default kompatibel. Bila belum ada PIN karena setup lama belum tuntas, selesaikan pengamanan melalui alur setup yang sesuai; jangan membuka pengelolaan tanpa pengamanan. Tidak perlu mengulang onboarding penuh.

### 3.2 Bantuan fitur yang harus disampaikan dengan benar

- **Grosir**: harga khusus yang dikonfigurasi per barang; opsional dan tetap mengikuti aturan grosir/promo proyek. Mengaktifkan fitur tidak otomatis memberi semua barang harga grosir.
- **Dus/box**: input jumlah kemasan dan isi per kemasan; saldo dasar tetap pcs. Perubahan konfigurasi tidak mengubah transaksi lama.
- **Harga beli/biaya**: membantu HPP, nilai persediaan dan estimasi laba. Jika tidak dicatat, omzet masih dapat dicatat tetapi HPP/laba mungkin tidak lengkap. Jangan mengganti biaya yang tidak diketahui menjadi nol.
- **Barcode**: bisa memakai kamera perangkat **atau** scanner eksternal yang didukung; tidak wajib memiliki scanner fisik terpisah. Barang tanpa barcode dapat memakai kode internal otomatis dan label cetak yang didukung.
- **Kedaluwarsa**: mencatat tanggal/batch untuk pengingat dan kelayakan jual; tidak memastikan kondisi fisik barang tanpa pemeriksaan. Menyembunyikan input tidak menghapus tanggal/batch atau mengubah barang kedaluwarsa menjadi layak jual.

### 3.3 Mode stok dan biaya

1. Mode toko `nonaktif`, `parsial`, `aktif` menjadi kebijakan pembuatan/perubahan produk, bukan manipulasi massal saldo tanpa konfirmasi.
2. **Aktif**: jumlah awal wajib diisi eksplisit, termasuk 0 jika belum ada stok. Jangan mengisi 999 ketika isian wajib kosong. Semua produk operasional harus dilacak. Migrasi dari parsial/nonaktif memerlukan input jumlah fisik dan penanganan biaya produk yang belum dilacak.
3. **Parsial**: setiap produk mempunyai pilihan “Lacak stok barang ini”. Jika aktif, jumlah awal wajib. Jika tidak, simpan kompatibilitas 999+flag untracked. Ini pilihan per barang, tidak ada produksi otomatis.
4. **Nonaktif**: produk baru tidak dilacak, jumlah fisik tidak wajib. Pertahankan 999+flag untracked, tidak berkurang setelah penjualan, tidak dibatasi 999, tidak dimasukkan ke stok fisik/nilai persediaan/selisih opname. Jika ada produk lama yang masih dilacak, perubahan mode harus menyelesaikan transisinya secara eksplisit; jangan menyembunyikan ketidaksesuaian kebijakan.
5. Eksplisit 999 pada barang tracked tetap stok nyata 999. Semua laporan/output yang menampilkan nilai fiktif diberi label **“999 — Stok fiktif (tidak dilacak)”**; lebih baik tampilkan “Tidak dilacak” sebagai informasi utama di UI operasional.
6. Teks bantuan: “Stok yang tidak dilacak tidak menunjukkan jumlah barang di toko dan tidak berkurang saat penjualan. Anda tetap perlu memastikan barang tersedia. Jika stok dilacak, catat barang masuk, penjualan, retur, dan koreksi agar data sesuai kondisi fisik. Penjualan di luar aplikasi perlu dicatat kembali atau direkonsiliasi.” Jangan memakai larangan absolut yang seolah aplikasi dapat mengawasi transaksi di luar sistem.
7. HPP tracked tetap memakai metode average cost yang sudah ada, bukan diganti FIFO karena penambahan barcode/opname. HPP untracked memakai biaya acuan per pcs yang diketahui dan disnapshot saat penjualan.
8. Saat fitur biaya aktif, input harga beli wajib valid pada tambah barang/barang masuk yang memerlukannya. Biaya 0 hanya jika disengaja dan dikonfirmasi sebagai tanpa biaya; jangan menyamakan kosong dengan 0.
9. Saat fitur biaya tidak ditampilkan, barang tidak boleh dipaksa mengisi biaya hanya untuk memakai kasir. Pertahankan biaya historis yang diketahui; biaya baru yang tidak diketahui diberi status eksplisit, bukan nol fiktif atau harga beli lama yang diam-diam dianggap aktual. Jika data biaya tidak lengkap, HPP/nilai/laba terkait ditandai **belum lengkap/estimasi**, dengan jumlah penjualan atau barang yang belum memiliki biaya. Jangan menyajikan omzet sebagai laba. Definisikan propagasi status biaya tidak lengkap pada average cost dan rekonsiliasi di domain; jangan membagi nilai known saja dengan seluruh quantity seolah unknown bernilai nol. Pengisian biaya kemudian tidak mengubah snapshot penjualan lama secara diam-diam.
10. Pergantian mode/fitur tersedia bagi pemilik dalam Pengaturan Toko, dengan pratinjau dampak. Mematikan fitur tampilan tidak menghapus harga grosir, konfigurasi kemasan, barcode, biaya, tanggal atau sejarah. Transisi yang memengaruhi saldo/nilai harus memakai use case dan audit history yang benar.

## 4. hak akses, PIN dan penguncian

### 4.1 Matriks akses

Gunakan istilah **Pemilik/Laporan** untuk akses tertinggi karena pekerjaannya mencakup pengaturan, bukan hanya membaca laporan.

| Kemampuan | Kasir | Gudang | Pemilik/Laporan |
|---|---|---|---|
| Kasir, keranjang, checkout, pelanggan untuk transaksi/piutang sesuai kebijakan lama | Ya | Ya bila beralih ke kasir | Ya |
| Pengaturan printer publik dan nominal uang cepat | Ya, hanya area operasional tersebut | Ya | Ya |
| Barang, kategori, supplier; barang masuk, retur supplier, rak, opname, label | Tidak | Ya | Ya |
| Tagihan supplier dari penerimaan dan jadwal kedatangan | Tidak | Ya, informasi operasional supplier | Ya |
| Posting pembayaran/kredit supplier, ubah jatuh tempo tagihan final, laporan utang lintas supplier | Tidak | Tidak | Ya |
| Perubahan biaya/harga yang memang diperlukan pekerjaan gudang | Tidak | Ya dengan validasi yang sama | Ya |
| Laporan laba, potensi nilai jual, selisih opname, audit kas | Tidak | Tidak | Ya |
| Pengaturan toko, mode stok/fitur, backup/restore, PIN/hak akses, hapus data | Tidak | Tidak | Ya |

Pada pola 1/2 satu PIN memberi akses pengelolaan penuh seperti sebelumnya. Pada pola 3, pilih akses yang ingin dibuka sebelum autentikasi; jangan otomatis mencoba semua verifier dan memberikan akses tertinggi yang cocok. Proteksi harus diterapkan pada use case/repository dan protected reads, bukan sekadar menyembunyikan menu. Periksa juga jalur promo/rak/label/undo, notifikasi, deep link, route lama dan callback async.

Pemilik boleh mengatur ulang PIN gudang setelah autentikasi pemilik. Gudang tidak boleh mengganti PIN pemilik, mengubah pembagian akses, membaca laporan keuntungan atau menaikkan sesi. Perubahan pola tugas/PIN mencabut capability/sesi lama dan menjaga recovery yang sudah ada. Jangan membangun sistem akun karyawan/cloud pada M5.3.

Gudang dapat melihat nilai tagihan, status pembayaran dan ringkasan supplier yang diperlukan untuk penerimaan barang, tanpa memperoleh laporan laba atau laporan keuangan semua supplier. Gudang boleh mengisi informasi pembayaran yang diberitahukan pada draft, tetapi **posting pembayaran/penyesuaian utang** hanya oleh Pemilik/Laporan. Pada pola 1/2, pemegang PIN pengelolaan penuh memiliki kewenangan itu. Pembuatan penerimaan tidak boleh diam-diam mencatat pembayaran final lewat capability gudang.

### 4.2 Perilaku PIN dan biometrik

1. PIN pengelolaan dibuat melalui onboarding/setup, bukan dialog pendaftaran baru setiap pertama masuk Kelola. Dialog unlock empat kotak: numerik saja, 1 digit per kotak, fokus otomatis, paste empat digit, backspace benar, auto-submit hanya sekali setelah lengkap, tombol manual tetap ada, show/hide tetap aman. Kegagalan/lockout dan KDF lama tetap berlaku.
2. Biometrik yang berhasil tidak otomatis membuktikan jabatan pegawai; semua biometrik yang terdaftar pada perangkat berpotensi membuka akses itu. Jelaskan singkat saat aktivasi. Jangan mengubah enrollment atau kunci layar OS.
3. **Pengingat PIN 72 jam**: bagi akses yang memakai biometrik, jika sudah 72 jam sejak verifikasi PIN aplikasi terakhir yang sukses untuk akses tersebut, pembukaan sesi terlindungi berikutnya wajib menggunakan PIN. Bukan tiga kali sehari dan bukan memaksa kasir memasukkan PIN di tengah transaksi. Setelah PIN sukses, mulai interval baru; login biometrik tidak mereset interval ini. Tangani restart/perubahan jam secara konservatif, tanpa loop dan tanpa background alarm wajib.
4. Grace period/penguncian sesi pengelolaan yang sudah ada dipertahankan. Dialog izin kamera/Bluetooth, biometric prompt, SAF/file picker atau intent WhatsApp bukan alasan membuat loop PIN. Tidak boleh memakai flag “abaikan lifecycle” yang tertinggal dan membypass penguncian.
5. **Bug Back pada PIN**: dari submenu pengelolaan mana pun yang terkunci, tombol Back HP maupun tombol kembali dialog harus menutup seluruh stack pengelolaan dan kembali ke Kasir, bukan naik satu submenu terlindungi. Cabut sesi, jangan tampilkan data terlindungi sesaat. Keranjang tetap utuh. Dirty draft yang belum disimpan tidak boleh di-commit diam-diam saat keluar; pertahankan melalui mekanisme aman yang sudah ada atau buang sesuai kebijakan keluar yang terdokumentasi, tanpa menampilkan kembali draft terlindungi sebelum autentikasi.

### 4.3 Kunci kasir opsional

- Default nonaktif. Pengaturan hanya pemilik. Sediakan shortcut “Kunci kasir” ketika fitur aktif.
- Pemicu: tombol tersebut; dan **layar perangkat benar-benar terkunci/noninteraktif** jika opsi “Kunci kasir saat layar terkunci” aktif. Dialog izin, notifikasi, perpindahan sesaat ke aplikasi lain tidak otomatis menjadi pemicu ini. Jika OS tidak memberi pembedaan yang dapat diandalkan, dokumentasikan batasnya dan utamakan kunci manual; jangan mengklaim deteksi yang tidak ada.
- Gunakan PIN kasir sendiri atau referensi PIN pengelolaan sesuai pilihan pemilik. Jangan menyalin PIN plaintext. Memakai PIN kasir/rujukan pengelolaan untuk membuka kasir **tidak** memberikan capability Kelola. PIN gudang/pemilik tetap berbeda di mode terpisah.
- Relock tidak menghapus keranjang, tender draft, atau membuat penjualan ganda. Jangan menambah permintaan PIN untuk kasir yang tidak mengaktifkan fitur ini.

## 5. kasir, pencarian dan pembayaran

### 5.1 Pencarian barang

1. Hasil yang tidak layak jual, kedaluwarsa tanpa saldo batch layak, atau stok tracked habis diletakkan paling bawah. Masih dapat ditampilkan sebagai informasi dengan status dan tidak dapat dimasukkan ke keranjang jika aturan jual melarangnya. Untracked bukan stok habis walau database memakai sentinel.
2. Tambahkan urutan **“Paling sering terjual”**, dengan default yang sesuai perilaku cepat kasir. Setelah tier kelayakan jual, urutkan hasil relevan berdasarkan jumlah transaksi penjualan selesai yang memuat barang selama 30 hari terakhir, lalu quantity bersih, relevansi dan ID stabil sebagai tie-break. Reversal penuh/parsial tidak boleh membuat popularitas palsu. Jelaskan definisinya di bantuan; tidak memerlukan pilihan algoritma rumit bagi user.
3. Pencarian “b” dapat menaruh beras C di atas baygon sesuai popularitas, tetapi pencarian barcode/kode persis tetap diprioritaskan sebagai exact match yang benar. Popularitas tidak boleh memasukkan barang yang tidak cocok dengan pencarian.
4. Jangan SELECT seluruh histori dan menyortirnya di Dart. Gunakan agregat/indeks/cache turunan yang dapat direkonstruksi; batasi update dan gunakan cursor/keyset yang sesuai urutan baru. Cursor harus stabil pada tie dan refresh hasil saat transaksi baru mengubah urutan. Pertahankan debounce, kategori/alias/normalisasi pencarian, dan fungsi fokus pencarian M5.2.

### 5.2 Uang cepat dan numpad

1. Pindahkan pengaturan nominal uang cepat dari Kelola ke **Kasir → Bayar → Uang cepat → Atur nominal**. Kasir dapat mengatur tanpa PIN pengelolaan; validasi positive/unique dan currency tetap ada. Jangan memberi akses pengaturan toko lain.
2. Tombol pecahan kini **menambah**, bukan mengganti uang diterima. Tagihan Rp93.000, tekan 50.000 + 20.000 + 10.000 + 10.000 + 5.000 menghasilkan Rp95.000, kembalian Rp2.000. Tampilkan jumlah lembar/koin per pecahan dan tombol mengurangi/koreksi agar salah ketuk mudah dibatalkan.
3. Tambahkan **Bersihkan uang diterima**, yang hanya membersihkan tender draft beserta rincian pecahannya, bukan keranjang atau pembayaran tersimpan.
4. “Uang pas” mengisi total yang harus dibayar. Jika setelah itu pengguna mengetik digit pertama di numpad, **ganti** nilai hasil “Uang pas”, jangan append. Simpan state asal nilai/replace-on-next-digit yang jelas; jangan menebak dari nilai kebetulan sama dengan total. Berlaku juga untuk input awal dari preset yang memang dimaksudkan untuk diganti.
5. Hapus tombol “Konfirmasi nominal” bila audit membuktikan tidak punya efek bisnis yang diperlukan; perubahan tender tampil live. Letakkan tombol **hapus satu digit** di posisinya. Posisi lama hapus satu digit menjadi **000**. Tombol 000 mengikuti aturan formatter dan minor unit, tidak menghasilkan nilai/desimal yang keliru untuk USD/MYR/EUR. Batasi panjang/overflow.
6. Perpindahan numpad ↔ pecahan tidak boleh merusak angka atau berpura-pura mengetahui komposisi fisik. Jika nilai manual tidak mempunyai rincian pecahan, tampilkan status tersebut. Dalam mode audit wajib, input nominal tanpa rincian fisik tidak boleh menjadi jalan pintas.

### 5.3 Pencatatan uang fisik opsional

Implementasikan tiga kebijakan yang sederhana:

- **Nonaktif**: checkout biasa; numpad dan uang cepat dapat dipakai tanpa pencatatan laci lengkap.
- **Catatan kasir**: kasir menyalakan pencatatan harian untuk membantu menghitung uang; data tidak dihapus saat ganti tanggal. Tidak otomatis menjadi kewajiban audit pemilik.
- **Audit wajib oleh pemilik**: ditetapkan pemilik, kasir tidak dapat mematikannya. Pencatatan pecahan aktif; numpad nominal tender disembunyikan/dinonaktifkan, termasuk jalan pintas “Uang pas” yang tidak memiliki rincian pecahan.

Aturan:

1. Pisahkan **uang diserahkan pelanggan**, **bagian yang membayar tagihan**, **kembalian**, **piutang**, dan **uang laci**. Tender Rp95.000 dengan kembalian Rp2.000 menghasilkan kas masuk bersih Rp93.000, bukan omzet Rp95.000.
2. Rincian pecahan masuk adalah data yang dinyatakan kasir, bukan sensor penghitung uang. Label audit tidak menjamin kejujuran/kebenaran fisik.
3. Untuk catatan laci yang bermakna, sediakan saldo awal per pecahan, catatan kas masuk/keluar nonpenjualan yang sederhana beserta alasan, dan setoran/penyerahan uang. Ini jurnal laci, bukan modul pengeluaran atau akuntansi umum. Jika saldo awal tidak diketahui, jangan mengklaim jumlah lembar seharusnya sudah pasti.
4. Rincian kembalian default dapat disembunyikan pada dropdown saat pencatatan tidak aktif. Wajib diisi ketika pencatatan uang fisik aktif, dengan total tepat sama dengan kembalian yang dihitung. Tolak kelebihan/kekurangan; jangan otomatis membulatkan diam-diam. Untuk pembayaran sebagian/utang tanpa kelebihan tender, kembalian 0.
5. Boleh sarankan komposisi kembalian dari saldo pecahan yang diketahui; user mengonfirmasi/koreksi. Pecahan kurang/tidak diketahui mendapat penjelasan dan alur pencatatan koreksi yang dapat diaudit, bukan saldo lembar negatif atau bypass tersembunyi. Jangan mengurangi saldo hanya karena menekan tombol di draft.
6. Commit sale/payment, detail tender/kembalian, mutasi laci, stock/history/piutang harus konsisten dalam transaksi/idempotency boundary yang tepat. Retry/double-tap, batal checkout, reversal dan crash tidak boleh menduplikasi kas atau memotong uang sebelum sale tersimpan.
7. Pelunasan piutang tunai dan transaksi kas lain yang sudah didukung juga memengaruhi laci satu kali; tidak menambah omzet/HPP lagi. Metode nontunai yang mungkin sudah ada tidak masuk laci. Jangan menambahkan integrasi QRIS baru.
   Pembayaran supplier yang secara eksplisit diambil dari laci tercatat sebagai kas keluar satu kali, dengan referensi pembayaran dan rincian pecahan jika audit fisik aktif. Pembayaran supplier dari transfer/rekening atau uang pribadi pemilik tidak otomatis memotong laci kasir. Jangan menghitung kas keluar dua kali melalui jurnal manual dan posting pembayaran yang sama.
8. Pada penutupan hari, kasir mengisi hitungan fisik. Rumus uang yang diharapkan: saldo awal + kas masuk − kembalian − kas keluar/setoran yang tercatat. Bandingkan nilai dan jumlah pecahan; simpan selisih dengan alasan bila ada. Selisih tidak otomatis menjadi pencurian atau mengubah penjualan.
9. Simpan sesi harian dengan timezone toko dan currency snapshot. Lewat pukul 00.00 **jangan menghapus atau mengarang hasil penutupan/hitungan fisik**. Tandai hari sebelumnya perlu ditutup bila belum selesai; hari baru mempunyai pencatatan sendiri. Buka kembali, lintas tengah malam dan app tidak aktif beberapa hari harus konsisten dan tidak membuat carry-over saldo ganda.
10. Pada mode audit, rincian tersimpan dapat dilihat pemilik dalam detail penjualan dan laporan kas. Pada mode catatan kasir tetap tersedia untuk kasir sesuai desainnya; jangan menyebutnya rahasia terenkripsi dari pemilik perangkat. Riwayat audit yang sudah dibuat tidak hilang saat mode dimatikan.

## 6. pelanggan/member dan piutang

1. Pada Bayar, tambahkan bagian dropdown opsional **Pelanggan**: “Cari pelanggan” dan “Buat pelanggan baru”. Pembelian lunas tetap boleh tanpa member. Untuk transaksi yang menyisakan piutang, pemilihan/pembuatan member baru menjadi wajib.
2. Member baru: nama wajib, nomor telepon wajib dan unik setelah normalisasi, alamat opsional. Gunakan ID internal stabil; jangan memakai nama sebagai primary key atau menggabungkan dua orang bernama sama. Nomor bisa diubah tanpa memutus foreign key/transaksi.
3. Pencarian berdasarkan nama/nomor; urutkan pelanggan cocok berdasarkan jumlah transaksi selesai, dengan tie-break stabil. Pembayaran piutang bukan kunjungan pembelian baru untuk statistik. Tampilkan data seperlunya, bukan seluruh data pribadi pada daftar publik yang tidak diperlukan.
4. Nomor opsional supplier/identitas toko tetap opsional; validasi anggota baru lebih ketat karena memang wajib. Kosong/spasi-only dibedakan dari format invalid secara konsisten. Nomor menerima bentuk nasional/internasional yang sah melalui aturan negara/kode telepon yang jelas, bukan asumsi semua negara +62. Normalisasikan 08… dan +62… ke identitas sama untuk Indonesia. Jangan menentukan negara nomor berdasarkan currency saja. Jangan mengklaim validasi format membuktikan nomor aktif/terdaftar WhatsApp.
5. Pada output detail nomor, aksi WhatsApp memakai nomor internasional yang dinormalisasi, dibuka setelah user mengetuk. Tidak mengirim pesan otomatis. Jika aplikasi/nomor tidak tersedia, beri fallback salin nomor atau penjelasan; intent tidak memicu loop PIN.
6. Sediakan CRUD pelanggan di pengelolaan untuk pemilik. “Hapus” pelanggan yang punya histori/piutang menjadi arsip atau diblokir sesuai kewajiban, bukan menghapus transaksi/utang. Kasir boleh membuat member dari transaksi, bukan memperoleh akses manajemen massal data pribadi.
7. Piutang dihubungkan ke member dan transaksi asal. Detail menunjukkan produk, quantity, nilai snapshot dan sisa piutang transaksi. Untuk pembayaran sebagian, piutang adalah saldo transaksi; **jangan mengarang pembagian utang tiap produk** bila pembayaran tidak dialokasikan ke baris tertentu. Tampilkan barang transaksi dan saldo transaksi secara jelas.
8. Pertahankan tombol “Lunas semua”, pembayaran sebagian, histori pembayaran dan rekonsiliasi. Lunas menutup saldo aktif, bukan menghapus bukti historis.
9. **Migrasi pelanggan lama**: nomor kosong/duplikat/invalid tidak boleh membuat migrasi gagal atau utang lama tak bisa dilunasi. Pertahankan ID dan histori, tandai “data pelanggan perlu dilengkapi”. Member baru wajib nomor; transaksi utang baru pada profil lama meminta pembaruan bila perlu. Penggabungan duplikat hanya melalui tindakan eksplisit pemilik, tidak berdasarkan nama. Tidak mengirim SMS/OTP atau meminta akses kontak ponsel.

## 7. barcode, barang, kategori dan supplier

### 7.1 Kamera dan scanner

1. Scan barcode dengan kamera di kasir dan form/operasi gudang. Reuse kode lookup scanner eksternal; pertahankan leading zero dan exact-match, jangan parse barcode menjadi integer.
2. Pilih implementasi Android yang dapat bekerja offline; periksa apakah model perlu dibundel/download awal, dukungan Google Play services dan ABI/min SDK sesuai perangkat aktual. Tidak boleh mengasumsikan DV punya kamera atau Google Play services lengkap. Tanpa kamera/izin ditolak, pencarian manual dan scanner eksternal tetap berfungsi.
3. Kamera tidak boleh menambahkan satu barang berulang pada setiap frame ketika barcode masih diam di layar. Ada feedback sukses/gagal dan mekanisme re-arm/pindai lagi yang jelas agar scan fisik berikutnya kode sama benar-benar menambah 1. Bedakan dedup frame kamera dari scan berulang yang disengaja.
4. Unknown barcode: tampilkan pesan dan bunyi singkat bila didukung, dengan visual fallback. Di gudang user dapat memisahkan/mendaftarkan barang; jangan otomatis membuat produk kosong. Kamera, audio dan lifecycle tidak membocorkan sesi atau menghapus draft.
5. Batasi format barcode yang sesuai, pilih hasil jika banyak kode terdeteksi; jangan membuka URL atau menjalankan isi barcode sembarang.

### 7.2 Barang dan form

1. Daftar gudang: kelompok barang dengan stok kedaluwarsa terlebih dahulu, berikut tracked habis, lalu barang lainnya menurut waktu penambahan terbaru. Satu produk bisa mempunyai stok expired dan stok layak; tampilkan keduanya, jangan memblokir seluruh produk hanya karena satu batch expired. Kategori/rak/supplier dan pencarian tetap dapat digabung.
2. Filter “Ada stok kedaluwarsa” dan “Stok habis”. Jangan menganggap 999/untracked sebagai stockout. Definisi expired konsisten dengan expiry policy/day boundary proyek; gunakan jumlah expired yang masih ada, bukan batch lama bersaldo nol.
3. Saat Barang masuk, isi harga beli per pcs dari **harga pembelian terakhir yang sesuai**, bukan average cost tanpa label. Jika yang tersedia hanya biaya acuan, labeli sebagai acuan; jika tidak diketahui, biarkan kosong. Peringatan kuning: “Harga ini diambil dari pembelian terakhir. Periksa dan ubah jika harga saat ini berbeda.” Hilangkan saat user mengubahnya. Jika dikembalikan ke nilai awal, reminder dapat muncul kembali. Konversi harga per dus/pcs tetap mengikuti unit input, bukan copy angka mentah yang salah.
4. Tampilkan field sesuai preferensi fitur toko; field tersembunyi tidak boleh tetap menghasilkan error “wajib diisi” tanpa penjelasan. Mode stok aktif/parsial dilaksanakan sesuai §3.3.
5. Hilangkan pesan umum seperti “lengkapi nominal/jumlah dengan angka dan tanggal yyyy-MM-dd”. Gunakan error per field dengan label yang benar-benar tampil, border merah, scroll ke field invalid pertama dan fokus bila relevan. Picker tanggal tidak diperlakukan sebagai teks bebas. Input kosong, parse gagal, biaya dan grosir salah harus menunjuk field yang tepat.
6. Terapkan preferensi peringatan harga rendah **di tambah, ubah barang dan seluruh jalur yang mengubah harga terkait**, termasuk harga grosir. Threshold memakai nilai uang sesuai currency, bukan sekadar menghitung jumlah digit. Preferensi IDR100 harus mengingatkan harga grosir IDR99 di Ubah barang. Tidak mengubah threshold menjadi USD100 tanpa konfirmasi saat currency berubah.
7. Pertahankan validasi keras harga beli/grosir melebihi harga jual dari M5.2 dan perbaiki label salah. Harga tidak umum sesuai threshold boleh mengikuti konfirmasi/preferensi yang disepakati; konflik harga yang memang dilarang bukan warning yang bisa dibypass. Biaya tidak diketahui ditangani sebagai unknown, bukan validasi angka nol buatan.
8. Rapikan khusus form Tambah/Ubah barang: grup informasi dasar, harga, stok/kemasan, detail opsional. Urutan fokus jelas, section opsional ringkas, label/helper konsisten, tidak overflow pada layar kecil/keyboard terbuka. Tidak melakukan redesign global M5.5.
9. Tambah satuan **ons** pada berat/volume. Maknanya lokal Indonesia **1 ons = 100 gram**, bukan ounce internasional. EN tampilkan “ons (100 g)” atau penjelasan setara. Metadata ini bukan satuan stok pecahan. Desimal mengikuti locale angka yang dipilih; jangan mengikat aturan pemisah desimal semata pada currency. Parser/formatter bersama mencegah karakter lain atau dua pemisah.
10. Semua form baru mengikuti unfocus luar input, dirty guard berdasarkan perubahan dari baseline, dan undo yang sudah ada. Checkbox tidak berubah hanya karena kehilangan fokus. Mengetuk Simpan berkali-kali tidak membuat record ganda.

### 7.3 Stok opname dengan scan

1. Buat **sesi draft opname**. Scan fisik menambah hitungan draft per barang; barcode sama menambah quantity, ada minus/ubah/reset/undo untuk salah scan. **Tidak langsung menambah stok database**.
2. Tampilkan stok sistem, jumlah terhitung, selisih dan status belum dihitung. Belum discan **bukan** otomatis jumlah fisik 0; input 0 memerlukan pilihan eksplisit.
3. Bekukan baseline/revisi pada awal penghitungan. Pada finalisasi, jika stok berubah karena penjualan/restock setelah baseline, jangan overwrite dengan angka lama. Pilih mekanisme sederhana: tolak finalisasi baris berubah, tampilkan konflik dan minta hitung ulang/rekonsiliasi dengan mutasi yang jelas. Tidak memerlukan multi-device untuk muncul race ini; worker/use case lokal pun perlu aman.
4. Barcode produk mengidentifikasi jenis barang, **bukan serial unik setiap pcs**. Aplikasi tidak dapat membuktikan barang yang sama tidak discan dua kali. Jelaskan pada panduan tanpa menghambat scanning.
5. Jika produk punya beberapa batch/expiry, scan barcode produk tidak menentukan batch fisik. Minta rincian batch untuk koreksi yang memerlukannya; jangan mengarang batch otomatis. Pertahankan costing average yang ada; pemilihan fisik FEFO/pemeriksaan expiry tidak mengubah metode HPP menjadi FIFO.
6. Finalisasi memerlukan ringkasan dan alasan koreksi, memperbarui stok/history/nilai secara atomik sesuai kewenangan. Simpan baseline, count, delta, waktu dan sumber operasi. Gunakan label actor berdasarkan capability yang diketahui; PIN bersama bukan identifikasi pegawai perorangan.
7. Untracked tidak dapat dilaporkan hilang berdasarkan sentinel999. Tawarkan mengaktifkan tracking melalui alur resmi bila dibutuhkan.

### 7.4 Kategori dan supplier

- Ketuk kategori → daftar barang terfilter kategori tersebut. Long-press tetap ubah nama dan tampilkan petunjuk “Tekan lama untuk mengubah nama kategori”; sediakan aksi edit yang dapat ditemukan tanpa gesture saja bila diperlukan aksesibilitas.
- Ketuk supplier → daftar barang terkait supplier itu. Tambahkan tombol edit supplier yang jelas; bukan langsung edit saat mengetuk nama. Form opsional kontak/email/website tetap tervalidasi dan tidak memberi hak laporan.
- Jika model lama hanya menghubungkan produk ke satu supplier, pertahankan model tersebut untuk daftar master. Penerimaan/retur harus menyimpan supplier transaksi sendiri; jangan otomatis memindahkan master supplier hanya karena sekali menerima dari supplier lain, dan jangan menganggap seluruh stok kini pasti berasal dari master supplier itu.
- Pada daftar/detail supplier, tambahkan ringkasan **Total pembelian**, **Sudah dibayar**, **Sisa utang**, dan **Lewat jatuh tempo**, dengan periode/cakupan yang jelas. Ketuk nama supplier tetap membuka barang terkait sesuai permintaan awal; sediakan tab/tombol **Transaksi supplier** untuk tagihan, pembayaran dan ringkasannya, serta bagian **Jadwal kedatangan**. Jangan mengganti arti “Sudah dibayar” menjadi nilai pembelian.
- Supplier tetap opsional untuk pendataan barang dan penerimaan sederhana. Namun pencatatan tagihan/tempo wajib menunjuk supplier nyata dengan ID stabil; jangan menaruh seluruh utang supplier yang belum dipilih pada satu supplier anonim.

### 7.5 Barang masuk banyak produk dengan scan

1. Pilih supplier opsional, scan berbagai produk ke draft penerimaan. Kode sama menambah jumlah baris yang sama; ada quantity/unit, biaya sesuai preferensi, expiry/batch bila dibutuhkan, serta preview total pcs/nilai.
2. Scanner berfungsi untuk lookup dan hitung draft; stok, receipt, batch, history, biaya tidak berubah sebelum **Konfirmasi barang masuk**.
3. Barcode tidak dikenal diberi feedback bunyi/visual dan tidak dibuat sebagai produk palsu. Tawarkan membuat produk baru melalui form yang benar, lalu kembali ke draft bila disimpan.
4. Scan barcode produk default menambah 1 pcs. Jangan mengasumsikan barcode kemasan berarti 1 dus kecuali pemetaan kemasan sudah ada dan dipilih jelas. Kemasan mengikuti konfigurasi proyek.
5. Satu supplier dapat mempunyai banyak item penerimaan. Konfirmasi seluruh dokumen atomik dan idempotent; gagal salah satu baris menghindari receipt separuh tersimpan. Perubahan produk/stok/capability saat draft terbuka divalidasi ulang pada commit.
6. Jika pencatatan tagihan supplier dipakai, draft menampilkan ringkasan pembelian, informasi tagihan dan pilihan tunai/tempo sesuai §7.7. Simpan relasi receipt–tagihan tanpa menggandakan penerimaan. Posting pembayaran awal hanya bila user berwenang dan benar-benar mengonfirmasinya; jika tidak, status pembayaran belum tercatat ditampilkan dengan jujur.

### 7.6 Retur ke supplier

1. Buat dokumen retur dengan referensi penerimaan/item/batch yang dapat ditelusuri; supplier ikut dokumen. Draft, quantity dan alasan harus jelas. Di M5.3 prioritaskan retur dari penerimaan tercatat, dengan penyesuaian tagihan/kredit supplier yang terhubung ke §7.7; tidak menambahkan purchase order atau akuntansi umum lengkap.
2. Quantity tidak boleh melampaui quantity yang boleh diretur dan stok fisik tersedia yang sesuai. Barang untracked dapat dicatat sebagai peristiwa retur dari penerimaan tercatat, tetapi sentinel tidak berubah dan jangan mengklaim saldo fisik tervalidasi. Dokumen lama tanpa jejak yang diperlukan harus mendapat alasan keterbatasan, bukan dibuat-buat.
3. Pisahkan **nilai persediaan yang keluar menurut metode biaya proyek** dari **nilai refund/kredit supplier**. Keduanya bisa berbeda; simpan selisih dengan jelas, jangan mengubah harga/HPP penjualan lampau untuk menyamakan angka. Tidak otomatis masuk uang laci kasir; penerimaan uang tunai harus dicatat sebagai pergerakan kas yang nyata.
4. Commit retur, stock/history, referensi dan nilai atomik/idempotent. Undo menggunakan reversal yang sah bila saldo dan kondisi masih memungkinkan, bukan menghapus histori atau menyatakan pembatalan penjualan pelanggan.
5. Barang yang dikembalikan dan **kredit yang telah disetujui supplier** adalah fakta berbeda. Retur fisik berstatus menunggu persetujuan tidak langsung mengurangi utang. Saat nilai kredit disetujui, alokasikan ke tagihan terkait sekali saja melalui operasi keuangan berwenang; jangan sekaligus mencatat refund tunai untuk nilai sama. Jika tagihan sudah lunas, simpan kredit/refund supplier terpisah sampai diterapkan pada tagihan lain atau uang benar-benar diterima. Jangan membuat “sisa utang” negatif untuk menyamarkan kelebihan kredit. Reversal juga memeriksa alokasi kredit/pembayaran yang sudah bergantung pada dokumen tersebut.

### 7.7 Tagihan supplier, pembayaran tunai dan tempo

Ini pencatatan pembelian dan utang supplier yang sederhana, **bukan integrasi transfer bank, pinjaman atau purchase order lengkap**. Jangan memindahkan seluruh pekerjaan ini ke milestone lain karena dalam revisi ini sudah menjadi cakupan M5.3.

1. **Dokumen dan histori**: gunakan penerimaan barang sebagai dasar tagihan yang memuat supplier, tanggal transaksi, nomor nota/faktur opsional, item/quantity, biaya per unit, total, currency, syarat pembayaran, jatuh tempo bila tempo, pembayaran dan saldo. Satu tagihan dapat memuat banyak jenis barang. Reuse dokumen/tabel yang sudah ada; pembayaran berikutnya mereferensikan tagihan, bukan membuat penerimaan/stock_history baru. Cegah satu penerimaan ditagihkan dua kali melalui constraint/operation ID yang tepat.
2. **Pilihan sederhana**: ketika pencatatan tagihan dipakai, tampilkan “Dibayar lunas” atau “Tempo / bayar sebagian”. Opsi tempo hanya tersedia jika pengaturan supplier “Supplier mengizinkan pembayaran tempo” aktif; default nonaktif untuk supplier baru; toggle ini mencatat kesepakatan di toko, bukan persetujuan otomatis dari pihak supplier. Pengaturan ini diubah pemilik; gudang memakai syarat yang diizinkan. Mematikan izin tempo menghentikan tagihan tempo baru, tidak menghapus utang lama atau memaksa seluruhnya lunas.
3. **Nilai pembayaran**: tempo mendukung belum dibayar, uang muka dan cicilan. Nominal pembayaran awal minimal 0, tidak melebihi total; pembayaran berikutnya positif dan tidak melebihi saldo tagihan yang masih terbuka setelah kredit. Tambahkan “Lunasi seluruh sisa” untuk mengisi nilai sisa, tetap perlu konfirmasi. Tanpa transaksi pembayaran yang tercatat, jangan menyimpulkan tagihan lunas hanya karena syaratnya tunai. Jika memang dibayar lunas oleh user berwenang pada konfirmasi penerimaan, posting tagihan dan pembayaran terkait secara konsisten/atomik.
4. **Kalender jatuh tempo**: tanggal wajib untuk tempo, dipilih lewat date picker. Untuk transaksi baru, tanggal tidak boleh sebelum tanggal tagihan, tetapi boleh hari yang sama jika itu kesepakatannya. Jangan memakai batas minimum besok dari tanggal kedaluwarsa barang. Pencatatan historis yang berwenang boleh memiliki jatuh tempo lampau; tandai sudah terlambat jika masih bersaldo. Ubah tanggal pada tagihan final hanya oleh pemilik, dengan alasan/audit dan reschedule pengingat.
5. **UI per supplier**: tampilkan daftar tagihan dengan total, jumlah yang sudah dibayar, kredit yang diterapkan, saldo, jatuh tempo dan status. Status minimal: belum dibayar, dibayar sebagian, lunas; badge waktu: belum jatuh tempo, jatuh tempo hari ini, terlambat. Sediakan filter dan pagination. Pada ringkasan pisahkan pembelian bruto, retur/kredit yang disetujui, pembayaran bersih dan sisa utang; saldo kredit yang belum dialokasikan ditampilkan terpisah. Jangan menampilkan “total pembayaran” tanpa menjelaskan periode atau apakah nilai refund sudah dikurangkan.
6. **Pencatatan pembayaran**: tanggal, nominal, sumber/metode (misalnya dari laci, transfer, atau dana pemilik), referensi opsional dan catatan. Ini **mencatat pembayaran yang dilakukan di luar aplikasi**, bukan mengeksekusi transfer. Bila satu pembayaran melunasi beberapa tagihan, alokasinya harus eksplisit dan total alokasi cocok; jika UI memilih satu tagihan per pembayaran demi kesederhanaan, beri label yang jelas dan jangan mengklaim mendukung pembayaran gabungan. Hindari kredit/uang muka supplier bebas tanpa referensi di luar kebutuhan retur yang sudah dijelaskan.
7. **Integrasi HPP**: untuk barang tracked, biaya perolehan barang masuk memperbarui nilai persediaan dan average cost sesuai aturan proyek, termasuk jika supplier belum dibayar. Saat barang dijual, snapshot biaya itu dipakai untuk HPP. Membayar cicilan/pelunasan supplier **hanya** mengubah saldo utang dan catatan kas yang benar; tidak mengubah quantity, menghitung HPP lagi atau mengubah HPP penjualan lama. Untuk untracked, pertahankan sentinel dan aturan biaya acuan/snapshot; jangan menciptakan aset stok 999. Harga perolehan yang berbeda memang dapat mengubah biaya melalui penerimaan/penyesuaian biaya yang sah, bukan melalui besar cicilan.
8. **Tagihan dan biaya tidak diketahui**: modul tagihan bersifat opsional, namun tagihan pembelian yang dikonfirmasi perlu nilai item/total yang jelas dan konsisten dengan dokumen sumber. Jika preferensi menyembunyikan harga beli aktif, tampilkan rincian biaya yang diperlukan khusus dalam alur tagihan dengan penjelasan; jangan memaksa semua produk/toko mengaktifkan modul itu. Total utang yang diketahui tanpa biaya per item yang dapat dialokasikan tidak otomatis membuktikan HPP lengkap. Gunakan status belum direkonsiliasi/incomplete jika sumber lama kurang, jangan membagi total secara tebakan atau mengganti unknown menjadi 0. Tidak menambahkan perhitungan bunga/denda otomatis.
9. **Saldo dan transaksi**: sisa utang per tagihan = total tagihan final − pembayaran efektif teralokasi − kredit efektif teralokasi. Semua saldo berasal dari dokumen/posting yang dapat direkonsiliasi, bukan field bebas yang boleh diedit tanpa histori. Receipt/valuation/tagihan yang dibuat bersama harus atomik; posting pembayaran/alokasi/kas keluar juga atomik dalam boundary yang tepat. Double-tap/retry/crash/reopen tidak boleh membayar dua kali. Pembatalan menggunakan reversal berwenang dengan alasan, bukan menghapus bukti atau mengedit nominal pembayaran lama diam-diam.
10. **Tidak ada pencampuran piutang**: utang toko ke supplier berbeda dari piutang pelanggan ke toko, meskipun nama/nomor kontak orangnya sama. Jangan otomatis melakukan saling hapus saldo. Supplier yang memiliki saldo/histori hanya diarsipkan, bukan dihapus beserta tagihannya. Tagihan, pembayaran, kredit dan profil yang diperlukan ikut backup/restore encrypted, dengan hak akses yang benar.
11. **Migrasi**: penerimaan/supplier lama tidak otomatis dianggap punya utang ataupun sudah lunas. Tandai “Pembayaran belum direkonsiliasi” bila tidak ada bukti. Pemilik dapat mengaitkan/melengkapi tagihan historis dengan pratinjau saldo, tanpa mengulang penerimaan atau membebankan biaya lagi. Tampilkan cakupan data lama yang belum masuk laporan; jangan membuat tunggakan fiktif hanya untuk mengisi tabel baru.
12. **Contoh penerimaan wajib diuji**: saldo awal 0, beli 100 pcs × Rp10.000 = Rp1.000.000, bayar awal Rp200.000, tempo tersisa Rp800.000. Setelah 20 pcs dijual, HPP penjualan Rp200.000 dan stok 80 pcs bernilai Rp800.000 jika tidak ada mutasi lain. Pelunasan sisa Rp800.000 mengubah utang menjadi 0, **HPP tetap Rp200.000** dan stok tetap 80 pcs. Jika pembayaran berasal dari laci, kas keluar dicatat sekali; jika dari transfer, saldo laci tetap. Uji juga retur/kredit dan reversal agar saldo rekonsiliasi tetap benar.

### 7.8 Jadwal kedatangan supplier dan notifikasi

1. Sediakan jadwal kedatangan pada supplier: tanggal dari kalender, jam opsional, catatan opsional, status direncanakan/selesai/dibatalkan. Mendukung beberapa jadwal tersimpan dan satu jadwal berikutnya yang mudah terlihat; tidak perlu membuat sistem rute sales atau pengulangan kalender rumit. Kedatangan aktual tidak otomatis membuat penerimaan atau pembayaran.
2. **Pisahkan dua tanggal dan dua pengingat**: jadwal kunjungan supplier dan jatuh tempo setiap tagihan. Supplier datang belum tentu pada hari pembayaran, dan pembayaran belum tentu saat supplier datang. Jangan memakai satu field untuk keduanya atau memindahkan due date ketika jadwal kunjungan diubah.
3. Gunakan notifikasi lokal yang sudah ada untuk **H-1 kedatangan** dan **H-1 jatuh tempo pembayaran**. Dalam UI ada pilihan pengingat yang dapat dimatikan; gunakan jam pengingat toko yang sudah tersedia, atau default 09.00 waktu toko jika belum ada. Tanggal tanpa jam dihitung berdasarkan hari kalender timezone toko, bukan sekadar now + 24 jam.
4. Contoh: supplier datang 20 November → pengingat 19 November; tagihan jatuh tempo 25 November → pengingat 24 November. Ringkasan notifikasi menunjukkan jenis pengingat dan supplier, sedangkan nomor tagihan/nominal sensitif tidak ditampilkan di lock screen secara berlebihan. Mengetuk notifikasi menuju route yang memerlukan autentikasi/role yang benar; tidak menembus PIN lewat deep link.
5. Tagihan lunas, jadwal selesai/dibatalkan, perubahan tanggal/timezone/identitas toko dan restore harus membatalkan atau menjadwalkan ulang job terkait secara idempotent. Pembayaran sebagian mempertahankan pengingat untuk saldo tersisa. Hindari satu notifikasi baru untuk setiap cicilan atau duplikasi setelah reboot/reopen. Restore menjadwalkan ulang hanya data toko yang dipulihkan, tidak memakai job/key dari toko lain.
6. Jika H-1 sudah lewat ketika jadwal/tagihan dibuat, jangan memasukkan notifikasi ke masa lalu atau melakukan spam catch-up. Tampilkan badge perlu perhatian di aplikasi; pekerjaan lama belum lunas tetap terlihat overdue tanpa memerlukan worker berhasil tepat waktu. Izin notifikasi ditolak atau battery restriction tidak menghalangi simpan barang/tagihan/pembayaran.
7. Reschedule mengikuti kemampuan Android/plugin dan kebijakan izin OS yang berlaku. Jangan menjanjikan alarm tepat-menit, meminta exact-alarm permission tanpa kebutuhan, atau mengulang pengingat tanpa batas agar terlihat berhasil. Dokumentasikan batas OS; periksa ulang data pengingat saat aplikasi dibuka.
8. Uji H-1 dengan clock/timezone terkontrol, ganti bulan/tahun, jadwal hari ini/besok, jatuh tempo lampau, cancel, pembayaran sebagian/lunas, reboot/restore pada jalur yang dapat diuji. Bedakan hasil pengujian waktu sintetis, native scheduling dan notifikasi yang benar-benar tampil; jangan menyatakan H-1 alami sudah terverifikasi hanya dari mock.

## 8. cetak, label dan kebijakan struk

Ralat langsung pengguna29Oktober: label baru memakai **QR code**, bukan barcode.
Semua ketentuan lain tetap, implementasi setelah E3 sesuai urutan. Lihat
[ralat QR](M53_QR_LABEL_AMENDMENT.md); keterbacaan fisik tetap perlu bukti.

1. Hilangkan informasi **“hampir kedaluwarsa”** dari template struk konsumen. Pengingat internal tetap ada di aplikasi/notifikasi. Jangan menghilangkan pemeriksaan kelayakan jual atau mengubah fakta transaksi.
2. Tambahkan cetak label **QR code** dengan template terbatas: nama barang, identitas/kode produk dan harga opsional. Payload memakai identitas produk stabil untuk lookup literal, bukan URL/perintah. Jangan mengarang kode GS1/EAN resmi atau mengubah identitas produk lama.
3. Label harus mempunyai quiet zone, ukuran minimum modul yang terbaca, scaling benar, panjang nama dibatasi/wrap, dan preview jumlah label/ukuran fisik. Uji hasil encoder dengan decoder independen bila tersedia. QR code yang terlalu padat harus ditolak/diubah ukuran template, bukan diperkecil sampai tidak terbaca.
4. Dukungan label bergantung kemampuan printer/protokol. Reuse profil per printer yang sudah mendukung ESC/POS raster/kolom, TSPL/CPCL; cek kemampuan nyata. **Adanya opsi TSPL/CPCL tidak membuktikan printer mendukung sensor gap.** Printer struk continuous boleh mencetak QR code pada kertas biasa, tetapi bukan otomatis menjadi printer label gap.
5. Pada printer label yang mendukungnya, sediakan ukuran label, gap, offset dan test/kalibrasi terbatas. Kirim perintah protokol hanya jika profil/kemampuan cocok. Jangan mengirim empat protokol coba-coba ke satu printer, melakukan factory reset, atau merusak profil struk lama. Simpan pengaturan label terpisah dari layout struk.
6. Pertahankan lebar58/80mm, dots/profile, pilihan transport, padding/alignment dan **feed manual0–8/default3 sesuai baseline terbaru**, termasuk migrasi profil legacy yang sudah diperbaiki. Jangan mengembalikan default6 tanpa alasan baru yang diuji.
7. Tambahkan pengaturan pemilik **“Wajib mencetak struk sebelum transaksi berikutnya”**, default nonaktif. Status sale selesai/commit tidak bergantung keberhasilan printer; stok/piutang/uang hanya berubah sekali. Saat diwajibkan, tombol “Belanja berikutnya” memberi peringatan dan tetap di hasil transaksi bila syarat belum terpenuhi, dengan akses langsung pengaturan printer publik dan cetak ulang.
8. Definisikan status job: antre/terkirim/gagal/status fisik belum diketahui/terkonfirmasi sesuai transport yang memang tersedia. ACK atau sukses menulis byte **bukan bukti kertas keluar**. Jika printer tidak punya status fisik andal, tampilkan konfirmasi “Struk sudah tercetak?”; jangan menulis laporan “tercetak fisik terverifikasi otomatis”. Tidak boleh mengirim cetak ulang otomatis tanpa batas ketika hasil pengiriman ambigu.
9. Untuk printer rusak/kertas habis, pemilik boleh membuat pengecualian satu transaksi dengan autentikasi dan alasan yang tersimpan; ini jalur pemulihan eksplisit, bukan tombol bypass untuk kasir. Default tetap mengikuti kebijakan wajib cetak. Fitur ini jangan membuat transaksi dibatalkan/di-charge ulang hanya karena kertas gagal.

## 9. laporan

### 9.1 Selisih stok, bukan tuduhan kehilangan

Judul **“Selisih stok / indikasi kekurangan barang”**. Sumbernya sesi opname yang selesai, bukan dugaan dari penjualan rendah. Tampilkan stok sistem saat baseline/finalisasi, hasil fisik, delta negatif/positif, waktu, alasan, dokumen mutasi dan estimasi nilai jika biaya diketahui. Jelaskan bahwa kekurangan bisa berasal dari salah hitung, transaksi belum dicatat, kerusakan atau sebab lain; bukan bukti pencurian. Tanpa opname valid tampilkan “Belum ada data pembanding”. Sentinel/untracked dan baris belum dihitung tidak dianggap kehilangan.

Jangan menghitung ulang delta memakai saldo stok hari ini sehingga laporan lama berubah, dan jangan menjadikan selisih stok sebagai penjualan/HPP penjualan. Kerugian/penyesuaian persediaan ditampilkan terpisah sesuai ledger proyek.

### 9.2 Potensi omzet dan laba kotor

Sediakan level produk, kategori, supplier dan seluruh toko, hanya untuk pemilik/laporan.

- Nama utama: **“Potensi nilai jual stok”** dan **“Estimasi laba kotor stok”**. Subjudul dapat menyebut proyeksi dengan asumsi stok layak saat ini terjual pada harga yang dipilih. Ini bukan prediksi penjualan dalam jangka waktu tertentu.
- Dasar default: quantity tracked yang masih layak jual × harga jual eceran saat ini. Biaya adalah carrying cost/nilai stok yang relevan menurut model average proyek. Estimasi laba kotor = potensi nilai jual − biaya stok terkait. Jangan pakai harga pembelian terakhir sebagai pengganti nilai stok tanpa label estimasi.
- Jangan kurangi seluruh carrying value jika quantity yang dihitung hanya stok layak dan sebagian lain expired; alokasi harus konsisten dengan model biaya. Expired/arsip/nonjual dipisahkan dan dijelaskan.
- Asumsi harga eceran, belum memasukkan promo/grosir yang bergantung keranjang, ongkos, pajak yang belum dimodelkan, serta biaya operasional. Jangan menyebut laba bersih. Tidak menambahkan engine peramalan atau simulasi kombinasi promo.
- Untracked 999 tidak boleh dikalikan dengan harga. Tampilkan “Tidak dapat dihitung karena jumlah stok tidak dilacak”. Untuk campuran, tampilkan subtotal produk yang dapat dihitung + cakupan produk yang dikecualikan; jangan menyamarkan subtotal sebagai total toko lengkap.
- Biaya unknown membuat estimasi laba/nilai biaya terkait tidak lengkap. Potensi omzet dengan quantity/harga valid tetap bisa ditampilkan, disertai cakupan yang jelas. Agregasi tidak boleh menganggap unknown=0.
- Agregat kategori/supplier harus deterministik, tidak menggandakan produk akibat join riwayat penerimaan. Bila memakai master supplier untuk grouping, labeli “berdasarkan supplier pada data barang”; **bukan** klaim stok seluruhnya berasal dari supplier tersebut. Supplier kosong masuk “Tanpa supplier”.
- Pisahkan laporan potensi ini dari omzet/HPP/laba yang sudah terealisasi dalam transaksi lama. Ekspor CSV/XLSX mengikuti definisi/cakupan yang sama dan tidak menghitung hanya halaman UI yang sedang dimuat.

### 9.3 Audit kas

Pemilik dapat mengaktifkan audit wajib dan melihat histori pecahan tender/kembalian, saldo awal, kas masuk/keluar, penyerahan, count fisik dan selisih per hari/transaksi sebagaimana §5.3. Tidak bisa mengubah histori final secara diam-diam; koreksi memakai jejak yang dapat ditelusuri. Statistik kunjungan/member dan laporan tidak memberi hak pengelolaan kepada kasir.

### 9.4 Laporan utang dan tunggakan supplier

Hanya Pemilik/Laporan yang melihat laporan konsolidasi ini. Sediakan rincian per supplier dan per tagihan, dengan pencarian, rentang tanggal yang jelas dan ekspor CSV/XLSX sesuai scope seluruh data, bukan halaman yang sudah dimuat.

- Ringkasan **total pembelian**, **total pembayaran**, **kredit/retur yang diterapkan**, **total utang belum lunas**, **jatuh tempo hari ini**, dan **tunggakan lewat jatuh tempo**. “Belum lunas” mencakup seluruh saldo terbuka; “tunggakan” hanya saldo terbuka dengan tanggal jatuh tempo sebelum hari ini menurut timezone toko. Keduanya tidak boleh dijumlahkan lagi seolah kelompok terpisah.
- Filter belum jatuh tempo/hari ini/terlambat/lunas/belum direkonsiliasi, serta bucket keterlambatan sederhana: 1–7, 8–30, dan >30 hari. Jumlahkan sisa saldo, bukan seluruh nilai faktur yang sudah dicicil. Tagihan tanpa due date tidak otomatis overdue; status tanggal kurang perlu diperbaiki ditampilkan terpisah.
- Pada daftar supplier tampilkan tagihan, total, sudah dibayar, sisa, due date dan jumlah hari terlambat. Jadwal kunjungan berikutnya boleh tampil sebagai informasi terpisah, bukan dasar menghitung keterlambatan tagihan.
- Laporan **pembayaran periode** memfilter tanggal pembayaran; laporan **saldo per tanggal** menghitung posting efektif hingga cutoff yang dipilih beserta reversal/kredit yang relevan. Pembayaran sesudah cutoff tidak boleh menghilangkan utang historis. Jika versi awal hanya menyediakan saldo saat ini, labeli dengan jelas dan jangan memberikan date picker seolah mendukung saldo historis. Biaya/HPP tetap mengikuti transaksi persediaan/penjualan, bukan pembayaran periode itu.
- Tampilkan kredit/refund supplier yang belum dialokasikan dan data lama belum direkonsiliasi secara terpisah agar total tidak seolah lengkap. Jangan menjumlahkan currency berbeda sebagai satu angka; kelompokkan sesuai currency snapshot bila ada data lintas currency.
- Uji rekonsiliasi total supplier = jumlah saldo tagihan efektif pada cutoff yang sama; retur menunggu persetujuan, kredit disetujui, pembayaran sebagian/lunas/reversal dan filter harus menghasilkan saldo benar tanpa mengubah omzet/HPP penjualan.

## 10. retensi cadangan dan penghapusan data toko

### 10.1 Retensi cadangan

1. **Jangan menghapus database aktif atau transaksi berumur lebih dari tiga bulan.** Kebutuhan saya adalah daftar restore tidak penuh dengan terlalu banyak berkas cadangan.
2. Audit fitur retensi yang sudah ada pada M5, termasuk kebijakan jumlah arsip. Perluas/reuse, jangan membangun worker retensi kedua yang saling menghapus.
3. Sediakan pengaturan opsional “Bersihkan cadangan lama”, contoh umur 90 hari. Default perubahan untuk pengguna lama tidak mengaktifkan penghapusan massal baru. Tampilkan ringkasan kebijakan dan jumlah cadangan yang akan dibersihkan sebelum aktivasi pertama.
4. Hanya menyentuh berkas backup milik aplikasi/toko/origin dan akun Drive yang sedang dipilih sesuai scope. Jangan menghapus arsip akun/origin lain, file ekspor user, folder umum atau dokumen di SAF tanpa izin/scope yang sah.
5. Pembersihan dilakukan setelah cadangan baru benar-benar berhasil dan tervalidasi menurut mekanisme proyek. Pertahankan sedikitnya 3 cadangan valid terbaru (atau minimum lama jika lebih tinggi) meskipun lebih tua dari batas, recovery/safety backup yang dilindungi, kandidat restore aktif dan cadangan yang ditandai simpan. Jangan menghapus satu-satunya cadangan yang dapat dipulihkan.
6. Backup gagal/Drive terputus/metadata umur tidak dipercaya/kunci tidak tersedia tidak boleh diikuti penghapusan agresif. Mode lokal dan Drive memiliki status terpisah. Daftar restore dapat memakai pagination/filter/tanggal agar tetap cepat tanpa harus menghapus data.
7. SQLCipher maintenance/VACUUM yang sudah ada bukan penghapusan riwayat. Tidak menjalankannya sembarangan saat checkout atau mengklaim menghapus arsip cloud. Background job tidak dijanjikan berjalan tepat pada menit tertentu.

### 10.2 Hapus data toko

1. Tambahkan aksi pemilik **“Hapus seluruh data toko di perangkat ini”**. Ini fitur destruktif runtime yang hanya berjalan setelah tindakan eksplisit user dan autentikasi ulang pemilik; keberadaan instruksi ini tidak mengizinkan penguji menghapus data eksplorasi saya.
2. Peringatan merah: “Seluruh data toko di perangkat ini akan dihapus, termasuk barang, transaksi, pelanggan, dan pengaturan. Tindakan ini tidak dapat dibatalkan. Buat dan periksa cadangan terlebih dahulu jika data masih diperlukan.”
3. Tombol “Kembali”, “Buat cadangan”, “Hapus data toko”. Cadangan menawarkan lokal dan Google Drive opsional; jangan mewajibkan Drive atau berpura-pura logout berarti backup. Jika backup dipilih, tunggu hasil nyata sebelum melanjutkan; backup gagal tidak memberi label aman.
4. Konfirmasi final terpisah dan autentikasi ulang diperlukan. Dokumentasikan dengan tepat apakah arsip lokal dipertahankan/dihapus. Default cadangan tidak ikut dihapus; jangan menghapus satu-satunya recovery key yang membuat cadangan dipertahankan menjadi tidak berguna. Ingatkan menyimpan kode pemulihan portabel di luar aplikasi sebelum reset. Jangan mencetak/menampilkan kode di log.
5. Hentikan/koordinasikan worker, antrean cetak, export dan sesi; cegah stale callback menghidupkan kembali data. Hapus data bisnis/key toko aktif/config/otorisasi aplikasi yang relevan secara konsisten, reset onboarding dan buat identitas/key toko baru pada setup berikutnya. Tidak menyentuh enrollment biometrik, akun Google OS atau data aplikasi lain.
6. Cadangan Drive lama **tidak dihapus otomatis**. Jika suatu saat user ingin menghapus backup cloud juga, itu tindakan terpisah dengan daftar dan konfirmasi spesifik; jangan implementasikan wipe lintas akun sebagai bagian reset ini.
7. Pengujian fitur ini hanya pada fixture/paket sintetis terisolasi. Jangan menjanjikan penghapusan fisik forensik sempurna pada storage flash/cloud hanya karena delete file.

## 11. Data, migrasi, performa dan ketahanan

1. Audit skema aktual sebelum menambahkan tabel/kolom. Gunakan ID stabil, FK, CHECK, indeks, unique constraints dan timestamp yang sesuai. Nama domain transaksi tetap `SaleTransaction`/`sale_transactions`; jangan membuat tabel pelanggan/piutang/receipt duplikat hanya karena istilah baru “member”.
2. Entitas konseptual yang mungkin perlu diperluas: kebijakan setup/fitur, capability dan kredensial per akses, cashier lock, customers, cash sessions/movements/denomination details, stocktake sessions/items, dokumen penerimaan multi-item, supplier returns, supplier invoices/payments/payment allocations/credits, supplier visit schedules/reminder metadata, label profiles dan backup retention. Reuse struktur yang sudah memenuhi kebutuhan; ini bukan daftar tabel yang wajib dibuat satu per satu. Relasi supplier–penerimaan–tagihan–pembayaran–retur harus dapat direkonsiliasi, dengan indeks supplier/status/due date dan dedup operation ID yang sesuai.
3. Buat migrasi maju dari schema 14 dan jalur upgrade lama yang masih didukung. Naikkan versi schema hanya jika memang berubah. Existing completed onboarding, PIN/KDF, biometric binding, wrapped key, printer/feed, preferensi uang cepat, barang/tracking/biaya, promo, debts, history dan snapshot uang harus tetap benar.
4. Data lama tidak ditulis ulang dengan angka biaya/nomor pelanggan/stocktake/identitas pegawai hasil tebakan. Tampilkan status legacy/incomplete secara jujur. Tidak menambah transaksi fiktif untuk menutup selisih migrasi.
5. Semua perubahan bisnis divalidasi ulang di transaksi database; UI disabled bukan satu-satunya pengaman. Cancel/retry/crash/reopen tidak menduplikasi sale, penerimaan, retur, kas atau pembayaran utang. Gunakan operation ID/unique guard dan reversal sesuai pola yang sudah ada.
6. Harga jual/HPP/customer/denomination/currency yang diperlukan audit disnapshot saat commit; edit master tidak mengubah struk/angka lama. Currency toko yang sudah bertransaksi tidak boleh hanya diganti simbol atau mengonversi saldo diam-diam.
7. Query list besar tetap terbatas dan pagination sesuai sort baru; laporan agregat menghitung seluruh scope, bukan list yang sudah dimuat. Hindari OFFSET besar untuk histori panjang. Uji query plan/indeks pada filter dan sort yang baru, bukan menambahkan indeks di setiap kolom tanpa alasan.
8. Scanner, kamera, sorting popularitas dan penghitungan uang tidak boleh menyebabkan full-table scan/rebuild setiap ketukan. Ukur pada data sintetis representatif dan perangkat ARM32/ARM64 yang tersedia tanpa menurunkan fitur/keamanan.
9. Backup/restore portable harus membawa data M5.3, menjaga invariant dan versi skema; capability/session/token/biometrik yang terikat perangkat tidak boleh menjadi akses aktif di perangkat lain. Restore bukan fitur sinkronisasi multi-device.

## 12. Urutan pelaksanaan dan checkpoint

Kerjakan berurutan menurut dependensi berikut; boleh menyesuaikan rincian urutan jika alasannya dicatat:

1. **A — fondasi**: audit baseline, kontrak/migrasi, preferensi fitur/onboarding, mode stok/status biaya.
2. **B — pengamanan**: role/capability, setup/rotasi PIN, 72 jam, Back gate dan kunci kasir.
3. **C — operasional kasir**: search/sort, uang cepat/numpad, pelanggan dan migrasi piutang.
4. **D — kas fisik**: sesi kas, pecahan/kembalian, jurnal laci, penutupan harian dan audit.
5. **E — gudang dan supplier**: kamera/scanner bersama, form/filter/sort, kategori/supplier, multi-item receipt, opname, retur, tagihan/pembayaran tempo dan jadwal kunjungan/pengingat. Integrasi kas mengikuti fondasi pada tahap D, tidak membuat jurnal uang kedua.
6. **F — output/laporan**: barcode label, template struk/kebijakan wajib cetak, laporan selisih/potensi/audit dan utang/tunggakan supplier.
7. **G — keselamatan data**: retensi backup, reset toko terkonfirmasi, backup/restore seluruh penambahan.
8. **H — regresi/handoff**: perbaikan temuan, dokumentasi, build, commit/push dan update Paket Eksplorasi Mandiri.

Setiap checkpoint mencatat source/schema, perubahan, tes lulus/gagal, bug vs masalah harness/lingkungan, file penting, bukti, batas yang belum terverifikasi dan langkah berikutnya. Tidak mengklaim M5.3 selesai sementara bagian belum diimplementasikan atau hanya berupa mock/tombol kosong. Jangan berhenti menunggu “review sebelum tahap berikutnya” jika pekerjaan lanjutan sudah jelas diotorisasi dalam dokumen ini.

## 13. Pengujian, perbaikan langsung dan isolasi

### 13.1 Kebijakan perangkat

- Utamakan host/unit/widget/integration untuk domain baru, lalu pengujian native pada perangkat yang tersedia.
- **Poco F6**: target utama handoff, kamera, biometric/lifecycle, UI dan printer yang memang tersedia. Baca ulang device/package sebelum menjalankan perintah.
- **DV8910**, firmware boleh terdeteksi DV8947-KIX, IP terakhir 192.168.0.102: target pembanding ARM32 bila tersedia dan relevan. Jangan mempersoalkan nama firmware. Root hanya boleh write untuk tujuan pengujian terisolasi; di luar itu read-only. Tidak mengubah firmware, bootloader, sistem, akun atau konfigurasi permanen; state sementara yang diizinkan dipulihkan dan dibaca ulang.
- **Realme C11 tidak wajib tersedia** dan jangan menunggu perangkat pinjaman. Jangan memulai ulang suite lama yang sudah ditutup hanya karena nama milestone berubah.
- Tidak ada pengujian iPhone atau sinkronisasi antarperangkat pada M5.3.
- Jika perangkat tidak tersedia, lanjutkan pekerjaan independen; tandai verifikasi native tersebut belum dilakukan, bukan PASS. Perubahan shared domain/security/SQLCipher memerlukan pengujian target terdampak yang tersedia, bukan hanya file yang berubah namanya. Tidak perlu mengulang seluruh M1–M5.2 tanpa alasan.

### 13.2 Kasus penerimaan minimum yang bermakna

1. Setup baru ID/EN, kembali/lanjut/restart, validasi optional/required, printer skip/gagal, pola 1/2/3, konfirmasi PIN dan tidak bocor PIN di draft/log.
2. Upgrade toko lama dari baseline populated: PIN/key/biometrik/profil printer/feed/pelanggan tanpa nomor/piutang/transaksi/tracking dan history tetap benar; reopening dan migration rollback/failure aman.
3. Mode stok aktif/parsial/nonaktif; tracked 0, tracked 999, untracked 999; tidak berkurangnya sentinel; tidak masuk nilai/opname; transisi tidak membuang saldo; biaya known/unknown/zero dan tidak merusak laba.
4. Gudang mencoba membaca laporan/backup/PIN/reset lewat route dan use case langsung ditolak; stale capability setelah rotasi/perubahan peran ditolak; PIN kasir tidak membuka management. Biometrik bukan bypass kewajiban PIN 72 jam.
5. Back dari PIN pada submenu bertingkat selalu ke Kasir tanpa protected-frame flash; keranjang tetap. Izin kamera/Bluetooth/SAF, WhatsApp, Home, screen lock dan biometric cancel tidak membentuk loop atau meninggalkan akses bocor.
6. Search stok layak/habis/expired/untracked, exact barcode leading zero, sort popularitas/reversal/tie/page boundary; member search/nama sama/nomor nasional/internasional duplikat.
7. Uang cepat contoh 93.000/95.000, rapid taps, kurangi/reset, Uang pas→digit mengganti, 000/backspace, currency desimal dan overflow; mode audit tidak dapat dibypass lewat numpad/preset.
8. Kas: saldo awal, tender/kembalian tepat/kurang/lebih, pecahan tidak tersedia, bayar sebagian/utang, pelunasan, kas keluar/setoran, batal/doubletap/retry/crash/reversal, tengah malam dan beberapa hari offline. Catatan kas tidak mengubah omzet/HPP dua kali.
9. Scan kamera dedup frame vs scan fisik ulang, izin ditolak/perangkat tanpa kamera, unknown barcode, receipt multi-item belum mengubah stok sebelum commit; partial failure/retry tidak menduplikasi.
10. Opname: belum dihitung vs 0, scan salah/undo, stok berubah saat draft, batch ambiguity, delta/history/cost dan laporan snapshot. Tidak menuduh hilang dari sentinel.
11. Retur: quantity berlebih/stok tidak tersedia/referensi salah/biaya berbeda/refund berbeda/retry/reversal; tidak mengubah HPP sale lama atau menambah uang kas tanpa peristiwa nyata.
12. Form error field pertama benar, low-price threshold pada tambah/ubah/grosir, fitur tersembunyi, ons 100 g dan locale, expiry picker dan kerangka validasi M5.2.
13. Struk tidak menampilkan hampir kedaluwarsa; konfigurasi feed/protokol/58/80mm tidak regresi; label encode/decode/padding/dots, gap yang tidak didukung; wajib struk/gagal/ambigu/reprint/pengecualian tidak membuat transaksi baru.
14. Laporan potensi quantity layak/biaya tidak diketahui/untracked/campuran/join supplier tidak ganda; realized profit tidak berubah; export semua scope lebih dari satu halaman sesuai UI.
15. Retensi: cadangan gagal/satu-satunya/protected/account berbeda/umur invalid tidak dihapus; reset hanya fixture, membutuhkan owner confirmation, tidak menghapus Drive/enrollment/backup di luar scope, worker callback lama tidak menghidupkan data.
16. Backup portable terenkripsi M5.3→restore pada fixture ber-key berbeda, migrasi data baru/legacy, kunci salah/berkas rusak/cancel; restorasi tidak membuat sesi/biometrik perangkat lama aktif.
17. Supplier tunai/tempo, izin tempo Off/On, supplier opsional pada alur biasa tetapi wajib pada tempo, biaya tersembunyi/unknown, uang muka/cicilan/lunas/lebih bayar ditolak, doubletap/retry/crash/reversal, stok dan HPP tidak berubah lagi saat bayar, kas keluar sesuai sumber pembayaran, kredit retur belum disetujui/disetujui/setelah lunas, cutoff laporan dan migrasi pembayaran legacy tanpa utang fiktif.
18. Kalender kunjungan berbeda dari due date; H-1 pada tanggal bulan/tahun/timezone berbeda, due date hari ini/lampau, pemberitahuan ditolak, kunjungan batal/selesai, pembayaran sebagian/lunas, restore/reboot/reschedule tanpa duplikasi, permission/deep link tidak membypass role. Bukti jam sintetis/job native/notifikasi fisik dipisahkan.

Jalankan formatter, analyzer, audit lokalisasi, tes relevan, build debug dan release dengan pemeriksaan native/ABI/16KiB/signature yang sudah dipakai proyek. Benchmark hanya untuk perubahan berisiko performa atau kegagalan baru; jangan mengulang tes mahal tanpa alasan.

### 13.3 Kejujuran bukti dan perlindungan data

1. Temukan masalah → reproduksi → perbaiki → uji ulang kasus itu dan regresi terdampak. Jangan menyatakan crash berasal dari umur OS tanpa bukti. Pisahkan bug app, test/harness dan lingkungan.
2. Bukti domain/widget, callback debug, UI hierarchy, ADB/native input, OS dialog, dan hasil fisik cetakan adalah tingkat berbeda. Jika INJECT_EVENTS ditolak, jangan menyebut callback sebagai sentuhan fisik yang terverifikasi. Byte terkirim bukan bukti kertas tercetak; Google tiruan bukan Drive nyata; jam tiruan bukan bukti menunggu 72 jam nyata.
3. Gunakan paket uji terpisah. Audit data dan file terlindungi sebelum/sesudah sesuai mekanisme proyek; worker yang dapat mengubah DB harus dikoordinasikan. Hash DB yang berubah karena aktivitas sah harus dijelaskan lewat fakta logis yang cukup, bukan otomatis dianggap utuh.
4. Jika isolasi gagal, tandai **FAILED ISOLATION**, simpan bukti gagal asli, investigasi dan perbaiki harness. Jangan mengganti baseline untuk menghapus kegagalan. Tidak menyalin sandbox seluruh aplikasi sebagai jalan pintas bila scope melarangnya.
5. Jangan mengubah/mereset biometrik, kunci OS, akun Google, clipboard pribadi, atau data toko eksplorasi. Izin/setup sederhana boleh diminta singkat hanya bila benar-benar perlu; lanjutkan pekerjaan independen selama menunggu. Cetak fisik hanya target yang dipilih, satu job terkontrol, tidak spam.
6. Tes fitur hapus data/retensi tidak pernah memakai toko saya sebagai fixture. Secret, customer nyata, nomor kontak pribadi, DB/key/token tidak masuk evidence publik.

## 14. Git, dokumentasi dan handoff yang wajib konkret

1. Perbarui SPEC/PLAN/STATUS, catatan keputusan, panduan setup/penggunaan singkat ID/EN yang diperlukan, laporan M5.3 dan indeks bukti terkurasi. Bedakan sumber kebenaran aktif dari checkpoint historis.
2. Repository `https://github.com/MuhYusuf93/SkyBee`, remote origin, branch main menurut informasi saya. Verifikasi keadaan aktual, jangan mengganti remote/branch sembarangan. Commit dan push perubahan yang sudah selesai dan lulus pemeriksaan melalui mekanisme biasa; tidak force-push/penulisan ulang history/reset pekerjaan saya. Jangan melakukan push diam-diam ketika pemeriksaan gagal atau remote membutuhkan penanganan berbeda; laporkan hambatan konkret.
3. Audit diff, `.gitignore`, `docs/evidence/`, `release-artifacts` dan file baru. Jangan commit APK/AAB, database, key/recovery code/token, kredensial privat, log mentah sensitif atau hasil build besar. Pertahankan source, lockfile, migrasi, tes, laporan ringkas, lisensi dan vendor source yang memang diperlukan. Cleanup artefak yang sudah dilacak Git gunakan untrack yang menjaga salinan lokal; `.gitignore` saja tidak membersihkan file yang sudah dilacak Git. Tidak ada penghapusan massal/penulisan ulang history hanya demi rapi.
4. Build aplikasi yang bisa dijalankan dari **Android Studio**; jelaskan run configuration/flavor/entrypoint sebenarnya. Jangan hanya mengirim laporan APK “belum dipasang” tanpa melanjutkan handoff yang sudah diotorisasi.
5. Perbarui **Paket Eksplorasi Mandiri `com.example.kasir_app.skybee`** di Poco F6 **secara in-place**, mempertahankan data saya yang sudah bertambah, PIN/key/biometrik/seed marker/printer/preferences. Jangan mengembalikannya ke seed 100 produk/20 penjualan atau membuat package baru yang menyembunyikan data lama. Naikkan versionCode sesuai build aktual, verifikasi signing cocok. Jangan uninstall atau memaksa downgrade bila signing/install bermasalah.
6. Sebelum update, buat perlindungan/snapshot yang sah. Setelah update, periksa migrasi/reopen, key/biometrik/config, fakta bisnis, dua startup termasuk pembukaan ulang setelah proses dihentikan sesuai mekanisme proyek, dan kasir siap dipakai. Data baru hanya di fixture, bukan transaksi sintetis tambahan dalam toko eksplorasi saya. Paket ordinary/integration lain tidak diperbarui tanpa kebutuhan dan otorisasi yang memang berlaku.
7. Jika Poco tidak terhubung, tetap siapkan APK dan langkah Android Studio/install yang tepat, tandai **handoff build siap, pemasangan belum dilakukan**. Jangan mengklaim update terpasang; jangan menghentikan implementasi fitur lain karena perangkat tidak tersedia.
8. Hentikan runner/kontrol debug yang selesai dan pulihkan state pengujian sementara. Tinggalkan `.skybee` siap untuk saya coba tanpa menunggu laporan pengujian mandiri sebagai prasyarat menyelesaikan tugas ini.

Laporan akhir minimal berisi: perubahan yang benar-benar selesai; versi/schema/commit dan status push; matriks requirement→implementasi→tes→batas; kasus gagal/perbaikan/retest tanpa menghapus riwayat; perangkat/jenis bukti; kompatibilitas printer yang benar-benar terbukti; hasil preservasi data; APK/path/hash/config Android Studio dan status pemasangan; pekerjaan blocked/unverified dengan sebab spesifik. Jangan menutup milestone sebagai “semua terverifikasi” hanya karena build lulus.

## 15. Penelusuran ke nomor catatan pengguna

| Nomor awal | Bagian yang menanganinya |
|---|---|
| 1a–1f,2,3 | §3 onboarding, preferensi dan bantuan; §4 setup PIN |
| 4,21,39 | §4 peran/PIN/72 jam dan perubahan akses |
| 5 | §7.1 kamera/scanner |
| 6,8,13–17 | §5.2 uang cepat/numpad |
| 7,9,47 | §5.3 kas fisik dan §9.3 audit |
| 10,11 | §5.1 pencarian/sort |
| 12 | §4.3 kunci kasir opsional |
| 18 | §8 template struk |
| 19,20,38,48 | §6 member/CRUD/piutang/migrasi data lama; referensi “nomor 20” pada catatan yang menunjuk dirinya dibetulkan menjadi model pelanggan |
| 22–30 | §7.2 barang/form/filter/ons, §3.3 biaya/tracking |
| 31,42 | §7.3 opname dan §9.1 selisih stok |
| 32 | §8 label barcode |
| 33–35 | §7.4 kategori/supplier |
| 36,37 | §7.6 retur supplier dan §7.5 penerimaan multiscan |
| 40 | §3.3 mode stok toko/per barang |
| 41 | §8 wajib struk, status job dan pemulihan |
| 43–46 | §9.2 potensi nilai jual/laba kotor |
| 50 | §4.2 Back pada PIN |
| 51,52 | §10 retensi cadangan dan hapus data toko |
| Tambahan supplier setelah prompt pertama | §4.1 hak akses; §5.3 kas keluar; §7.4–7.8 ringkasan supplier, tagihan/pembayaran/retur/tempo/jadwal/pengingat; §9.4 laporan utang/tunggakan; §11–13 data, tahapan dan pengujian |

Catatan awal tidak memiliki nomor 49; jangan menciptakan kebutuhan tambahan untuk mengisi nomor itu.

## 16. Rujukan teknis untuk diperiksa saat implementasi

Gunakan dokumentasi primer dan versi dependency aktual, bukan menyalin asumsi tanpa memeriksa kemampuan plugin:

- Android biometrik: https://developer.android.com/identity/sign-in/biometric-auth
- Barcode on-device: https://developers.google.com/ml-kit/vision/barcode-scanning dan https://developers.google.com/ml-kit/vision/barcode-scanning/android — pilihan model/deployment harus cocok dengan kebutuhan offline dan hardware.
- WorkManager: https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work — waktu eksekusi dipengaruhi OS/constraints, bukan scheduler tepat-menit.
- SQLite VACUUM: https://www.sqlite.org/lang_vacuum.html — maintenance file berbeda dari retensi backup/penghapusan transaksi.
- IAS2 synopsis: https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/ — acuan pembedaan biaya persediaan dan biaya penjualan; M5.3 tidak mengklaim aplikasi sudah menjadi sistem akuntansi lengkap atau laporan pajak tersertifikasi.

**Mulai sekarang dari audit baseline dan kontrak M5.3, kemudian lanjutkan implementasi sampai handoff sesuai cakupan di atas.**
