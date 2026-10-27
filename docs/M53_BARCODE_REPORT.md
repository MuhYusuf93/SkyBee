# M5.3 — fondasi scanner kamera

Fondasi scanner bersama tervalidasi pada host, DV8910 dan Poco F6 dengan scope
di bawah. Source tetap0.5.2+12/schema24; Paket Eksplorasi Mandiri0.5.2+12/schema14
belum diupdate. Gudang/form/ons, dokumen penerimaan/opname, supplier dan E–H
lainnya tetap aktif. Ini belum handoff M5.3.

[Keputusan](decisions/M53_BARCODE_CAMERA.md), [panduan ID/EN](M53_BARCODE_USAGE.md).
Scanner dibundel tanpa unduhan model/Play services, memakai Activity Flutter
yang sama, izin terbatas, pause pada lock/lifecycle/route dan konfirmasi satu
hasil per arm. Pilihan UPC-A tidak menghapus nol EAN13 secara diam-diam.

| Pemeriksaan | Hasil dan batas |
|---|---|
| Host kamera | 12 kasus PASS dalam run gabungan; controller6/adapter1/SQL2/UI3 |
| Host regresi drawer UI | 6 PASS pada run yang sama |
| Host search UI | Awal2FAIL; sesudah helper diperbaiki2 PASS13s |
| Analyzer/format/l10n | Noissues6,1s;443file/0changed;946key/636referensi/245RID |
| DV8910 ARM32 | 14 PASS3:10,715hash lama cocok |
| Poco F6 ARM64 | 14 PASS2:24,646hash lama cocok |
| API kamera DV/Poco | SDK30/36, kamera0/2, izinfalse/false |
| Decoder native | Gambar sintetis Code128 dan EAN13prefix0 lulus pada keduanya |
| Preview dan barcode cetak melalui kamera fisik | Belum terverifikasi |

Native14 mencakup controller6, SQL2, UI3 dengan transport sintetis, search UI2
dan decoder/API native1. Tidak meminta izin kamera fisik atau mengubah izin OS
untuk membuat run lulus. Fitur kamera eksternal DV bukan bukti kamera terpasang;
API saat run memang melaporkan0. Pada kedua perangkat, checker native menandai
`physicalCamera=false` untuk decoder fixture. Bunyi/IME OEM/gestur HID fisik tidak
diklaim terverifikasi oleh widget callbacks atau output sintetis.

Source539 berkas identik sepanjang dua run. Kedua wrapper exit0/controlOff;
awake DV dipulihkan dan dibaca kembali tepat. Semua berkas protected yang sudah
ada cocok pada interval masing-masing. Hanya package integration yang dipasang
in-place, dengan fixture baru bernama numerik dan worker background dipause.
Tidak reset/reseed/downgrade atau mengubah APK/data eksplorasi.

Kasir diuji pada320px, teks2× dan inset keyboard ID/EN: sepuluh frame belum
menambah barang, satu konfirmasi menambah1, konfirmasi ulang dinonaktifkan,
Scan again dengan kode sama menambah lagi. URL yang tidak cocok menghasilkan
pesan unknown dan tidak membuat produk/membuka browser. Fallback manual/Enter
masih menambah keranjang, sementara stok fisik tetap5 dan belum ada penjualan.
Form barang hanya menerima kode di RAM, mempertahankan dirty guard dan menyembunyikan
isi saat pemilik lock. Gudang lookup exact memerlukan capability; DTO kasir tidak
membawa biaya. Feature off tidak memutus input manual/HID lama.

Adapter memeriksa token arm sebelum menerima hasil native yang sudah mengantre;
controller juga mengonsumsi satu konfirmasi saja. Lock saat izin/lookup, resume,
restore serta callback terlambat diuji tanpa menghidupkan akses baru. Hints decoder
menghindari konversi otomatis EAN13→UPC-A; fixture native membuktikan string13digit
berawalan nol, sementara pilihan12digit diuji sebelum konfirmasi pada UI.

Riwayat kegagalan disimpan:

- Analyzer pertama3error karena MethodChannel.setMethodCallHandler pada SDK ini
  mengembalikan void. Await tersebut dihapus; temuan gaya dibereskan, final bersih.
- UI awal0PASS3FAIL8s: target lazy hilang setelah ensureVisible/autofocus dan judul
  bagian barcode ditebak salah. Helper dibatasi pengungkapan ulang setelah pump;
  judul aktual dipakai. Retest3PASS19s dengan skala/keyboard/assertion tetap.
- SQL/controller awal6PASS1FAIL6s: denial synchronous dilempar sebelum argumen
  expectLater dievaluasi. Matcher callback diperbaiki, tanpa mengubah otorisasi.
- Regresi gabungan18PASS2FAIL49s: kedua search UI memperoleh text client yang
  sudah di-evict setelah resize. Pengungkapan ulang dibatasi dan dipanggil juga
  sebelum exact-code input. Retest2PASS13s mempertahankan seluruh pemeriksaan
  query/ranking/help/pagination/unavailable serta roundtrip wide/narrow.

Lisensi native disertakan dan versi Gradle yang terambil4.3.0/core3.4.1 diperiksa.
Verifier vendor PIN tetap106berkas upstream identik. Tidak ada perubahan KDF,
KeyStore, ABI/minSDK atau profil printer. Tidak menghentikan stream CCTV DV.

[Host](evidence/m53-20261026/barcode-host-validation.json),
[DV](evidence/m53-20261026/barcode-dv.json),
[Poco](evidence/m53-20261026/barcode-poco.json),
[source](evidence/m53-20261026/barcode-source-sha256.json).
Raw log tetap privat. Scanner ini menjadi dependency operasi draft E berikutnya;
tidak mengklaim dokumen gudang/supplier sudah diimplementasikan.
