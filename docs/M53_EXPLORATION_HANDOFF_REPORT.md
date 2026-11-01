# H — Regresi dan Paket Eksplorasi Mandiri

1 November 2026. **M5.3 A–H selesai; handoff aktual PASS.**
Poco F6 `com.example.kasir_app.skybee` terpasang **0.5.3+13/schema37**, update
in-place/cert sama tanpa uninstall/downgrade. Source APK sudah push **d06f7e1**.
[Actual handoff](evidence/m53-20261026/exploration-actual-handoff.json).

Paket ditinggalkan di wizard genuine langkah1/7, ID/EN, identitas kosong.
Dua startup native witness + UI hierarchy dan screenshot akhir diperiksa.
**Database bisnis aktif saat handoff adalah0/0**;100 produk/50 sale diaktifkan
atomic pada Finish yang dilakukan pengguna dengan PIN/policy pilihannya.
Flow Finish diuji pada native fixture kedua perangkat; wizard pengguna sengaja
belum diselesaikan agar pengalaman setup pertamanya tetap milik pengguna.

## Perilaku yang diimplementasikan

Launcher debug khusus .skybee memeriksa identitas native dan marker one-shot
sebelum jalur seed/audit lama. Marker historis tetap disimpan. Worker menunggu
selama perlindungan, dan guard onboarding asli tetap berlaku setelah reset.
Database hilang secara tak terduga ditolak, bukan dibuat kosong untuk menutupi
kehilangan. Paket ordinary tidak mengimpor admin/demo dan tidak diperbarui.

Admin handoff hanya dituju launcher debug tersebut dengan permintaan lokal
terikat nonce/hash database. Frozen safety archive melewati native streaming
authentication, SQLCipher/integrity, migrasi staging dan invariant bisnis. Retensi
automatis tidak berjalan pada safety copy ini, sehingga arsip lama tetap utuh.
Manifest mencatat schema snapshot sebenarnya, termasuk sumber lama14. Phase
protecting menyimpan kode dan digest fakta untuk retry yang tidak mengadopsi
perubahan bisnis. Reset baru dilanjutkan setelah receipt salinan eksternal yang
cocok dengan nonce, digest arsip dan recovery. Ini bukan bypass PIN runtime
ResetToko: tidak tersedia dari ordinary main/UI dan tidak memakai toko pengguna
untuk fixture pengujian.

Reset memakai key journal/cleanup G2B, identitas dan key baru, scope .skybee saja.
Cadangan Drive, akun OS dan enrollment OS tidak dihapus. Material recovery lama
harus disimpan/verifikasi eksternal sebelum clear. Izin seed terikat toko hasil
reset; reset toko berikutnya tidak mendapat seed otomatis lagi.

Wizard genuine tetap tanpa owner credential operasional/barang/penjualan sampai
pengguna menyelesaikan setup. Finish menyelesaikan salinan terenkripsi, membuat
100 produk/50 penjualan lewat writer domain, mengembalikan verifier/recovery hash
asli, memvalidasi, lalu memilih shadow secara atomic dengan key journal same-store
replace. PIN sementara PUBLIC4digit hanya berlaku pada shadow dan tidak disimpan
sebagai credential aktif pengguna. Biometrik perangkat tidak disentuh oleh proses
seed shadow. Policy/tracking/currency/identitas/printer yang dipilih disalin,
bukan ditimpa konfigurasi demo. Grant tetap terkunci sesudah commit.

100 produk mencakup stok0/positif/999, untracked bila mode mengizinkan, unknown
bila biaya tidak diwajibkan, free yang dikonfirmasi, expiry/mixed, grosir/kemasan,
leading-zero code dan5 arsip. Ada4 supplier,6 kategori,8 pelanggan terdaftar dan
50 sale termasuk2 reversal sintetis. Keadaan dibatasi pilihan policy pengguna;
mode off tetap semua untracked, mode all/task3 tetap semua tracked. Semua bernama
CONTOH; nomor merupakan fixture sintetis, tidak diklaim nomor reserved. Tidak ada
pesan/kontak eksternal atau cetakan otomatis. Data disiapkan sekali saat Finish;
pada Poco fixture memerlukan beberapa menit, dengan UI menunggu operasi selesai.

## Bukti sampai checkpoint ini

- Generator dan ordinary onboarding domain/UI **15PASS00:22** pada host.
- Analyzer H awal35temuan style/wiring; scoped35fix, review7,1s menyisakan1style
  test, diperbaiki. Calon version13 analyzer **bersih89,4s**.
- Native H awalPoco **2PASS3FAIL02:18/1331hashlama sama/controlOff/exit1**.
  [Bukti awal](evidence/m53-20261026/exploration-poco-initial.json) disimpan.
  Dua kasus memakai dummy PIN8digit padahal kontrak4; produksi diganti4digit.
  Satu harness Coordinator14 mencoba membuka hasil reset37; guard downgrade
  benar menolak, fixture sekarang reopen Coordinator current. Tidak melonggarkan
  guard atau mengubah data pengguna untuk memperbaiki pengujian.
