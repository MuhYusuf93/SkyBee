# Realme C11 — kelanjutan checkpoint sampai M5.2

Sesi23Oktober2026 ditutup **24-10-2026 00:19 WIB**. Pengujian Realme dilanjutkan dari
checkpoint, dan verifikasi DV/Poco mengikuti perubahan harness yang relevan.

| Pemeriksaan | Hasil |
|---|---|
| Realme — delta60skenario | 59PASS1FAIL17:43 + retest migrasi1PASS00:34; seluruh60memiliki PASS |
| Realme — checkpoint worker lama | Reader/cleanup2PASS00:06, tanpa replay setup |
| Realme — worker current | Reader/cleanup2PASS00:05, proses worker berbeda dari setup |
| Realme — AOT ARM32 final | PASS; exact debugAPK versi9 dipulihkan tanpa downgrade |
| DV — verifikasi migrasi terarah | 1PASS00:29; 496berkas lama cocok; awake pulih exact |
| Poco — verifikasi migrasi terarah | 1PASS00:18; 443berkas lama cocok termasuk Skybee |
| DV — run60yang terlanjur terlalu luas | Native60PASS14:47, **ISOLATION FAILED**, satu DB fixture berubah |

Bukti: [bukti terkurasi](evidence/realme-resume-20261023/validation-results.json). **Tidak ada suite60Poco.** Source fitur aplikasi tidak
berubah; koreksi Realme adalah pembanding migrasi aditif, pembacaan checkpoint
worker yang terprune dan helper/probe. Karena hanya pembanding migrasi yang
relevan lintas perangkat, DV/Poco masing-masing memverifikasi satu kasus itu.

Kegagalan isolasi DV tidak ditimpa:436berkas lama lain cocok, satu
`com.example.kasir_app.integration/databases/kasir_app.db` berubah. Mtime DB
1792774067 dan last_enqueue_time worker1792774068518ms berdekatan; metadata
read-only menunjukkan alert periodik6jam pada cycle12. Ini konsisten dengan
worker lama berjalan saat app tests dibuka, **bukan proof row-by-row**. Tidak
tersedia before-image untuk membuktikan seluruh row DB fixture lama; bagian
ini tetap **UNVERIFIED**. Retest terarah memakai interval/baseline baru dan
tidak memulihkan atau menghapus failure interval awal. DB tidak di-reset atau
ditimpa. Wrapper diperbaiki agar gagal hash selalu tercatat FAILED_OR_BLOCKED.

Auto-review menolak rencana salinan seluruh sandbox DV karena risiko data/
secret; rencana itu tidak dijalankan. Audit DV memakai SELECT metadata
WorkSpec/WorkName on-device, tanpa payload/DB/key disalin. Query langsung
Poco tidak dapat berjalan; pengguna kemudian mengizinkan **WorkManager
integration saja**. Salinan konsisten menunjukkan0job, tidak query kolom
payload, dan seluruh rawcopy sementara sudah dihapus sebelum tes terarah.

Tidak ada fitur dihilangkan, downgrade, uninstall/reset, reboot, perubahan
fingerprint atau update Skybee baru. Ketiga fixture tetap0.5.2+9; hash
Skybee/key Poco sama selama verifikasi terarah. Semua package sendiri tertutup,
kontrol otomatis Off dan WorkManager Realme0pending pada endpoint metadata.
Perubahan test/tooling/docs tersimpan lokal; tidak ada commit/push baru.

Tes fisik printer, akun Drive, OEM touch/keyboard, TalkBack/biometrik fisik,
reboot/Doze tidak diklaim pada sesi ini. Bukti historis tetap memiliki tanggal
dan scope sendiri. Tidak menunggu uji manual pengguna atau memulai M5.3–M6.

## Metode dan riwayat bukti

23 Oktober 2026. Pengguna meminta melanjutkan checkpoint terakhir hingga source
terbaru, otomatis tanpa acceptance manual. Izin/pengaturan perangkat dan reboot
yang benar-benar diperlukan diminta kepada pengguna. Tidak menghapus fitur,
reset atau downgrade; jika tidak dapat diselesaikan, laporkan batasnya. M5.3–M6
tidak dimulai. Source awal `b45f069`,0.5.2+9/schema14.

## Titik lanjut dan audit sebelum perubahan

Checkpoint [Realme19Oktober](M5_REALME_CURRENT_AUTOMATED_20261019.md) sudah
mempunyai98kasus native unik PASS lintas run, bukan seluruh suite perlu diulang.
APK terakhir integration debug0.5.1+8/schema11. Ordinary/Skybee tidak terpasang
pada Realme; Poco/Skybee tidak disentuh. Target terkonfirmasi
`0062112V2210F9B3`/RMX3231/API30/armeabi-v7a,armeabi.

