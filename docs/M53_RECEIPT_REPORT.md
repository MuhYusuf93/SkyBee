# E — harga beli terakhir dan editor penerimaan

Source0.5.2+12/schema26 setelah d5f7210. [Keputusan](decisions/M53_RECEIPT_EDITOR.md).
Ini checkpoint editor satu produk, bukan penutupan seluruh E atau handoff M5.3.

Usulan biaya kini memakai pembelian efektif terakhir dengan supplier transaksi
opsional dan total/quantity asli, bukan average persediaan. Unknown terakhir
tidak diganti harga known lama. Referensi saldo awal diberi label acuan. Angka
pecahan minor tidak dibulatkan untuk mengisi harga; basis kemasan manual dan
input unfinished/composing tetap dimiliki form. Pengingat kuning muncul hanya
ketika harga canonical sama dengan usulan actual.

Route penerimaan dari detail barang memakai editor bersama dengan field error,
focus pertama, kalender expiry, validasi harga/hard error sebelum gratis0,
supplier terpisah master, dirty Back dan privacy gate sendiri. Save atomik dan
retry memakai service lama dengan optional revision guard; master yang berubah
menolak commit sambil mempertahankan input. Async hint tidak menimpa harga manual.
Save ganda tidak menggandakan receipt. Cabang receive dialog lama yang tidak
terpakai sudah dibuang. Fitur biaya tersembunyi menerima unknown, bukan0.

Host acceptance13 PASS24s: SQL5, price-state5 dan actual-route UI3 ID/EN pada
320px/text2x/keyboard. Mencakup supplier/last-unknown/free/reversal/reference,
CAS/idempotency, konversi dan unfinished IME, validasi/focus, lock/Back, cancel
gratis dan commit gratis, cost-hidden dan tidak ada mutasi sebelum Save.
Regresi inventory/form/uang43 PASS1:20; analyzer bersih6,5s, format467/0changed,
l10n965keys/649refs/245RIDs dan PIN106upstream/license sama.
[Bukti host](evidence/m53-20261026/receipt-host-validation.json).

Native DV13 PASS2:51 melalui wrapper resmi; seluruh737 hash berkas protected
lama cocok, runner exit0/controlOff dan awake dipulihkan/readback tepat. Source563
berkas identik sebelum/sesudah run. [Bukti DV](evidence/m53-20261026/receipt-dv.json),
[manifest source](evidence/m53-20261026/receipt-source-sha256.json). Semua mutasi
memakai fixture numerik baru pada package integration, background paused.
Paket eksplorasi .skybee+12/schema14 belum diperbarui/reset. Preservasi tersebut
adalah bukti interval run DV ini, bukan klaim pengamatan aktivitas pribadi Poco.
Poco delta DEFERRED karena dipakai pribadi, sesuai
[checkpoint Poco](M53_POCO_CHECKPOINT.md).

Riwayat gagal tetap pada log lokal: pembandingan identitas Money diperbaiki ke
minor/currency/scale; field disabled menolak focus, diperbaiki frame enabled
sebelum reveal; dialog Back terkunci overflow di320px/text2x, diperbaiki scrollable.
Harness rapid-tap yang kedua menargetkan tombol tertutup dialog gratis; dibetulkan
dengan cancel/confirm dialog aktual, rapid-tap tetap diuji pada kasus lain.
Analyzer style braces diperbaiki tanpa mengubah aturan bisnis.

Panduan ID: buka detail barang, pilih Terima stok, pilih unit/isi kemasan dan
supplier transaksi bila diperlukan. Periksa asal harga dan pengingat kuning;
isi harga baru bila konversi tidak tepat. Masukkan quantity dan pilih expiry
dari kalender bila berlaku, lalu Simpan. Membuka/mengubah form belum menambah
stok. Harga0 membutuhkan konfirmasi gratis; biaya unknown tidak disamakan gratis.

English: open a product and choose Receive stock. Select the input unit, pack
size and optional purchase supplier. Check the price source; enter a new amount
when the old price cannot be converted exactly. Enter quantity and choose an
expiry date if applicable, then Save. Editing alone does not change stock. A
zero cost requires free-cost confirmation; unknown cost is a separate state.

Berikutnya: dokumen multi-item dan scan draft, opname/recount/batch, tagihan,
pembayaran/retur/credit/jadwal supplier, F output/laporan, G keselamatan data
dan H build/handoff. Native widget gestures bukan sentuhan fisik atau bukti
kamera/printer; tidak ada transaksi sintetis di toko pengguna.
