# Klarifikasi Back saat terkunci — 26 Oktober 2026

Instruksi langsung pengguna: bila Back pada layar terkunci dan form telah
berubah, tetap tampilkan peringatan perubahan seperti sebelum terkunci.
Ini menggantikan keputusan checkpoint awal yang membuang unsigned draft tanpa
dialog pada security exit. Cakupan M5.3 tetap; tidak mengubah fakta bisnis.

- Belum ada perubahan: cabut sesi dan kembali ke Kasir, menutup stack pengelolaan.
- Ada perubahan: tampilkan peringatan generik tanpa nilai form/data terlindungi.
  Pilihan tetap di layar terkunci mempertahankan form dalam memori, tanpa grant
  capability; melanjutkan edit memerlukan autentikasi yang sesuai.
- Pilihan buang perubahan dan kembali ke Kasir menutup seluruh stack pengelolaan
  tanpa commit. Route Kasir, cart dan tender draft yang sudah ada dipertahankan.
- Berlaku pada Back HP/AppBar, gate pengelolaan dan Back dari PIN bertingkat.
  Keluar dari dialog terlindungi yang sudah terkunci mengikuti aturan yang sama.
- Registry hanya membawa flag dirty per lifecycle route, bukan nilai form/PIN;
  form unregister saat dispose dan satu navigator hanya mempunyai satu prompt.
- Form publik mengikuti kebijakan keluar sebelumnya. Tidak menawarkan simpan
  dari sesi terkunci atau membocorkan isi form lewat teks peringatan.

Tes harus membuktikan tetap terkunci setelah batal keluar, prompt dari gate dan
PIN, tidak ada frame data owner setelah autentikasi Gudang, SQL form tidak berubah,
serta keranjang tetap tanpa sale baru setelah buang. Bukti sintetis dibedakan
dari sentuhan fisik OEM. Hasil aktual mengikuti checkpoint/hasil runner terbaru.
