# Prompt Codex — SkyBee M5.4

Disusun 6 November 2026, WIB, berdasarkan `milestone 5.4`, `STATUS(20261106-151533).md`, dan klarifikasi pengguna mengenai QRIS manual.

## Permintaan aktif

**Jalankan implementasi M5.4 dalam proyek SkyBee yang sedang terbuka, uji dan langsung perbaiki temuan pada DV8910 serta Poco F6. Sesudah itu perbarui Paket Eksplorasi Mandiri `.skybee`, buat APK terpisah berdata dummy untuk dicoba teman saya, lalu lakukan pengujian M5.3 dan M5.4 pada Realme C11 ketika perangkat tersedia.**

Ini instruksi kerja aktif, bukan permintaan menyusun rencana saja. Audit dahulu, pecah pekerjaan berdasarkan dependensi, implementasikan sampai konkret, uji, perbaiki, dan lakukan handoff. Jangan menjadikan setiap checkpoint sebagai alasan berhenti meminta persetujuan. Jika ada hambatan nyata, lanjutkan pekerjaan independen dan catat langkah yang perlu dilanjutkan.

Saya mengutamakan kesederhanaan operasional toko kecil, akurasi uang/stok, dan kemudahan pengelolaan kode. Perbaiki copywriting, kesalahan asumsi dan rincian teknis tanpa meluaskan M5.4 menjadi ERP atau layanan keuangan online.

**Klarifikasi QRIS yang mengikat:** kasir memeriksa pembayaran sendiri melalui m-banking/kanal merchant di luar SkyBee. SkyBee hanya menampilkan gambar QRIS dan mencatat konfirmasi manual kasir. Tidak ada payment gateway, webhook, akses rekening, API bank, QRIS dinamis, pembacaan notifikasi bank, atau klaim autentikasi pembayaran otomatis.

## 1. Baseline, roadmap, dan batas pekerjaan

1. Baca `AGENTS.md`, SPEC/PLAN/STATUS, handoff serta keputusan aktif di repository. Periksa source, working tree, branch, paket dan signing aktual. Berkas status berisi banyak checkpoint historis; gunakan penutupan terbaru sebagai baseline, jangan mengulang run lama yang sudah selesai.
2. Lampiran melaporkan M5.3 A–H selesai pada **0.5.3+13/schema 37**, source yang sudah dipush `d06f7e1`, handoff `.skybee` Poco in-place. Ada reset eksplorasi yang dahulu diotorisasi secara khusus: aplikasi ditinggalkan pada wizard asli, seed 100 produk/50 penjualan aktif saat Finish sesuai pilihan pengguna, PIN dipilih pengguna. **Itu bukan izin melakukan reset atau seed ulang pada M5.4.** Kondisi terkini bisa sudah berubah setelah saya menguji; periksa dan pertahankan data/config/PIN sekarang.
3. SQLCipher, wrapped key, portable encrypted backup, recovery, Provider modular, integer minor unit, presisi biaya, keyset pagination, ID/EN dan perbaikan printer yang sudah ada tetap dipertahankan. Tidak fallback plaintext, menurunkan KDF, mengganti PIN, atau menghapus fitur demi satu perangkat.
4. M5.4 adalah fitur/perbaikan dalam dokumen ini, termasuk regresi M5.3 yang dilaporkan pengguna. **M5.5 khusus multi-device.** Jangan membangun sinkronisasi/server/Wi-Fi Direct/LAN replication sekarang; jangan memakai rencana lama yang menamai M5.5 sebagai redesign visual. Perombakan visual menyeluruh menunggu milestone/arahan tersendiri. iPhone dan publikasi Play Store belum menjadi cakupan.
5. Jangan mengubah berkas/prefix `Gemini_`, `gemini_`, `gemini2_` atau pekerjaan lokal lain yang tidak terkait; hormati aturan repository aktual. Tidak uninstall/reset/clear data paket operasional, tidak mengubah enrollment biometrik/kunci OS/akun Google pribadi.
6. Buat kontrak kerja `docs/decisions/M54_REQUEST.md`, matriks nomor catatan→implementasi→tes→batas, dan checkpoint ringkas. Komentar kode menjelaskan invariant dan keputusan penting, bukan setiap baris. Tetap pisahkan domain, service/repository, adapter dan UI; hindari satu Provider besar.

## 2. Keputusan koreksi sebelum implementasi

| Topik | Keputusan M5.4 |
|---|---|
| Fokus kamera | Ketuk preview untuk **tap-to-focus**, jika hardware/plugin mendukung; bukan mengatur jarak fokus lensa secara manual pada semua perangkat. |
| Recovery 256-bit menjadi 12/16 kata | Pertahankan 32 byte entropy: gunakan **24 kata BIP-39** dengan checksum dan wordlist resmi yang tetap. Tetap terima 64 hex lama. Jangan memotong entropy atau membuat kamus sendiri. |
| Kode pada struk | Identitas transaksi asal yang dapat dicari/ditelusuri; bukan bukti pembayaran online atau jaminan orang yang membawa struk adalah pemilik barang. |
| Retur 1 dari 5 pcs | Sisa 4 pcs masih dapat diretur jika memenuhi syarat; jangan menolak seluruh struk hanya karena pernah dipakai satu kali. Batasi quantity kumulatif per baris. |
| Pembulatan | Default nonaktif; bila diaktifkan, rekomendasi pembulatan tagihan tunai ke bawah sebagai **potongan pembulatan untuk pelanggan**, bukan diam-diam mengurangi hak kembalian pelanggan. |
| Foto nota 80–150 KB | Itu sasaran ukuran, **bukan jaminan** keterbacaan atau batas mutlak setiap nota. Prioritaskan semua angka dan tulisan tetap terbaca. |
| Produk–supplier | Banyak-ke-banyak; relasi master tidak membuktikan asal fisik seluruh stok. Penerimaan/retur tetap memiliki supplier transaksi tersendiri. |
| Larangan retur ganda antar-supplier | Lindungi **unit/quantity yang sama melalui reservasi**, bukan melarang seluruh SKU selamanya masuk ke supplier lain. |
| Hapus permanen | Hanya arsip yang lolos pemeriksaan dependensi, saldo dan audit. Tidak menghapus histori penjualan/utang hanya agar arsip terlihat pendek. |
| QRIS | Gambar statis dan konfirmasi manual setelah kasir mengecek pembayaran di luar SkyBee; split payment tetap dicatat dengan benar. |

## 3. Pengamanan PIN, recovery, dan penguncian layar

### 3.1 Percobaan PIN gagal yang persisten — catatan 2

Terapkan pada akses karyawan yang mempunyai PIN/kunci: pola 3/peran terpisah untuk **Kasir dan Gudang**; pola 2 untuk **Kasir**. Kasir yang belum mengaktifkan kunci/PIN opsional tidak tiba-tiba diwajibkan login. Pemilik/pengelola tunggal tetap mendapat proteksi kredensial yang sudah ada, tetapi jangan menguncinya permanen dengan syarat membuka menggunakan PIN miliknya sendiri yang sudah terkunci.

- Gagal ke-3: cooldown 1 menit. Gagal ke-5: cooldown 5 menit. Gagal ke-8: **terkunci sampai dibuka pemilik atau recovery yang sah**. UI menjelaskan sisa waktu/keharusan menghubungi pemilik, tanpa memperlihatkan PIN.
- Jumlah kegagalan, level/status lock, deadline dan versi kredensial disimpan persisten secara atomik di database lokal terenkripsi sesuai desain keamanan proyek; bukan hanya RAM/shared widget. Request paralel/double-submit tidak kehilangan hitungan atau menjalankan KDF tanpa batas.
- Kedaluwarsa cooldown **tidak mereset hitungan kegagalan**: setelah gagal 3 dan menunggu, salah berikutnya adalah gagal 4. PIN benar sebelum hard lock boleh mereset epoch hitungan target. Setelah gagal 8, PIN karyawan yang benar maupun biometrik tidak menjadi bypass hard lock.
- Force-close/restart/reboot tidak menghapus lock. Gunakan waktu monotonik selama proses hidup dan deadline persisten yang dapat diperiksa setelah reboot; tangani jam mundur/maju secara konservatif. Jangan menjanjikan ketahanan terhadap manipulasi administrator/root tanpa dukungan yang memang ada.
- State per target akses/credential diisolasi dengan benar. Beralih route/peran, mengganti referensi PIN kasir, rotasi PIN atau restore tidak boleh menjadi jalan sederhana menghapus hitungan. Tentukan aturan migrasi/restore dan verifikasi, tanpa memindahkan sesi aktif perangkat lama atau membuat pemilik terjebak.
- Pemilik membuka kunci lewat tindakan spesifik dengan autentikasi pemilik yang masih sah/fresh sesuai operasi, lalu mencabut sesi lama dan mencatat audit tanpa secret. Jangan cukup menerima flag UI `isOwner=true` atau PIN karyawan sebagai bukti pemilik. KDF, timing-safe verification dan pembatasan percobaan yang sudah ada dipertahankan.
- Istilah **Master Recovery Key** harus dipetakan setelah audit ke recovery secret yang benar-benar berlaku bagi toko saat ini. Recovery backup, wrapped database key dan PIN adalah konsep berbeda. Jika membuka lock dengan recovery diterapkan, wajib verifikasi secret terikat identitas/key-version toko melalui mekanisme yang aman dan sudah diuji; bukan sekadar menerima 64 hex/24 kata berformat benar. Recovery lama/secret toko lain ditolak. Jangan menyimpan recovery plaintext untuk memudahkan unlock.
- Recovery yang mengizinkan pemulihan pemilik memerlukan alur khusus, konfirmasi/reset PIN yang benar dan pencabutan sesi, bukan langsung membagikan capability tanpa batas. Biometrik/owner recovery juga tidak membuka lock semua toko atau package sekaligus.

### 3.2 Hindari dua PIN berurutan yang salah konteks — catatan 18

Reproduksi: kunci kasir aktif → user berada di Kelola → layar dikunci → kembali ke aplikasi. **Hanya gate pengelolaan yang tampil saat route aktif berada di Kelola**, bukan PIN kasir lalu PIN Kelola.

