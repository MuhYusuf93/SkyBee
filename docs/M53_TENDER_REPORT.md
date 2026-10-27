# M5.3 — checkpoint tender, belum handoff akhir

Source +12/schema 21 setelah checkpoint kunci kasir `6c9e5a3`. Paket Eksplorasi
Mandiri masih +12/schema 14 tanpa update, reset, atau reseed. [Aturan tender](decisions/M53_TENDER.md).

Tender menyimpan jumlah pecahan, nominal tanpa rincian dan intent Uang pas;
tombol tambah/minus/bersihkan, `000`, pergantian tampilan dan editor nominal cepat
publik tersedia. Rincian ikut transaksi checkout dan cadangan. Back terkunci
mengenali perubahan formulir publik dengan warning generik, tanpa membuka Kelola.

Host awal 8 PASS (18 detik). Followup 9 PASS/2 FAIL: fixture mencoba mengubah
completed draft yang memang dijaga trigger dan memakai nama kolom stok keliru.
Fixture diperbaiki; untuk simulasi arsip rusak, guard hanya dilepas pada database
temp baru milik kasus tersebut. Acceptance berikut 13 PASS/1 FAIL (27 detik):
helper UI membaca count sebelum antrean save/notifikasi selesai. Helper kini
menunggu antrean persist, dengan assertion bisnis tetap.

Regresi 26 PASS (1:26), mencakup tender UI tiga kasus, M5.1 cash, provider/layout,
dan enam UI kunci kasir. Analyzer bersih (85,4 detik); audit 820 kunci bilingual,
544 referensi statis dan 245 ID persyaratan asli. Final acceptance menambah layout
320 px/text2x ID/EN serta migrasi populated 14→21 dengan rollback kegagalan dan
retry `cash-v1` lama. Final acceptance 17 PASS (1:01): SQL 11, UI 5, migrasi 1.
Format 388 file tanpa perubahan; source 474 file dibekukan untuk native.

Native hanya melalui wrapper terisolasi dengan `KASIR_FIXTURE_BACKGROUND_PAUSED`,
baseline hash seluruh data terlindungi sebelum/sesudah. DV 17 PASS (4:37), seluruh
622 hash protected lama cocok, kontrol otomatis berakhir dan pengaturan awake
dipulihkan dengan readback exact. Poco 17 PASS (2:59), seluruh 567 hash lama cocok
dan kontrol otomatis berakhir. Source 474 file identik pada kedua run.
Analyzer final retry `--no-pub` bersih (66,9 detik); invocation sebelumnya tertahan
sebelum analisis lalu diinterupsi, tidak dihitung sebagai PASS. Raw log tidak diubah.
Build ordinary/release final belum diklaim. [Validasi terkurasi](evidence/m53-20261026/tender-validation.json)
dan [source checksum](evidence/m53-20261026/tender-source-sha256.json) tersedia;
raw logs/database/keys tetap privat. Member/pencarian C,
jurnal laci D, serta E–H tetap aktif sampai handoff M5.3.

Pada lanjutan member C, lengkapi warning checkout untuk perubahan RAM ketika
autosave masih antre/gagal saat lock; tender yang sudah tersimpan tetap dipulihkan.
Ini belum acceptance seluruh variasi formulir dan belum jurnal laci/audit D.
