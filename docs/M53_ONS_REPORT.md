# E — ons dan locale metadata (checkpoint M5.3)

Source0.5.2+12/schema25, setelah checkpoint scanner e1100f5. Bagian E
gudang/dokumen/supplier dan F–H tetap aktif. Ini bukan handoff akhir aplikasi.

Implementasi mengikuti [keputusan ons/locale](decisions/M53_ONS_LOCALE.md).
Metadata ons disimpan aditif tanpa konversi stok, harga atau HPP. Parser memakai
locale UI terpisah currency; form mengonversi tanda desimal saat ganti bahasa
dan baseline kanonis tetap. Snapshot sale lama immutable. Public DTO, draft,
receipt viewer, ekspor inventory dan staged backup memakai representasi ons.

Pengujian host final31 PASS59s mencakup ons SQL4/UI2, metadata lama, backup
forgery, codec uang dan currency SQL. Tambahan live-locale uang1 PASS5s mencakup
partial decimal/composing/cursor; pelunasan stale-balance1 PASS10s. Formatter448
berkas/0 perubahan; analyzer bersih5,9s; l10n947keys/637refs/245RIDs; PIN audit
106upstream files/license identik. [Bukti host](evidence/m53-20261026/ons-host-validation.json).

Riwayat kegagalan tetap dicatat: awal25PASS3FAIL2:05 (dua fixture snapshot
tanpa item, satu member fixture tanpa nomor dan cleanup setelah abort); retest
SQL4PASS dengan2UI loadfail karena await APIvoid; UI1PASS1FAIL8s menemukan bug
MoneyField saat build. Perubahan menunda codec/teks secara atomik sampai build
selesai, menjaga revision/controller/composing; UI2PASS6s sesudah perbaikan.
Fixture pelunasan lama kemudian1PASS1FAIL52s karena melewati route deklarasi
sumber pembayaran yang diwajibkan D24; mengikuti alur aktual menghasilkan
1PASS10s tanpa mengurangi assertion stale-debt. Filter locale yang tidak cocok
tidak dihitung PASS; exact-name retest1PASS5s.

Native6 kasus DV PASS2:04/Poco PASS1:19; seluruh724/655 hash berkas terlindungi
lama cocok. Kedua wrapper exit0/controlOff, awake DV dipulihkan tepat. Source544
identik sebelum/sesudah kedua run. [DV](evidence/m53-20261026/ons-dv.json),
[Poco](evidence/m53-20261026/ons-poco.json),
[checksum source](evidence/m53-20261026/ons-source-sha256.json).
Paket eksplorasi .skybee+12/schema14 belum diperbarui/reset pada checkpoint ini.
Portable recovery seluruh penambahan tetap checkpoint G; pemasangan in-place H.

Panduan singkat: pilih ons (100 g) pada detail opsional berat/volume. ID menerima
misalnya1,25; EN1.25, maksimal tiga desimal tanpa pemisah ribuan. Perubahan bahasa
menjaga nilai. Jumlah stok tetap pcs/kemasan integer yang diatur terpisah.

English: choose ons (100 g) in optional weight/volume details. ID accepts1,25;
EN1.25, up to three decimal places without grouping. Changing language retains
the value. Stock counts remain separate whole pieces/packs. Ons is not an ounce.
