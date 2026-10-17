# Aturan kerja proyek kasir Flutter

## Acuan dan tahap aktif

- Baca `docs/SPEC.md`, `docs/PLAN.md`, dan `docs/STATUS.md` sebelum bekerja. Spesifikasi berisi kebutuhan akhir; instruksi pengguna menentukan tahap aktif.
- Saat melanjutkan sesi, baca ulang status dan bagian spesifikasi yang relevan. Jangan bergantung pada ringkasan chat saja.
- Kerjakan tahap yang diminta sampai implementasi dan pemeriksaannya selesai. Jangan otomatis memperluas tugas ke tahap lain. Jangan berhenti pada rencana jika tugas meminta implementasi.
- Pertahankan file/data yang sudah ada. Perubahan kebutuhan dicatat konsisten pada spesifikasi, rencana, status, dan matriks persyaratan. Jangan mengubah kebutuhan diam-diam.

## Batas arsitektur

- Flutter + Provider + sqflite, Android dahulu, satu perangkat aktif per toko. Google Drive opsional sebagai backup, bukan sinkronisasi.
- Tidak ada Provider global yang mengurus seluruh aplikasi. Ikuti kepemilikan state pada SPEC bagian 2; scope sesuai lifecycle layar/alur.
- Widget dan Provider tidak membuka transaksi SQL atau memuat semua data. Aturan bisnis dan persistensi berada di service/repository.
- Domain penjualan memakai `SaleTransaction`/`sale_transactions` dan `SaleTransactionItem`/`sale_transaction_items`; foreign key `sale_transaction_id`. Bedakan dengan objek transaksi sqflite, misalnya `dbTxn`.
- Daftar besar memakai keyset/cursor dengan ORDER BY, tie-breaker, collation, dan index yang konsisten. Laporan agregat mencakup seluruh periode, tidak hanya halaman UI.

## Invariant penting

- Checkout/reversal atomik dan idempotent; stok tidak negatif; draft selesai konsisten dengan commit.
- HPP snapshot/moving weighted average; pelunasan piutang bukan penjualan baru; transaksi lama tidak dihitung ulang memakai harga terbaru.
- Kedaluwarsa per batch; supplier opsional; koreksi keuangan append-only/reversal, bukan hard delete.
- Printer berjalan sesudah commit. Gagal/cetak ulang tidak mengubah stok atau menciptakan penjualan baru.
- Backup harus konsisten dan restore bisa pulih dari kegagalan. Jangan membocorkan PIN, token, atau data pribadi pada log/fixture produksi.

## Validasi dan pelaporan

- Tambahkan Dartdoc/catatan alasan pada operasi dan modul penting. Hindari komentar yang hanya mengulang sintaks.
- Tulis kode langsung dalam file; chat berisi ringkasan dan hasil pemeriksaan.
- Jalankan formatter, `flutter analyze`, dan test relevan setelah milestone. Jalankan build bila toolchain mendukung. Perbaiki kegagalan sebelum meneruskan pekerjaan yang bergantung padanya.
- Jangan mengarang hasil test, benchmark, printer, Drive, atau build. Catat blocked/unverified jika tool, akun, atau hardware belum tersedia.
- Perbarui `docs/STATUS.md` dan `docs/REQUIREMENTS.md` berdasarkan bukti, termasuk pekerjaan tersisa dan langkah berikutnya.
- Jangan mengklaim seluruh aplikasi selesai ketika baru satu tahap selesai. Jangan memublikasikan aplikasi/halaman atau menambahkan pengiriman data di luar spesifikasi tanpa instruksi pengguna.

## Keamanan pengujian Android setelah insiden M3.1

- Native integration tests WAJIB melalui `tools/test_android.ps1` dengan DeviceId HP yang sudah dikonfirmasi dan AndroidSdkRoot. Script build/verifikasi APK package `com.example.kasir_app.integration` terlebih dahulu, memakai `--dart-define=KASIR_INTEGRATION_TEST=true` dan `--no-uninstall`.
- Jangan menjalankan bare `flutter test integration_test/...` pada package operasional. Flutter3.44.7 default-uninstall setelah integration tests; database fixture terpisah di package yang sama tidak melindungi data pengguna. Gradle guard harus menolak test entrypoint tanpa flag isolasi.
- Verifikasi APK biasa tetap package operasional. Jangan membuka/menginisialisasi database kosong setelah insiden kehilangan data tanpa keputusan pengguna. Catat data missing/unrecovered, jangan klaim preservation atau restore tanpa bukti.

## Referensi pembelajaran dan status data pengembangan

- Baca docs/LESSONS-LEARNED.md saat melanjutkan pengujian/perubahan workflow.
- Pengguna menyatakan data saat ini dummy dan belum akan memakai data penting sampai M6 selesai. Reset database pada tindak lanjut M3.1 ini diotorisasi; itu bukan izin umum reset masa depan atau package lain. Gunakan script scoped dengan ConfirmDummyData, lalu startup/migration asli.
- Verifikasi ordinary DB baseline/hash sebelum dan setelah integration run untuk membuktikan isolasi. Jika HP belum terdeteksi, lanjut pemeriksaan independen dan catat blocked; jangan mengarang hasil perangkat.
