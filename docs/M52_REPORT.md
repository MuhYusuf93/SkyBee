# M5.2 — perbaikan operasional A–H

Status22 Oktober2026,14:29WIB: **M5.2 selesai pada cakupan implementasi,
pemeriksaan yang tersedia, repository dan handoff debug Skybee**.
Source0.5.2+9/schema14. Kontrak [M52_REQUEST](decisions/M52_REQUEST_20261022.md)
diaktifkan oleh pengguna, disertai syarat DV8910 diuji sebelum commit/push/update
Skybee. M5.3–M6 tidak dikerjakan. Batas hardware/manual di bawah tetap berlaku.

Skybee `com.example.kasir_app.skybee`0.5.2+9 sudah diperbarui in-place pada Poco
dari source `704642c06b7a519623bc053f86b32adbfafcca14`, setelah DV diuji dan source
dipush. APK lokal:
`build/m52-skybee-repair-20261022/skybee-kasir-0.5.2-debug.apk`,
SHA256 `edcc9879051ba190e9c593adad911bf9c3eb0138d8216feb2791ace9d79abd2d`.
Signature/3ABI/ELF+ZIP16KiB dan hash APK terpasang cocok. Dua startup lulus,
ditambah startup tanpa salinan recovery sesudah cleanup; kasir siap, kontrolOff.

Data eksplorasi101produk/21sale serta seluruh fakta bisnis lama diverifikasi;
key terbungkus, seed marker dan konfigurasi biometrik lama tetap sama.
Pengguna mengonfirmasi membuka Kelola dengan fingerprint. Izin menghapusnya
tidak perlu dipakai: konfigurasi tetap aktif. Printer publik, Kunci/redaksi,
layar PIN dan Back→kasir lulus melalui callback Flutter debug dan hierarchy
Android read-only. PIN route sementara memakai API `allowBiometrics:false`,
bukan perubahan preferensi. Sentuhan ADB ditolak INJECT_EVENTS; hasil itu tetap
tercatat sebagai batas metode, bukan PASS sentuhan fisik. Tidak memasukkan PIN.

Snapshot/priorAPK dan failure awal tetap lokal; hanya dua file cache milik audit
yang isinya terverifikasi dihapus.438hash terlindungi ordinary/integration sama
pada pemeriksaan akhir; keduanya tidak diperbarui demi handoff ini.
[Bukti terkurasi](evidence/m52-20261022/validation-results.json).

Checkpoint berikut merupakan riwayat sebelum penutupan.

Checkpoint07:31WIB: native DV acceptance24PASS304s (13→14 logical proof,
route/forms, promo/stok/ekspor, portable cross-key),400hash sama/awake exact/
controlOff; tambahan form publik DV2PASS41s. Poco final25PASS143s,402hash lama
sama termasuk4file Skybee. Pengaman upgrade file/gate nyata DV3PASS57s;
Poco helper dan printer/build/repository/handoff masih dilanjutkan.

## Pemetaan22request

