# E2 — draft penerimaan banyak barang

Source0.5.2+12/schema28 setelah da719c8: dokumen27 ditambah guard stok28.
Ini checkpoint penerimaan multi-item;
opname, keuangan supplier E3 dan seluruh F–H masih aktif.
[Keputusan implementasi](decisions/M53_RECEIPT_DOCUMENTS.md).

Gudang kini mempunyai daftar draft/terkonfirmasi/dibatalkan dengan halaman
20+1 dan cursor status/generation/revision, serta draft durable maksimal100baris.
Scan menambah1unit dasar, menyimpan input saja. Baris kemasan dipertahankan;
batch ambigu memerlukan target atau baris terpisah. Unknown membuka formulir
barang sebenarnya dengan stok awal0 yang terkunci, kemudian kembali ke draft.
Edit baris memakai editor harga/kemasan/expiry yang sama. Supplier transaksi
tetap terpisah supplier master; biaya draft yang sudah diisi tidak dihapus
hanya karena preferensi tampilannya berubah.

Konfirmasi memeriksa seluruh baseline lalu mencatat satu header dan seluruh
item/batch/nilai/history/audit dalam satu transaksi writer lama. Retry tidak
menambah stok. Perubahan master/stok menolak commit; tinjauan ulang baseline
mempertahankan input sebelum konfirmasi berikutnya. Untracked mencatat actual
pembelian dan acuan biaya tanpa batch, historyquantity999 atau aset999. Unknown
tetap unknown, gratis0 memerlukan persetujuan. Batas integer biaya diuji.

Provenance operasi langsung menunjuk receipt item, termasuk beberapa baris produk
yang sama. Harga pembelian terakhir mengikuti stock_revision_after, sehingga
timestamp sama dan ID acak tidak memilih harga lama; reversal/tracking opening
tetap bukan pembelian baru. Reversal seluruh dokumen memakai preview semua
baris, alasan dan pilihan eksplisit; alur detail satu produk menolak membalik
produk lain. Mutasi stok/biaya berikutnya menghalangi reversal seluruhnya.
Backup menambahkan preflight metadata, batas dan relasi dokumen secara readonly.

Host acceptance23 PASS30s: dokumen8, UI dokumen2, harga SQL5, input state5,
editor receiving lama3. Uji migrasi26 membandingkan semua kolom dari semua tabel
lama sebelum unlock baru dan memverifikasi retry payload lama. UI ID/EN memakai
320px/text2x/keyboard, save/open draft, dirty lock/Back, unknown product stock0,
konfirmasi dan receipt tepat satu. Analyzer bersih7,2s, format477/0changed;
l10n996keys/669refs/245RIDs, PIN106upstream/license sama. Regresi inventory,
M52/money/backup metadata45 PASS1:19. [Bukti host](evidence/m53-20261026/receipt-document-host-validation.json).
Source573 native DV23 PASS6:04,746hash lama cocok/controlOff dan awake pulih
tepat. Poco21PASS2UIFAIL4:04,668hash lama cocok/controlOff; kegagalan reveal
kolom kode tetap disimpan, bukan kegagalan isolasi.
[DV awal](evidence/m53-20261026/receipt-document-dv.json),
[Poco awal](evidence/m53-20261026/receipt-document-poco-initial.json),
[source573](evidence/m53-20261026/receipt-document-source-sha256.json).

Audit lanjutan menemukan checkout mengubah stock_revision tanpa master revision.
Writer tetap additive/atomic, tetapi draft lama belum meminta review sesudah
penjualan. Migrasi aditif28 menambah baseline stock_revision nullable: NULL pada
draft lama tetap tidak diketahui, wajib Tinjau ulang, tanpa backfill tebakan.
Dokumen memeriksa kedua revision dan editor tunggal meneruskan snapshot stok.
Legacy retry hash tanpa argumen baru tetap sama. Fixture27 mereproduksi gap,
menyimpan receipt posted+draft pending dan membandingkan kolom lama8tabel setelah
migrasi; penjualan lama tidak berubah setelah review/confirm/retry.

Source28 host71 PASS1:31 (receipt26+regresi45), kemudian focused5 PASS19s untuk
tambahan assert migrasi dan gulir pada ukuran jendela asli sebelum resize.
Analyzer bersih7,2s/format480/0, l10n/PIN sama.
[Bukti guard](evidence/m53-20261026/receipt-stock-host-validation.json).
Poco focused5 PASS2:09,689hash lama cocok/controlOff; source576 identik.
[Poco perbaikan](evidence/m53-20261026/receipt-stock-poco.json).
DV focused5 PASS2:58,767hash lama cocok/controlOff/awake pulih tepat.
[DV perbaikan](evidence/m53-20261026/receipt-stock-dv.json),
[source guard](evidence/m53-20261026/receipt-stock-source-sha256.json).
Reveal viewport sintetis memakai jumpTo bounded;
button tetap actual widget tap/hit-test. Ukuran jendela asli juga diuji dengan
synthetic drag ketika ada overflow. Tidak mengklaim sentuhan fisik ADB/OEM.

