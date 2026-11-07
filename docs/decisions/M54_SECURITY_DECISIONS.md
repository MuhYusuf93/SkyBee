# M5.4 — keputusan keamanan dan kompatibilitas

Kontrak: [M54_REQUEST](M54_REQUEST.md). Ini keputusan implementasi, bukan klaim
seluruh acceptance/hardware/handoff sudah lulus.

## Target akses dan percobaan

Schema38 menambah dua baris `employee_access_attempts`: `cashier` dan `warehouse`.
Baris tetap ada saat kebijakan kasir dimatikan, sumber PIN diganti, PIN dirotasi,
atau pola tugas berubah. Verifikasi pemilik langsung tetap memakai proteksi
kredensial pemilik; PIN referensi pada gate Kasir memakai counter target Kasir.
Referensi sukses boleh menaikkan witness jam pemilik, tanpa memperbarui tanggal
verifikasi PIN72jam atau counter pemilik.

Percobaan3/4 menunggu60detik; percobaan5/6/7 menunggu300detik;8 hard lock.
Cooldown kedaluwarsa hanya menghapus deadline. Benar sebelum hard lock mereset
counter target. Setelah hard lock PIN benar tidak menjalankan KDF/membuka gate.
Verifikasi/penulisan hasil berada pada transaksi terurut; error dikembalikan
sesudah commit sehingga penolakan tidak me-rollback hitungan.

Selama proses hidup, cooldown memakai clock monotonik; deadline/high-water wall
tersimpan untuk restart. Jam mundur memerlukan tunggu konservatif. Manipulasi
jam maju melintasi reboot oleh administrator tidak dapat dibuktikan dengan
clock lokal saja; jangan mengklaim anti-root atau waktu tepercaya dari server.

Pemilik membuka target tertentu melalui Pengamanan, PIN pemilik fresh untuk
purpose `security`, one-use claim yang diperiksa dalam SQL, dan audit tanpa
secret. Epoch Kelola dan Kasir dicabut; sesi lama tidak dihidupkan kembali.
Rotasi PIN sendiri tidak dianggap tindakan buka blokir.

## Restore dan migrasi

Migrasi37→38 aditif, tanpa mengganti verifier, PIN, key, biometrik, atau fakta
bisnis. Counter lama dipertahankan secara konservatif; untuk referensi Kasir
lama yang dahulu berbagi counter pemilik digunakan maksimum counter lama.
Pemilik tidak mendapat hard lock karyawan. Fingerprint versi kredensial baru
mencatat verifier yang benar-benar diperiksa, bukan PIN atau recovery plaintext.

Backup membawa counter. Restore toko yang sama mengambil maksimum counter dan
deadline lokal/arsip di bawah lease penggantian DB, sebelum promotion. Toko
berbeda mempertahankan counter miliknya sendiri. Sesi/capability proses lama
tidak dipindahkan. Restore arsip lama pada instalasi lain bukan bukti bahwa
percobaan setelah tanggal arsip dapat diketahui tanpa state tepercaya tambahan.

## Dua recovery yang memang berbeda

- Kunci cadangan: secret256bit/64hex `backup-master-v1`. Representasi baru
  BIP39English24kata mengembalikan **32byte yang persis sama**; tidak menggunakan
  mnemonicToSeed, tidak rekey/merotasi, tidak mengubah HKDF/AEAD arsip lama.
- Pemulihan PIN existing: secret lain32hex dari `PinHasher.recoveryCode`, dengan
  verifier tersalt pada kredensial toko. Tidak dipanjangkan/diganti menjadi
  kunci cadangan secara diam-diam. Reset PIN pemilik existing memerlukan secret
  yang benar; sesudah itu pemilik dapat melakukan tindakan buka blokir target.
- Format24kata/QR yang valid saja tidak memberikan capability. Tidak ada jalan
  baru menerima kunci cadangan berformat benar sebagai PIN/recovery pemilik.
  Recovery PDF, scan recovery khusus dan pembuktian lintas toko end-to-end masih
  mengikuti checkpoint/matriks aktif; codec saja bukan implementasi seluruhnya.

Wordlist resmi tetap English: SHA256 upstream
`2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda`.
[BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki),
[wordlist](https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt),
[vektor independen](https://github.com/trezor/python-mnemonic/blob/master/vectors.json).
Lisensi dibundel di `assets/third_party/BIP39-LICENSE.txt`. QR memakai namespace
`SKYBEE:RECOVERY:1:<storeUuid>:<entropyHex>`. Lookup produk dan kamera bisnis
menolaknya sebelum menawarkan pendaftaran produk/menampilkan payload.

## Input dan prioritas route

Input PIN tidak dipotong/digit-stripped. commitText dan burst panjang tetap
utuh dan invalid. Auto-submit empat digit menunggu settling200ms; ini heuristik
untuk menghindari prefix burst, bukan identifikasi scanner. Scanner empat digit
atau input pelan dapat sama dengan input manusia dan tetap dihitung sebagai
percobaan autentikasi. Tidak ada pengecualian counter berdasarkan sumber input.

Registry route menentukan gate yang perlu ditampilkan, tanpa memberi akses.
Kelola memakai gate Kelola, Kasir tetap terkunci sampai benar-benar dikunjungi
dan diverifikasi. Dirty draft tetap dimiliki route asal. Back dan sesi grace
tetap memakai use case existing, bukan menghapus lock global untuk menyembunyikan
dialog. Bukti widget memakai input/OS sintetis; bukan keyboard OEM atau reboot.

## Kebijakan toko dan sesi kas (§6.4)

Raw `cash_drawer_policy.mode` adalah preferensi pemilik untuk sesi berikutnya.
Mode sesi fisik yang sudah terbuka immutable. Buka sukarela di bawah Nonaktif
membuat sesi Notes tanpa mengubah preferensi itu. Tanpa sesi terbuka, Notes
legacy juga tidak menciptakan catatan fisik fiktif. Audit tanpa sesi tetap
menuntut sesi/pecahan sebelum pembayaran tunai yang perlu dicatat.

Transisi yang dipilih adalah **berlaku mulai sesi berikutnya**, dengan konfirmasi
eksplisit sebelum autentikasi pemilik. Tidak merekonstruksi saldo awal atau
menaikkan mode sesi berjalan. Penutupan biasa tetap memakai deklarasi hitungan
fisik kasir; pengecualian penutupan lama tetap membutuhkan fresh owner proof.
Tidak menambahkan kewajiban owner PIN baru pada semua penutupan normal.

Revision kebijakan juga dinaikkan di transaksi open/close. Form yang dibuka
sebelum perubahan lifecycle ditolak saat commit, walaupun nilai mode sama.
Retry idempotent tidak menaikkan revision lagi. Raw preferensi dan sesi dibaca
ulang di service; widget tidak membuka SQL. Semua cash writer (sale, piutang,
refund dan supplier) mengikuti mode sesi aktual. Intent dengan ID sesi lama
ditolak, bukan diam-diam berubah menjadi pembayaran tanpa pencatatan.

Validator backup memeriksa mode/replay masing-masing sesi; kesamaan mode sesi
dengan raw preferensi bukan invariant lagi. Fakta historis, saldo unknown dan
selisih nullable tetap dipertahankan. Tidak perlu tabel baru untuk pemisahan ini.