Gate kasir hanya berlaku saat hendak menampilkan/menggunakan UI Kasir. Jika kasir masih terkunci saat user benar-benar kembali ke Kasir, tampilkan gate kasir di sana. Jangan menghapus lock kasir global hanya untuk menyembunyikan dialog. Gunakan satu state machine gate/route dengan prioritas jelas; PIN/biometrik tidak membuka hak akses lain secara tidak sengaja.

Pertahankan Back dari PIN Kelola menuju Kasir, grace period, permintaan PIN 72 jam, dirty draft, keranjang dan anti-loop lifecycle M5.3. Dialog kamera, izin, SAF, WhatsApp, m-banking atau biometric prompt tidak dianggap otomatis sebagai screen-lock. Tidak menampilkan protected content sebelum gate selesai.

### 3.3 Recovery 24 kata dan lembar pemulihan — catatan 7

1. Gunakan representasi reversible **entropy 32 byte ↔ mnemonic24 kata**. Untuk mengembalikan secret lama gunakan `mnemonicToEntropy`, **bukan** fungsi BIP-39 `mnemonicToSeed` yang menghasilkan bahan kunci berbeda. Jangan mengganti derivasi kunci backup, merotasi secret lama, atau mematahkan 64 hex hanya karena format tampilan berubah.
2. Wordlist resmi dibundel dan diidentifikasi versinya, disarankan English tetap untuk kompatibilitas; UI/helper tetap ID/EN. Jangan menerjemahkan kata mnemonic saat user mengganti bahasa atau memakai kalimat yang dipilih sendiri. Checksum membantu mendeteksi sebagian kesalahan, bukan menjamin salah tulis menjadi nol.
3. Tampilkan kata bernomor dalam grup yang mudah ditulis, show/hide dan salin sesuai mekanisme sensitif yang sudah ada. Form pemulihan menerima format lama serta24 kata, validasi jumlah/kata/checksum/version dan memberi pesan jelas tanpa membocorkan secret ke log/analytics/evidence.
4. Tambahkan **Simpan Lembar Kunci (PDF)** dan pilihan share melalui OS setelah tindakan eksplisit pemilik. PDF 1 halaman berisi identitas toko, tanggal/key-version seperlunya,24 kata bernomor, QR pemulihan versioned dan instruksi singkat bahwa pemegangnya dapat memulihkan data. Nama yang lebih jelas: “Lembar Pemulihan Toko / Store Recovery Sheet”, bukan sertifikat legal identitas toko.
5. QR recovery berbeda namespace/parser dari QR produk, struk retur dan QRIS. Berisi secret yang sama dalam format terdefinisi dan tervalidasi; jangan memasukkan PIN atau plaintext database key lain. Pemindaian QR recovery hanya pada alur pemulihan, tidak pada kasir biasa.
6. Export/share memerlukan autentikasi pemilik dan konfirmasi singkat bahwa PDF berisi kunci rahasia; jangan mengunggah ke Drive umum, mengirim WhatsApp/email, menyimpan ke galeri publik, atau mencetak otomatis. User boleh memilih sendiri tujuan lewat SAF/share sheet. File sengaja diekspor membawa secret; jangan menyebutnya terenkripsi jika tidak diberi enkripsi file terpisah.
7. Gunakan private temporary files dengan cleanup setelah tidak dipakai, tidak mencatat isi secret, dan jangan memakai secret toko nyata pada tes PDF/QR. Verifikasi render 1 halaman dan keterbacaan24 kata serta decode QR pada dokumen sintetis. Jangan menghapus berkas yang sudah sengaja disimpan user di luar scope aplikasi.
8. Uji vektor independen BIP-39, round-trip 32 byte, checksum salah, kata salah/berlebih,64 hex legacy, backup lama/baru dan recovery toko lain ditolak. Tidak perlu migrasi ulang seluruh database atau mengurangi entropy menjadi 128 bit.

## 4. Scanner, fokus kamera, dan pencetakan kode

### 4.1 Scan kamera dan tap-to-focus — catatan 1,13,32

- Audit semua entry point scan produk/struk/penerimaan/retur/opname/recovery yang memang tersedia. Reuse adapter kamera yang sesuai, jangan membuat beberapa controller saling berebut kamera.
- Tambahkan tap-to-focus pada koordinat preview yang sudah ditransformasikan menurut crop/orientasi; tampilkan indikator singkat. Auto-focus normal tetap ada. Pada hardware fixed-focus/fitur tidak didukung, fallback aman dengan pesan seperlunya, bukan error setiap ketuk.
- Tambahkan tombol scan kamera di pencarian barang Gudang seperti Kasir. Izin ditolak/perangkat tanpa kamera tetap mempunyai lookup manual/scanner eksternal. Pastikan kamera berhenti saat route ditutup/gate terkunci dan callback lama tidak menambah item.
- Bedakan frame duplikat ketika barcode diam di kamera dari scan baru yang disengaja. Scanner fisik yang mengirim kode sama 15 kali harus menambah 15 pcs; jangan memakai debounce global yang membuang scan fisik sah. Barcode tetap string agar leading zero utuh.
- Pilihan label produk **Barcode 1D** dan **QR 2D** tersedia bagi user. Reuse implementasi QR M5.3, tambah 1D yang sesuai seperti Code128. Jangan menganggap scanner 1D membaca QR. Simpan preferensi per profil/template, pertahankan label/kode lama dan ID produk stabil.
- Periksa format/check digit, quiet zone, minimum module size/dots, panjang kode, width 58/80 mm, label gap versus kertas continuous. Jika 1D tidak muat dengan keterbacaan yang memadai, beri opsi kode lebih pendek/QR/template yang cocok; jangan merusak barcode dengan kompresi horizontal. Tidak mengklaim EAN/GS1 resmi untuk kode internal buatan toko.

### 4.2 Input scanner fisik dan Enter — catatan 34

Audit dahulu; jika sudah aman, tambahkan bukti regresi seperlunya, jangan mengganti adapter tanpa alasan.

- Timing <30 ms/karakter **hanya heuristik**, bukan bukti scanner atau batas universal. Bluetooth/HID, keyboard cepat, paste, input method dan scanner tanpa Enter dapat berbeda. Reuse adapter/prefix/suffix yang sudah didukung; fitur tambahan konfigurasi hanya jika benar-benar diperlukan.
- Capture/routing scan hanya pada route/field yang sedang menerima scan. Scanner boleh menambah draft, bukan memicu checkout, pembayaran supplier, retur final, penghapusan, PIN atau konfirmasi finansial.
- Saat modal sensitif/gate aktif, hentikan routing scan bisnis dan jangan memakai Enter buffer scanner sebagai persetujuan. Pada PIN, auto-submit 4 digit input manusia tetap berfungsi; burst barcode yang panjang tidak boleh dipotong menjadi 4 digit PIN lalu dihitung sebagai kredensial sah. Uji urutan key/text/IME aktual; jangan hanya memasang global key listener yang tidak melihat `commitText`.
- Heuristik scanner tidak boleh menjadi alasan membuang kegagalan autentikasi atau membolehkan brute force tanpa hitungan. Bila keyboard/scanner tidak dapat dibedakan secara andal, dokumentasikan batasnya dan lindungi routing/konfirmasi; jangan mengklaim identifikasi sumber input selalu sempurna.
- Bersihkan buffer setelah perubahan route/dialog; tidak replay scan tertahan sesudah unlock. Tetap dukung keyboard manusia, Enter pencarian dan aksesibilitas tanpa blanket-block semua keyboard. Scanner data/prefix tidak boleh dianggap URL/perintah.

## 5. Retur penjualan, kode struk, garansi dan karantina — catatan 3

### 5.1 Penjualan asal dan verifikasi

1. Retur hanya untuk **penjualan yang benar-benar sudah checkout/commit**. Ini dokumen retur terhubung penjualan asal, bukan edit/hapus penjualan lama. Pisahkan dari retur ke supplier yang sudah ada.
2. Cetak kode transaksi unik pada struk, dengan pilihan format 1D/QR sesuai kemampuan perangkat dan human-readable reference untuk lookup manual. Pilih format token cukup ringkas agar 1D terbaca pada printer 58 mm; gunakan uniqueness constraint dan token stabil yang tidak bergantung pada nomor urut mudah tertukar antar-toko. Internal transaction ID boleh tetap UUID, token cetak dapat berbeda.
3. Parser memeriksa jenis/version/store identity sesuai format, lookup ke data lokal dan status sale, lalu menampilkan tanggal, daftar barang, harga snapshot, pernah diretur dan sisa yang dapat diretur. Scan kode hanya membuka detail, **tidak** langsung refund/commit.
4. Kode tidak membuktikan kondisi fisik/serial unit atau bahwa pembayaran bank terverifikasi. Jangan menerima nominal/quantity/HPP yang diklaim payload tanpa mencocokkan sumber database. Kode palsu/toko lain/sale belum committed/terhapus tidak mendapat refund. Struk lama tanpa kode tetap bisa dicari lewat referensi/tanggal sesuai akses, tanpa membuat token baru yang mengubah histori finansial.

### 5.2 Draft dan batas retur

- Pilih baris asal dan quantity integer yang valid; maksimal sold quantity dikurangi retur efektif/reversal yang relevan. Catat `returned_quantity` sebagai derived/cache dengan transaksi dan constraint yang benar; jangan hanya flag pernah retur. Beli 5, retur 1, sisa 4; scan berikutnya masih boleh mengembalikan sebagian dari 4, bukan barang 1 yang sudah dikembalikan lagi.
- Draft menampilkan harga neto setelah diskon/grosir/promo/pembulatan snapshot, HPP asal bila diketahui, kondisi **Layak jual** atau **Rusak/Karantina**, alasan dan rincian penyelesaian finansial. Quantity melebihi sisa ditolak baik UI maupun repository.
- Diskon tingkat transaksi/pembulatan dialokasikan ke baris/unit secara deterministik dengan integer dan sisa pembagian, supaya beberapa retur parsial tidak mengembalikan uang lebih banyak daripada nilai bersih asal. Finalisasi atomik/idempotent menangani race beberapa draft/sesi lokal, double-tap, retry dan crash.
- Keranjang penjualan baru tidak dicampur dengan draft retur. Sediakan aksi **Retur penjualan** di Kasir dan struk/dokumen retur tersendiri. Kasir dapat memproses kasus normal dalam kebijakan toko; pengecualian di luar ketentuan/garansi, koreksi histori, atau override sensitif memerlukan pemilik sesuai capability. Jangan menampilkan laporan laba kepada kasir untuk memproses retur.

