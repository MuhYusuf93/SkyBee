# Validasi restore Drive nyata — 18 Oktober 2026

## Bukti manual

- D-MAN07/D-MAN07R: arsip dipilih dari Drive, autentikasi/metadata sesuai; C27 tombol Salin digunakan sampai validasi berhasil.
- D-MAN08/08R: pemulihan selesai kembali ke Kasir; Kelola tetap meminta PIN. Tidak adanya prompt langsung di Kasir bukan failure.
- D-MAN09: PIN backup fixture0001 diterima; laporan penjualan42000/HPP36000/laba6000/pembayaran22000/piutang20000/2sale/0batal, stok18/expired0/nilai150000 sesuai.
- D-MAN10:5kartu backup schema8/IDR termasuk terbaru sekitar restore; Drive belum terhubung.
- D-MAN11: profil printer kosong, notifikasi aplikasi Off/hari5/lowstock2-min5. Profil dan switch memang sudah kosong/Off sebelum restore Drive ini; jangan mengklaim transisi aktif→reset dari langkah ini.

Semua di atas dilaporkan pengguna, bukan hasil instrumentasi. Rujukan JSON per langkah berada di docs/evidence/m5-20261018/.

## Audit native yang disiapkan

`integration_test/m5_post_restore_audit_test.dart` menambah pilihan eksplisit `M5_POST_RESTORE_SOURCE=drive`; default local tetap3arsip dengan marker historisnya. Jalur Drive mewajibkan5arsip dan marker C27 pre-restore4arsip. Selisih terhadap marker C26 pre-upload3arsip mengidentifikasi satu arsip yang benar-benar dibuat untuk unggah; tidak menebak dari urutan nama/waktu saat ini.

Pemeriksaan yang ditargetkan:

- SQLCipher/envelope/integrity/FK/rekonsiliasi dan23fingerprint tabel bisnis beserta fakta penjualan/stok serta struk immutable.
- Seluruh5arsip disahkan/decrypt di staging privat memakai recovery yang tetap di proses perangkat; cek digest/katalog/containment/metadata/logo dan data bisnis. Staging dibuang pemilik setelah inspeksi; arsip asli tidak diubah.
- Safety terbaru harus berasal dari instalasi sebelum swap, dibuat sebelum instalasi hasil restore, dan mempertahankan seluruh printer queue/profiles serta backup_runs/local_backups terhadap checkpoint C27 stabil. Safety memuat satu run sukses dan4kartu lama.
- Snapshot yang diunggah dibuat ketika run masih running, remote_id belum ada, dan katalog3kartu. Database aktif harus membersihkan run tersebut, profil/queue/consent/jadwal dan menonaktifkan notifikasi/Drive.
- Setelah satu autentikasi PIN fixture yang memang menulis audit/attempt, seluruh fingerprint database aktif harus sama sebelum/sesudah inspeksi arsip; tidak mengabaikan tabel supaya tes lulus.
- Wrapper aman mempertahankan hash ordinary/default legacy, dua ekspor publik dan APK C27 persis; tidak uninstall/reset/reseed atau membuka database ordinary/default.

Tidak ada snapshot seluruh tabel yang baru diambil tepat sebelum pengguna menekan Konfirmasi pada restore Drive. Pembandingan safety terhadap checkpoint C27 dibatasi tabel stabil yang disebut di atas; audit/PIN/alert metadata dapat berubah selama interaksi manual. Tidak mengklaim seluruh metadata identik sepanjang interaksi manusia.

## Hasil saat persiapan

Formatter PASS; flutter analyze No issues7,9s. Native audit sedang berjalan; belum PASS sebelum marker runner dan restoration diverifikasi. Ini tambahan pengujian, bukan perbaikan bug aplikasi atau pengulangan38host/6UI/JVM11 sebelumnya. Tidak ada klaim restore Google nyata pada DV8910/Realme atau ketahanan power-loss/reboot/Doze dari run Poco ini. Preview clipboard Android tetap UNVERIFIED.

## Percobaan native pertama: FAIL dipertahankan