- Native reviewPoco **5PASS08:42/1338hashlama sama/controlOff/exit0**.
  [Bukti review](evidence/m53-20261026/exploration-poco-review.json),
  [source737](evidence/m53-20261026/exploration-review-source-sha256.json).
- DV native **5PASS10:32/1233hashlama sama/controlOff/exit0/awakeexact** pada source737
  identik. [Bukti DV](evidence/m53-20261026/exploration-dv-review.json).
- Host final **54PASS01:33** pada11file, timeout2m. Sebelumnya53PASS1FAIL01:27
  berasal dari legacy test yang masih mengharapkan counter-recovery13→14 ketika
  guard sengaja menolaknya pada schema37. Hanya ekspektasi host diperbaiki; guard
  produksi tidak dilonggarkan. Dua nama file keliru pada invocation lebih awal
  menghasilkan41PASS2loaderror01:23; log asli tetap disimpan.
- Hosttool **5PASS0,922s**: import tanpa device action, authorization wajib sebelum
  ADB, optimized Python tidak dapat menonaktifkan assert, archive/marker/unknown
  files dilindungi, scope retained recovery/biometric exact.
- Final analyzer **bersih119,5s**, format14file0changed, l10n1532/939/245, checksum
  PIN106 upstream unchanged. [Host checks](evidence/m53-20261026/exploration-host-checks.json).
- Ordinarydebug/release dan.skybeedebug **0.5.3+13**, ketigaABI/ELF+ZIP16KiB,
  notification icon/package/launcher/signature/pinned licenses lulus.
  [Build checks](evidence/m53-20261026/exploration-builds.json).
  Signature kandidat.skybee cocok dengan installed0.5.2+12. Belum dipasang.
- Post-native delta adalah satu host-only expectation serta hosttool/runconfig.
  Kode aplikasi/manifestbuild identik native737. Native proof historis tidak
  ditulis ulang untuk menghapus testfailure lama.

Kasus native: actual archive schema14/protection, receipt eksternal salah/missing
ditolak, reset scoped/retainedarchive; wizardFinish100/50 partial dantask3/all,
verifier owner/Gudang persis prepared, PIN sementara ditolak, dua reopen dan
reconcile; postSelection fault selesai satu kali; early shadow fault meninggalkan
fingerprint/wizard asli; permit toko berbeda menjalankan setup biasa tanpa seed.
Receipt eksternal native adalah sintetis; belum merupakan salinan host data nyata.

## Handoff aktual — selesai

Source software d06f7e1 dipush sebelum handoff. APK .skybee debug3ABI:
`build/m53-release-candidate/skybee-kasir-0.5.3-debug.apk`, SHA256
`2025aa13491c30c75a01e9cb94e1a41cbc8c67dc227b035eb04fa402039e3a89`.
Ordinary debug/release juga dibangun/diverifikasi, tidak dipasang ke perangkat.
Konfigurasi IDE ada pada `.run/SkyBee_Exploration.run.xml`; detail
[panduan ID/EN](M53_HANDOFF_GUIDE.md). Development signing, bukan publikasi M6.

Sebelum update, snapshot terpilih DB family/wrapped default/recovery serta
seed/audit disimpan privat, bukan kloning sandbox. Tujuh hash lama .skybee
sama sesudah install-r dan sebelum launch. Portable safety kemudian menjalani
native archive/cipher/integrity/business preflight. Arsip1.541.594byte dan
recovery eksternal dibaca ulang/hash cocok sebelum receipt reset diterbitkan.

Lokasi pribadi:
`C:/Users/ACER/Documents/SkyBee-Backups/M53-H-20261101-225304/` berisi arsip
terenkripsi `.kasirbackup`, `RECOVERY.txt`, dan README. Recovery tidak masuk Git,
chat atau evidence publik. Kode ini milik backup sebelum reset, bukan PIN baru.
Tidak ada arsip lokal preexisting pada baseline; arsip safety baru tetap cocok
hash sesudah reset. Dua marker historis seed/upgrade tetap byte-identik.

Reset khusus .skybee terjadi sesudah perlindungan tersebut, dengan key/store/
installation baru dan guard genuine setup. Lima file lama berubah/hilang sesuai
reset: active DB/journal, wrapped DB key, active backup code dan app biometric
binding. Tidak ada perubahan lain yang tidak dijelaskan. Ordinary **2** dan
integration **1336** entry hash semuanya sama; tidak diupdate/reset oleh handoff.
OS account/enrollment/cloud backups tidak dihapus. Semua controller/runner Off,
DV awake restored/read-back exact pada suite native terakhir.

Actual phase logs/private screenshots/DB-family protection tetap di
`build/m53-skybee-handoff-20261101-225304/`; data/recovery tidak dipublikasikan.
Invocation PowerShell awal salah membentuk argv dan ditolak parser sebelum
operasi perangkat; invocation argv Python kemudian menyelesaikan ketiga fase.
Tidak ada baseline diganti atau install-failure uninstall fallback.

Bukti crypto/SQLCipher/filesystem nyata dipisahkan dari transport/printer/biometrik
sintetis. Physical printer/2D scanner, OS biometric enrollment, Drive cloud baru,
clock72h/90hari alami dan power-cut fisik tidak dibuktikan oleh suite ini.
