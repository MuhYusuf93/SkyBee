# M5 — worker Google Drive dan retensi nyata, 18 Oktober 2026

Status: **PASS pada cakupan worker terkontrol dan retensi nyata**. Native reader
1PASS3s; bukan bukti penjadwalan alami21.00. M5 masih berlangsung; M6 tidak dimulai.

## Koreksi manual C28

C28-MAN01R **PASS dilaporkan pengguna**: switch OFF menampilkan target belum
terjadwal; ON menampilkan 18/10/2026 21.00. Pengamatan sebelumnya mengenai teks
21.00 tanpa tanggal adalah penjelasan statis switch, bukan baris target. Selama
jeda pengguna melaporkan hanya satu OFF dan satu ON, kondisi akhir ON. Ini tidak
membuktikan semua metadata beku atau tidak ada aktivitas worker selama jeda.

## Lingkup dan pengamanan

- Poco F6 `7f0edea0`, Android16/API36; package
  `com.example.kasir_app.integration`, database kampanye yang sudah ada
  `m5_acceptance_1792150309449.db`. Tidak membuat database jika kampanye hilang.
- Akun nyata yang sebelumnya dikonfirmasi pengguna; OAuth/Google HTTP dan
  Keystore produksi. Akun, token dan kode recovery tidak disalin ke laporan.
- Tidak seed/reset/uninstall, tidak mengubah data transaksi/stok, konfigurasi OS,
  waktu sistem, firmware, aplikasi lain atau memasang APK ordinary.
- APK masuk C28 release disimpan dan diverifikasi SHA256 sebelum penggantian.
  Probe/reader debug ARM64 melalui `tools/test_android.ps1`; hasil bukan klaim
  bahwa seluruh jalur ini telah diuji pada release.
- Sumber probe mempertahankan delegasi job harian/peringatan ke service produksi.
  Callback normal dipulihkan melalui startup C28 setelah probe.
- Retensi dipanggil oleh `DriveBackupService.run` setelah setiap upload selesai;
  tujuh versi berhasil pada namespace integration + toko + origin yang sama.
  Arsip lokal sebelum probe tidak dihapus. File Drive lama dalam lingkup tersebut
  dapat dihapus sesuai aturan retensi yang diotorisasi.

## Pelaksanaan dan bukti

Run: [ledger](evidence/m5-20261018/live-drive-1792327725515/ledger.json).
Baseline nyata: **5 arsip lokal, 1 arsip Drive, connected=true, automatic=true**.
Proses setup PID12588 keluar normal, bukan force-stop; worker PID26905.

Job probe terdaftar tetapi belum mulai saat observasi; snapshot scheduler
menunjukkan job siap dengan konektivitas terpenuhi. Nama nonce dicocokkan ke
systemJobId9 dari metadata WorkManager package uji yang sudah tidak mempunyai
proses aktif. Pemicu terkontrol hanya job9 melalui `cmd jobscheduler run -s -n
androidx.work.systemjobscheduler com.example.kasir_app.integration 9` mengembalikan
Running job. Tidak memicu job harian lain atau mengubah syarat/jam sistem.
Penyebab penundaan alami belum diidentifikasi; tidak menyimpulkan bug aplikasi
atau menyalahkan OEM. Ini **bukan bukti pelaksanaan alami pukul21.00**.

Probe menjalankan delapan operation key berbeda melalui API produksi headless.
Dua pemanggil untuk key pertama menguji koalesensi dalam worker yang sama;
ini tidak identik dengan pengamatan manual bersamaan worker dari dua proses.
Setiap langkah memeriksa status success, remote complete/ukuran, urutan tujuh
terbaru dan keberadaan metadata cakupan lain yang telah ada di baseline.
Jika baseline tidak mempunyai origin lain, pemeriksaan itu bersifat kosong dan
tidak membuktikan perlindungan lintas-origin secara nyata; tes transport tiruan
tetap bukti terpisah.

