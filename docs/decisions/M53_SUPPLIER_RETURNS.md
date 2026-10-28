# E3 — retur fisik supplier

Schema32 aditif mempertahankan seluruh tabel stok/kas/penerimaan lama. Retur
adalah dokumen fisik terpisah dari kredit yang disetujui atau refund. Tidak
mengubah penjualan, HPP snapshot, pembayaran supplier, atau saldo kas secara
otomatis. Persetujuan kredit/refund berada pada langkah E3 berikutnya.

Draft maksimum100baris berasal dari satu penerimaan pembelian yang tercatat,
dengan ID item/batch yang dapat ditelusuri. Supplier transaksi asli dipakai;
jika kosong, hanya supplier dari rekonsiliasi invoice historis owner yang
eksplisit dapat menjadi sumber, dengan FK invoice disimpan. Supplier master
produk tidak digunakan untuk menebak supplier pembelian. Opening stock dan
receipt yang sudah dibalik tidak eligible.

Setiap baris menyimpan revisi master/stok saat dipilih. Konfirmasi memeriksa
ulang sumber, jumlah kumulatif yang masih boleh diretur, batch asal, saldo
fisik, currency dan grant di dalam satu transaksi. Konflik meminta tinjauan
eksplisit; tidak mengganti batch, menurunkan jumlah atau menimpa saldo diam-diam.
Draft tidak mengubah stok. Daftar sumber50baris dan daftar dokumen20 memakai
cursor terikat konteks/generation/revision; halaman mengganti halaman sebelumnya.

Nilai yang keluar mengikuti moving weighted average pool saat posting, bukan
harga receipt atau nilai refund yang kelak dinegosiasikan. Unknown tetap
incomplete; angka projection numerik bukan bukti nilai lengkap. Untracked
mencatat peristiwa retur dengan batas jumlah receipt, mempertahankan999/nilai0/
reference cost, tanpa mengklaim saldo fisik tervalidasi atau menciptakan history
stok palsu. Stok revision tetap bertambah sebagai jejak operasi.

Semua return items, inventory operations/history yang relevan dan urutan
eligibilitas sumber diposting atomik/idempotent. Ledger sumber menyimpan sequence
per receipt item, before/after returned quantity dan relasi ke return/undo item.
Timestamp identik atau UUID tidak dipakai sebagai urutan kejadian. Reversal
kemudian tidak boleh menyembunyikan over-return sebelumnya pada arsip.

Undo seluruh dokumen mempertahankan fakta lama dan menambah reversal. Restore
pool/batch persis hanya jika belum ada mutasi stok yang bergantung dan tidak ada
kredit disetujui efektif. Beberapa baris produk sama dibalik dalam urutan posting
terbalik, dengan stock revision terus meningkat. Return operations tidak memakai
stock_receipt_id sehingga undo retur tidak salah menandai penerimaan asal sudah
dibalik. FK item serta dokumen return mempertahankan provenance sumber.

Gudang boleh operasi fisik; persetujuan kredit/refund tetap owner. UI ID/EN
menyimpan alasan dan draft selama lock serta dirty Back, termasuk dialog jumlah.
Final original reason dan reversal reason ditampilkan terpisah. Daftar supplier
menyediakan alur retur tanpa mensyaratkan pembuatan invoice baru.

Validator backup32 membaca FK, sumber supplier/item/batch, snapshot biaya,
operasi/history, before/after pool dalam urutan dokumen, dan replay seluruh
source ledger dalam halaman100. Draft stale tetap boleh dicadangkan; validator
tidak menyamakan draft lama dengan stok saat ini. Native digabung dengan sisa E3
sebelum F; host bukan bukti fisik atau native baru.
