# Kunci Kasir opsional M5.3

Source20; kunci default nonaktif untuk toko lama/baru. Pemilik mengatur melalui
Keamanan dengan PIN owner fresh/CAS. Own PIN memakai salt32B dan verifier32B,
PBKDF2-HMAC-SHA256600k yang sama; tidak ada PIN plaintext dalam policy/draft.
Pilihan lain merujuk verifier owner, tanpa mencoba PIN Gudang atau semua role.
Verifikasi untuk Kasir tidak pernah grant Kelola/fresh owner, tidak mengubah
last_pin_verified_at owner. High-water clock boleh maju untuk mendeteksi rollback,
bukan mereset interval72jam. Audit verifikasi modecashier/actor_roleNULL tidak
mengarang identitas individu. PIN salah/lockout tetap dipersistenkan dan tidak
hilang pada restart/rollback jam; parameter crypto tidak diturunkan.

Grant Kasir hanya RAM, terikat issuer/generation DB/config/gate/access epoch dan
credential. Manual lock menutup lokal seketika dan menaikkan epoch persisten;
KDF yang tertinggal tidak dapat menghidupkan grant baru. Klaim operasi diperiksa
sebelum dan sesudah seluruh SQL, dengan nonce sync diperiksa lagi sesudah epoch
read terakhir. Cart mutator/checkout/pelunasan menolak dependency yang hilang
ketika policy aktif; gagal/relock menggulung satu transaksi. Cart open/recovery
boleh memuat draft di balik route kunci, tidak mengurangi stok/menciptakan sale.
Receipt/print sesudah commit mempertahankan boundary lama.

Root NavigatorObserver menjaga route opaque tanpa transisi di atas semua alur.
Route/controller keranjang dan tender tetap hidup. Callback terlambat yang
mendorong route lain tidak dapat menutup gate; route terlindungi tetap membutuhkan
capability owner/gudang sesudah Kasir dibuka. Back HP dan tombol atas memakai
peringatan generic untuk protected dirty form sesuai koreksi pengguna. Stay tetap
locked; discard menghapus stack di bawah route kunci sambil mempertahankan root
Kasir, tanpa menampilkan nilai form atau melakukan commit. Generic warning route
yang dibuat gate sendiri boleh tampil; bukan flag UI yang memberi akses.

Owner recovery adalah aksi inline eksplisit untuk menonaktifkan gate dengan
consent dan PIN owner; authority owner dicabut pada finally termasuk failure.
Normal settings memakai alur fresh PIN yang ada. Snapshot policy dipublikasikan
langsung dari hasil transaksi yang sudah commit, bukan policy lama ketika gate
baru muncul. State UI hanya membaca snapshot; tidak dapat menulis bool grant.
Lock screen PIN obscure/show-reset-inactive, redaction background dan native
protectedScreen scope yang dilepas saat dispose; tidak ada clipboard/OS enrollment.

Automatic screen lock membaca keyguard/noninteractive serta generation SCREEN_OFF
Android. App inactive/permission/notification/switch sendiri bukan pemicu; tidak
ada ignore-lifecycle flag. Batas [PowerManager.isInteractive](https://developer.android.com/reference/android/os/PowerManager#isInteractive())
berbeda dari panel light/proximity. Properti interactive ditambahkan tanpa mengubah
semantik locked biometrik yang sudah ada. Bila deteksi OS tidak tersedia, tampilkan
manual fallback, tetap verifikasi PIN manual; jangan membuat loop PIN. Native test
API hanya membuktikan bentuk nilai pada perangkat, bukan pengalaman tombol layar
fisik/OEM. Synthetic lifecycle/generation tests dinyatakan sebagai synthetic.

Backup hanya membawa policy/verifier, tidak grant; validasi panjang/type/KDF dan
missing verifier menolak archive rusak. Restore/replacement/newservice mulai locked
bila enabled. Role/warehouse serta seluruh portable tambahan masih audit G.
Quick-cash public save dan pecahan/tender/member/search merupakan C/D berikutnya,
bukan kemampuan yang diklaim sudah diselesaikan checkpoint ini.
