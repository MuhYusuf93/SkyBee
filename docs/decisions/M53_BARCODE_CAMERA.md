# M5.3 — scanner kamera offline bersama

Implementasi tahap E mengacu [§7.1 dan matriks akses §4.1](M53_REQUEST.md).
Ini fondasi scanner yang dipakai kasir/gudang/form barang dan operasi dokumen E
berikutnya. Status penerimaan aktual ada pada checkpoint; keberadaan dokumen
tidak menyatakan kamera fisik sudah membaca barcode cetak.

- Decoder dibundel: JourneyApps Android Embedded4.3.0/core3.4.1, Java, tanpa
  model yang perlu diunduh atau Google Play services untuk scanning. MinSDK24
  proyek tetap; tidak mengubah ABI, verifier/KDF atau key instalasi. Lisensi
  Apache2 dan checksum sumber lisensi masuk aset/halaman atribusi native.
- BarcodeView ditanam pada Activity Flutter yang sama melalui PlatformView.
  Tidak membuka CaptureActivity eksternal yang terus memicu perpindahan sesi.
  Manifest menyatakan kamera/autofokus opsional; tanpa kamera/izin tetap dapat
  memakai pencarian dan scanner keyboard. Kamera eksternal yang disebut fitur
  perangkat belum membuktikan kamera tersebut terpasang atau dapat dibuka.
- Izin kamera diminta setelah tindakan pengguna, maksimal60detik. Interaksi OS
  untuk alur gudang memakai lease sistem terbatas yang sudah ada. Otorisasi
  persisten diperiksa sebelum/sesudah; tidak memberi grant Kelola atau mereset
  interval PIN. Callback izin terlambat tidak menghidupkan kembali intent lama.
- Hanya satu camera owner dalam Activity. Route tertutup, lifecycle nonaktif,
  kunci kasir/Kelola dan pergantian DB menghentikan decode. Resume tidak
  mengautentikasi atau memindai lagi otomatis. User memulai Scan again.
- `decodeSingle` dan token per arm menolak frame antrean dari arm sebelumnya.
  User meninjau satu hasil yang dipilih decoder dan mengetuk Gunakan kode;
  konfirmasi ganda hanya memproses sekali. Scan again menerima kode sama
  sebagai intent berikutnya. Tidak mengklaim deteksi semua kode dalam satu frame
  atau pembuktian bahwa satu pcs fisik tidak dipindai dua kali.
- Whitelist EAN13/EAN8/UPC/Code128/Code39/ITF/QR; teks maksimal256, karakter
  kontrol ditolak. Tidak parse menjadi integer, fuzzy lookup atau menjalankan
  URL/isi QR. Kamera tidak menyimpan/mengirim gambar atau menulis stok sendiri.
- EAN13 yang dimulai nol dan UPC-A dapat memiliki pola garis identik. Hints
  decoder mempertahankan13digit, lalu UI menawarkan pilihan12digit UPC-A secara
  eksplisit. Tidak mencopot nol diam-diam sebelum exact-match. Pilihan tidak
  menambah barang sampai dikonfirmasi dan tidak membuka konfirmasi kedua pada
  arm yang telah dikonsumsi.
- Kasir memakai lookup/CartService yang sama dengan input Enter, termasuk
  pemeriksaan kelayakan dan commit guard. Gudang memakai exact lookup dengan
  capability inventory, membuka detail atau formulir barang yang sebenarnya.
  Kode tidak dikenal menampilkan hasil visual dan bunyi bila platform mendukung;
  tidak membentuk produk kosong. Field barcode form hanya berubah di RAM sampai
  form disimpan; dirty guard tetap berlaku juga sebelum frame berikutnya.
- Controller/adapter milik route. AppServices hanya memegang factory dependency;
  test dapat mengganti transport kamera tanpa mengganti aturan SQL/otorisasi.
  Preview form gudang ikut ManagementGate di route sendiri. Hasil/camera key
  tidak menjadi akses aktif setelah restore atau di perangkat lain.

Sumber teknis yang diperiksa:
[README release4.3.0](https://github.com/journeyapps/zxing-android-embedded/blob/v4.3.0/README.md),
[embedding/lifecycle](https://github.com/journeyapps/zxing-android-embedded/blob/v4.3.0/EMBEDDING.md),
[ZXing konversi UPC/EAN](https://github.com/zxing/zxing/blob/zxing-3.4.1/core/src/main/java/com/google/zxing/oned/MultiFormatUPCEANReader.java),
[Flutter Platform Views](https://docs.flutter.dev/platform-integration/android/platform-views).

Uji transport sintetis, decode gambar yang dibuat fixture, API ketersediaan,
preview kamera dan pembacaan barcode fisik adalah bukti berbeda. Jangan mengubah
hasil sintetis menjadi klaim uji kamera fisik atau mematikan aplikasi CCTV untuk
membuat pemeriksaan lulus. Audio juga bersifat best effort dengan fallback visual.
