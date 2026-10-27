# M5.3 — intent tender dan nominal cepat

Kontrak: [§5.2 dan §5.3](M53_REQUEST.md). Ini bagian C; jurnal laci dan audit
wajib pada D tetap harus diselesaikan sebelum handoff akhir.

- `TenderSnapshot` immutable menyimpan nominal mentah, asal input, aturan digit
  berikutnya, jumlah pecahan, dan nominal tanpa rincian. Penyimpanan/restore tidak
  menebak pecahan dari nominal manual atau tombol Uang pas. Perpindahan tampilan
  numpad/pecahan tidak mengubah uang atau rincian.
- Pecahan menambah jumlah dan nominal; minus hanya mengurangi pecahan yang telah
  dinyatakan. Bersihkan mengosongkan tender pada kedua tampilan, mempertahankan
  keranjang dan pelanggan. Uang pas/preset mengganti nominal; digit pertama
  berikutnya mengganti hasil preset. Backspace menyunting nominal dan mengakhiri
  status preset. Tombol `000` mengisi maksimal presisi currency ketika sudah ada
  separator desimal; IDR tetap integer. Semua hitungan memakai integer minor unit.
- Numpad manual mengakhiri rincian pecahan terdahulu dan menandai nominal tanpa
  rincian. Menambah pecahan setelah nominal manual menghasilkan komposisi campuran
  dengan bagian tanpa rincian tetap terlihat. Ini deklarasi kasir, bukan sensor.
- Schema 21 menambah JSON nullable pada draft dan tender checkout. `NULL` berarti
  data lama tanpa rincian, tanpa rewrite histori. Raw input yang valid dipertahankan
  juga pada draft selesai, termasuk nol awal dan desimal yang belum dipanjangkan.
- Fingerprint versi baru mencakup rincian finansial, bukan pilihan tampilan atau
  asal kosmetik. Retry lama tanpa metadata tetap memakai payload `cash-v1` asli.
  Sale, tender, payment, stok, dan completed draft berada dalam transaksi yang
  sama; kegagalan tidak meninggalkan rincian tender atau mutasi separuh tersimpan.
- Restore memeriksa tipe/panjang sebelum mengambil JSON, membaca halaman terbatas
  dengan urutan primary key, memvalidasi bentuk/nilai/overflow serta kesesuaian
  nominal dan snapshot draft selesai–tender. Arsip yang kehilangan constraint atau
  trigger tetap diperiksa. Histori lama tidak diberi klaim rincian fisik.
- Nominal cepat tersedia dari checkout tanpa PIN Kelola. Use case publik hanya
  mengubah daftar currency toko saat ini dan menulis audit kasir, mengikuti kunci
  kasir jika diaktifkan. Input baru wajib positif, unik, dan 1–8 nominal. Mengubah
  daftar tidak mengubah pecahan yang sudah dimasukkan ke tender terbuka.
- Form nominal cepat mendaftarkan dirty boolean untuk Back Kunci Kasir. Registry
  Kelola tetap hanya menghitung formulir terlindungi. Warning generik tidak
  menampilkan isian; tetap terkunci atau buang stack ke Kasir sesuai klarifikasi
  pengguna, tanpa memberi authority Kelola atau menghapus tender tersimpan.

Audit wajib D harus menolak nominal tanpa rincian pada service, termasuk jalan
pintas Uang pas, dan memvalidasi rincian kembalian serta mutasi laci. Implementasi
tender C ini sendiri belum menyatakan jurnal laci atau audit wajib selesai.