Yang belum ditutup: worker nonce1792404362140. Audit baru menemukan setupPID3467
dan resultPID3685,3produk sintetis, SQLCipher4.19.0, Keystore dan plugin notifikasi
reopened, retry attempt2, arsip615392byte. Metadata WorkManager closed/readback
konsisten membuktikan exact unique task succeeded/state2,1attempt,0pending.
Semua257entri baseline sebelum probe tetap sama; saat ini266entri, sembilan
tambahan milik probe diketahui. Tidak replay setup atau membuat nonce baru.

Reader native telah memeriksa result lama, seluruh kolom lama sebelum/sesudah
migrasi fixture miliknya, retry claim3 dan cleanup unique task/callback produksi.
Snapshot encrypted+priorAPK dipertahankan lokal. Hanya dua file own-probe
diperbolehkan berubah: DB exact nonce untuk migrasi dan retry budget namespaced
untuk claim3. Semua file lama lainnya sama. Retest reader **2PASS6s**, seluruh
257entri baseline awal sama, kontrolOff, setup tidak diulang.

Reader pertama1PASS1FAIL: sesudah update/inisialisasi WorkManager, row terminal
multi-hari tidak lagi tersedia. Preflight sebelum update telah menangkap exact
WorkSpec succeeded. Reader diperbaiki agar ketiadaan row hanya diterima dengan
terminal-proof exact nonce/workId/state/attempt yang terikat SHA256 setup dan
result asli; ketiadaan tanpa bukti tetap gagal. Retest lulus, bukan worker baru
atau penulisan ulang failure lama. Dua file own-probe berubah sesuai scope;
semua marker, backup, wrapped DB/recovery/origin key lama tetap terjaga.

Audit helper awal menganggap exit0 dari adb exec-out cat berarti file ada;
Realme mengembalikan pesan missing untuk marker failure yang absent. Diperbaiki
dengan shell test-f eksplisit, audit ulang PASS sebelum ada install/SQL/callback
change. Failure helper pertama tetap lokal, bukan bug aplikasi.

## Pemeriksaan lanjutan yang dipilih

Tambahan langsung pengguna: DV8910 dan Poco F6 tersedia untuk verifikasi sesudah Realme.
Koneksi192.168.0.102:5555/AX810 terkonfirmasi authorized. Rencana awal suite delta
yang sama terlalu luas; pengguna mengoreksi24Oktober agar hanya perubahan
akibat temuan Realme diverifikasi. DV/Poco masing-masing satu kasus migrasi
terarah, serial dengan audit hash/awake; tanpa update/reset/reseed Skybee.

Setelah reader/cleanup/audit endpoint selesai, lanjut delta yang belum dimiliki
Realme: M5.1 D/E/G (uang tunai, laporan/export, maintenance), failure metadata
maintenance sesudah backup valid, M5.2 acceptance forms/operasi/portable, helper
upgrade lease/recovery, serta regresi antrean output yang terkait feed terbaru.
Tambahkan satu probe worker current untuk delta schema14/backup terbaru setelah
worker lama sudah ditutup; bukan replay setup nonce lama. Pemeriksaan release
ARM32/startup/notifikasi hanya otomatis yang tersedia;
tidak memilih akun pribadi, mengirim pesan, mencetak atau mengubah OS.

Hasil lama tidak diubah menjadi hasil source terbaru. Tidak mengulang M1–M4
atau seluruh98kasus M5 tanpa alasan delta/failure. Tes memakai safe runner
`tools/test_android.ps1`, integration package dan no-uninstall; wrapper melindungi
hash seluruh file lama. Tidak memakai wrapper legacy yang mengembalikan APK6
dengan downgrade. Tes source diubah hanya bila temuan membutuhkannya.

## Hasil rinci

Suite delta terdiri dari60skenario: cash8, laporan3, maintenance7, fault metadata
backup1, form M5.2 sebanyak17, operasi M5.2 sebanyak7, portable restore1,
upgrade5, antrean cetak10 dan kapabilitas printer publik1. Sebagian beririsan
dengan bukti98kasus historis; jangan menjumlahkannya sebagai kasus unik baru.

