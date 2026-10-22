# M5.1-C — cetak recovery, 19 Oktober 2026

Status: implementasi dan bukti otomatis tersedia; hasil recovery pada kertas
nyata belum diuji. M5.1 keseluruhan belum selesai.

Kode lama tetap256bit/64hex. Setelah kode pertama/rotasi dikonfirmasi dan
disimpan melalui alur M5, tombol Cetak kode pemulihan tersedia. Cetak opsional.
Pending kode yang belum disimpan menonaktifkan tombol agar kode tersimpan lama
tidak tercetak dengan keliru sebagai kode rotasi baru. Salin manual tetap ada.
Tidak menanam master key atau mengganti recovery dengan PIN/biometrik.

Tiap cetak memerlukan autentikasi baru, kemudian dialog tujuan nama/id printer
dan peringatan kertas rahasia. Perubahan profil sebelum kirim ditolak. Claim
opaque purpose recoveryPrint memiliki deadline60detik dan satu consumer;
service lain tidak bisa memakai proof yang sama untuk cetakan kedua. Lock,
expiry atau revocation membatalkan kirim berikutnya. Tidak ada auto retry.

RecoveryPrintService menggunakan lease output yang sama dengan struk biasa,
pengubahan koneksi dan restore. Lease mencakup seluruh dokumen, lintas engine
Android via native semaphore/file lock. Kode baru dibaca setelah lease diperoleh
dan proof/target diperiksa. Tidak melalui prepare()/print_jobs, snapshot struk,
filename, log, clipboard atau antrean yang dipulihkan ketika proses restart.

Template khusus ID/EN: judul recovery, peringatan rahasia/bukan struk, versi
Hex256/v1 dan fingerprint pendek SHA256 key, waktu UTC berakhiranZ, empat baris
kode16karakter berkelompok4, instruksi penyimpanan terpisah dan pemeriksaan
seluruh64karakter. Tidak memuat PIN, barang, harga, penjualan atau HPP.

Raster tetap bertile maksimal64px tinggi; gambar di-dispose, input hash UTF8,
rawRGBA, encoded tile dan chunk mutable dihapus best-effort. Java juga
membersihkan salinan buffer setelah write. Immutable String/codec/driver/
transport/memori printer tidak dijanjikan terhapus atau terenkripsi.

Hasil UI membedakan belum dikirim, bytes dikirim/periksa kertas, dan tidak pasti.
Putus/lock/timeout setelah kemungkinan bytes masuk tidak dinyatakan aman untuk
retry otomatis. Cetak ulang eksplisit memerlukan autentikasi/konfirmasi baru.
Checkbox pemeriksaan kertas/salinan pribadi hanya mencatat event konfirmasi
tanpa key, fingerprint atau isi salinan. Tidak mengubah backup atau fakta uang.

File utama:

- `lib/features/printer/application/recovery_print_service.dart`
- `lib/features/printer/application/printer_output_gate.dart`
- `lib/features/printer/application/print_queue_service.dart`
- `lib/features/printer/application/receipt_layout.dart`
- `lib/features/backup/application/backup_service.dart`
- `lib/features/backup/presentation/backup_settings_screen.dart`

Bukti aktual:

- Host awal9PASS18s; regresi49PASS04:08 (9recovery+33UI+7antrean).
- Repro kalibrasi stale credential1FAIL08s; perbaikan epoch dan konteks history,
  focused19PASS01:13 (10antrean+9recovery, subset). Cashier copy tetap tanpa PIN.
- Analyzer final checkpoint No issues7,5s.
- Poco/DV masing-masing10PASS native (SQLCipher/KDF, public key/fake output,
  termasuk satu native output lease concurrency probe). Tidak ada kertas.
- Native backup/restore dengan hook lease output produksi Poco1PASS00:58.
- Semua hash lama yang dilindungi sama dan awake DV dipulihkan/readback exact.
- [Bukti native](evidence/m51-20261019/c-poco-recovery-result.json),
  [DV](evidence/m51-20261019/c-dv-recovery-result.json),
  [restore](evidence/m51-20261019/c-poco-restore-lease-result.json).

Uji native tambahan untuk epoch kalibrasi dan host sesudah wipe hash input
sedang dilanjutkan; angka di atas tidak mengasumsikan hasilnya. Log gagal dan
retest privat tetap di build. Uji paper baru hanya boleh memakai key fixture
publik/discardable, dengan pengecekan kertas oleh pengguna. Keberhasilan teks
[USB dari PC](M51_USB_PC_20261019.md) terpisah dari recovery dan OTG Android.

QR recovery/scanner dan mnemonik24kata belum diimplementasikan, sesuai opsi
defer kontrak. Tidak ada tombol/stub yang menyatakan fitur itu tersedia.

Checkpoint tambahan C: host final10PASS24s/analyzer8,3s; epoch native khusus
Poco1PASS14s dan DV1PASS24s. Hash lama sama, awake DV pulih exact.
Ini menutup pending epoch/wipe di atas; tetap tanpa paper recovery nyata.