### 5.3 Stok, HPP dan kondisi fisik

1. Barang layak: pulihkan quantity layak dan nilai biaya dari **snapshot HPP asal**, bukan harga beli saat ini. Recompute average/nilai stok menurut pola proyek tanpa menulis ulang HPP sale lama. Barang expired/arsip tidak otomatis menjadi boleh dijual hanya karena dikembalikan.
2. Barang rusak: masuk bucket **Karantina/Rusak** dengan jumlah, sumber retur, kondisi dan nilai biaya yang dapat ditelusuri. Tidak masuk stok layak jual atau saran kasir; total fisik, stok layak, karantina dan nilai terkait tidak boleh dihitung ganda. Jika produk untracked, sentinel999 tetap tidak berubah, sedangkan unit rusak yang benar-benar diterima dapat dicatat terpisah secara nyata.
3. Bedakan pembalikan HPP retur, biaya barang yang pulih, dan kerugian/write-down barang yang tidak bisa dipulihkan. Barang rusak tidak otomatis dinilai seharga barang layak. Biaya asal unknown tetap unknown; estimasi nilai karantina yang menunggu penilaian diberi label. Koreksi/kerugian yang sah tidak sekaligus membebankan biaya sama dua kali.
4. Karantina dapat dipilih untuk draft retur supplier; setelah diserahkan supplier jumlah/nilai keluar melalui dokumen itu sekali saja. Tidak otomatis membuat supplier berutang/kredit sebelum persetujuan yang sah. Bisa ditandai tidak dapat dikembalikan/dimusnahkan melalui pengeluaran stok beralasan dan otorisasi yang sesuai, bukan sale fiktif.
5. Existing full-sale reversal dan retur parsial tidak boleh digunakan bergantian untuk membalik barang/uang dua kali. Jika ada retur/alokasi dependent, reversal harus ditolak dengan alasan atau melalui reversal gabungan yang benar, bukan membiarkan invariant rusak.

### 5.4 Penyelesaian uang dan piutang

- Hitung nilai retur dari sale snapshot. Untuk sale berutang, kurangi **piutang terbuka yang terkait terlebih dahulu**; jangan mengembalikan tunai untuk bagian yang belum pernah dibayar. Sisanya baru menjadi kewajiban refund, dibatasi pembayaran efektif dan retur sebelumnya.
- Contoh: sale Rp30.000, dibayar Rp10.000, sisa Rp20.000; retur Rp6.000 → piutang Rp14.000, refund tunai 0. Retur seluruh sale → piutang 0 dan refund maksimal Rp10.000, bukan Rp30.000.
- Refund tunai yang benar-benar diserahkan mengurangi laci **hari/sesi refund**, bukan sesi hari penjualan lama. Gunakan dokumen cash refund yang referensinya unik; pecahan keluar mengikuti kebijakan audit kas. Jangan mencatat kas keluar saat draft atau ketika refund belum diberikan.
- Untuk asal pembayaran QRIS/transfer/split, jangan menganggap uang bisa dikirim kembali oleh aplikasi. Catat metode refund yang nyata setelah diproses di luar aplikasi; pilihan refund tunai harus eksplisit, dan hanya uang laci yang benar-benar dipakai mengurangi laci. Jika refund belum dilakukan, simpan kewajiban/status **Menunggu pengembalian dana**, bukan otomatis “Selesai dibayar”.
- Commit retur, pergerakan barang, pengurangan piutang dan refund yang dikonfirmasi/utang refund harus konsisten/atomik pada boundary yang tepat. Dana laci tidak cukup tidak boleh menghasilkan saldo pecahan negatif; jelaskan dan gunakan sumber/metode lain atau status menunggu. Retry tidak menghasilkan refund kedua.
- Retur menjadi penyesuaian pendapatan/HPP pada waktu retur sesuai definisi laporan, bukan mengubah nominal penjualan historis diam-diam. Simpan snapshot agar laporan per periode dan rekonsiliasi benar.

### 5.5 Garansi opsional

Warehouse dapat menetapkan **masa garansi dalam bulan** pada produk jika fitur toko aktif. Kosong berarti tidak dicatat; nilai positif tervalidasi. Pada checkout sukses, snapshot masa garansi, waktu mulai dan batas akhir per baris. Tanggal kalender menambahkan bulan secara benar pada akhir bulan/tahun kabisat menurut timezone toko; batas cakupan tanggal dijelaskan konsisten. Edit konfigurasi produk hanya berlaku untuk penjualan berikutnya.

Cetak di bawah barang bila ada: **“Garansi s/d: 30-Apr-2027. Simpan struk untuk pengajuan garansi.”** ID/EN dan format lokal mengikuti konfigurasi. Garansi ditampilkan ketika retur/claim diproses; bukan berarti setiap klaim otomatis mendapatkan uang atau barang baru. Tidak menambahkan modul servis/serial/perbaikan di luar konteks ini. Biaya/stok/uang baru berubah setelah keputusan dan finalisasi retur yang sah.

## 6. Checkout, QRIS manual, uang cepat dan kebijakan kas

### 6.1 Gambar QRIS dan split payment — catatan 5 + klarifikasi terakhir

1. Hanya pemilik dapat mengunggah/mengganti/menghapus gambar QRIS dari sumber gambar yang dipilihnya. Validasi berkas/decode/dimensi, simpan privat, tampilkan preview dan jangan memotong area QR/quiet zone hingga sulit dipindai. Tidak perlu mengirim gambar ke server atau membuat QRIS merchant baru.
2. Pada Bayar tampilkan gambar dan nominal yang harus dibayar; label **“Pembayaran diperiksa manual oleh kasir”**. Kasir memeriksa m-banking/kanal merchant di luar aplikasi, lalu memilih **“Pembayaran sudah saya periksa dan terima”** untuk nominal nontunai yang dicatat. Screenshot milik pelanggan/scan gambar bukan verifikasi otomatis. Jangan membaca notifikasi bank, SMS, clipboard, saldo atau data akun pengguna.
3. Support **Tunai + QRIS** atau **Tunai + Transfer**, dan nontunai saja. Simpan allocation/method/nominal/status konfirmasi manual/waktu seperlunya. Cash tender berbeda dari net cash payment karena ada kembalian. Total pembayaran bersih + saldo piutang yang sah = total final transaksi. Hanya komponen tunai memengaruhi laci.
4. Overpayment hanya menghasilkan kembalian dari tender tunai yang sah; jangan menganggap pembayaran QRIS berlebih otomatis dapat menjadi kembalian tunai. Nontunai yang belum dikonfirmasi tidak dianggap diterima. Bila nominal/tagihan/metode berubah, invalidate konfirmasi yang tidak lagi sesuai dan minta diperiksa ulang.
5. Operasi ini tetap offline-first untuk **pencatatan di SkyBee**; proses QRIS/transfer nyata di luar aplikasi bergantung kanal pembayaran terkait. UI tidak boleh mengklaim uang sudah masuk berdasarkan koneksi internet aplikasi atau checkbox yang terisi otomatis. Tidak membuat token/API kredensial bank baru.
6. Pembayaran sebagian yang menyisakan piutang mengikuti member wajib dan aturan M5.3. Struk/detail laporan memisahkan Tunai, QRIS/Transfer—dikonfirmasi manual, Kembalian dan Piutang. Double-submit/crash/reopen tetap idempotent; tidak melakukan transfer ke mana pun.

### 6.2 Tombol pecahan kembalian — catatan 15

Ganti input jumlah lembar yang merepotkan dengan tombol pecahan seperti uang cepat pembayaran: setiap tekan menambah 1 lembar/koin; tampilkan jumlah per pecahan, minus/undo dan bersihkan kembalian. Total draft kembalian ditampilkan live. Sediakan input jumlah alternatif jika diperlukan aksesibilitas, bukan memaksa user mengetuk 100 kali untuk 100 lembar.

Pecahan mengikuti currency dan pengaturan, tidak hardcode IDR. Ketika pencatatan fisik aktif, rincian total harus sama dengan **kembalian final sesudah pembulatan**. Menekan tombol tidak langsung memotong saldo laci sebelum transaksi dikonfirmasi.

### 6.3 Pembulatan yang jelas dan dapat direkonsiliasi — catatan 16

Saya memberi keleluasaan memilih mekanisme yang aman. Terapkan pilihan sederhana berikut, bukan sistem pembagian kekurangan sebagai pendapatan pribadi kasir:

- Pengaturan pemilik: **Nonaktif** (default), atau **Potongan pembulatan tunai** dengan kelipatan valid sesuai currency, misalnya IDR 100/500/1.000. Batas kelipatan wajar, tidak mengizinkan potongan melebihi tagihan. Tidak otomatis mengubah aturan semua toko lama.
- Bila aktif, bulatkan **sisa tagihan yang akan dilunasi dengan tunai ke bawah**. Ini membuat kembalian lebih besar, sehingga manfaatnya jelas untuk pelanggan. Tampilkan subtotal/diskon lain, **Potongan pembulatan**, Total akhir, Uang diterima dan Kembalian sebelum konfirmasi dan pada struk. Ini penyesuaian/diskon penjualan toko, bukan selisih laci atau komisi kasir.
- Contoh: tagihan Rp86.750, dibayar tunai Rp100.000, kelipatan Rp500 → potongan Rp250, total akhir Rp86.500, kembalian Rp13.500. **Kembalian Rp13.000 berarti pelanggan membayar Rp87.000—lebih mahal Rp250**; jangan diam-diam menerapkannya sebagai “pembulatan”. M5.4 tidak otomatis menambahkan surcharge/pembulatan yang merugikan pelanggan.
- Untuk split payment, jumlah nontunai yang benar-benar dikonfirmasi tidak dibulatkan. Pembulatan hanya sisa tunai untuk pelunasan: `cash_due_before = total_after_other_discounts − confirmed_non_cash`; `rounding_discount = cash_due_before mod step`; `cash_due_final = cash_due_before − rounding_discount`; total final berkurang tepat sebesar potongan tersebut. Contoh Rp86.750 − QRIS Rp50.000 → sisa Rp36.750 → potongan Rp250, tunai bersih Rp36.500. Tidak membulatkan piutang/pembayaran cicilan secara otomatis atau membuat saldo utang menghilang.
- Simpan nominal pembulatan dan alokasi baris/unit secara deterministik. HPP tidak berubah karena potongan; pendapatan dan laba kotor menyesuaikan. Retur/refund memakai harga neto/alokasi snapshot sehingga diskon tidak dikembalikan dua kali.
- Dalam audit kas, saldo fisik memakai tender aktual dikurangi kembalian aktual. Contoh Rp100.000−Rp13.500=Rp86.500 harus cocok dengan tunai bersih transaksi, bukan Rp86.750. Tidak menyalahkan kasir atas Rp250 yang sudah disepakati sebagai potongan. Perubahan setting tidak menulis ulang histori.
- Jika komposisi kembalian belum tersedia walaupun dibulatkan, bantu koreksi pecahan/sumber kas secara eksplisit; jangan membuat angka cocok lewat selisih tersembunyi. User dapat memakai numpad/pilihan uang lain sesuai kebijakan audit yang sah.

