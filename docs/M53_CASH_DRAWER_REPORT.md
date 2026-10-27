# M5.3 — kas fisik schema24

Tahap D telah lulus pemeriksaan host, DV8910 dan Poco F6.
Source 0.5.2+12/schema24 belum dipasang pada Paket Eksplorasi Mandiri
0.5.2+12/schema14. Handoff seluruh M5.3 belum selesai; E–H tetap aktif.
[Kontrak implementasi](decisions/M53_CASH_DRAWER.md),
[panduan ID/EN](M53_CASH_DRAWER_USAGE.md).

Tersedia tiga kebijakan default nonaktif, pembukaan yang membedakan unknown dari
nol, editor pecahan/kembalian, jurnal nonpenjualan/penyerahan, recount, penutupan
dengan selisih dan penutupan pemilik tanpa count historis. Checkout, pelunasan,
refund dan provenance kas berada di boundary atomik/idempotent yang sama dengan
operasi finansialnya. Pemilik mendapat pengaturan ber-PIN baru, histori terbatas
per halaman dan rincian tender penjualan; kasir mendapat histori mode catatan.

| Pemeriksaan | Bukti |
|---|---|
| Domain/replay backup/migrasi/role | 14 PASS53detik |
| Acceptance domain14 + UI6 | 20 PASS52detik |
| Regresi kasir/search/tender/UI | 58 PASS dalam run82kasus; 18 fixture laporan gagal |
| Laporan/koreksi sesudah perbaikan fixture | 24 PASS55detik |
| Analyzer | No issues6,7detik |
| Lokalisasi | 926 key bilingual/624 referensi statis/245 RID asli |
| DV8910 ARM32 SQL14/UI6 | 20 PASS8:26;693 hash lama cocok |
| Poco F6 ARM64 SQL14/UI6 | 20 PASS06:27;624 hash lama cocok |

Source516 berkas identik sepanjang dua run akhir. Kedua wrapper exit0,
kontrol otomatis berakhir dan awake dipulihkan/readback tepat. Native hanya
package integration, fixture numerik baru dan background worker dipause.
Tidak ada reset/reseed/downgrade/update package eksplorasi. Bukti hash berlaku
pada interval pengujian; belum merupakan bukti migrasi aplikasi eksplorasi H.

Kasus utama memeriksa Rp95.000 diterima/Rp2.000 kembali/Rp93.000 dibayarkan,
refund Rp93.000 dengan pecahan aktual berbeda, pelunasan tanpa penjualan/HPP/
kunjungan baru, sumber di luar laci, saldo tidak negatif, manual/Uang pas ditolak
saat aktif, retry dan fault di tahap drawer/draft/audit, late lock sebelum hasil
terbit, middle-of-day dan lintas tanggal/clock mundur. Migrasi23 mempertahankan
seluruh kolom asli yang dipopulasi tanpa menciptakan provenance/sesi lama.

Backup memeriksa rekonstruksi saldo/revisi/knowledge dan menolak cache palsu,
referensi sumber hilang, rincian kembalian/closure yang tidak cocok. Test import
yang merusak fixture dibatalkan dalam transaksi milik test; bukan mutasi data
pengguna. Restore portable lintas key dengan semua penambahan masih tahap G.

UI aktual dikonfirmasi lewat widget callbacks pada lebar320px, skala2× dan inset
keyboard ID/EN. Count editor tidak memotong kas sebelum submit. Back saat lock
mempertahankan atau membuang perubahan tanpa mengubah tender/stok tersimpan.
Count editor pemilik ikut privacy gate dan tetap menyimpan RAM saat terkunci.
Input/reveal programmatic ini bukan bukti gesture fisik/IME OEM.

Riwayat gagal dipertahankan:

- Run UI awal berhenti di SQL fixture yang ditunggu tanpa pumping I/O. Helper
  diperbaiki; empat kasus lulus23detik. Tidak mengubah otorisasi atau data toko.
- UI tambahan awal5PASS1FAIL1:59 menunggu form pelunasan. Helper menunggu tombol
  aktif sebelum mengetik; assertion kemudian disesuaikan terhadap nominal
  kanonis, karena MoneyField memformat `20000` menjadi `20,000` sesuai locale.
  Focused1PASS7detik dan acceptance gabungan20PASS menjadi bukti akhirnya.
- History test pertama gagal kompilasi karena parameter journal yang ditebak.
  Signature aktual memakai `pieces`/`incoming`; focused1PASS5detik lalu14PASS.
- Regresi82 awal64PASS18FAIL59detik: helper laporan lama membuat member baru
  tanpa phone. Nomor sintetis unik ditambahkan pada fixture, tidak melonggarkan
  aturan profil. Retest laporan/koreksi24PASS55detik.
- Satu retry host terlanjur berjalan bersamaan sehingga Flutter tidak dapat
  mengganti sqlite3.dll. Sesudah proses awal berakhir, pengulangan serial lulus.
- Analyzer awal hanya temuan gaya; source akhir bersih. Test migrasi search22
  kini membandingkan seluruh kolom lama dan default baru terpisah, mengikuti
  bentuk skema aditif tanpa mengurangi bukti preservasi.

[Host terkurasi](evidence/m53-20261026/drawer-host-validation.json),
[DV](evidence/m53-20261026/drawer-dv.json),
[Poco](evidence/m53-20261026/drawer-poco.json),
[source checksum](evidence/m53-20261026/drawer-source-sha256.json). Raw log tetap privat.
Pembayaran supplier dari laci dilengkapi bersama E; laporan/ekspor lintas periode
pada F, keselamatan portable/retensi/reset fixture pada G, build dan update
eksplorasi in-place pada H. Tidak ada klaim audit mendeteksi kejujuran atau selisih
berarti pencurian. Beban CCTV DV tidak diubah dan tidak menjadi kesimpulan sebab.
