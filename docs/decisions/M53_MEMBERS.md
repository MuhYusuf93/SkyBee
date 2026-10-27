# M5.3 — member, identitas stabil dan kunjungan

Kontrak: [§6](M53_REQUEST.md). Source schema 22 sedang diperiksa; laporan dan
checkpoint menentukan status bukti, bukan keberadaan rancangan ini.

- Member memakai primary key `customers.id` yang lama. Nama sama tidak berarti
  orang yang sama. Nomor baru/edit wajib valid dan unik; normalisasi menggunakan
  `phone_region` toko atau kode internasional eksplisit, terpisah dari bahasa dan
  currency. Format nasional dan E164 yang menunjuk nomor sama dianggap duplikat.
- Migrasi membaca 100 baris per halaman dengan keyset BINARY dan hanya mengisi
  kolom metadata baru. Nomor mentah, ID, transaksi, snapshot dan utang lama tidak
  ditulis ulang. Nomor kosong/invalid mendapat metadata null, duplikat dipertahankan
  pada ID masing-masing. Indeks nonunique menghindari kegagalan upgrade.
- `profile_version=0` menandai data legacy; penulisan profil tervalidasi memakai
  versi 1. Service dan trigger melindungi penulisan baru dari collision. Data
  legacy tetap dapat dilunasi dan dipilih secara eksplisit untuk penjualan lunas.
  Utang baru memerlukan profil aktif dengan nomor valid dan unik; profil yang
  perlu diperbaiki diarahkan ke pemilik, tanpa penggabungan otomatis.
- Penjualan lunas default tanpa member. Checkbox mengaktifkan pilihan/pembuatan
  member; penjualan utang selalu memakai member. Pembuatan dari checkout berada
  dalam transaksi yang sama dengan sale, stok, pembayaran dan draft selesai.
  Gagal checkout tidak meninggalkan profil baru separuh tersimpan.
- Flag intent tambahan dan alamat draft bersifat aditif. Fingerprint baru untuk
  opt-in member mencakup identitas/input yang relevan; intent lama/default false
  mempertahankan fingerprint asli. Retry penjualan lama dibaca sebelum validasi
  profil baru. Snapshot nama/nomor sale tidak mengikuti perubahan profil kemudian.
- Pilihan paid-member (`member_opt_in`) tersimpan terpisah dari intent efektif
  member yang wajib ketika utang. Membuka ulang draft utang tidak menebak pilihan
  checkbox dari nominal; pilihan eksplisit tetap. Flag tampilan ini tidak mengubah
  fingerprint finansial bila intent dan data transaksi tetap sama.
- Alamat opsional tersimpan pada profil/draft, tidak otomatis menambah data pribadi
  pada struk. Tidak ada SMS, OTP, akses kontak atau pengiriman data tambahan.
- CRUD, arsip, pulihkan dan daftar administrasi hanya pemilik, dengan pengecekan
  capability sebelum/sesudah SQL, CAS revision, dan audit tanpa isi data pribadi.
  Lookup kasir terikat draft checkout aktif dan tidak memberikan authority Kelola.
- Arsip menghilangkan pilihan untuk penjualan baru, mempertahankan sejarah dan
  tetap menampilkan utang yang belum lunas pada pelunasan. Nomor profil arsip
  tetap terikat untuk mencegah reuse identitas yang ambigu; pemilik dapat
  memulihkan/memperbaiki profil secara eksplisit.
- `visit_count` adalah cache turunan jumlah header sale selesai yang belum
  dibatalkan, bukan jumlah item atau pembayaran. Backfill SQL dan trigger sale/
  reversal memperbaruinya dalam transaksi yang sama. Model reversal proyek saat
  ini membatalkan satu sale penuh; tidak menambah modul refund pelanggan baru.
  Pelunasan bukan kunjungan baru. Cache dapat dihitung ulang dari fakta sumber.
- Pencarian nama/nomor dan daftar memakai SQL, indeks dan keyset yang mengikuti
  urutan kunjungan turun, nama ternormalisasi BINARY, lalu ID BINARY. Cursor terikat
  query/scope/generation/revision. Form kasir mempertahankan debounce dan menolak
  hasil pencarian lama. Layar pemilik hanya menyimpan satu halaman profil.
- Restore memeriksa tipe/panjang sebelum mengambil data, normalisasi metadata,
  uniqueness profil tervalidasi serta cache kunjungan terhadap fakta penjualan.
  Legacy invalid/duplicate tetap valid sebagai arsip yang harus dipertahankan.

Checkout membandingkan input saat ini dengan snapshot terakhir yang benar-benar
berhasil disimpan. Autosave antre/gagal saat lock tetap dirty; keberhasilan save
lama tidak menandai input baru sebagai tersimpan. Registry membaca callback bool
terkini meski frame lock mendahului rebuild. Back normal/terkunci memperingatkan
perubahan RAM tersebut; input yang sudah durable tidak mendapat warning palsu.
Pilihan tetap terkunci mempertahankan RAM, unlock mengizinkan retry, dan buang
stack mempertahankan keranjang serta tender terakhir yang sudah durable.