### 6.4 State kebijakan pencatatan kas — catatan 33

Reproduksi dan perbaiki simpan yang tampak sukses tetapi tetap dirty, serta kebijakan yang berubah di radio tanpa benar-benar tersimpan.

- Tampilkan status sesi kas sekarang: belum dibuka/terbuka/perlu ditutup, tanggal dan identitas sesi seperlunya.
- Bila **belum ada sesi terbuka**: pilihan pemilik adalah **Nonaktif** dan **Audit wajib oleh pemilik**; pencatatan sukarela dimulai kasir lewat Buka sesi kas, bukan memilih state fiktif pada pengaturan.
- Bila **sesi terbuka**: pilihan relevan **Pencatatan kasir tanpa audit wajib** dan **Audit wajib oleh pemilik**. Menonaktifkan seluruh pencatatan harus menjelaskan perlunya menutup sesi dahulu. Pilihan Nonaktif yang tersimpan sebelumnya tetap boleh ditampilkan sebagai kebijakan lama dengan catatan sesi sukarela sedang berjalan; jangan mengubahnya otomatis hanya karena halaman dibuka.
- Pisahkan **kebijakan toko** dari **status sesi fisik**. Pergantian kebijakan tidak menghapus/menutup sesi diam-diam. Peningkatan audit dapat perlu saldo awal/pecahan yang lengkap; bila belum cukup, tampilkan syarat dan jalankan transisi terkonfirmasi untuk sesi sekarang atau berlaku sesi berikutnya. Jangan mengarang histori pecahan sebelumnya.
- Setelah owner auth dan commit benar-benar sukses, reload sumber kebenaran, perbarui baseline form, nonaktifkan Simpan sampai ada perubahan, Back tidak menampilkan dirty dialog palsu. Jika gagal/ditolak/batal PIN, kebijakan aktual tetap, error spesifik ditampilkan dan perubahan form tidak disamarkan sebagai sukses. Validasi ulang state sesi di database pada commit.

## 7. Gudang, form, histori, arsip dan daftar

### 7.1 Form barang — catatan 8,10,11

1. Hapus pesan umum “lengkapi nominal/jumlah dengan angka dan tanggal yyyy-MM-dd”. Validasi **field wajib pertama yang invalid** menurut urutan tampilan, gunakan label sebenarnya, outline/helper merah, scroll dan fokus ke sana. Setelah diperbaiki dan Simpan ditekan lagi, lanjut ke field invalid berikutnya. Jangan membuat expiry opsional wajib hanya karena fitur expiry diaktifkan; tanggal kosong adalah tidak dicatat, tanggal terisi tidak valid tetap error.
2. Field tersembunyi karena preferensi tidak menghasilkan error yang tidak bisa dilihat. Quantity/biaya/tracking mengikuti kontrak M5.3. Biaya unknown tidak dibikin nol hanya agar form lulus.
3. Rak wajib berasal dari data rak yang sah bila terisi. Teks acak yang belum dipilih/tidak dikenal memblokir Simpan dengan pesan **“Rak ini belum terdaftar. Pilih rak yang tersedia atau tambahkan rak baru.”** Sediakan tombol ke Tambah/Edit rak dan pertahankan draft saat kembali. Kosong tetap boleh jika opsional. Jangan menyimpan sukses lalu diam-diam membuat `rack_id=null` untuk teks yang user kira sudah tersimpan.
4. Saat nilai terkait ada/diketahui, **harga beli < harga jual** dan **harga grosir < harga jual**, bukan≤. Sama atau lebih tinggi ditolak, pesan menunjuk field benar, tidak ada “lanjutkan saja” yang menembus hard validation. Harga grosir opsional; unknown/field fitur off mengikuti aturan status biaya, tidak memaksa angka buatan. Jangan menambahkan kewajiban harga grosir≥harga beli di luar aturan yang memang ada tanpa alasan/kebutuhan.
5. Berlaku pada tambah/edit, jalur harga terkait dan repository; harga pembelian aktual yang melanggar kebijakan tidak boleh diubah menjadi angka palsu. Arahkan pemilik memperbaiki harga jual/konfigurasi sebelum finalisasi bila policy melarangnya. Pesan harga beli tidak boleh tertukar menjadi harga grosir. Pertahankan peringatan harga rendah yang berbeda dari validasi keras ini.

### 7.2 Histori barang — catatan 9

Pada detail barang, tampilkan histori penerimaan: tanggal **dan jam**, quantity/unit dan konversi pcs, harga beli/unit yang jelas, total seperlunya, supplier atau **“Tidak dicatat”**, serta aksi Pengeluaran stok yang sudah ada dengan kewenangan semula. Expiry/batch tetap bisa dilihat pada detail tambahan; jangan membuang data itu dari database demi merapikan tampilan.

Ikon panah naik/turun membandingkan biaya pembelian **per pcs dalam currency sama** dengan penerimaan pembanding terdahulu yang diketahui; bukan membandingkan harga per dus dengan per pcs atau mengambil avgcost sebagai harga nota. Sama diberi tanda netral; pembelian pertama/unknown tidak diberi panah palsu. Histori tetap snapshot dan dipaginasi.

### 7.3 Sort dan navigasi — catatan 19,20,21,28

- Hapus tombol bahasa ganda di Promo quantity eceran, pertahankan satu kontrol bahasa yang jelas serta draft saat bahasa berubah.
- Kategori: ketuk nama membuka produk terfilter kategori, tombol Edit mengubah; hapus long-press edit dan petunjuk lama yang kini tidak berlaku. Aksesibilitas edit tetap ada.
- Rak: ketuk nama membuka barang pada rak tersebut; tombol Edit khusus mengubah nama. Form add/edit rak dan suggestion tetap bekerja.
- Daftar Gudang menambah **Urut berdasarkan: Nama, Terakhir diubah, Paling laku**, dengan asc/desc berikon dan accessible label. Filter stok/expiry/kategori/rak/supplier tetap bisa digabung. Popularitas memakai definisi konsisten dengan M5.3, memperhitungkan retur/reversal yang relevan, bukan query seluruh histori setiap ketuk. Stable tie-break dan keyset cursor harus mengikuti sort; refresh/reset cursor ketika urutan/filter berubah.

### 7.4 Perbaikan archive produk — catatan 24

Reproduksi produk tanpa keranjang aktif → Arsipkan → cek daftar aktif Gudang, daftar Arsip, pencarian Kasir/Favorit dan reopen. Perbaiki akar masalah commit, flag/filter/cache/provider/session/undo yang sebenarnya; jangan sekadar menyembunyikan satu widget.

Arsip harus final di sumber kebenaran, hilang dari scope aktif, muncul pada scope arsip, dan transaksi lama tetap benar. Undo yang memang tersedia mengembalikan status dengan konsisten. Repository checkout tetap menolak produk yang sudah diarsipkan walaupun ada cache lama; draft terbuka diberi pesan koreksi, tidak silent delete transaksi.

### 7.5 Hapus permanen arsip secara aman — catatan 22

1. Audit semua layar arsip. Tambahkan mode pilih, checkbox per item, header pilih semua dengan cakupan jelas (**halaman yang dimuat** vs **seluruh hasil filter**). Gunakan ID stabil, tampilkan jumlah pilihan dan reset/rekonsiliasi pilihan saat scope berubah; jangan diam-diam menghapus arsip di luar filter.
2. Aksi Hapus permanen hanya pemilik dengan autentikasi ulang/konfirmasi yang sesuai. Tampilkan pratinjau item yang dapat dihapus dan item terlindungi beserta alasannya. User mengonfirmasi daftar eligible yang konkret; item blocked tetap tersimpan. Dialog menjelaskan tidak dapat di-undo dan cadangan dianjurkan, tanpa mewajibkan Google Drive.
3. Eligible hanya data arsip yang tidak mempunyai fakta bisnis/dependensi yang wajib dipertahankan, saldo fisik/nilai/utang/kredit/reservasi aktif, draft, sale/receipt/retur/cash history atau reference audit yang memerlukan record tersebut. Pelanggan piutang 0 tetapi punya sejarah sale tidak otomatis aman dihapus. Saldo stok 999 untracked bukan 999 barang nyata, tetapi bukan alasan mengabaikan dependensi lainnya.
4. Jangan menonaktifkan FK, cascade-delete histori keuangan, menulis ulang snapshot, atau menghapus log keamanan karena user memilih semua. Data historis yang dilindungi tetap dapat disembunyikan/difilter dengan efisien; tampilkan alasan “Dipertahankan karena digunakan pada transaksi”. Ini keputusan integritas, bukan bug tombol.
5. Revalidasi dependensi di transaksi saat delete, bukan hanya preflight. Batch besar memakai rencana/cursor dan progres yang terukur; jika scope berubah atau muncul reference baru, hentikan/replan dengan hasil jelas. Jangan menyatakan seluruh batch terhapus jika sebagian gagal.
6. Files/lampiran hanya dibersihkan ketika benar-benar tak direferensikan dan scope sah. Jangan menghapus cadangan, PDF pemulihan atau file user di luar aplikasi. Maintenance SQLCipher/VACUUM mengikuti jalur aman M5.3, tidak dipaksa sinkron setiap delete dan bukan penghapusan transaksi lama berdasarkan umur.