| Request | Perubahan | Pemeriksaan/status saat ini |
| --- | --- | --- |
| 1 | Cari barang fokus sesudah draft/route siap, kembali Kelola, tidak tiap rebuild | Host/native DV/Poco gesture/focus PASS |
| 2 | Tap area baris+1; kontrol anak tetap terpisah | Host PASS; native DV lama PASS |
| 3 | Printer publik lewat capability khusus, tanpa grant Kelola/logo/recovery | Host/native boundary dan installed debug callback smoke PASS; INJECT_EVENTS ditolak |
| 4 | Profil saved tetap; default umum6, opsi Iware3; sampel berlabel feed | Iware58 Bluetooth6/2/3 masing-masing submitted sekali; kertas6/2utuh, pengguna memilih3yang terbaik |
| 5 | Lunas semua membaca saldo terkini dan hanya mengisi input | Host fill-only/saldo berubah sebelum konfirmasi PASS |
| 6 | Promo quantity eceran terpisah/soft archive/CAS/snapshot | Host/native DV/Poco operasi+portable PASS |
| 7 | ManagedTextField melepas fokus tap luar | Host/native gesture PASS; OEM keyboard terpisah |
| 8 | Dirty canonical dibanding baseline, reset sesudah save, revocation bypass | Host/native DV/Poco revert/save/lock/public repayment PASS |
| 9 | Back PIN mengunci generation lalu kembali root kasir yang sama | Host/native DV lama PASS; callback KDF terlambat ditolak |
| 10 | Validasi telepon offline libphonenumber/E164/region toko | Host ID/internasional/invalid PASS; legacy tidak digabung |
| 11 | Supplier email/website nullable, error per-field/aggregate, service validation | Host/native UI kosong/salah/clear dan portable PASS |
| 12 | Satu input PIN obscured dengan4kotak, auto-submit4 dan busy guard | Host sekali-submit/failure/rebuild PASS; lockout service lama tetap |
| 13 | Kosong→999+untracked;0/25/999 eksplisit→tracked | Host domain/campuran>999/refHPP/reversal/transisi PASS |
| 14 | Berat presisi3, IDRkoma/USD-MYR-EURtitik, reject invalid paste whole | Host semua mapping/selection PASS; metadata M5.1 tetap |
| 15 | Rak master bounded/suggestion/inline add dan rename revision | Host/native service stale-edit/current-ID PASS; inline UI tersedia, tidak seluruh alur diklaim diuji fisik |
| 16 | Batas jumlah awal6digit dan hasil konversi<=999999 | Service/UI validation tersedia, domain PASS |
| 17–18 | Hard error beli/grosir di atas eceran berbeda/exactpack | Host domain dan actual purchase UI PASS; tanpa bypass soft warning |
| 19 | Ambang nominal per currency, suppression hanya sesudah save sukses/reset | Host atomic rollback/save/reset+UI PASS |
| 20 | Calendar besok lokal, cancel nilai lama, revalidate saat save | Host boundary/year rollover/cancel/confirm PASS; DV lama PASS |
| 21 | Bantuan backup best effort/HyperOS, Info aplikasi melalui tap | Source tersedia; tidak mengubah OS/consent/jadwal |
| 22 | Lebar58/80mm berbeda dengan dots, renderer memakai profil | Profil/layout otomatis tersedia; hardware80mm NOT TESTED |
| Tambahan kontak | Tap outputphone→WhatsApp, website→browser, editor tidak membuka app | Host intent mock PASS; app eksternal fisik belum diperiksa |

## Aturan data dan kompatibilitas

Schema14 menambah relasi rak, kontak supplier, region, penanda stok/refbiaya,
audit biaya append-only, promo terpisah dan snapshot item, serta preferensi harga.
Migrasi tidak mengubah saldo0/999 lama menjadi fiktif, label lama atau fakta sale.
Penjualan untracked mempertahankan999/value0, tanpa batch/history fisik dan tanpa
batas999. HPP snapshot memakai acuan biaya eksplisit, termasuk0 yang dipilih
pengguna; edit memengaruhi sale berikutnya. Operasi fisik ditolak pada untracked;
transisi protected menolak menghilangkan stok/batch/nilai yang masih ada.

Promo retail berlaku ke seluruh quantity bila>=minimum, satu aktif per produk.
Diskon dibulatkan half-up pada total baris memakai BigInt, bukan unitprice float.
Grosir tidak stacking. Perubahan saat checkout perlu penerimaan total baru.
Revenue/piutang net, HPP tidak didiskon, retry/reversal memakai snapshot lama.
Laporan meniadakan placeholder dari unit/valuasi fisik dan memberi label biaya;
ekspor memuat mode/gross/discount/promo. Backup memvalidasi scalar/metadata baru
dan aritmetika snapshot, termasuk ketika CHECK pada SQLite impor dipalsukan.

Skybee memiliki proof private sebelum runtime: fingerprint semua kolom/tabel lama
diambil sebelum migrasi13→14 lalu dibandingkan sesudahnya. Tidak memaksakan100/20
row seed lama. Marker prepared memungkinkan audit dilanjutkan sesudah process
death; mismatch menghentikan startup normal. Snapshot closed dan key terbungkus
tetap diperlukan untuk handoff; snapshot lokal ini bukan recovery Keystore
portable. Tidak reset, uninstall, downgrade atau reseed.