`docs/evidence/m5-20261018/drive-restore-audit-1792315519574/ledger.json`: native1FAIL16s pada fingerprint cart_drafts milik arsip saat loop inspeksi. Pemeriksaan database aktif sebelum loop melewati23business/integrity/FK/cipher/rekonsiliasi; belum full audit PASS. Ordinary hash sebelum/sesudah sama, dua ekspor publik tetap sesuai dan C27 restored exact. Tidak ada reset/perbaikan SQL atau perubahan aplikasi.

Hipotesis yang diuji berikut: arsip lama dari sebelum restore lokal pertama harus dibandingkan terhadap checkpoint historis mereka (marker1792191568561), bukan checkpoint C27 yang diambil setelah rangkaian penggunaan kasir berikutnya. Pilihan checkpoint tidak berdasarkan hash yang ingin diluluskan: membership tiga arsip lama didapat dari dua marker set katalog sebelum/sesudah upload; arsip Drive dan safety terbaru memakai checkpoint C27. Seluruh23tabel termasuk kedua tabel draft tetap diperiksa tepat. Log diagnostik hanya role arsip, nama tabel yang berbeda dan boolean matchesAssignedCheckpoint; tidak ada row/kode/account/payload. Penyebab belum diklaim terbukti sebelum retest menunjukkan provenance yang konsisten.

## Hasil akhir audit otomatis pada checkpoint ini

Retest satu kasus **PASS25s**. Log5role: latestSafety dan uploadedDrive tidak berbeda dari checkpoint C27; tiga olderRetained berbeda hanya cart_drafts/cart_draft_items dari C27 dan tepat cocok seluruh23tabel checkpoint historis. TEST-DRIVE-RESTORE01 terbukti kesalahan pembanding tes; tidak ada perbaikan kode aplikasi atau SQL. Retest tidak membuktikan setiap aksi lifecycle yang dahulu mengubah draft; hanya membuktikan provenance/digest sesuai dua checkpoint.

Kelima arsip authenticated/digest tidak berubah; selected Drive snapshot/draft, safety pre-swap/successful run/full stable queue+catalog, receipts/business23/cipher/envelope/FK/integrity/reconcile, canonical logo serta live device defaults/Drive disconnected PASS. Setelah autentikasi fixture, seluruh tabel live tetap selama inspeksi. Native wrapper ordinary/sidecar SHA sebelum-sesudah sama; dua ekspor publik sama; exact installed C27 SHA0ec0734a…6e3e1 kembali, kontrol otomatis Off. Legacy default baseline diperiksa pada awal testcase, bukan klaim rawhash akhir tambahan yang tidak dijalankan. Analyzer final No issues8,7s. Semua source C27 yang dicatat ledger tetap hash sama.

**Restore Drive: audit native PASS, 18 Oktober 2026:** Poco1kasus unik PASS25s; kelima arsip terautentikasi,23tabel bisnis/struk/integrity/FK/SQLCipher/envelope/rekonsiliasi dan logo sesuai; snapshot unggahan berstatus running/katalog3, safety terbaru memuat run sukses/katalog4 sebelum swap, live run/Drive/jadwal/default device bersih. Seluruh fingerprint live tetap selama inspeksi setelah autentikasi fixture yang didokumentasikan. First1FAIL16s dipertahankan: pembanding memakai checkpoint C27 untuk3arsip lama; log membuktikan hanya dua tabel draft berbeda dan semua23tabel cocok checkpoint historisnya. Ini kesalahan tes diperbaiki, bukan bug/repair database aplikasi. Analyzer final No issues8,7s; ordinary/sidecar dan2ekspor publik sama, APK C27 kembali hash persis; legacy baseline dicek pada awal audit. Kontrol otomatis Off; M5 belum selesai/M6 tidak dimulai. Berikut sambungkan ulang akun uji untuk consent/jadwal otomatis, jangan unggah/aktifkan sebelum instruksi. OriginalAPK6/closing pending. [Laporan](M5_DRIVE_RESTORE_VALIDATION_20261018.md), [hasil](evidence/m5-20261018/drive-restore-audit-results.json).**