### 7.6 Opname manual dan scan — catatan 14

Pertahankan dua metode dalam sesi yang sama: **input jumlah manual** dan **scan barcode/kamera**. User boleh memilih atau menggabungkan, dengan aturan jelas apakah input manual mengganti total atau menambah. Jangan membuat jumlah hasil scan ditambah lagi secara diam-diam ketika mengetik angka total fisik. Tetap bedakan belum dihitung dari 0, baseline/revisi stok, conflict check saat finalisasi, batch/expiry jika diperlukan, draft/undo, reservasi/karantina dan unknown cost. Tersedianya scanner tidak menghapus cara manual M5.2. Masukkan kasus ini pada matriks acceptance dan data pengujian.

## 8. Penerimaan supplier, banyak supplier, foto nota dan draft retur

### 8.1 Alur penerimaan multi-produk yang saya maksud — catatan 25

Jadikan satu alur **Supplier → Barang masuk / Penerimaan** dengan daftar draft yang dapat diisi bergantian lewat scanner fisik, kamera atau pencarian manual:

1. Pilih/cari supplier (supplier tetap opsional pada operasi dasar yang tidak memerlukan tagihan; tagihan/tempo membutuhkan identitas supplier jelas). Buka draft penerimaan, bukan langsung memutasi saldo.
2. Scan Marie Roma 15 kali → quantity 15; scan Hit 12 kali → quantity 12. Scan campuran tanpa mengelompokkan merek tetap menggabungkan baris produk yang sama, bukan membuat baris baru setiap scan.
3. Alternatif: cari/pindai satu produk, ketik jumlah 15/12, lalu tambah; dukung koreksi/minus/undo. Jangan mewajibkan semua toko scan satu-per-satu atau punya hardware scanner.
4. Jika Sunco belum terdaftar, tampilkan pendaftaran produk. **Pertahankan seluruh draft penerimaan** saat form dibuka/dibatalkan/disimpan. Setelah produk baru disimpan, kembali ke draft lalu masukkan quantity 20. Produk baru tidak otomatis membuat stok awal/receipt kedua: dalam konteks ini stok datang melalui penerimaan, sehingga pembuatannya memakai saldo awal 0 yang jelas atau mode untracked yang sah, bukan mengisi 20 di dua tempat.
5. Daftar akhir menampilkan 15 Marie Roma, 12 Hit, 20 Sunco, unit dan preview pcs. Warehouse mencocokkan dengan nota fisik, lalu mengisi/mengoreksi **harga beli pada setiap baris**. Default dari harga beli terakhir yang sesuai, note kuning M5.3 tetap ada sampai diubah; jangan menganggap avgcost pasti harga nota.
6. Sistem menghitung total pembelian dari quantity×harga/unit secara presisi, mempertahankan data kemasan/expiry/batch yang dibutuhkan. Hanya Konfirmasi dokumen yang menyimpan receipt/items, stok/history/nilai biaya dan tagihan yang dipilih secara atomik/idempotent. Request gagal tidak membuat sebagian stok masuk.
7. Tunai atau tempo terhubung dengan invoice/payment M5.3, bukan ledger baru. **Gudang atau pemilik dapat mencatat pembayaran untuk transaksi supplier yang ditangani sesuai kewenangan operasional ini**, termasuk pembayaran pada konfirmasi penerimaan. Buat capability khusus yang sempit dan audit; ini memperjelas instruksi terbaru, bukan membuka seluruh laporan/pengaturan finansial untuk gudang. Pengaturan rekening/QRIS/PIN/laporan laba tetap milik pemilik. Pembayaran cicilan/koreksi/override dokumen lain tetap mengikuti kebijakan pemilik dan scope yang dijelaskan di UI.
8. Pembayaran hanya dicatat setelah benar-benar diserahkan/dikonfirmasi, tidak otomatis dibayar karena nota bertipe tunai. Sumber laci versus transfer/dana pemilik dipisah; uang laci berkurang sekali. Jika tempo, simpan saldo/due date dan pengingat yang sudah ada. Pelunasan utang tidak menghitung HPP lagi.

Contoh 15/12/20 di atas menjadi kasus penerimaan wajib, termasuk Sunco baru, beralih form lalu kembali, cancel, harga sebelumnya berbeda dan retry finalisasi.

### 8.2 Relasi produk–supplier banyak-ke-banyak — catatan 27

- Tambahkan/reuse junction seperti `product_suppliers` dengan unique(product,supplier), flag preferensi utama opsional. Produk boleh 0/1/banyak supplier. Jangan menggandakan SKU/stock balance untuk satu barang yang sama.
- Pada tambah/edit barang pilih beberapa supplier dengan suggestion, bukan teks yang tidak tersimpan. Ketuk supplier tetap menunjukkan barang yang terkait melalui relasi ini; migrasikan relasi supplier tunggal lama menjadi satu relasi tanpa kehilangan ID/sejarah.
- Penerimaan memperlihatkan supplier aktual per dokumen. Boleh menambah relasi master melalui aksi jelas, tetapi jangan mengganti asal semua stok lama. Menghapus relasi master tidak menghapus receipt/utang/retur historis.
- Perbedaan harga per supplier dan histori berasal dari transaksi yang tepat. Tidak menduplikasi carrying value/quantity atau laporan potensi toko karena join many-to-many. Laporan per supplier menjelaskan apakah mengelompokkan berdasarkan asal penerimaan yang dapat ditelusuri atau relasi master yang dapat overlap; hasil relasi yang overlap tidak boleh dijumlahkan sebagai total toko unik.

### 8.3 Draft retur supplier lintas hari dan reservasi — catatan 26

1. Pilih supplier lalu **Siapkan retur**. Cari/scan produk tanpa mewajibkan supplier itu menjadi satu-satunya supplier master. User boleh memilih supplier penerima yang berbeda dari preferensi master, tetapi aplikasi tidak boleh mengarang bahwa supplier tersebut pasti menyetujui kredit atau pernah menjual unit itu.
2. Draft menyimpan produk, quantity, kondisi/bucket/batch atau provenance bila diketahui, biaya acuan otomatis dengan label sumbernya, alasan opsional, tanggal dan supplier target. Jika asal tidak dapat dibuktikan, simpan **asal belum diketahui**, jangan membuat receipt fiktif. Harga biaya internal dan nilai kredit yang disepakati supplier adalah angka berbeda.
3. Draft tersimpan persisten, dapat ditambah/diubah pada hari lain, dilihat kembali ketika supplier datang. Draft belum merupakan pengeluaran fisik/finalisasi utang supplier. Pemindahan fisik ke area retur/karantina, jika dilakukan, dicatat sebagai perubahan lokasi/status yang konsisten, bukan membuat atau menghilangkan quantity.
4. **Reservasikan unit/quantity yang dipilih** ke draft supplier tersebut agar tidak dijual/diretur ulang ke supplier lain. Reservasi mengurangi ketersediaan operasional yang relevan tanpa mengurangi total fisik/nilai sebagai retur final. Karantina yang sudah tidak layak tidak dihitung/dipindahkan dua kali.
5. Contoh karantina 5 unit: draft supplier A reservasi 3 → hanya 2 tersisa untuk draft supplier B. Ini memenuhi larangan barang yang sama didaftarkan dua kali, tetapi tidak melarang SKU yang sama mempunyai unit berbeda untuk supplier berbeda. Barcode SKU bukan serial unit; jelaskan batas ini dan gunakan bucket/batch/source/quantity agar tersedia benar.
6. Untuk produk untracked, jangan memakai sentinel 999 sebagai bukti jumlah yang dapat direservasi. Unit karantina yang benar-benar tercatat boleh direservasi; jika draft dari stok fisik tak dilacak, minta jumlah fisik yang disiapkan dan catat keterbatasannya, tanpa jaminan aplikasi tahu semua stok toko. Cegah duplikasi reservasi atas unit yang sudah tercatat sama.
7. Batal/hapus baris draft melepaskan reservasi secara konsisten. Perubahan stok/retur pelanggan/kerusakan saat draft terbuka divalidasi pada finalisasi. Tidak boleh membiarkan stok negatif atau reserved>available karena dua commit bersamaan.
8. Saat supplier datang: review → supplier menerima seluruh/sebagian/menolak → finalisasi quantity yang benar-benar diserahkan, sisanya tetap draft/ditolak sesuai tindakan. Baru saat itu stock/history/value keluar sesuai costing, dan kredit supplier menunggu/disetujui sesuai transaksi keuangan. Tidak otomatis mengurangi utang dua kali atau membuat refund tunai sebelum uang diterima.
9. Pertahankan dokumen final, audit dan reversal dengan pengecekan dependent transactions. Draft kasir, retur supplier dan retur pelanggan mempunyai state/ID yang berbeda dan tidak saling membatalkan.

### 8.4 Foto nota supplier — catatan 6

- Tambahkan **Ambil foto nota** pada penerimaan supplier. Lampiran boleh 1 atau beberapa halaman jika nota panjang, dengan preview/zoom, ambil ulang, rotasi dan hapus sebelum konfirmasi. Ini dokumentasi untuk audit pemilik, **bukan OCR otomatis** atau verifikasi supplier otomatis.
- Mulai dengan resize proporsional sekitar lebar 1280 px dan JPEG 70–75%; ukur hasil. Jangan menjamin 80–150 KB selalu tercapai, memotong bagian nota atau membuat angka tulisan tangan tak terbaca. Untuk nota panjang/blur boleh kualitas/resolusi lebih baik atau beberapa foto. Grayscale opsional hanya jika tetap terbaca; hindari decoding gambar besar sekaligus di UI thread.
- Hapus metadata lokasi/EXIF yang tidak diperlukan. Validasi dimensi/type/ukuran aman, simpan privat dengan nama/ID konten yang terkendali. **SQLCipher tidak mengenkripsi foto di filesystem**: gunakan enkripsi lampiran yang sesuai key lifecycle/AEAD proyek, bukan menganggap folder privat sudah terenkripsi oleh SQLCipher. Jangan menulis algoritma kriptografi sendiri atau nonce berulang.
- Gudang bisa melampirkan pada draft, pemilik bisa audit; akses/export mengikuti capability. File tidak masuk galeri/cloud/WhatsApp otomatis. Data pelanggan/nomor nota tidak masuk log atau evidence publik.
- Portable backup/restore harus membawa lampiran dan manifest/hash yang terautentikasi, mendeteksi lampiran hilang/rusak, menjaga relasi dokumen dan mendukung streaming/batas ukuran. Migrasi key/restore/reset/retensi mengikuti key lifecycle yang benar. Crash antara save file dan commit DB tidak membuat record dangling atau menghapus foto yang masih direferensikan; bersihkan orphan privat dengan aman.