| Pemeriksaan | Status saat persiapan laporan |
| --- | --- |
| Format Dart 2file | PASS |
| Analyze pertama | 3warning pada kode probe, diperbaiki; bukan bug aplikasi |
| Analyze final | PASS, No issues,7,1s |
| Prepare/identitas/native ABI/16KiB/ikon/lisensi APK probe dan bridge | PASS sebelum install |
| Setup keluar dan worker PID berbeda | PASS12588→26905; reader juga PID berbeda |
| 8upload Google nyata + retensi7 | PASS; scoped count2,3,4,5,6,7,7,7 setelah upload1–8 |
| Reader finansial/stok/HPP/piutang dan23tabel bisnis | PASS1kasus3s; semua tabel selain backup_runs/local_backups sama |
| Hash ordinary/default fixture/2ekspor publik sesudah | PASS empat file per DB dan dua ekspor sama |
| Exact APK C28 kembali/startup produksi | PASS SHA256persis; startup produksi diminta, render tidak diinspeksi ulang pada fase ini |
| Jadwal alami21.00/reboot/Doze | UNVERIFIED |
| Akun kedua Google nyata | PENDING interaksi pengguna |

Hasil: delapan run sukses dengan remote ID tersedia, tidak ada error
retensi; pemanggilan ganda key pertama kembali ke run yang sama. Total arsip
lokal menjadi13 dan lima arsip awal memiliki digest sama. Seluruh fingerprint
tabel selain `backup_runs`/`local_backups` sama; policy digest tetap. Native
reader memeriksa kembali23tabel bisnis, angka42000/HPP36000/piutang20000, stok18
dan nilai150000 serta ledger2penjualan/struk yang telah disepakati.
Baseline remote hanya satu origin; tidak ada origin lain untuk membuktikan
preservasi lintas-origin secara nyata pada run ini. Jangan membaca boolean
otherScopesUnchanged pada cakupan kosong sebagai bukti tersebut.

Buffer logcat terkait setup29baris/worker158baris berisi0fatal/0unhandled/0ANR
markers; hanya hitungan disimpan, bukan log mentah SDK. Ini bukti pada buffer
dan PID yang dibaca, bukan jaminan seluruh aplikasi bebas crash. Bukti:
[result](evidence/m5-20261018/live-drive-1792327725515/result.json),
[reader](evidence/m5-20261018/live-drive-1792327725515/reader.log),
[log counts](evidence/m5-20261018/live-drive-1792327725515/log-marker-counts.json).

## Perubahan workflow pengujian

`integration_test/m5_live_drive_probe_app.dart` melakukan baseline, menjadwalkan
job nonce dan keluar; worker memakai service produksi tanpa login UI. Marker
checkpoint/identitas remote tetap privat di sandbox; host menerima hitungan,
boolean, nama fase/tabel dan error code yang dibatasi.
`integration_test/m5_live_drive_result_test.dart` memverifikasi marker/job dan
keuangan serta hash bisnis. `tools/run_m5_live_drive_probe.ps1` menjaga package,
hash dan APK; tidak memakai runner lama yang mensyaratkan ordinary tidak ada.
`tools/probe_m5_live_drive_logs.py` menghitung marker crash pada PID terkait tanpa
menyimpan isi log SDK yang mungkin mengandung identitas akun.

Sesudah run, sanitasi pesan assertion probe diperketat dari pola huruf menjadi
allowlist kode assertion milik probe. Ini perubahan helper pada jalur pelaporan
kegagalan, bukan perubahan aplikasi/kriptografi; analyzer final8,9s No issues.
Delapan upload tidak diulang untuk perubahan helper ini. Audit C29 selanjutnya
sebelum/sesudah update1+1PASS3s juga memastikan delapan remote ID unik dan
13arsip tetap, tanpa mengunggah tambahan.

Helper metadata WorkManager pertama menemukan job9 tetapi cleanup file salinan
lokal gagal karena context manager sqlite Python tidak menutup koneksi.
`finally: con.close()` memperbaiki helper; proses pertama sudah berakhir dan
empat nama file scratch yang tepat dibersihkan tanpa recursive delete. Tidak
menghapus atau menulis database perangkat. Snapshot dumpsys awal masih berisi
statistik global meski parameter package diberikan; file evidence diganti dengan
blok JOB package uji saja. Jangan mengasumsikan parameter package menyaring
seluruh output dumpsys.

## Pekerjaan berikutnya

Isi hasil akhir berdasarkan result/reader/closure, lalu uji akun kedua dan
disconnect/penonaktifan otomatis tanpa mencampur versi. Audit penutup dan
pemulihan original APK v6 tetap terpisah dari pengembalian C28 sesudah probe;
pointer original tidak boleh diganti. Kondisi yang tidak dapat dibuktikan tetap
UNVERIFIED/BLOCKED, termasuk printer80mm, redaksi overlay clipboard/lockscreen,
serta reboot/Doze atau perangkat yang tidak tersedia.
