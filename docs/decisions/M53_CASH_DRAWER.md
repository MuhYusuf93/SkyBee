# M5.3 — jurnal kas fisik dan batas audit

Kontrak aktif: [§5.3/§9.3](M53_REQUEST.md). Schema24 aditif; toko lama
default nonaktif. Tidak menebak metode atau jumlah lembar pembayaran lama.
Pemakaian dan bukti akhir mengikuti checkpoint/laporan, bukan keberadaan file ini.

- Mode nonaktif mempertahankan numpad dan nominal cepat. Catatan kasir dapat
  dinyalakan kasir. Audit wajib diatur pemilik dengan PIN baru untuk tindakan
  tersebut; kasir dan gudang tidak dapat menonaktifkannya. Ganti mode memerlukan
  semua sesi terbuka ditutup, termasuk sesi hari sebelumnya. Riwayat tetap ada.
- Setiap sesi menyimpan tanggal/zona toko, currency/scale, nomor sesi dan mode.
  Pembukaan harus menyatakan hitungan termasuk nol, atau unknown dengan alasan.
  Unknown memakai batas bawah pecahan tercatat, bukan klaim saldo awal nol.
  Sesi baru tidak menyalin saldo lama; hari berganti tidak menutup/menghapus sesi.
  Sesi berikut pada hari sama memerlukan alasan. Jam mundur ditolak.
- Hitungan memakai integer minor dan jumlah 0–1.000.000 per pecahan, katalog
  terbatas, JSON kanonis maksimal16KiB. IDR scale0, USD/MYR/EUR scale2. Katalog
  adalah nominal yang didukung editor; bukan sensor atau jaminan keaslian uang.
  Nominal cepat arbitrer lama tetap tersimpan tanpa dilabeli komposisi fisik valid.
- Saat pencatatan aktif, service dan UI menolak tender manual/Uang pas tanpa
  komposisi lengkap. Editor menghitung lembar/koin langsung, termasuk koreksi.
  Kembalian harus tepat, tidak dibulatkan. Tidak ada debit laci dari draft.
  Saldo pecahan keluar tidak boleh negatif; kekurangan diperbaiki dengan rincian
  benar atau hitung ulang beralasan yang menambah fakta rekonsiliasi.
- Pembayaran tagihan, uang diserahkan, kembalian dan piutang tetap terpisah.
  Rp95.000 masuk dan Rp2.000 kembali membayar Rp93.000. Payment, tender, jurnal,
  saldo, stok, allocation dan completed draft memakai transaksi/idempotency yang
  sama. Fingerprint baru kondisional; retry lama tanpa metadata tidak berubah.
- Pelunasan menyimpan sumber tunai atau luar laci secara eksplisit; tidak menambah
  penjualan/HPP/kunjungan. Refund menyatakan pecahan yang benar-benar keluar untuk
  nilai pembayaran yang dibatalkan, bukan membalik pecahan tender lama. Dana luar
  laci tidak mengubah laci. Ini klasifikasi, tanpa integrasi transfer/QRIS baru.
  Posting pembayaran supplier dari laci mengikuti kontrak E dalam transaksi
  pembayaran supplier; tidak melalui jurnal manual kedua.
- Kas masuk nonpenjualan, kas keluar, penyerahan/setoran dan recount menyimpan
  alasan serta jejak immutable. Penutupan memerlukan count fisik yang dinyatakan;
  beda komposisi walaupun total sama juga memerlukan alasan. Selisih nilai hanya
  dihitung jika saldo diharapkan diketahui. Tidak mengubah omzet atau menuduh
  pencurian. Penutupan sesi terlewat oleh pemilik memakai PIN baru, alasan dan
  count/difference NULL; tidak mengaku hitungan hari ini sebagai hitungan dahulu.
- Kasir membaca histori mode catatan, termasuk setelah dimatikan. Pemilik dapat
  membaca seluruh histori dan tender/kembalian pada detail penjualan, termasuk
  penjualan dibatalkan. Gudang tidak memperoleh akses audit. Service memeriksa
  otorisasi sebelum/sesudah pembacaan dan sebelum commit. Halaman sesi/jurnal
  memakai keyset25+1, index/tie-breaker BINARY konsisten, cache layar maksimum75.
  Saldo25 sesi dibaca satu batch terbatas, tanpa dua panggilan SQL per baris.
- Editor hanya membawa intent; FormExitGuard membaca dirty terkini juga sebelum
  frame berikutnya. Back di layar kunci tetap menawarkan tetap terkunci atau
  buang perubahan, tanpa memperlihatkan isian. Save menyelesaikan route miliknya
  sendiri sehingga callback tertunda tidak menghapus route kunci.
- Backup memeriksa tipe/panjang sebelum membaca JSON, lalu replay per sesi secara
  bounded. Saldo/knowledge/revision, sequence, closure, referensi sumber,
  provenance pembayaran baru dan kesamaan draft selesai–tender harus sesuai.
  Legacy payment/sale versi0 tidak diberi provenance baru. Restore portable penuh
  lintas key dan seluruh data baru tetap bagian G.

Referensi katalog yang diperiksa: [BI uang kertas TE2022](https://www.bi.go.id/id/publikasi/ruang-media/news-release/Pages/sp_2421922.aspx),
[BI Rp75.000](https://peraturan.go.id/files/pbi11-2020.pdf),
[BNM banknotes](https://www.bnm.gov.my/currency/banknotes),
[US Currency denominations](https://www.uscurrency.gov/denominations),
[ECB banknotes](https://www.ecb.europa.eu/euro/banknotes/html/index.en.html).
Katalog menghimpun nominal, bukan memisahkan seri/desain uang. Nominal historis
tidak diklaim sebagai pecahan yang sedang diterbitkan atau lazim tersedia.
