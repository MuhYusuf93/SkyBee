# Insiden data pada pengujian Android M3.1

13 Oktober 2026. Pengguna mengizinkan pengujian setelah HP siap. Agent menjalankan integration tests dengan Flutter3.44.7 pada package operasional com.example.kasir_app, mengandalkan fixture DB terpisah dan keliru mengasumsikan runner tidak uninstall. **Asumsi ini salah.** Flutter commands/test.dart mendaftarkan flag uninstall dengan defaultsTo:true, debuggingOptions.uninstallApp memicu IntegrationTestDevice.kill→device.uninstallApp setelah test.

## Bukti

- m31-android-regression.log: SQL kasir gagal install INSTALL_FAILED_USER_RESTRICTED, suite tersebut tidak dijalankan. Transisi berikutnya mencatat adb uninstall com.example.kasir_app gagal DELETE_FAILED_INTERNAL_ERROR. Ini bukan bukti semua uninstall sebelumnya ditolak: cleanup sukses tidak selalu dicetak.
- Metadata package yang diperiksa menunjukkan firstInstallTime sama dengan lastUpdateTime2026-10-13 03:46:28; run-as ls databases/kasir_app.db gagal No such file or directory (m31-operational-db-presence.log), pencarian read-only di sandbox juga tidak menemukan file tersebut. **Pelestarian data pengguna tidak dapat diklaim; database operasional lama tidak ditemukan pada package yang telah diinstal ulang.** Tidak ada baseline checksum yang memungkinkan audit nilai lama.
- Pengguna menyatakan tidak mempunyai salinan database lama. Tidak ada database/backup di workspace yang ditemukan. Pemulihan tidak berhasil/belum dapat dibuktikan; tidak mengarang restore atau memasukkan data perkiraan.
- Agent menghentikan runner ketika mengetahui uninstall otomatis. Usaha isolasi pertama dengan deteksi target-path tidak efektif karena Flutter memakai entrypoint generated listener; APK masih package lama. Run tersebut juga dihentikan setelah pemeriksaan identity tidak menemukan package integration. Log m31-android-isolated.log tetap disimpan (30 SQL+2 UI M3 melewati assertions sebelum interruption). Nama file isolated pada run itu **bukan bukti package terpisah**.

## Koreksi yang sedang diverifikasi

Android Gradle memakai flag eksplisit --dart-define=KASIR_INTEGRATION_TEST=true untuk applicationId com.example.kasir_app.integration, label kasir_app tests, activity fully qualified. APK harus diverifikasi aapt dump badging sebelum instalasi. Semua integration runs wajib --no-uninstall, flag fixture dan target fisik eksplisit. Target-path tidak dipakai sebagai kontrol isolasi. Ordinary APK tanpa flag tetap com.example.kasir_app.

Periksa identitas package dan tidak menyasar file operasional/berkas pribadi pada setiap script. Workflow/script akan menolak menjalankan suite native jika APK fixture memakai package operasional. Test suite memakai DB fixtures di sandbox package integration; package/data pengguna tidak dijadikan target cleanup/negative test.

Aplikasi biasa disiapkan/dipasang kembali tanpa meluncurkan atau menginisialisasi DB kosong sebelum keputusan pengguna. Tidak ada pemulihan data lama yang diklaim. M3.1 tidak boleh ditandai selesai tanpa menyebut insiden dan batas ini. Klaim historis STATUS/VALIDATION terdahulu bahwa flutter test biasa tidak uninstall tidak dapat dijadikan bukti pelestarian; catatan ini mengoreksi asumsi tersebut tanpa menghapus log lama.


## Hasil koreksi

APK fixture explicit flag verified com.example.kasir_app.integration; installed dataDir.integration, native14SQL+1UI exit0 dengan --no-uninstall melalui script. Negative build tanpa flag rejected before install, guard proven. Ordinary APKcom.example.kasir_app 0.3.1+5 build/install-r berhasil, **tidak launch**, pencarian DB sesudah install tetap tidak menemukan kasir_app.db. Database lama tidak pulih. Native fixture log scope PID7624 tidak fatal/DB exception; ini tidak membuktikan data user preserved. Perintah/log lengkap VALIDATION-M31.


## Klarifikasi pengguna dan tindak lanjut

13 Oktober 2026: pengguna menjelaskan data terdahulu seluruhnya dummy untuk pengujian, mengotorisasi hapus DB yang tersisa/create baru, serta tidak mengisi data penting sampai M6 selesai. Reset baru diotorisasi, bukan recovery/preservation data lama. Histori default-uninstall tetap menjadi pelajaran keamanan yang berlaku untuk data nyata kelak. Referensi LESSONS-LEARNED; pemeriksaan ulang VALIDATION-M31-RECHECK.

Tindak lanjut selesai pada lingkup otomatis tersedia: reset scoped tidak menemukan DB/sidecars lama; ordinary startup membuat DB baru V6/integrity/FK baik. Seluruh84kasus native package integration lulus exit0; hash ordinary DB sama sebelum/sesudah, setelah isolated release smoke dan install/reopen biasa. Aplikasi biasa0.3.1+5 ditinggalkan terbuka pada DB dummy kosong (PIN belum dikonfigurasi). Ini menyelesaikan permintaan pengguna untuk create/pengujian ulang, tidak mengubah histori menjadi bukti recovery atau mengesahkan restore/production release. Pembelajaran/guard dipertahankan bagi data penting setelah M6.
