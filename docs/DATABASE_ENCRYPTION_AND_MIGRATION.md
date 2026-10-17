# Database terenkripsi dan migrasi M5

Status16Oktober2026: implementasi dan regresi aktif. Bukti terbaru serta kegagalan/retry ada di M5_TEST_REPORT dan M5_IMPLEMENTATION_REPORT; dokumen ini bukan sertifikat kelulusan seluruh perangkat.

## Driver dan batas

Operasional Android memakai sqflite_sqlcipher3.4.1 (MIT), tetap API sqflite_common tanpa ORM baru. Gradle memaksa AAR modern net.zetetic:sqlcipher-android4.19.1. DV melaporkan core4.19.0community. minSdk24 dan dukungan ARM32/ARM64/x86_64 proyek dipertahankan. Build universal/release dan ELF/ZIP16KiB M5 harus diverifikasi tersendiri; bukti library PIN lama tidak membuktikan AAR baru.

Sumber primer: [adapter](https://pub.dev/packages/sqflite_sqlcipher), [SQLCipher Android](https://github.com/sqlcipher/sqlcipher-android), [rilis](https://github.com/sqlcipher/sqlcipher-android/releases), [API SQLCipher](https://www.zetetic.net/sqlcipher/sqlcipher-api/).

## Key dan startup

`EncryptedDatabase` memakai32byte SecureRandom per instalasi, disimpan AES256-GCM oleh AndroidKeystore melalui plugin lokal `packages/kasir_platform`. File wrapped berada pada noBackupFilesDir. Alias wrapping berbeda per sandbox Android; ordinary dan.integration tidak berbagi key/data. Key database bukan PIN, verifier PIN, recovery PIN, maupun recovery backup. Raw-key SQLCipher menghindari derivasi passphrase lemah dari PIN empat digit. Tidak ada login/PIN tambahan untuk kasir.

Wrapping formatA1 mengautentikasi nama secret sebagai AAD. Wrapper devM5 awal dapat dibaca dan direwrap tanpa mengganti key. Tidak ada raw key di preference/assets/manifest/log. Material key berada sementara di memori Dart/native; tidak mengklaim perlindungan terhadap proses/root yang telah dikompromikan atau secure erase pada flash. DV `KeyInfo.isInsideSecureHardware=true` merupakan laporan API perangkat itu, bukan bukti semua model mendukung StrongBox/hardware yang sama.

Key hilang/salah/Keystore gagal menghasilkan error eksplisit dan mempertahankan berkas. Tidak menghapus DB, membuat DB kosong di atas berkas lama, atau beralih plaintext. Jangan clear/uninstall untuk memperbaikinya. Key Keystore tidak dapat dipindahkan sebagai berkas biasa; gunakan backup portable terverifikasi pada instalasi lain bila key lama tidak dapat dipulihkan. Tanpa key/backup yang cocok, data terenkripsi tidak bisa dijanjikan pulih. Android AutoBackup/dataExtraction tetap mengecualikan data aplikasi.

`cipher_version` memeriksa library, `cipher_status` memeriksa handle terenkripsi, pembacaan skema memeriksa key. Driver aktual mengembalikan status sebagai string1; tidak membandingkannya dengan integer secara buta. Handle plaintext dengan library SQLCipher tetap harus ditolak. Wrong-key test dan SQLite biasa harus memaksa query nyata, karena membuka handle bisa lazy.

## Migrasi dan koordinasi

1. Semua reader/writer/maintenance melewati antrean coordinator serta semaphore dan file lock Android yang sama antar-engine/proses. Worker menutup koneksi sebelum melepas lease; tidak menyimpan koneksi headless idle.
2. Startup mendeteksi header SQLite hanya untuk jalur migrasi. Sumber di-check, WAL di-checkpoint dan mode jurnal diverifikasi sebelum promosi satu berkas. Busy/ruang kurang menghentikan operasi dengan sumber tetap tersedia.
3. Ekspor memakai ATTACH dengan key dan sqlcipher_export ke `.incoming`, bukan PRAGMArekey terhadap plaintext. Transfer user_version/application_id/auto_vacuum eksplisit. Fingerprint terurut dan streaming mencakup DDL/index/trigger/semua tabel/sequence. Rowlog/key tidak disimpan sebagai bukti.
4. Staging menjalani quick_check/FK serta envelope HMAC. Baru sesudah cocok koneksi ditutup dan jurnal promosi disimpan.
5. `DurablePromotion` mencatat hash lama/baru dan fase committed. Rename lama→previous dan staging→live bukan satu transaksi. Flush berkas dan fsync direktori mendukung recovery. Sebelum commit startup rollback ke lama yang dikenal; sesudah commit menyelesaikan cleanup baru yang dikenal. Hash/jurnal tidak dikenal menghentikan recovery, tidak menebak/menghapus sumber.

Fingerprint validasi memakai halaman100row pada snapshot beku; OFFSET internal ini bukan pagination daftar aplikasi. Daftar pengguna tetap keyset. Pemeriksaan HMAC dan logical integrity berbeda; keduanya tidak menggantikan rekonsiliasi keuangan.

Restore menggunakan mekanisme promosi sama, menolak intent generasi DB lama, merevoke session dan membuat ulang scope/navigator. Safety archive dibuat di dalam lease maintenance yang sama sampai swap selesai, sehingga tidak ada commit finansial di antaranya. Kegagalan/akhir setelah committed harus dibaca dari keadaan durable; respons UI yang hilang bukan bukti rollback.

## Batas bukti

Pembaruan16Oktober: Realme C11 sesudah reboot menyelesaikan **88 PASS** regresi domain pada SQLCipher (PIN/persediaan/kasir/piutang/grosir/dus/laporan/pagination/localization). Manual DB schema7 tidak dibuka atau dimigrasikan; hash dan APK original dipulihkan sesuai ledger. DV rich schema7/WAL/metadata/sequence/trigger serta lima fault migrasi PASS; portable snapshot/restore writer barrier/safety/stale-intent PASS. Pengukuran profile1k/250 dengan dataset sama tersedia pada M5_TEST_REPORT. Lisensi native di assets/third_party dan LicenseRegistry; build universal/release/ARM64 masih diperiksa tersendiri pada checkpoint ini.

Tes fault Windows membuktikan recovery batas rename pada filesystem uji, bukan pemadaman listrik fisik. Tes DV memakai sandbox dan fixture. ARM64/Poco, release/16KiB/runtime dan dataset besar tetap harus dicatat berdasarkan pemeriksaan M5 aktual. Jangan menandai M1–M4 terenkripsi lulus hanya dari SQLiteFFI atau sukses kompilasi.