## 9. Member dan jalan pintas kasir

### 9.1 Pencarian pelanggan dan histori — catatan 12,17,29–31

- Bayar menyediakan pencarian member **nama dan nomor HP**, bukan mewajibkan mengetik nomor penuh. Nama sama diperbolehkan; tampilkan nama, nomor seperlunya untuk membedakan, dan alamat/catatan yang memang ada pada detail. Nomor HP tetap wajib/unik setelah normalisasi untuk member baru sesuai keputusan saya; jangan menambahkan kewajiban nama unik atau otomatis menggabungkan nama sama.
- Helper nama singkat boleh berbunyi “Gunakan nama yang mudah Anda kenali. Pelanggan dengan nama sama dibedakan melalui nomor telepon.” Nomor nasional dan internasional yang ekuivalen tidak menciptakan member ganda. Legacy tanpa nomor tetap mengikuti migrasi/penanganan M5.3 agar utang lama bisa dilunasi.
- Ketuk member membuka **histori transaksi member**, dengan filter tanggal dan pagination, ringkasan pembelian/piutang yang relevan. Tombol Edit terpisah membuka form ubah. Histori mempertahankan sale/retur/pelunasan yang benar, bukan menambah kunjungan untuk setiap cicilan.
- Arsip member memiliki tombol **Pulihkan**, validasi konflik nomor dan hak akses. Memulihkan member tidak membuat saldo/piutang baru atau menghapus histori.
- Filter **Punya utang** memakai saldo piutang efektif>0, bukan pernah berutang atau tagihan sudah lunas. Sort **Nama, Terakhir ditambahkan, Kunjungan terbanyak, Utang terbanyak**, masing-masing asc/desc, stable tie-break dan query/indeks yang sesuai. Pilih semua/hapus arsip tetap mengikuti proteksi referensi §7.5.

### 9.2 Barang Favorit — catatan 35

Tambahkan tombol **Barang Favorit** di Kasir yang membuka grid/bottomsheet ringkas 6–8 produk paling sering terjual menurut statistik yang sama dengan M5.3. Satu ketuk memasukkan 1 pcs atau menambah baris produk yang sama di Keranjang, dengan aturan mode harga/quantity yang sudah ada. Tidak memerlukan barcode untuk kresek/kerupuk/es batu dan barang cepat lainnya.

Utamakan barang aktif/layak; stok tracked habis/expired/arsip tidak boleh dijual lewat shortcut. Untracked bukan dianggap habis. Cache/agregat tidak dibangun ulang dari semua histori setiap frame. Jika belum ada penjualan tampilkan empty state yang membantu; tidak otomatis memasukkan barang dummy pada toko asli. Menutup grid mengembalikan fokus yang benar tanpa popup keyboard/kehilangan draft yang mengganggu. Tidak menambah sistem rekomendasi cloud.

## 10. Laporan keuntungan, Drive dan konsistensi data

### 10.1 Grafik dan tabel keuntungan — catatan 4

1. Tambahkan grafik beserta tabel angka **Harian, Mingguan, Bulanan** di Laporan, hanya untuk pemilik/laporan. Gunakan filter/rentang tanggal yang ada dengan bucket yang jelas dan timezone toko, awal minggu yang terdefinisi. Nol pada periode kosong benar-benar nol; data unknown/incomplete tidak diubah menjadi nol biaya.
2. Label **Laba kotor** jika yang dihitung pendapatan bersih−HPP; jangan menyebut laba bersih jika biaya operasional belum dicatat. Pendapatan bersih memperhitungkan discount/pembulatan/retur; HPP memakai ledger snapshot beserta reversal yang sah. Pembayaran supplier/pelunasan piutang/refund kas bukan pengurang/penambah laba kedua kalinya.
3. Retur diposting pada periode kejadian retur menurut definisi yang sama dengan laporan uang/stok; jangan mengubah grafik bulan penjualan lama tanpa label restatement. Kerugian karantina/write-down ditampilkan terpisah dari HPP penjualan jika memang dicatat terpisah. Selaraskan grafik, tabel, ringkasan dan CSV/XLSX seluruh scope.
4. Agregasi dilakukan SQL/domain dengan indeks tanggal/filter tepat, bukan loop seluruh sales di UI. Bucket kosong diisi secara terukur; cache berdasarkan filter/revisi data, invalidasi saat sale/retur/koreksi. Hindari future/query baru setiap build dan animasi/rebuild canvas berlebihan. Pilih library sesuai dependensi aktual, jangan menganggap satu library pasti lambat tanpa pengukuran.
5. Uji batas hari/minggu/bulan/tahun/timezone, data retur periode negatif, unknown cost, pagination/ekspor scope dan UI perangkat lambat. Grafik mempunyai alternatif tabel/label agar tetap berguna jika animasi dimatikan atau aksesibilitas aktif.

### 10.2 Bug pemilihan akun Drive dianggap dibatalkan — catatan 23

Reproduksi menggunakan konfigurasi/paket yang benar dan akun yang diizinkan, tanpa mengubah proyek Cloud atau mengunggah data toko nyata sebagai eksperimen.

- Lacak state: memilih akun → authorization/scope → tujuan backup → upload/validasi. Bedakan **user benar-benar batal**, akun belum diizinkan, scope/client/package/SHA salah, token/auth error, ketiadaan Google Play services, timeout, intent/lifecycle dan kegagalan penyimpanan. Jangan memetakan semuanya menjadi “Dibatalkan”.
- Audit versi SDK/plugin nyata, result handling, pending future, null result, account/context setelah restore dan lifecycle gate. Log hanya metadata/error code/tahap yang aman, tanpa token/secret/recovery code/email pribadi lengkap. Perbaiki akar masalah, bukan menampilkan “Berhasil” untuk hasil null atau diam-diam memakai akun lama.
- Google Drive tetap opsional; pembatalan/kegagalan tidak mengubah akun aktif, menghapus backup, mengaktifkan jadwal backup otomatis atau memaksa reset. Settings tertulis dan feedback menggambarkan state yang benar-benar persisted.
- Paket pengujian/teman yang applicationId/signing-nya berbeda memerlukan OAuth client yang sesuai untuk uji Drive nyata. Jangan memakai credentials dari paket lain lalu menyebutnya user cancelled. Jika tidak dikonfigurasi, laporkan **konfigurasi OAuth paket uji belum tersedia** dan biarkan kasir/backup lokal bekerja; jangan menghapus fitur Drive dari source production.
- Bedakan tes SDK/HTTP mock, native account picker dan upload/restore Drive nyata. Jangan membuat akun OAuth/AI-agent baru, mengubah status production, membeli layanan atau meminta secret dimasukkan ke APK. Jika pengujian nyata memerlukan pilihan akun/izin, minta langkah sederhana spesifik; lanjutkan tes independen.

## 11. Fondasi data, migrasi dan integritas

- Audit skema aktual sebelum membuat tabel. Entitas baru/perluasan mungkin meliputi customer returns/items/refunds, warranty snapshot, stock disposition/quarantine/reservation, product–supplier links, attachment manifest, payment allocation/rounding snapshot, receipt lookup token, lock state dan recovery format metadata. Reuse ledger/cash/PIN/backup yang sudah benar; tidak membuat database kedua sebagai sumber kebenaran fitur baru.
- Migrasi maju dari schema 37 dan versi lama yang didukung, populated serta rollback/failure yang teruji. Pertahankan ID historis, uang, HPP, avgcost, piutang/utang, printer/protokol/feed, tracking 999+flag, feature preferences, membership, seed marker, wrapped key/biometrik dan sesi sesuai security policy. Data baru default kompatibel, tidak memberi garansi retroaktif atau returned quantity fiktif pada sales lama.
- Operasi finansial/stok final atomik dan idempotent, FK/constraint/operationID benar. Draft/reservasi/final credit/refund mempunyai state yang berbeda. Integer minor unit untuk uang, presisi biaya proyek tetap; IDR/USD/MYR/EUR dan locale input yang berbeda wajib tetap benar.
- Snapshot produk/kode/garansi/diskon/HPP/rounding pada sale tetap berlaku untuk refund meski master berubah/diarsipkan. Cache/Provider hanya representasi, repository memeriksa capability/status/stock pada commit.
- List besar memakai keyset/seek dengan tie-break stabil mengikuti sort/filter; query laporan menghitung seluruh scope, bukan cuma loaded items. Hindari OFFSET besar/full-table load tanpa alasan. Periksa query plan untuk indeks supplier/member/tanggal/stock buckets yang baru.
- Portable encrypted backup/restore mencakup seluruh fakta M5.4, attachment, reservation draft, cash refund dan key format yang relevan; job/token/session/device biometric tidak menjadi akses aktif pada perangkat lain. Recovery format baru tidak memutus arsip lama. Tidak mengimplementasikan sinkronisasi multi-device dalam proses backup ini.

## 12. Tahap kerja, pengujian dan perbaikan langsung

### 12.1 Urutan sampai handoff

