# Localization dan Money — pekerjaan terpisah sebelum M3

Addendum M5.1-D/E,20 Oktober2026: TenderDigits memakai raw canonical bertitik,
display ID/EN terpisah; IDR0pecahan, USD/MYR/EUR2pecahan. Tidak memakai double
atau menghapus titik/koma seragam lintas currency. CashTender memisahkan tunai
diterima/applied/change/debt; payment memakai applied. Numpad internal mengganti
IME nominal; customer tetap keyboard biasa. Konfigurasi uang cepat per currency,
label/status ID/EN. CSV/XLSX membawa currency/scale/minor/decimal eksak sebagai
text, barcode/nol depan dan integer64bit tidak dikonversi ke floating point.
Keterangan staging/snapshot/SAF ada pada
[D/E/G](M51_CASH_REPORT_EXPORT_MAINTENANCE.md). Paragraf M2 berikut adalah histori.

Instruksi pengguna 12 Oktober 2026 memperluas bahasa dan mata uang setelah M2. Proyek tidak dibuat ulang. Driver tetap sqflite; implementasi aktual M2 tidak memakai SQLCipher maupun kunci enkripsi. PIN/KDF dan opt-out backup OS dipertahankan.

## Kepemilikan state dan localization

`LocaleProvider` hanya memiliki preferensi bahasa tersimpan dan snapshot currency read-only. `SettingsProvider` tetap state formulir toko, `ManagementSessionProvider` tetap akses/lifecycle, Provider persediaan tetap sesuai layar. Bahasa ditulis lewat `SettingsService.setLanguage` tanpa PIN; perubahan currency lewat service terproteksi. MaterialApp/Navigator dan pemilik controller tetap sama saat locale berubah.

`lib/l10n/app_id.arb`, `app_en.arb`, `l10n.yaml`, `flutter gen-l10n` adalah sumber resmi. File `app_localizations*.dart` dihasilkan generator, jangan diedit manual. Key semantik, metadata, placeholder dan ICU plural digunakan. `localization.dart` menerjemahkan key pesan service saat render; tidak membaca SQL. `LocalizedNotice` memperbarui teks dan Undo pada snackbar yang masih tampil. Error tidak meneruskan SQL/PIN/data pribadi.

Saat belum dipilih, bahasa perangkat `id`/`en` diikuti dan bahasa lain fallback `en`. Pilihan tersimpan mengalahkan perangkat. Number locale **secara eksplisit** mengikuti bahasa: `id_ID` atau `en_US`. Currency dan zona waktu IANA tetap terpisah. Bahasa Inggris tidak memilih USD. Nama barang/master, alamat, kontak, footer dan alasan koreksi pengguna tidak diterjemahkan; reason_key mengidentifikasi alasan bawaan pada ledger lama/baru.

## Unit dan batas angka

Katalog `CurrencyPolicy`: IDR scale 0 (kebijakan aplikasi untuk rupiah bulat), USD/MYR/EUR scale 2. Pengguna tidak mengetik scale. `Money` membawa amountMinor, currencyCode, scale; tambah/kurang memeriksa kesamaan metadata dan quantity multiplication memakai BigInt sebelum menjadi integer. Batas API nominal baru **9.000.000.000.000 minor units**, termasuk total, bukan batas jumlah produk. Misalnya USD15.50 = 1550; mengetik 15 = 1500, tidak menggeser digit menjadi cents.

Biaya memakai **1.000.000 per minor unit**, terpisah dari currency_scale. IDR tetap micro-rupiah lama. USD/MYR/EUR adalah millionth-of-cent. CostAmount dari Money mempertahankan metadata dan service memeriksa currency. Total valuation tetap SQLite signed 64-bit, BigInt intermediate menolak overflow. Moving average memakai total value / jumlah stok, removal half-up dan residu terakhir tetap aturan M2. Jangan membulatkan unit cost dini; jangan memakai double untuk valuasi.

`MoneyCodec` memvalidasi grouping dan pemisah locale, lalu digit/string → BigInt → amountMinor. Kosong/incomplete bukan nol. Negatif, eksponen, simbol clipboard, grouping salah, desimal berlebih dan overflow ditolak. Locale clipboard tidak ditebak dan tidak dikonversi diam-diam.

NumberFormat.currency memakai locale/name/symbol-code/decimalDigits eksplisit. Kode ditampilkan untuk menghindari simbol `$` ambigu; formulir tanpa simbol. Konversi ke double hanya di boundary tampilan, dengan ceiling di atas yang lebih kecil dari 2^53 dan uji round-trip termasuk batas. Nominal lama M1/M2 di luar ceiling tetap dibaca Money.fromStoredMinor dan ditampilkan via digit integer dengan separator intl, tanpa konversi double; input baru/arithmetic di atas ceiling ditolak. Migration tidak memangkas nominal lama. Hasil formatting tidak masuk perhitungan/persistensi.