Pemasangan awal dari `41b3430` berhasil, tetapi startup berhenti pada guard.
Audit SQLCipher read-only membuktikan snapshot13 cocok dengan prepared proof
seluruh43tabel; pada current14 hanya `m5_store.alert_generation` dan
`alert_state.evaluation` berubah. Helper lama melepas lease sesudah capture,
memberi periodic worker kesempatan mengevaluasi notifikasi sebelum verifikasi.
Perbaikan menahan satu lease hingga proof selesai dan menunda worker debug
sebelum foreground audit lengkap. Pemulihan khusus memeriksa snapshot asli,
seluruh rowset/kolom lain serta monotonisitas dua penghitung tersebut. Proof
menyebut `allExistingFactsMatch:false`, `allExistingBusinessFactsMatch:true` dan
dua kolom metadata berubah; bukan klaim semua kolom current sama. Data
eksplorasi101produk/21sale tidak dipaksa menjadi100/20. Pemulihan aktual dan dua
startup kini PASS; startup tambahan tanpa snapshot cache juga PASS.

## Bukti yang sudah tersedia

- Host perbaikan upgrade10PASS5s: populated13→14 dan pemulihan penghitung,
  penolakan perubahan produk/preferensi/body/baris/snapshot/penghitung invalid,
  serta policy worker sebelum proof. Ini tes fixture, bukan handoff perangkat.
- Native perbaikan DV5PASS216s: capture populated, prepared, mismatch,
  workerRace dan recoverDerived memakai SQLCipher/lease nyata. Semua hash lama
  sama; awake restored/readback exact dan kontrolOff. Poco suite sama5PASS203s,
  seluruh hash lama sama/kontrolOff. Format akhir305file/0changed PASS.
- Host database/alert setelah perbaikan15PASS14s; audit lokalisasi678pesan/
  245requirement PASS dan analyze akhir No issues208,7s. Ordinary build ulang
  debug20,0s/release43,6s di `build/m52-ordinary-atomic-20261022` verified
  signature/3ABI/ELF+ZIP16KiB; tidak dipasang. Skybee repair16,7s kemudian
  diverifikasi/dipasang dan handoff lengkap PASS seperti ringkasan di atas.
- Percobaan native filter `workerRace|recoverDerived|mismatch` gagal pada shell
  Windows sebelum kasus berjalan; wrapper memakai plain-name, bukan regex.
  Semua hash lama sama/awake exact/controlOff. Retest tanpa filter5PASS per device;
  kegagalan harness awal tetap disimpan.

- Host domain/forms/operasi26PASS116s, lalu form terbaru+metadata18PASS69s.
  Run bertumpang tindih, tidak dijumlahkan menjadi kasus unik.
- Host fullform terakhir17PASS75s; output/domain/ops/queue/ekspor26PASS59s.
  Reader CSV dan SpreadsheetML independen membaca20row per format, termasuk mode999fiktif,
  valuasi kosong dan gross/diskon/net. Host boundary jumlah25/konversi1juta
  terakhir5PASS5s. Run/subset bertumpang tindih, tidak dijumlahkan.
- Formatter301file/0changed dan gen-l10n PASS; audit678pesan bilingual dengan
  metadata/placeholders cocok serta245ID requirement asli tetap. Audit lama
  menemukan144deskripsi belum ada, tiga pesan/mapping yang hilang, parser
  interpolasi dan konstanta244stale; diperbaiki tanpa menghapus requirement.
- Analyzer sebelum pilihan3bersih65,2s; final sesudah opsi Iware3bersih164,9s
  (`analyze-feed3.log`). Format301/0changed dan auditl10n tetap PASS.
- Ordinary final sesudah pilihan3: debug34,4s/release51,8s dibangun dan
  diverifikasi0.5.2+9/packageoperasional,
  launcher/notificationicon/signature/3ABI/ELF+ZIP16KiB. Bukan pemasangan ordinary
  dan bukan signing/identitas rilisM6. Artefak lokal ignored serta hash ada pada
  [bukti terkurasi](evidence/m52-20261022/validation-results.json).
