# Scanner kamera / Camera scanner — M5.3

Panduan source M5.3 yang sedang diperiksa. Status APK eksplorasi dan batas
pengujian selalu mengikuti [checkpoint](M53_CHECKPOINT.md).

## Indonesia

1. Ketuk ikon kamera pada pencarian kasir, toolbar gudang atau field barcode
   barang. Ketuk **Mulai kamera**; izinkan kamera jika dialog Android muncul.
   Jika kamera/izin tidak tersedia, kembali ke input manual atau scanner eksternal.
2. Arahkan satu barcode. Tinjau teks yang tampil, lalu ketuk **Gunakan kode**.
   Di kasir ini menambah satu pcs ke keranjang, tanpa memotong stok. Di gudang
   kode membuka detail; di formulir kode hanya diisi sampai formulir disimpan.
3. Ketuk **Pindai lagi** untuk barang berikutnya, termasuk kode yang sama.
   Kamera berhenti setelah satu hasil. Barcode jenis produk bukan serial unik;
   aplikasi tidak dapat membuktikan satu barang fisik tidak dihitung dua kali.
4. Jika tersedia pilihan EAN-13/UPC-A, pilih teks yang sama dengan data barang.
   Bentuk13digit dengan nol awal tetap ditampilkan; bentuk12digit memerlukan
   pilihan Anda. Kode tidak dikenal tidak menjadi produk baru otomatis. Gudang
   dapat membuka formulir pendaftaran barang yang sebenarnya.
5. Saat layar/app terkunci, berganti route atau berada di background, pemindaian
   berhenti. Buka akses yang sesuai lalu mulai lagi. Ini tidak menghapus keranjang
   atau formulir. Penggantian data toko memerlukan layar scanner dibuka ulang.
6. Format yang didukung: EAN-13, EAN-8, UPC, Code128, Code39, ITF dan QR. Isi QR
   dipakai sebagai teks lookup; aplikasi tidak membuka URL dari hasil scanner.
   Bunyi bergantung perangkat; pesan hasil selalu tampil. Tidak ada foto disimpan
   atau model decoder yang perlu diunduh untuk scanner ini.

## English

1. Tap the camera icon in cashier search, the inventory toolbar or a product's
   barcode field. Tap **Start camera** and allow camera access if Android asks.
   When camera access is unavailable, return to manual entry or an external scanner.
2. Aim at one barcode, review the selected text and tap **Use code**. Cashier
   adds one base item to the cart without deducting stock. Inventory opens its
   details; a product form only fills the code until the form is saved.
3. Tap **Scan again** for the next item, including the same code. Scanning stops
   after one result. A product barcode is not a unique item serial; the app cannot
   prove that a physical item has not been counted twice.
4. When EAN-13/UPC-A choices appear, select the exact text stored for the product.
   The13digit form keeps its initial zero; the12digit form requires your choice.
   Unknown codes never create empty products automatically. Inventory can open
   the real product registration form.
5. Locking, covering the scanner or backgrounding the app pauses scanning. Reopen
   the appropriate access and start again. Your cart and form remain available.
   Replacing store data requires closing and reopening the scanner.
6. Supported formats: EAN-13, EAN-8, UPC, Code128, Code39, ITF and QR. QR contents
   are literal lookup text; the scanner does not open decoded URLs. Sound is
   device dependent and a visible result is always provided. The scanner stores
   no photos and needs no decoder-model download.

Pada DV8910 yang diperiksa, API native melaporkan0kamera saat run kamera awal;
fitur Android kamera eksternal bukan bukti kamera terpasang. Uji decoder dengan
gambar sintetis dan uji route dengan transport sintetis tidak sama dengan
membaca barcode cetak melalui kamera fisik. Bukti aktual tercatat pada laporan.
