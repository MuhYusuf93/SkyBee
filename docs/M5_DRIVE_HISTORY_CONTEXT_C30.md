# C30 — daftar Drive dan riwayat lokal

Status terbaru18 Oktober2026: **C30 terpasang di paket uji Poco**. Host52PASS,
focused7subsetPASS; Poco7PASS32s/DV7PASS88s; analyzer6,7s No issues. Audit B nyata
before1PASS12s dan strict after1PASS3s; semua tabel/13arsip/policy sama pada
interval update setelah metadata PIN yang didokumentasikan. Startup release
cashier terlihat/0marker pada buffer; ordinary hanya build. Kontrol perangkat
Off. Retest fisik label berikutnya; M5 belum selesai/M6 tidak dimulai.

Catatan persiapan dan repro historis tetap di bawah; APK pada HP masih C29 saat
persiapan itu ditulis, kemudian baru diganti sesudah pemeriksaan lulus.

## Temuan dan dampak

D-MAN16: pengguna melaporkan daftar arsip akun B kosong, tetapi8baris Berhasil
diverifikasi/tanggal terlihat di bawahnya; akun A juga menampilkannya. Source
memisahkan `s.remote` (Drive API) dan `s.runs` (`backup_runs` lokal, semua akun).
Delapan catatan konsisten8upload nyata checkpoint sebelumnya. Riwayat bukan
daftar file cloud dan boleh tetap8walaupun retensi cloud hanya7versi. Tidak ada
bukti pencampuran arsip ke akun B dari pengamatan ini.

Masalah UI yang terbukti: tidak ada heading riwayat lokal/konteks akun atau pesan
halaman Drive kosong. Pengguna dapat mengira catatan sukses lama berarti file
masih tersedia pada akun tujuan yang sekarang. Koreksi ini tidak menghapus atau
memfilter riwayat, tidak mengubah retensi atau melakukan upload/restore.

## Perbaikan

- BackupSettingsProvider mencatat apakah permintaan daftar telah berhasil.
  Konfirmasi akun/disconnect menginvalidasinya bersama daftar dan cursor; jangan
  mengklaim akun kosong sebelum list dimuat atau saat request gagal.
- BackupSettingsScreen memberi judul arsip Drive, pesan halaman kosong setelah
  respons berhasil, judul/keterangan riwayat lokal semua akun, dan label akun
  tujuan saat ini/lain atau sebelumnya/tidak tercatat pada tiap catatan. Email,
  permissionId dan token tidak ditambahkan ke riwayat.
- Tujuh key localization Indonesia/Inggris + generated Flutter localization dan
  pemetaan tr. Source aplikasi utama dan fixture sama; tanpa flag fitur khusus.
- Getter riwayat, keyset30, SQL, data lama dan aturan Retry tidak diubah.

## Reproduksi dan regresi

Fixture UI tiga catatan sukses lokal: A, B dan akun tidak tercatat; policy B
tersimpan, API about/list tiruan mengembalikan identitas B dan halaman kosong.
Locale id/en. Ekspektasi meliputi pesan cloud kosong, heading riwayat, konteks
tiap catatan, tidak membocorkan ID/email pada row, seluruh fingerprint tabel sama
sesudah request dan tampilan. Ini bukan OAuth akun B nyata.

- Percobaan awal helper mencari key widget yang belum ada saat scroll, berakhir
  No element2kasus10s; disimpan terpisah. Perbaikan helper memakai tombol Versi
  backup Drive yang sudah ada sebagai anchor, tanpa melemahkan assert.
- Satu percobaan helper tidak dapat dikompilasi karena memakai parameter
  alignment pada tester.ensureVisible; diganti Scrollable.ensureVisible.
- Repro final **2FAIL9s** pada assert pesan halaman kosong tidak ada.
- Sesudah source **2PASS9s**, termasuk heading/konteks akun id/en dan fingerprint
  seluruh tabel tetap. Dua kasus focused subset dari regresi penuh berikutnya.

[Repro](evidence/m5-20261018/c30-history-repro.log),
[sesudah patch](evidence/m5-20261018/c30-history-after.log),
[laporan pengguna](evidence/m5-20261018/d-man16-user-report.json).

## Audit akun B dan update terencana

`integration_test/m5_account_b_audit_test.dart` membuka hanya campaign yang sudah
ada. Before-role mengautentikasi PIN fixture publik0001 (dua tabel metadata
credential/audit boleh berubah), lalu menangkap baseline baru. API B dibaca
tanpa dialog: list kosong; satu ID A yang sebelumnya verified unavailable pada
B; policy B berbeda dari8catatanA dan otomatisOff; headless run ditolak sebelum
unggah. Seluruh tabel sesudah network/penolakan harus sama dengan baseline setelah
PIN. Kode/identitas/token/remote ID tidak dilaporkan ke host.

Audit update before/after harus mencocokkan seluruh tabel/arsip/policy dan fakta
finansial/stok serta8IDunik. Baseline lama sebelum manusia mengganti akun/PIN
tidak dipakai sebagai metadata beku. Ini belum observasi job cancellation OS,
perubahan akun saat upload aktif, natural21/reboot/Doze atau readback A serentak.
Jika koneksi/akun menghalangi, tandai BLOCKED dan lanjutkan bagian independen;
tidak ada reset/uninstall, menyiapkan key baru atau menerima akun lewat otomasi.

Native Poco/DV, build ordinary/fixture/bridge, pemeriksaan sebelum/sesudah update
dan manual retest label masih pending. Kontrol perangkat belum dimulai saat
persiapan host. Ordinary hanya build, original APK v6 closing tetap pending.

**C30 siap di Poco,18 Oktober2026:** daftar cloud dipisahkan dari riwayat lokal semua akun, pesan halaman kosong/konteks tujuan id-en ditambahkan tanpa menghapus8catatan. Repro2FAIL9s→focused2PASS9s/fullhost52PASS146s; strengthened7subsetPASS32s; analyzer 6.7s No issues; Poco7PASS/DV 7PASS Drive/history UI mocks; exact prior APK/default hashes/awake restored/read back. Native UI memakai SDK/HTTP tiruan. Audit B nyata before1PASS: identitas berbeda dari8runA, list0, IDA unavailable padaB, autoOff menolak run tanpa unggah dan semua tabel tetap setelah metadata PIN fixture yang didokumentasikan. Strict after1PASS: semua tabel/13arsip/policy sama; B connected/Off dan targetnull. Ordinary/default/2ekspor hash sama; build3 universal verified, ordinary tidak dipasang. Release own cashier terlihat/0marker pada buffer. Kontrol otomatis Off; C30-MAN01 retest heading/empty/8labelakunlain berikutnya. Natural21/reboot/Doze/lintas-origin/job cancellation OS belum terbukti; originalAPK6/closing pending. M5 belum selesai/M6 tidak dimulai. [C30](M5_DRIVE_HISTORY_CONTEXT_C30.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-history-ui-update-1792331546910\update.json

**C30-MAN01 PASS manual dilaporkan pengguna,18 Oktober2026:** heading arsip tujuan menunjukkan halaman kosong; riwayat perangkat berisi8status sukses/tanggal dengan label akun lain/sebelumnya. Paragraf bantuan tidak dikutip terpisah. Tidak ada unggah/restore baru atau bukti cancel job OS dari langkah ini. Berikut C31 native/build/audit; manual dijeda selama antrean, M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/c30-man01-user-report.json).**
