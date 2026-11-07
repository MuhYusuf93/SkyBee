# M5.4 input dan routing scanner — berlangsung

Tahap2 §4.2/catatan34. Kas §6.4 sudah diperiksa pada revisi4, host48PASS dan
native7Poco/7DV dengan hash lama tetap sama. Bukti native dan pemulihan run DV tercatat di bagian review.

## Implementasi aktif

ManagedTextField memeriksa route terkini, fokus field dan enabled sebelum
meneruskan edit/Enter. FocusNode eksternal tetap dimiliki caller; jika tidak
disediakan, widget memiliki node sendiri. Enter manusia tetap diuji, tanpa
klasifikasi HID/timing/paste dan tanpa global key listener baru.

RouteInputScope memberi guard cancellation ber-epoch, bukan access grant.
Cover/pop, lifecycle dan disposal membatalkan intent lama meskipun layar
kembali terlihat. Query baru tidak membatalkan semua scan sebelumnya; scan
identik tetap independen. Guard berasal dari route penerima, termasuk guard
generation kamera; parent yang sengaja tertutup kamera tidak dianggap aktif.

Cart/receipt/opname meneruskan guard ke service. Guard diperiksa sebelum dan
sesudah awaited SQL/role proof, sehingga pembatalan final menggulung balik
draft. Widget/Provider tidak membuka transaksi. Camera lookup membawa guard
ke caller sebelum perubahan, bukan hanya mengabaikan feedback setelah commit.

Kasir tidak menarik fokus/clear query dari completion yang sudah dibatalkan.
Receipt/opname tidak membuka dialog unknown/batch yang usang; pada route kamera
ambiguity/batch diarahkan melalui pesan dan fallback input manual yang sudah
tersedia. Konfirmasi separate-line manual memulai intent baru sesudah tindakan
eksplisit; guard lama tidak dihidupkan kembali otomatis. Antrean scan penerimaan
15/12/20 tetap acceptance tahap penerimaan, belum diklaim selesai di sini.

PIN setup/rotasi kini memakai raw PinBoxes juga untuk old/new/confirmation;
tidak digits-strip/truncate barcode menjadi PIN4. Auto-submit hanya akses4digit,
setup/rotasi tetap Simpan eksplisit. Recovery PIN32hex berbeda dari backup24kata;
editor secret tidak memotong panjangnya. Enter konfirmasi pengaturan PIN kasir
tidak memicu Save. Seluruh capability/3/5/8 counter tetap pada service lama.

## Bukti dan batas sementara

- Field/route sebelum perbaikan:1PASS2FAIL pada stale callback; log asli disimpan.
  Sesudah route+focus fix:3kasus field/scope dan4PIN, total7PASS00:01.
- Regresi10file39PASS1compilefailure (operationKey fixture baru belum diisi).
  SQL review berikut6PASS1fixture-error karena nama tabel stock_history salah.
  Koreksi memakai nama tabel schema aktual, tanpa menghapus assertion rollback.
- SQL+field review2:7/7PASS00:11: final cancellation memulihkan draft/line/stok/
  histori;15scan melalui CartProvider diserialkan, stok25 tetap25, sale/payment0.
- Analyzer sesudah guard No issues11,9s. Satu lint braces dari run awal disimpan
  dan diperbaiki. Perubahan raw PIN sesudah itu masih harus dianalisis ulang.
- Raw setup/rotasi sebelum fix:4FAIL karena barcode dipotong menjadi4digit.
  Review sesudah fix:4kasusbaru+4PINPASS;3ekspektasi tampilan lama masih mengira
  Show PIN mengubah logical TextField.obscureText. PinBoxes sengaja tetap masked
  untuk editor logis, visual cells mengikuti toggle. Regresi diperbarui untuk
  memeriksa digit visual dan masking; review14kasus (raw4+layout3+field3+PIN4) PASS00:09, termasuk secret45karakter tidak dipotong dan Enter tidak bootstrapDB.

Gabungan16file77PASS4fixturefail02:03. Empat error tambahan Recovery berasal
dari mencari switch pada mode setup/nonvisible; kondisi rotate dan reveal
diperbaiki. Retest14PASS00:09 mencakup4kasus itu;81kasusunik melewati assertions
melalui runs/retest, bukan satu run81PASS. Analyzerfinal No issues110,8s;
formatter84/0, l10n1553/948/245, PIN106unchanged. Satu file perlu formatter saat
preflight; runner menolak lanjut sampai format-only dikoreksi dan check0change.

Native12kasus pada Poco berjalan, preflightPoco/DV0pending. Source894file frozen
build/m54/native-source-5.json SHA256
6bf9750dc7d093d2537734beea1e9c5a5975fe28c585cd4255388a556819f94a.
Jangan edit source sampai wrapper/audit ditutup. Ini bukan bukti native routing
selesai, scanner fisik/OEM, seluruh modal/arsip/penerimaan, maupun
handoff M5.4. Bukti modeled key/text/IME tidak disebut verifikasi hardware HID.
Source dibekukan lagi untuk native routing; draft build hanya
referensi historis, jangan disalin lagi di atas source yang sudah diperbaiki.

## Review native, belum ditutup

Run awal build/m54-input-routing-poco-20261107-045215 memilih0kasus karena
NameFilter tool memakai --plain-name, bukan regex. Audit oldhashsama/controlOff/
exit1; tidak dihitung PASS. Run full tanpafilter:
build/m54-input-routing-poco-all-20261107-045740 =19PASS2FAIL02:04.
Scope/focus3, setup2, controller7, SQL4 dan kameraUI3 lulus. Dua rotasiPIN gagal
pada helper scrollUntilVisible recovery switch, bukan assertion kredensial.
Audit full oldhashsama/controlOff/trueexit1. Source5 verified setelah wrapper.

Review memakai vertical ScrollPosition.jumpTo(min) dan assert switch benar-benar
terbangun; raw input/secret/Enter/no-commit assertions tidak dikurangi. Host4PASS
00:08. Manifest6 berbeda dari5 persis test/support/m54_pin_setup_suite.dart;
seluruh source produksi identik. Retest2Poco melalui filterliteral yang benar
sedang berjalan; sesudah audit, DVfull21 pada revisi6. Jangan edit source aktif.
Manifest6 SHA882365ca194b0a8ec19a9bfb5d980f92b3f0d886caa2221aab89e07ded888467.

Retest rotasi Poco lulus 2 kasus dalam 33 detik pada revisi 6. Audit paket
lulus dan proses keluar dengan kode 0. Gabungan run awal dan retest mencakup
21 kasus unik. APK fixture arm64 versi 0.5.4+14 lulus verifikasi package,
signature dan alignment ZIP/ELF 16 KiB. SHA256
`251bbbcb8c6ece621b2e3e155272298eae9938ef7ca86fcbc64e80cf6f9a2fae`.

Run DV pertama terputus pada 17 kasus lulus karena ADB offline. Empat kasus
tersisa belum selesai dan proses keluar dengan kode 1. Restore pada blok
finally juga terhalang, sehingga result.json asli masih mencatat RUNNING.
Setelah ADB kembali, snapshot awake asli dipulihkan dan terbaca persis.
Audit susulan terhadap baseline yang sama memeriksa 1.264 entri dengan nol
perubahan atau entri hilang. Bukti privat ada di `recovered-audit.json` dan
`awake-recovered.log` dalam folder run pertama. Full run DV kedua pada manifest 6 lulus 21 kasus dalam 2:48.
Audit hash lulus, awake dipulihkan persis, kontrol otomatis berhenti,
dan proses keluar dengan kode 0.
