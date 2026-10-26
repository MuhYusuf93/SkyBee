# M5.3 A2 — checkpoint biaya, belum handoff seluruh milestone

26 Oktober 2026. Source development **0.5.2+12/schema17**. Fondasi16 sudah
commit/push `f4fb719`. Bukti source checkpoint ada pada manifest SHA256; lihat
[checkpoint aktif](M53_CHECKPOINT.md). Paket Eksplorasi Mandiri tetap
**0.5.2+12/schema14**, tidak diupdate/reset/reseed.

## Perilaku yang tersedia

Biaya kosong berbeda dari0. Mematikan tampilan biaya mengizinkan penerimaan
unknown dan pembuatan barang tracked/untracked tanpa harga beli fiktif. Edit
master dengan field tersembunyi mempertahankan reference cost historis yang
diketahui. Biaya0 baru memerlukan konfirmasi; biaya positif per dus yang
membulat0 per pcs pada presisi internal tetap dianggap berbayar.

Pool campuran tidak memiliki average/total canonical. Penerimaan diketahui
berikutnya tidak melengkapi acquisition yang unknown. Saldo habis kembali
complete0 untuk penerimaan masa depan, tanpa mengubah HPP penjualan lama.
Reversal memakai snapshot lama dan dapat membuat pool baru kembali incomplete.
Checkout, receipt reversal, opname hitung langsung dan waste menjaga quantity,
batch, cost status dan ledger dalam transaksi yang sama.

Migrasi17 menambahkan flag legacy default1 dan before flag operasi; kolom lama
tidak ditulis ulang. Micros non-null pada flag0 hanya proyeksi ledger/reversal,
bukan HPP/aset/laba yang boleh ditampilkan. Detail domain, batas presisi dan
rekonsiliasi pada [keputusan biaya](decisions/M53_UNKNOWN_COST.md).

Rekonsiliasi seluruh saldo memerlukan quantity/revision terkini, total biaya,
alasan dan konfirmasi biaya0. Event append-only selalu tercatat, termasuk saat
delta numerik0. Tab riwayat valuasi mempunyai cursor/index sendiri dan menampilkan
total baru. Delta ledger dari before unknown tetap berstatus incomplete, sehingga
tidak disajikan sebagai selisih finansial diketahui.

Laporan seluruh periode mengembalikan HPP/laba nullable bila ada dokumen unknown,
dengan jumlah dokumen penjualan/reversal terkait. Nilai persediaan nullable
disertai jumlah produk tracked incomplete; untracked999 dikeluarkan dari aset.
CSV/XLSX memakai biaya kosong + cost_status, coverage metric dan basis biaya.
Validator restore memeriksa flag, relasi header/item, unknown reference/receipt,
empty pool dan event valuasi tanpa mempercayai CHECK dari berkas impor.

## Pemeriksaan aktual

| Pemeriksaan | Hasil |
|---|---|
| Regresi host setelah perbaikan fixture |66PASS1:28 |
| Biaya+UI final |15PASS45s; overlap66 |
| History/migration follow-up host |14PASS24s;10biaya+4followup,2case overlap |
| Fractional pack focused |1PASS4s; overlap kasus pack |
| DV SQLCipher biaya |10PASS2:34;531entri protected lama cocok |
| DV UI sintetis |5PASS1:59;542entri cocok |
| DV history2+UI1+migration1 |4PASS1:36;547entri cocok |
| DV fractional pack focused |1PASS26s;554entri cocok |
| Poco SQLCipher biaya |10PASS2:06;487entri cocok |
| Poco history2+UI1+migration1 |4PASS59s;498entri cocok |
| Analyzer/format/lokalisasi |No issues94,2s;175files/0changed;738key/492staticref/245ID asli PASS |

Native berjalan hanya lewat runner audited dengan package `.integration`, flag
isolasi + background pause, `--no-uninstall`, DB fixture baru milik testcase,
tanpa root. Semua wrapper yang selesai controlOff dan awake DV pulih/readback
exact. Hash hanya membuktikan interval/scope protected databases/no_backup yang
dinyatakan wrapper; metadata WorkManager dan lease terdokumentasi terpisah.

Build debug integration ARM32/ARM64 berhasil. Ordinary debug/release terakhir
yang diverifikasi tetap checkpoint schema16, tanpa install. Build ordinary dan
release final/handoff `.skybee` tetap bagian H setelah seluruh A–H selesai.
Uji widget menggunakan callback/keyboard sintetis pada SQLCipher native; bukan
bukti sentuhan/IME OEM atau cetakan fisik. Tidak menunggu72jam alami.

## Temuan, perbaikan dan retest

- Regresi awal114PASS19FAIL2:14:18kasus cashier memakai fixture phone00123 yang
  sudah invalid menurut validasi M52;1ekspor mengharapkan129row sebelum2coverage
  metric. Nomor fixture menjadi nomor sintetis valid, draft raw tetap diperiksa
  dan customer E164 diperiksa; ekspor sekarang131row. Retest66PASS.
- UI awal19PASS3FAIL1:57: dua finder baru lupa suffix currency(IDR), satu tes
  lama perlu mengikuti konfirmasi biaya0. Finder dan langkah persetujuan diperbaiki;
  retest66PASS, lalu15PASS setelah warning tap scroll ditutup.
- Audit diff menemukan perubahan encoding pesan ARB lama; pesan baseline UTF8
  dipulihkan, hanya10key baru ditambahkan dan generated localization diperbarui.
  Audit bilingual dan analyzer lulus; build salah tidak dipasang ke user package.
- Audit menemukan selisih semu pada rekonsiliasi unknown serta pengecualian dus
  positif yang membulat0 per pcs. History ledger diperbaiki, event0 terbaca pada
  tab terpisah; host/native follow-up dan focused pack lulus sesuai tabel.

Semua raw failure/retry/log/APK tetap privat di `build/m53` dan direktori run;
tidak dimasukkan Git. Ringkasan [terkurasi](evidence/m53-20261026/cost-validation.json) dan
[source checksums](evidence/m53-20261026/cost-source-sha256.json) tersedia,
tanpa DB/key/PIN/token atau data bisnis pengguna.

## Pekerjaan yang masih diperlukan

Transisi tracked dengan saldo nonzero masih menolak penghentian tracking; perlu
penutupan tracking eksplisit yang menyimpan qty/batch/nilai, terpisah dari selisih
fisik. Jangan menggunakan opname0 fiktif untuk mematikan tracking. Onboarding
belum diimplementasi; [desain berikutnya](decisions/M53_ONBOARDING.md) tersedia.
Sisa B serta C–H tetap aktif. Biaya ini merupakan checkpoint, bukan penutupan
M5.3 atau klaim backup portable/handoff seluruh penambahan sudah diterima.
