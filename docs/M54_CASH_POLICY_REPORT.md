# M5.4 kebijakan toko dan sesi fisik kas — verifikasi ditutup

Kontrak: M54_REQUEST §6.4/catatan33. Bagian tahap2, bukan penutupan M5.4.

`cash_drawer_policy` menyimpan preferensi pemilik; mode pada dokumen sesi
tetap immutable. Nonaktif mengizinkan Buka sesi sukarelaNotes tanpa mengubah
preferensi. Menutupnya mengakhiri pencatatan opsional, bukan menghapus histori.
Notes legacy tetap dibaca sebagai preferensi, bukan bukti bahwa sesi fisik ada.

Pemilik mengonfirmasi perubahan pada sesi berikutnya sebelum PIN baru. Sesi
terbuka tetap memakai mode/counts semula. Nonaktif ditolak sampai semua sesi
terbuka ditutup; pilihan Notes tanpa sesi ditolak. Owner-only snapshot memakai
agregat jumlah sesi terbuka/tertinggal dan satu dokumen terkini, bukan memuat
seluruh histori. Raw preferensi ditampilkan terpisah dari status sesi.

Open/close/policy menaikkan revision dalam transaksi yang sama; retry dengan
operation key yang sama tidak menggandakan epoch. Form usang sesudah perubahan
lifecycle ditolak. Setelah gagal CAS, status aktual dibaca ulang tanpa menimpa
pilihan draft. Batal autentikasi menampilkan pesan spesifik, bukan sukses.
Simpan sukses membaca ulang baseline; dirtyCheck dinamis dipakai saat Back.

Writer checkout/piutang/refund/supplier mengikuti mode sesi aktual. Intent
ber-ID sesi yang sudah ditutup ditolak, tidak menjadi pembayaran tanpa catatan.
Validator backup tetap replay/validate setiap sesi; mode sesi tidak diwajibkan
sama dengan preferensi untuk sesi berikutnya. Unknown tidak diubah menjadi nol.
Tidak mengubah normal close menjadi owner-only, tidak menambah tabel/ledger baru.

## Pengujian saat pengembangan

- Host awal24kasus:22PASS2FAIL validator yang masih mensyaratkan kesamaan mode
  sesi/preferensi. Guard itu diganti validasi per-sesi; replay forged counts,
  missing provenance, change dan old-day exception tetap diuji.
- Run berikut18domainPASS tetapi2loadfailure karena bool? pada harnesswidget.
  Compile diperbaiki; belum merupakan run gabungan yang bersih.
- Gabungan drawer/supplier44PASS,2UIFAIL karena tes menunggu radio lazy tanpa
  scroll,1loadfailure karena nama file portable salah. Log dipertahankan.
- UI review mengungkap asumsi tombol Back ambigu saat animasi dan akses widget
  lazy di luar viewport; helper menggunakan hardware Back dan reveal eksplisit.
- UI review berikut mengungkap overflow nyata dialog sesi berikutnya pada
  320px/text2; dialog diperbaiki menjadi scrollable. Review berikutnya menunggu busyflow nyata, bukan indikator lazy; UI2PASS00:31.
- Final gabungan5file48/48PASS01:26, termasuk UI2baru, supplier finance/credits
  dan portable full A–F2kasus. Exit0 aktual teramati; semua failure awal disimpan.
- Analyzer final No issues104,0s; formatter64file/0changed;
  l10n1552/947/245; PIN106unchanged.

Native kasPoco7/7PASS04:04 via retained-package safe wrapper:
build/m54-cash-policy-poco-20261107-041750. Oldprotectedhashsama/controlOff/
process exit0; manifest4 verified sesudah run. DV7/7PASS04:51 pada revisi sama, oldhashsama/awakeexact/controlOff/trueexit0: build/m54-cash-policy-dv-20261107-042539.
preflight Poco/DV0pending; source889file frozen manifest4:
2ae2e9e160de4083aec52bddca88737587160be85b78f33546b3605d24084ca0.
Kedua wrapper selesai; manifest4 diverifikasi sebelum source dibuka untuk HID.
Hasil ini menutup pemeriksaan perubahan kas §6.4; M5.4 keseluruhan tetap aktif.
Ini tidak memakai hasil native fondasi sebagai bukti modul kas.
Paket ordinary/.skybee tidak diupdate/reset/reseed. Tidak mengklaim pengujian
printer/scanner fisik atau handoff. Bukti runner privat tersimpan di build/m54/.

APK fixture actual source4 disimpan build/m54/cash-policy-source4-fixture.apk,
SHA256 bfea9f62cdabb9cccf437ed33325a3f2334a5fc431d6ac9bfb487d7d121239f8.
Verifikasi package.integration/version0.5.4+14/arm64/5libs/ZIP+ELF16KiB PASS.
Ini APK fixture device-build, bukan universal/handoff/release user.