- Preflight exact worker/hash: PASS seperti uraian di atas.
- Native reader/cleanup endpoint: PASS2/2,6s;257entri lama sama.
- Delta M5.1/M5.2: **60skenario lulus lintas run**, melindungi seluruh
  file lama. Helper public-printer baru sempat gagal compile sebelum install
  karena ekstensi getVersion tidak diimport; diganti PRAGMA user_version,
  formatter/analyzer diperiksa sebelum retest. Bukan bug aplikasi.
  Analyzer3entrypoint No issues112,8s. Run native
  `realme-current-m51-m52-delta-retest-20261023-230651`: **59PASS1FAIL1063s**, pada
  pembanding SELECT* schema11→14 karena kolom aditif baru; nilai lama terlihat
  identik. Setelah suite selesai, pembanding diperbaiki untuk proyeksi seluruh
  kolom lama dan lima default baru. Host kasus migrasi **1PASS8s**, native
  `realme-current-cash-migration-fixed-20261023-233031` **1PASS34s**.
  Semua hash lama cocok/controlOff pada kedua run. Tidak menghapus field baru
  atau melemahkan pemeriksaan fakta lama; source fitur aplikasi tidak berubah.
  Analyzer perbaikan/probe release No issues3,3s.
- Probe AOT ARM32 nonce1792773379344: **PASS**, schema14/release/ELF32.
  Transaksi retry idempotent, stok tracked22/untracked999, total8780000minor,
  HPP7015000000000micros (64-bit), integrity/cipher/rekonsiliasi PASS.
  Ekspor CSV6628byte/XLSX78074byte dan backup inspect697356byte PASS.
  Plugin notifikasi diinisialisasi tanpa post/izin. Tidak mengakses akun,
  mengirim pesan atau transfer printer. APK signature/16KiB diverifikasi;
  exact debugAPK versi9 dipulihkan memakai install-r tanpa downgrade.
  Semua hash berkas lama cocok, controlOff. Ini probe sintetis AOT, bukan
  benchmark performa, ordinary installation atau acceptance hardware fisik.
  Setelah guard nonce existing dipindah sebelum jalur penulisan marker, probe
  final nonce1792773864623 juga **PASS** (backup697355byte); hash lama cocok,
  exact debugAPK versi9 dipulihkan. Angka dua run ini tidak dijumlah sebagai
  skenario unik. Source final probe yang disimpan sesuai build final tersebut.
- Worker current baru nonce1792773513170: **PASS**, setupPID2035 keluar alami,
  workerPID2723 membuka ulang Keystore/SQLCipher4.19.0/plugin notifikasi,
  membuat backup697354byte/3produk, retry attempt2. Reader/cleanup **2PASS5s**,
  callback produksi dipulihkan dan semua hash lama cocok/controlOff.
  Ini bukti proses terpisah aktual, bukan force-stop setup atau simulasi worker.
  Verifikasi scoped final: DV1PASS00:29/Poco1PASS00:18, seluruh hash lama cocok.
  Run DV60sebelumnya nativePASS tetapi isolationFAILED; tidak mengulang suite60Poco.
- Format seluruh308file **0changed**; full flutter analyze **No issues121,0s**.
  Audit lokalisasi **678kunci bilingual/468referensi statis/245requirement PASS**.
  Python compile dan PowerShell parser helper baru PASS. Probe release diulang
  sesudah guard menolak nonce existing sebelum jalur penulisan marker.
  Tidak ada diff pada lib/android/pubspec; perubahan ada pada test/workflow/docs.
- Verifikasi terarah DV/Poco dan bukti terkurasi: **SELESAI**; batas failed-isolation DV awal tetap.
- Tidak ada reboot, izin tambahan, penghilangan fitur atau downgrade diperlukan
  berdasarkan bukti saat ini. Tidak ada hasil manual yang diminta dari pengguna.

Log/DB/APK/marker privat berada di ignored `build/realme-resume-20261023-audit/`
dan `build/realme-resume-worker-20261023/`. Bukti publik hanya metadata terkurasi,
bukan credential/row pengguna/log mentah.

Audit host ulang terhadap before/after mengonfirmasi jumlah berikut. Entri
ABSENT adalah sentinel paket tidak terpasang, bukan berkas yang di-hash.

| Interval Realme | Entri sebelum | Berkas sebelum | Perubahan berkas lama |
|---|---:|---:|---|
| Reader checkpoint lama retest | 266 | 265 | 2berkas own-probe exact; seluruh257entri checkpoint awal sama |
| Delta utama59PASS1FAIL | 268 | 266 | 0 |
| Retest migrasi1PASS | 327 | 325 | 0 |
| Worker current2PASS | 333 | 332 | 0 |
| Release ARM32 finalPASS | 343 | 341 | 0 |

Pengecualian hashing hanya database internal WorkManager beserta sidecar dan
tiga gate lock yang ditentukan wrapper. Database bisnis, seluruh wrapped key,
backup serta berkas fixture lama tetap tercakup. Baru sesudah job selesai
wrapper mengambil hash tertutup dan mengakhiri kontrol perangkat.

Pembandingan langsung baseline19Oktober ke endpoint Realme terakhir (sesudah
release final) juga PASS: seluruh257entri asli, yaitu256berkas dan satu sentinel
ordinary absent, tetap cocok. Ini diperiksa terpisah dari baseline per-run baru.
