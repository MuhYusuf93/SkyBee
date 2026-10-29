# F2 — kebijakan wajib struk (schema36)

Kontrak bagian8: [M53_REQUEST](M53_REQUEST.md). Penjualan tetap commit sekali;
printer berjalan sesudahnya. Default kebijakan nonaktif, owner-only CAS. Jika
aktif pada commit, requirement immutable merekam sale/policy revision/timestamp.
Toko/transaksi lama tidak diberi kewajiban hasil tebakan. Mematikan kebijakan
hanya memengaruhi penjualan berikutnya, bukan menghapus kewajiban yang tercatat.

`receipt_print_gate` singleton adalah projection pending, bukan scan seluruh
histori pada setiap keranjang. Checkout baru dan `Cart.next` memeriksa gate;
retry checkout lama tetap mengembalikan sale yang sama. Startup dengan pointer
hilang memulihkan receipt pending sebelum draft aktif lain. Requirement, stok,
payments, receipt snapshot dan completed draft berada dalam transaksi atomik.

Byte/ACK/submitted bukan bukti kertas keluar. Operator boleh mengonfirmasi
setelah pemeriksaan kertas, dengan job submitted/unknown yang benar-benar milik
sale sama. Prepared/failed, calibration, label atau sale lain ditolak. Job
eligible sebelumnya tetap bisa dikonfirmasi walau copy terbaru gagal. Tidak ada
autoretry ambigu. Konfirmasi manual tidak diberi label verifikasi fisik otomatis.

Pengecualian satu sale membutuhkan alasan dan fresh owner proof dengan purpose
`receiptException`, bukan grant Gudang/kasir atau security proof generik. Proof
sekali pakai tetap dilepas bila validasi gagal. Proposal alasan boleh disiapkan
kasir; PIN hanya ditangani layar autentikasi yang ada. UI mengunci kembali grant
pemilik sesudah tindakan agar tidak ditinggalkan untuk kasir. Histori protected
merevalidasi owner context; konfirmasi kasir mematuhi CashierLock proof.

Resolution append-only menyimpan actor, intent hash dan witness job/status atau
alasan. Witness tidak FK ke queue karena restore sengaja menghapus queue/binding
perangkat. Konfirmasi selesai tetap sah sesudah sanitization; obligation pending
tetap pending tanpa autoreplay. Validator membandingkan full ledger dan projection
secara bounded. Tidak ada mutasi stok/HPP/piutang/uang dalam fulfillment.

Host domain13PASS56s termasuk migration35→36/semua rows lama, atomic rollback,
wrong job/sale, stale history/cashier lock, fresh purpose, invalid input consuming
claim, append-only, queue-sanitized witnesses dan forged projection. Regresi
legacyqueue13PASS terpisah dalam invocation yang gagal load fixture baru (helper
local function dideklarasikan terlambat, diperbaiki); log gagal dipertahankan.
UI ID/EN320px/text2 sedang diperiksa. Harness awal memakai context di atas scoped
CartProvider dan sempat menganggap parent offstage sebagai selesai ketika PIN
masih terbuka. Fixture print memakai transport/lease sendiri untuk menghindari
static ProcessPrinterGate Future berpindah FakeAsync zone antar-widget test;
domain/native tetap menguji gate produksi. Regresi/final host serta native41
Poco dan DV pada source683 kini lulus; lihat [laporan](../M53_RECEIPT_POLICY_REPORT.md).
Belum buildhandoff atau bukti fisik.

F3/G/H tetap aktif. `.skybee` tidak diupdate/reset/reseed. Reset100produk/50sale
hanya pada H sesudah seluruh M5.3 dan encrypted backup/material pemulihan verified.