- DV domain operasional awal5PASS87s; Poco5PASS. Semua hash lama yang dilindungi
  sama, kontrolOff; DV awake dipulihkan/readback exact. Bukti ini mendahului UI baru.
- Native form DV lama10PASS1FAIL pada nama revert. Diagnosis mempertahankan
  failure dan menemukan hanya nilai nama berubah sesudah helper injeksi teks.
  Native suite kini memakai TestTextInput agar tidak bersaing dengan IME nyata;
  assertion nilai/dirty/Back tetap. Retest acceptance DV24/Poco25 dan form publik
  DV2PASS. Ini bukan bukti keyboard OEM fisik sudah diuji.
- Helper upgrade pertama0PASS3FAIL karena namespace fixture tidak sesuai guard;
  guard tetap, namespace diperbaiki. DV retest3PASS57s memakai SQLCipher/gate
  nyata untuk capture/prepared/mismatch dan reopen. Tidak ada data Skybee diubah
  oleh suite. Log kegagalan lama dipertahankan.
- Helper Poco3PASS41s; semua427hash lama sama/controlOff. DV426hash sama.
- Kalibrasi Iware58 Bluetooth1PASS4s: feed6dan2masing-masing submitted sekali,
  tanpa penjualan/pembayaran/stockhistory; semua430hash lama sama/controlOff.
  Pengguna melaporkan kedua kertas utuh dan feed2tepat garis putus-putus di area
  sobek. Ini bukti paper manual untuk2sampel, bukan asumsi dari accepted bytes.
  Pengguna kemudian meminta1sampel feed3: native1PASS2s/submitted sekali dengan
  marker tersendiri, tidak mengulang6/2. Pengguna menyebut **feed3yang terbaik**.
  Opsi coba Iware58 kini mengisi3baris pada form, tetap memerlukan Simpan;
  default umum6/saved profile tidak diubah diam-diam. Build final ulang PASS.
- Regresi sebelumnya63PASS9FAIL; sembilan kasus diperbaiki terarah9PASS39s.
  Penyebab/fixture dijelaskan di CURRENT_HANDOFF; logfailure tidak ditimpa.

Log mentah, DB, APK dan laporan privat berada di `build/` yang diabaikan Git.
Hasil native, ekspor independen, printer, Git dan handoff aktual sudah dicatat.
Natural21/Doze/reboot, keyboard OEM, TalkBack, WhatsApp/browser eksternal fisik
dan printer80mm tidak dibuktikan oleh mock/host. Fingerprint Kelola Skybee
berhasil dilaporkan langsung pengguna; bukan kampanye seluruh kondisi biometrik.

## Panduan singkat penggunaan

Printer dapat dibuka dari kasir tanpa PIN. Pilih perangkat/transport dan profil
58/80mm; periksa dots/margin, simpan per perangkat. Tombol coba Iware58/3baris hanya
mengubah form, mengikuti pilihan pengguna setelah sampel6/2/3. Simpan hasil
yang footer-nya utuh dan bisa disobek. Jangan cetak ulang hasil ambigu otomatis.

Di Gudang, promo memilih produk melalui suggestion, minimum pcs dan persen
0,01–100,00; aktifkan/nonaktifkan atau arsip dengan konfirmasi. Periksa preview
di bawah biaya. Keranjang retail menampilkan gross/diskon/net; grosir terpisah.

Jumlah awal kosong memerlukan harga beli acuan eksplisit dan menampilkan catatan
stok999fiktif. Isi0 bila stok awal nyata nol. Untuk mengubah mode barang lama,
gunakan aksi transisi yang protected dan selesaikan stok fisik terlebih dahulu.
Rak ditambah/diubah dari halaman khusus; draft barang tetap. Kontak supplier
opsional boleh kosong; error semua field harus selesai sebelum Simpan aktif.
Ambang/suppression harga rendah dapat direset per currency di Pengaturan.
