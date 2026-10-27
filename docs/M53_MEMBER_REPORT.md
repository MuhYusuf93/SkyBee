# M5.3 — member schema 22, pemeriksaan aktif

Final acceptance 20 PASS (1:46): SQL13/UI6/migrasi1, termasuk paid legacy dan
persistensi opt-in terpisah. Regresi 79 PASS (1:34), analyzer bersih 7,2 detik,
format399/0changed, l10n845/561/245. Source485 file identik pada DV/Poco.
DV20 PASS7:10, Poco20 PASS4:48; semua642/587 hash lama cocok/controlOff,
DV awake restored/readback exact. Belum update/reset .skybee+12/14.

Baseline source tender `4de1442` sudah dipush. Source +12/schema 22 belum dirilis
atau dipasang pada Paket Eksplorasi Mandiri (+12/schema 14). [Aturan](decisions/M53_MEMBERS.md).

Service/profil member, migrasi metadata legacy, lookup kasir, owner CRUD/arsip,
paid opt-in, kredit wajib member, cache kunjungan dan validasi cadangan tersedia
di source. Checkout memakai dirty callback untuk autosave yang belum durable.
Native 22 selesai pada batas di atas; build ordinary/release final dan handoff
M5.3 masih H. Semua wrapper sudah ditutup.

Domain awal 6 PASS/3 FAIL (36 detik): helper membuka keranjang yang sudah selesai
tanpa acknowledgement `cart.next`; guard aplikasi dipertahankan, helper diperbaiki.
Retest 8 PASS/1 FAIL (32 detik): fixture mencoba membatalkan sale dengan pelunasan
aktif yang memang ditolak aturan koreksi. Kasus kini membatalkan sale lunas lain,
tetap memeriksa kunjungan dan pelunasan. Tidak melemahkan guard atau menghapus tes.
Satu invocation tambahan gagal compile karena scope helper manifest; diperbaiki.

Domain 11 PASS (41 detik) mencakup migrasi 21→22 dengan kegagalan/rollback, audit
seluruh nilai lama, legacy kosong/invalid/duplikat tetap bisa dilunasi, fingerprint
retry lama, snapshot, akses, CAS, arsip, visits dan forged backup metadata.
Sesudahnya ditambah kasus paid selection profil legacy, sehingga target domain
menjadi 12. Regresi tender SQL 11 PASS (24 detik) pada source 22 awal.

UI awal 3 PASS/3 FAIL (2:19): paid create, credit lookup dan dirty owner Back lulus;
helper pending-save memakai BuildContext layar kunci yang telah di-dispose setelah
unlock, dan dua layout helper menunggu row lazy sebelum menggulir. Helper diperbaiki
dengan label lokal yang sudah dibaca dan readiness/loading lalu scroll; assertion
preservasi/dirty/layout tetap. Acceptance gabungan 19 lalu20 kasus PASS.

Analyzer awal 7 warning/info (267,7 detik), tanpa error; pembersihan/final analyze
kemudian 5 warning/info (124,8 detik), telah dirapikan; final bersih 7,2 detik.
L10n memuat 25 pesan member tambahan; audit final 845/561/245 PASS.
Member/pencarian C dan D–H tetap aktif; ini bukan klaim seluruh M5.3 selesai.

Regresi pertama melaporkan69 PASS/5 FAIL lalu tertahan pada cleanup fixture UI
setelah failure, sehingga tidak ada completion suite. Hanya process host milik
runner tersebut dihentikan; tidak ada native/device mutation. Cleanup kini berada
di body-finally memakai pumped IO. Tiga fixture lama disesuaikan dengan phone
wajib/unik; urutan validasi menampilkan tender kosong lebih dahulu. Helper reveal
memilih scroll vertikal pada route aktif, dengan langkah programmatic terbatas;
ini bukti layout/selection, bukan gesture fisik. Focused paid UI1 PASS9s, lalu
regresi79 PASS1:34. Log failure/interruption tetap privat, tidak dihapus.

[Validasi terkurasi](evidence/m53-20261026/member-validation.json) dan
[source checksum](evidence/m53-20261026/member-source-sha256.json) tersedia.
Native widget input dan programmatic reveal bukan bukti gesture fisik/IME OEM.
Pencarian produk/popularitas C, D–H dan restore seluruh tambahan akhir masih aktif.