1. **Audit dan kontrak**: baseline, matriks 35 catatan, reproduksi bug utama, design invariant migrasi.
2. **Fondasi keamanan dan perbaikan operasional**: lock state/recovery compatibility, gate, validasi form/archive, scanner routing, kebijakan kas.
3. **Retur dan keuangan**: return ledger/garansi/quarantine, refund/utang, QRIS manual/split, tombol pecahan/rounding.
4. **Gudang/supplier**: penerimaan 15/12/20, many-to-many, reservasi draft retur, lampiran nota, lookup/member/favorit.
5. **Recovery PDF/grafik/output/Drive**: integrasikan semua perubahan dan backup portable, perbaiki temuan.
6. **Acceptance M5.4 pada DV8910 dan Poco F6**: uji domain/integrasi/native yang relevan; perbaiki langsung, retest kasus dan regresi terdampak. Checkpoint lulus/gagal serta batas.
7. **Handoff awal**: update `.skybee` tanpa reset/reseed, buat APK Uji Teman berdata dummy dan panduan feedback; perangkat/fitur baru yang belum teruji ditandai. Jangan menunggu penilaian teman sebelum pekerjaan lain berlanjut.
8. **Realme C11**: sesudah tahap 7, uji cakupan **M5.3 dan M5.4** pada fixture terisolasi ketika perangkat tersedia; langsung perbaiki. Jika tidak tersedia, simpan checkpoint perintah/kasus yang jelas dan status belum diuji, jangan klaim selesai atau menahan APK yang sudah siap.
9. **Finalisasi**: jika temuan Realme mengubah source, jalankan regresi perubahan relevan pada DV/Poco, build ulang kedua APK terdampak, update `.skybee` lagi secara aman dan tandai APK terbaru. Commit/push/dokumentasi final tidak menyamakan bukti APK lama dengan kode baru.

### 12.2 Aturan perangkat dan isolasi

- **DV8910**: nama firmware DV8947-KIX/AX810 boleh berbeda dari hardware, jangan dipermasalahkan. Endpoint LAN terakhir 192.168.0.102:5555 bersifat petunjuk; **verifikasi device authorized aktual**, karena alamat bisa berubah. Root: write hanya tujuan pengujian yang diizinkan; selain itu read-only. Tidak mengubah firmware/HDMI/CCTV/bootloader/akun/sistem permanen. State sementara yang sah wajib dipulihkan dan readback exact.
- **Poco F6**: target UI/kamera/PIN biometrik/checkout/printer yang tersedia. Periksa serial/paket sebelum perintah. Iware MP-581RL 58 mm telah digunakan; printer 80 mm/protokol lain hanya diuji jika benar-benar tersedia. Tidak mengklaim kompatibilitas universal dari satu printer.
- **Realme C11**: jalankan setelah handoff awal, bukan paralel memotong urutan saya. Gunakan suite M5.3+M5.4 yang mencakup operasi baru, bukan mengulang semua M1–M4 tanpa alasan. Jangan mengurangi fitur/parameter keamanan demi Realme. Crash/ANR investigasi lewat log dan repro; hanya tandai SKIP/ENV jika bukti menunjukkan masalah sistem/perangkat di luar app, bukan otomatis karena HP tua.
- Host test dulu, lalu native suite relevan. DV tanpa kamera tidak wajib menjadi pengganti uji kamera Poco; ketiadaan hardware bukan bug app. Kamera/fingerprint/paper/cloud nyata yang tidak tersedia ditandai unverified dengan alasan.
- Seluruh mutasi acceptance memakai package/DB sintetis terisolasi. Jangan menggunakan `.skybee` aktif, ordinary, atau data teman sebagai fixture destructive. Hindari runner default-uninstall terhadap package operasional. Jangan menyalin seluruh sandbox/data privat di luar scope sebagai jalan pintas.
- Lindungi berkas/key/data lama dengan mekanisme proyek yang konsisten dengan WAL/background workers. Hash byte berbeda harus diinvestigasi; hash main DB sendiri tidak cukup membuktikan semua fakta. Jika isolasi gagal, simpan failure asli dan tandai FAILED ISOLATION, bukan baseline baru untuk menyembunyikannya.
- Bedakan pure test/mock, callback debug, UI hierarchy, input native, dialog OS dan bukti fisik. Jika ADB INJECT_EVENTS ditolak, jangan menamakan callback sebagai sentuhan manual. Uji timing 72 jam/expiry/lock tiruan bukan menunggu waktu nyata. Root permission tidak memberi izin otomatis untuk membaca/mengubah data pribadi.
- Jalankan perangkat terkontrol secara teratur dengan source/test manifest jelas; jangan mengedit kode yang sedang diuji oleh runner frozen. Tutup runner/worker fixture, pulihkan state, tandai controlOff sebelum handoff.

### 12.3 Skenario acceptance minimum

| Kelompok | Skenario wajib |
|---|---|
| PIN | Gagal 3/5/8, cooldown tidak mereset counter, PIN benar, force-close/reboot, auth paralel, pemilik/recovery sah dan invalid, secret toko lain, pergantian peran, rotasi dan migrasi. |
| Gate | Layar terkunci saat di Kelola hanya meminta PIN Kelola; gate kasir saat route kasir, Back, izin/SAF/m-banking tidak loop, draft tetap. |
| Recovery |24kata↔32 byte,64 hex lama, checksum, format/version, PDF 1 halaman dan decode QR, export tanpa izin ditolak, backup/restore lintas key. |
| Scanner | HID kode sama15 kali, frame kamera duplikat, leading zero, unknown→buat produk→kembali ke draft, Enter/paste/modal PIN/payment/delete, tap-focus ada/tidak didukung. |
| Retur | Sale committed saja, kode palsu/toko lain/struk lama, beli 5 → retur 1 → sisa 4, commit paralel, quantity berlebih, diskon/grosir/rounding, good/bad/unknown cost/expired/arsip, interlock reversal. |
| Uang retur | Tunai/split/nontunai/piutang, utang dikurangi dahulu, refund belum diserahkan, kas keluar pada sesi hari ini, pecahan kurang, double-tap/crash/retry, tidak ada HPP/kas ganda. |
| Garansi | Kosong, bulan positif, checkout gagal, akhir bulan/tahun kabisat, edit master tidak mengubah sale lama, struk ID/EN. |
| QRIS | Upload hanya pemilik, pemeriksaan manual wajib, nominal berubah membatalkan konfirmasi lama, nontunai tidak memotong laci, split+piutang, tidak ada transfer/verifikasi bank otomatis. |
| Pembulatan/kas |86.750/100.000/step 500→13.500, nontunai tidak diubah, piutang tidak dibulatkan hilang, currency desimal, alokasi retur, tombol kembalian/reset/undo, policy sesi buka/tutup dan dirty-state. |
| Form/master | Field invalid pertama, expiry opsional, rak belum dikenal, harga sama/lebih ditolak, pembanding histori per unit, navigasi kategori/rak, sort dan batas halaman. |
| Opname | Manual dan scan sama-sama tersedia, mengganti total vs menambah jelas, belum dihitung vs 0, conflict-check, reservation/karantina dan draft/retry. |
| Archive/delete | Arsip produk berubah pada semua scope/reopen/undo, pulihkan member, record bersejarah diblokir dari hard delete, pilihan/filter/batch/auth/cancel, FK dan snapshot uang utuh. |
| Supplier | Marie 15/Hit 12/Sunco 20, manual dan scan campur, note harga lama, tunai/tempo/capability/sumber kas, rollback, barang baru, migrasi banyak supplier dan agregat tidak ganda. |
| Draft retur supplier | Simpan hari ini/resume besok, reservasi 3 dari 5→supplier lain maksimal 2, master supplier berbeda, asal unknown, karantina/untracked, pembatalan, serah sebagian, kredit belum disetujui. |
| Foto nota | Portrait/panjang/buram/oversize, keterbacaan/kompresi tanpa crop, EXIF, file terenkripsi dan akses, crash-orphan, backup/restore lampiran hilang/rusak. |
| Member/favorit | Nama sama+nomor ekuivalen, filter piutang sekarang, sort/tie/histori tanggal/pulihkan konflik, top 6–8/untracked/habis/arsip, popularitas sesudah retur/reversal. |
| Reports/Drive | Bucket hari/minggu/bulan, periode retur negatif/biaya incomplete, query plan/cache, tabel/ekspor cocok, akun terpilih/batal/auth failure berbeda, lifecycle callback dan OAuth sesuai paket. |
| Migrasi/ketahanan | Schema 37 populated→baru/reopen/cancel/failure, portable backup lintas key, data/key/preferensi lama utuh, idempotency, ARM32/ARM64 dan penggunaan memori. |

Jalankan formatter, analyzer, lokalisasi ID/EN, tes yang relevan, build debug/release, pemeriksaan ABI/16KiB/signature/license dan guard package yang sudah diwajibkan repository. Ukur performa jalur scanner, grafik, foto dan restore dataset pada data representatif; jangan menulis tes yang hanya menyalin implementasi atau mengulang suite berat tanpa perubahan/risiko baru.

## 13. Handoff `.skybee` dan APK untuk teman

### 13.1 Paket eksplorasi saya

Update **`com.example.kasir_app.skybee`** di Poco F6 secara in-place dengan signing yang cocok, versionCode naik dan data/PIN/key/biometrik/printer/seed marker/preferensi utuh. Jangan membuat package baru sebagai pengganti update, jangan reset/reseed atau memaksa downgrade. Jika wizard M5.3 masih belum selesai, pertahankan pilihan dan statusnya; jangan menekan Finish/memilih PIN atas nama saya untuk memaksa seed.

Siapkan snapshot/perlindungan yang sah sebelum update. Verifikasi migrasi/fakta bisnis/kunci/preferensi, dua startup termasuk cold reopen, tidak ada unintended seed dan kasir siap. Jangan menambahkan transaksi tes ke data eksplorasi saya. Paket ordinary/integration lain tidak diubah tanpa kebutuhan/scope yang sah.

Jika perangkat tersedia, lakukan pemasangan yang sudah diotorisasi ini; jangan berhenti hanya dengan link APK “belum dipasang”. Jika ADB/signing/perangkat terhalang, jelaskan hasil konkret, tetap sediakan APK/run configuration Android Studio dan langkah lanjut tanpa uninstall paksa.

### 13.2 APK Uji Teman berdata dummy