`MoneyTextInputFormatter` menggunakan unit utama, grouping real-time, kosong/trailing decimal/fraction sementara, cursor/selection, backspace/Delete separator dan paste tervalidasi. IME composing tidak diformat. `MoneyField` menunda perpindahan locale sampai composing selesai, menerjemahkan digit dari codec lama, menjaga selection; blur menormalisasi pecahan dan submit memakai parser ketat. PIN/quantity/barcode/contact tidak memakai formatter uang. Tidak ada listener controller yang menghitung ulang uang atau menulis SQL.

`MoneyEditingController` milik form menyimpan codec terakhir dan menyediakan canonicalMoney/parseMoney. Saat field terbuang dari lazy ListView atau tersembunyi auth gate, nominal tetap diparse dengan codec pemiliknya; ketika remount, field menerjemahkan dari codec lama ke locale sekarang. Currency nominal tetap terikat, tidak relabel otomatis. Submit `finish:true` menormalisasi trailing decimal/padding secara eksak; kosong/composing belum selesai tetap error. Pembulatan CostAmount menolak currency mismatch, dan moneyCostLabel mengikat biaya mikro ke metadata header sebelum membulatkan untuk tampilan. Inventory DTO/API baru memakai priceMinor/amountMinor secara eksplisit; SQL suffix lama tetap kompatibilitas.

CurrencySelector membatasi lebar label pada teks besar, menaruh kode di depan agar tetap terlihat, dan mengembalikan pilihan tersimpan setelah setiap upaya. Snapshot currency diterapkan langsung setelah commit/read preferences; tidak menunggu reload layar terproteksi atau bergantung pada apakah frame busy sempat dirender. Tidak ada perubahan controller nama/alamat/footer yang belum disimpan.

## Migration dan fakta

V4 additive; V1–V3 tidak ditulis ulang. Backfill default **IDR/0**, tanpa x100 atau perubahan nominal/stok/HPP/UUID/relasi. store_settings menambah ui_language nullable dan currency_code/currency_scale. Metadata ada pada products, draft header dan fakta header stock_receipts, sale_transactions, payments, ledger/history/inventory_operations. Detail receipt/sale/payment mewarisi header lewat FK; reader SaleTransaction/Item menggunakan metadata header, tidak settings terkini.

Kolom SQL lama `selling_price_rupiah`, `*_rupiah` **dipertahankan sebagai nama storage kompatibilitas**, tetapi mulai V4 berarti minor units sesuai metadata. Domain/API menggunakan Money/amountMinor; `_micros` berarti millionth-of-minor. Jangan menebak unit berdasarkan suffix lama atau mengalikan data IDR lama dengan 100. Rename storage dapat dibuat lewat migration terpisah bila perlu, bukan mengubah migration historis.

Perubahan currency hanya untuk toko tanpa nilai/fakta terkait: harga/valuation produk termasuk arsip, receipt, sale, payments, draft items, price/stock history dan inventory_operations. Fakta nol/reversal pun mencegah retag; riwayat tidak dihapus. Service dan SQL trigger memblokir perubahan; insert metadata berbeda juga ditolak. Harga produk nol tetap Money yang terikat currency, sehingga keberadaan produk apa pun (termasuk arsip/harga nol) memblokir perubahan. Master kategori/supplier tanpa nilai keuangan boleh tetap ada; hanya draft header kosong tanpa harga yang mengikuti currency baru secara atomik. Perubahan yang memerlukan konversi menjelaskan perlunya migration khusus. Bahasa tetap boleh diubah.

Upgrade di callback transaksi sqflite dengan FK/quick_check; kegagalan membatalkan seluruh migration. Immutable triggers tetap aktif setelah backfill reason_key khusus pesan sistem; isi user tidak diubah. Backup/restore M5 belum diimplementasikan; kewajiban archive staging/migration dijelaskan di BACKUP-CONTRACT.

## Kewajiban tahap berikutnya

M3 telah menerapkan snapshot header currency_code/currency_scale pada checkout/payment/draft; detail mewarisi header. Harga/pembayaran Money dan total overflow checked; currency guard tetap. Draft menyimpan minor units/metadata dan valid payment input, bukan string berformat; form sementara invalid tetap milik UI. Koreksi quantity/price acceptance mempertahankan payment intent tersimpan dan memvalidasi ulang total, tidak beralih diam-diam ke Lunas. Checkout remaining-debt listener menunda rebuild yang dipicu codec locale selama frame build; controller/nilai/session tetap. Bukti terkini di VALIDATION-M3/M3-NOTES.

M4 agregasi/laporan menjaga metadata, tidak mencampur mata uang; formatter hanya di display. M5 preview/struk/cetak ulang memakai metadata fakta tersimpan dan localization, notifikasi melalui ARB. M6 dokumen legal/onboarding bilingual, identitas dan footer pengguna tetap asli. Hardware printer, keyboard OEM/TalkBack dan release/profile tetap membutuhkan validasi target. Bukti aktual tahap ini ada pada VALIDATION-LOCALIZATION-MONEY.