Pemeriksaan legacy ambiguity tambahan mereproduksi0PASS1FAIL9s, lalu diperbaiki:
receipt ambigu tetap menjadi sumber latest dengan biaya unknown dan item/pack
NULL, sehingga tidak mempromosikan harga known yang lebih tua. Direct item link
baru tetap tepat. Businessrows6tabel sebelum/sesudah hint26/28 identik.
Host hint6+doc8=14 PASS38s, analyzer bersih68,7s/format480/0/l10n/PIN sama.
[Bukti host akhir](evidence/m53-20261026/receipt-legacy-host-validation.json).
Native hanya delta SQL1: Poco PASS31s/696hash lama cocok/controlOff, DV PASS40s/
774hash lama cocok/controlOff/awake tepat. [Poco akhir](evidence/m53-20261026/receipt-legacy-poco.json),
[DV akhir](evidence/m53-20261026/receipt-legacy-dv.json),
[source akhir](evidence/m53-20261026/receipt-legacy-source-sha256.json).
Manifest akhir juga576 berkas tetapi hash berbeda dari guard; hanya query hint
dan suite pengujiannya berubah. Bukti tiap lapisan dipertahankan, tidak dianggap
satu run atau dijumlahkan sebagai kasus unik. Semua wrapper sudah exit dan
kontrol otomatis berhenti; tidak ada runner aktif pada checkpoint20:28.

Riwayat kegagalan/perbaikan dipertahankan: sync denial harus ditangkap sebagai
closure; nullable fold dan bracket/arg helper SDK diperbaiki; timestamp tie
mengungkap bug actual harga terakhir dan diubah ke revision order. Helper UI
sempat menggulir text-scroll horizontal, menunggu child lazy sebelum reveal,
atau membaca indikator di luar viewport. Kini menunggu state/aksi nyata,
memilih scrollvertikal, restart dari atas dan memeriksa hit-test setelah pump.
List header tetap dan subtitle panjang membuat viewport kecil; diganti satu
area gulir/status ringkas dan bantuan expandable. Dialog Back ID overflow12px
karena action panjang; action kini ikut bergulir dengan penjelasan. Form baru
menunggu policy selesai; rapid pointer kedua memeriksa apakah save pertama
sudah menutup editor. Assertion stok/biaya/isolasi tidak dilonggarkan.

Panduan ID: di Gudang pilih ikon Draft barang masuk, Buat draft, lalu ketik/pindai
kode. Kode sama menambah1unit dasar; ketuk baris untuk mengubah quantity, kemasan,
biaya atau expiry. Pilih supplier bila diperlukan. Draft tersimpan tanpa mengubah
stok. Periksa semua baris lalu Konfirmasi barang masuk. Jika baseline berubah,
pilih Tinjau ulang, periksa input dan konfirmasi lagi. Tab Terkonfirmasi membuka
receipt lama dan reversal seluruh dokumen dengan alasan bila belum ada dependency.
Barcode bukan identifikasi batch fisik atau bukti pcs belum pernah dipindai.

English: open Receiving drafts from Inventory, create a draft and type or scan a
code. Each accepted scan adds one base unit. Tap a line to edit quantity, pack
size, cost or expiry; select an optional purchase supplier. Saved drafts do not
change stock. Review every line, then confirm the entire receipt. Review changed
baselines explicitly before confirming again. The Confirmed filter reopens old
documents and offers whole-document reversal with a reason when dependencies
allow it. Product barcodes do not identify a physical batch or prove uniqueness.

Poco tersedia kembali sejak28Oktober18:40 dan setiap run memakai baseline
protected baru; bukan kembali ke snapshot/seed sebelum pemakaian pribadi.
Tidak ada update/reset/reseed paket eksplorasi .skybee+12; schema14 adalah
baseline terpasang terakhir yang diketahui, bukan hasil migrasi M5.3 baru.
Preservasi berkas berlaku pada setiap interval wrapper di atas.
Kamera fisik, sentuhan ADB/OEM keyboard dan printer bukan bukti widget suite.

Berikutnya: stocktake draft/countNULL-vs0/recount/batch/undo, supplier invoice/
payment/physical return/approved credit/schedules, F output/reports, G portable
backup/retention/reset fixture dan H build/install/handoff. Rancangan private
build/m53/stocktake-next-design.md bukan implementasi dan tidak boleh dilaporkan PASS.