1. Buat build/flavor terpisah berlabel **SkyBee Uji Teman — Data Demo**, applicationId berbeda dari ordinary/.skybee saya (contoh `com.example.kasir_app.skybee.trial`; verifikasi tidak bentrok). User dapat memasang tanpa menimpa app lain. Ini APK native Android, bukan link web, sertifikat produksi Play Store atau build instrumentation dengan remote backdoor.
2. Gunakan signing test yang stabil untuk update APK teman berikutnya, tidak membocorkan/private key produksi dan tidak commit keystore/password. APK universal jika memenuhi ukuran, mencakup ABI yang didukung source termasuk ARM32/ARM64, minSDK sesuai plugin aktual. Jika ada batas OS/ABI nyata, jelaskan sebelum user mencoba; tidak menaikkan minSDK diam-diam hanya untuk satu plugin.
3. Dataset dummy **benar-benar tersedia dari APK secara offline**, seed lokal yang dibundel dan dibuat **sekali secara atomik** pada penyelesaian setup demo/pilihan PIN awal; tidak memerlukan login Google/download API. Preferensi/wizard dasar tetap dapat dites, store identity demo dapat diisi sebelumnya agar setup singkat. Key SQLCipher/recovery dibuat unik per instalasi, PIN dipilih user; jangan membundel DB copy Poco atau secret identik semua pengguna.
4. Reuse mekanisme seed yang aman sesuai flavor yang sudah ada, guard flavor/seed version dan marker yang mencegah seed ulang saat update/restart. Dataset terisolasi dari source ordinary; feature trial bukan alasan mengaktifkan debug MethodChannel, remote controller atau jalur bypass PIN pada APK release.
5. Dataset sasaran kira-kira 100–150 produk dan 50–100 sales dengan integritas/ledger yang valid, bukan angka yang saling tak cocok. Cakup kategori/rak, beberapa supplier, receipts berbeda harga/tempo/cicilan/overdue, member nama sama nomor dummy berbeda, piutang/lunas, promo/grosir/dus, stok 0/minimum/normal, tracked 999 nyata/untracked 999, biaya unknown yang dilabeli, expiry dekat/expired/antar batch, foto nota **sintetis**, arsip yang eligible/tidak eligible hard delete, sesi/pecahan kas, split payment manual, rounding, retur parsial good/bad/karantina, reservasi supplier dan warranty aktif/berakhir. Gunakan tanggal sintetis relatif ke saat seed agar contoh relevan, tanpa mengubah jam OS. Variasi yang butuh policy store berbeda didemonstrasikan lewat skenario test/setting, bukan melanggar kebijakan stok aktif dengan barang untracked tanpa alasan.
6. Kontak/WA/email/nota/foto semuanya sintetis dan diberi label. Jangan memakai akun, nomor, logo QRIS penerima pembayaran nyata, transaksi, key/PIN/recovery atau foto toko saya. Gambar QRIS demo **bukan kode pembayaran yang dapat mengirim uang**; tampilkan “Contoh — bukan untuk pembayaran”. Tindakan buka WA/share/backup Drive tetap tindakan user, bukan otomatis.
7. Verifikasi instalasi pertama pada fixture, seed counts/integrity/FK/rekonsiliasi uang/stok, restart tanpa seed ulang, update in-place dan tidak bentrok paket. Uji smoke APK release yang benar-benar akan diberikan, bukan hanya build debug berbeda seed.
8. Buat `PANDUAN_UJI_TEMAN_M54.md` singkat: nama APK/versi/hash/paket/min Android, instalasi sebagai APK dari user, data demo, cara memilih PIN, skenario test 15–30 menit dan cara menyampaikan feedback dengan versi/perangkat/langkah/expected/actual. Tidak meminta mereka memberikan PIN/recovery/token/nomor rekening. Tidak mengirim APK/pesan kepada teman atas nama saya; saya yang mendistribusikannya.
9. Sediakan APK dan manifest build/path/hash yang mudah ditemukan (`release-artifacts` lokal yang diabaikan Git sesuai aturan), serta catatan fitur cloud/hardware yang belum teruji. Hindari modul telemetry/analytics/expiry timebomb/require login tambahan hanya untuk mengumpulkan penilaian.

## 14. Pengujian Realme setelah handoff dan konsistensi APK final

Setelah `.skybee` diperbarui dan APK Uji Teman tersedia, lanjut pengujian **M5.3+M5.4** di Realme C11 yang disediakan. Reuse paket fixture terisolasi, jangan mencopot app pribadi atau reset HP pinjaman. Periksa storage/memori/OS/API/ABI/koneksi dan izin sebelum menuduh hardware tua sebagai penyebab bug.

Cakupan M5.3 meliputi onboarding/roles/PIN/biometrik jika ada, mode stok/biaya/promo/grosir/kemasan, pembayaran/numpad/uang cepat/kas fisik, member/piutang, receipt/retur supplier, opname, scanner fallback, reports/export, backup portable/restore/retensi/reset **fixture**. Cakupan M5.4 mengikuti matriks §12.3 dengan prioritas ketepatan uang/stok/security dan pengalaman input pada layar kecil/perangkat lambat. Hardware yang tidak ada diberi status not applicable/unverified, bukan lulus dengan mock.

Perbaiki temuan langsung. Bila akar masalah di domain/SQLCipher/PIN/shared UI/native adapter yang juga dipakai DV/Poco, jalankan **regresi terdampak**, bukan mengulang seluruh suite Android lain. Jika hanya fixture/harness Realme yang berubah, jelaskan dan uji harness itu tanpa mengklaim perubahan fitur. Jangan mengurangi entropy/KDF, membuang garansi/retur/grafik atau memotong jumlah data untuk membuat angka PASS.

Jika source app berubah, kedua APK handoff harus dibangun ulang/diuji smoke pada revisi baru, `.skybee` diupdate aman, dan APK teman lama ditandai superseded. Jika teman sudah menggunakan APK lama, siapkan update in-place dengan data mereka terjaga; jangan mengubah applicationId/signature untuk menghindari migrasi. Jangan menunggu feedback teman sebagai syarat menjalankan tes Realme.

## 15. Dokumentasi, Git dan laporan akhir

- Perbarui SPEC/PLAN/STATUS, kontrak/keputusan M5.4, skema migrasi, panduan run Android Studio, laporan acceptance dan checkpoint Realme/handoff yang jelas. M5.5 dicatat **khusus multi-device, belum dikerjakan**, bukan milestone visual lama.
- Commit/push biasa ke repository/branch/remote yang sah setelah verifikasi keadaan aktual, meneruskan workflow proyek yang telah diotorisasi. Jangan force-push/rewrite history/reset perubahan saya. Pisahkan checkpoint yang sudah teruji bila pekerjaan besar; laporan menjelaskan apakah remote benar-benar sinkron.
- Audit diff, `.gitignore`, `docs/evidence/`, `release-artifacts`. Jangan commit APK/AAB/DB/foto privat/key/secret/recovery PDF/keystore/token/log sensitif. Source, migration, fixture generator/dummy sintetis yang aman, lockfile, tes, lisensi dan laporan ringkas boleh dikirim sesuai scope. Jangan hapus massal working files demi merapikan repository.
- Laporan akhir memisahkan **implementasi selesai**, tes host/native per device, tes fisik/cetakan/Drive, handoff terpasang/belum, Realme lulus/blocked/unverified, serta isu yang tersisa. Jangan menjumlah retry seolah kasus unik atau mengklaim M5.3/M5.4 full hardware PASS dari widget mock.
- Catat versionCode/schema/source commit, APK path/hash/signing identity, package IDs, dataset seed manifest dan hasil preservasi data. Berikan langkah memulai pengujian mandiri yang singkat serta APK teman yang tepat. Rahasia/PIN tidak ditulis pada laporan publik.
- Tutup runner/kontrol otomatis yang selesai, pulihkan keadaan perangkat dan tinggalkan `.skybee` siap digunakan. Tugas selesai setelah cakupan yang diotorisasi dan pemeriksaan yang tersedia konkret; perangkat yang terhalang dicatat jelas, bukan disamarkan sebagai tuntas.

## 16. Penelusuran 35 catatan pengguna

| Nomor | Bagian kontrak |
|---|---|
|1|§4.1 tap-to-focus|
|2|§3.1 cooldown/lock persisten|
|3|§5 retur penjualan/kode struk/garansi/karantina/refund|
|4|§10.1 grafik/tabel keuntungan|
|5 + klarifikasi QRIS terakhir|§6.1 gambar dan konfirmasi manual, split payment|
|6|§8.4 foto nota|
|7|§3.3 recovery 24 kata/PDF|
|8,10,11|§7.1 form/rak/harga|
|9|§7.2 histori penerimaan|
|12,17,29,30,31|§9.1 member/history/search/restore/filter/sort|
|13,32|§4.1 pilih 1D/QR dan scan gudang|
|14|§7.6 opname manual dan scan|
|15,16|§6.2 pecahan kembalian; §6.3 pembulatan|
|18|§3.2 gate kasir/management|
|19,20,21,28|§7.3 bahasa/kategori/sort/rak|
|22|§7.5 hard delete arsip terproteksi|
|23|§10.2 bug Drive|
|24|§7.4 arsip produk|
|25,26,27|§8.1–8.3 penerimaan/draft retur/banyak supplier|
|33|§6.4 kebijakan kas dan persisted form|
|34|§4.2 routing HID/modal/Enter|
|35|§9.2 Barang Favorit|



## 17. Rujukan primer untuk memeriksa asumsi teknis

- BIP-39, entropy/checksum/wordcount: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki — **256 bit→24 kata**; entropy encoding berbeda dari mnemonic-to-seed derivation. Gunakan test vector dan wordlist resminya.
- CameraX focus/metering: https://developer.android.com/media/camera/camerax/configuration — kemampuan tergantung hardware/adapter; jangan mengasumsikan Flutter plugin menyediakan semua API native.
- Contoh resmi scanner keyboard wedge: https://techdocs.zebra.com/datawedge/latest/guide/output/keystroke/ — scanner dapat mengirim key/text/Enter; ini acuan risiko, bukan klaim semua scanner identik Zebra.
- SQLite FK: https://www.sqlite.org/foreignkeys.html — proteksi referensi harus aktif; hard delete bukan alasan memutus integritas historis.
- IAS2 synopsis: https://www.ifrs.org/issued-standards/list-of-standards/ias-2-inventories/ — bedakan biaya persediaan, HPP dan kerugian persediaan. Aplikasi tidak mengklaim laporan akuntansi/pajak tersertifikasi.

**Mulai dengan audit source/baseline dan kontrak M5.4; lanjutkan sampai implementasi, uji DV/Poco dan perbaikannya, handoff `.skybee`/APK Uji Teman, lalu pengujian Realme M5.3+M5.4 sesuai ketersediaan perangkat. M5.5 multi-device tidak dimulai sekarang.**
