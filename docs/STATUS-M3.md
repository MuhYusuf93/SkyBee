# Status proyek

> Koreksi 13 Oktober 2026: klaim no-uninstall/data pengguna untouched di checkpoint historis ini tidak boleh dijadikan bukti preservation. Flutter integration test default --uninstall=true; insiden M3.1 menemukan package operasional diinstal ulang dan DB lama tidak ditemukan. Lihat [INCIDENT-M31-ANDROID-TEST](INCIDENT-M31-ANDROID-TEST.md). Hasil assertion fixture tetap historis, bukan bukti retensi data produksi.


**13 Oktober 2026 — M3 selesai pada lingkup implementasi dan bukti pengujian; siap review.** Development **0.3.0+4**, schema **5**. M1–M2 dan Localization/Money dipertahankan; tidak ada recreate database/proyek. M4–M6 belum dimulai. Histori sebelum M3: [STATUS-LOCALIZATION](STATUS-LOCALIZATION.md), STATUS-M2, VALIDATION-M1/M2/LOCALIZATION-MONEY/PHYSICAL.

## Hasil implementasi M3

Kasir aktif: nama/SKU/barcode, scanner keyboard Enter, suggestion token/alias/kategori, keranjang persisten/quantity/undo dan konfirmasi harga terbaru. CartProvider/Search/Checkout/Receivables/History mempunyai scope terpisah; SQL dan financial rules berada di service.

Checkout atomik menyimpan SaleTransaction/items, snapshot harga/HPP/currency, alokasi FEFO, stok/value/ledger, pembayaran/alokasi, draft completed dan audit. Draft menjadi idempotency key; recovery membuka hasil tersimpan sebelum membuat belanja berikutnya. Pelunasan preview tertua-first menyimpan pembayaran/alokasi saja, tidak penjualan/HPP baru. Customer ID dipilih eksplisit; nama sama tidak digabung. Riwayat dasar/HPP terproteksi PIN.

Migration 5 additive, minor units dan metadata V4 tetap, FK/quick_check dan failure rollback. Receipt view tersedia; transport printer, cancellation/reports penuh/backup/Drive/legal/release tetap tahap berikutnya. Detail keputusan/file di [M3-NOTES](M3-NOTES.md).

## Bukti aktual

| Jenis | Hasil/batas |
| --- | --- |
| Otomatis Windows | **103 test lulus**, exit0, reporter 01:10; 64 regresi +30 SQL M3 +4 Provider +5 layout. Focused 38 setelah payment-intent correction juga lulus sebelum guard scan terakhir |
| Analyze | Exit0, No issues found,2,3 s |
| Native awal M3 | 29 SQL lulus di HP; UI install awal ditolak USER_RESTRICTED, pengguna menyatakan USB siap dan instalasi berikutnya berhasil |
| Native akhir | **65 kasus unik lulus** pada HP 24069PC21G/7f0edea0 Android 16/API36:61 SQL +4 UI. Run 7 suite awal 63 pass/2 fail (finder shell lama); dua regresi UI diulang exit0/2 pass, dua M3 UI final diulang exit0/2 pass. Tidak mengklaim run 7 suite awal exit0 |
| Gen/format/audit/doctor | Exit0:gen-l10n;96 files / 0 changed;272 bilingual keys/233 references/244 ID lama;doctor No issues found |
| APK debug final/install/startup | Build exit0,Gradle 13,2 s;install -r pada HP exit0/Success;am start exit0; versionName0.3.0/versionCode4 terverifikasi. Startup log PID aplikasi:0 fatal/unhandled/Flutter error;8 pesan GPU probe/alokasi vendor |
| Manual pengguna | Laporan emulator/HP baik sebelumnya tercatat di VALIDATION-PHYSICAL; laporan itu mendahului M3 dan tidak mengesahkan M3 baru |
| Pending/unverified | Keyboard/clipboard/scanner OEM, TalkBack, Home/force-stop/power-loss semua OEM, release/profile/AAB/signing/performa release, printer/Drive/restore nyata |

Perintah/log/kegagalan yang diperbaiki di [VALIDATION-M3](VALIDATION-M3.md). Test memakai fixture DB terpisah, bukan kasir_app.db. Tidak uninstall/clear-data/reset/restore data pengguna. APK aplikasi biasa sudah dibangun setelah test APK dan dipasang kembali tanpa menghapus data. Log startup dibatasi PID; pesan GPU/vendor tetap dicatat, bukan sertifikasi seluruh rendering/performa. Migration bukan restore, startup bukan audit manual seluruh data pengguna.

## Berikutnya

Berhenti setelah M3 untuk review pengguna. M4 hanya setelah instruksi pengguna: laporan penuh/corrections/reconciliation/performance; M5 integrasi printer/backup/restore; M6 legal/onboarding/accessibility/rilis. Tidak melanjutkan tahap lain otomatis.
