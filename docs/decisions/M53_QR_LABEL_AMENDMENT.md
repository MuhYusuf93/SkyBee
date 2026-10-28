# Ralat pengguna — output label QR code

29 Oktober 2026 pengguna meminta pekerjaan tetap berurutan sampai handoff M5.3
dan meralat bagian8: output cetak label memakai QR code, menggantikan barcode.
Ketentuan lain tetap sama. Checkpoint menyimpan kelanjutan, bukan alasan berhenti
ketika pekerjaan aktif masih dapat dilanjutkan.

Bagian8.2–8.4 pada kontrak repository diselaraskan: label baru memakai QR code,
payload identitas produk yang stabil untuk lookup literal, nama/kode dan harga
opsional. Bukan URL atau perintah. Kode produk, leading zero, transaksi/snapshot
lama dan dukungan pembacaan kode produk yang sudah ada tetap dipertahankan.

Quiet zone, ukuran modul, batas kepadatan, scaling, preview ukuran fisik/jumlah,
profil/protokol/transport, gap capability dan pengujian encoder–decoder tetap
wajib. QR label sendiri harus dapat dibaca jalur lookup bersama; input scanner
yang sudah didukung tetap berlaku. Implementasi F dilakukan sesudah E3 sesuai
urutan, tanpa merombak desain atau kebijakan struk lain.

Alasan keterbacaan berasal dari preferensi pengguna, bukan hasil uji hardware.
Keterbacaan scanner fisik harus dibuktikan pada perangkat yang benar-benar
tersedia; uji decoder sintetis tidak boleh dilaporkan sebagai bukti scanner fisik.
