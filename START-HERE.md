# Cara memulai

Paket ini berisi dokumen pengarah Codex, bukan implementasi aplikasi Flutter. Spesifikasi lengkap berada di `docs/SPEC.md`. `AGENTS.md` sengaja ringkas; rencana dan status dapat diperbarui selama pengembangan.

1. Tempatkan isi paket di folder proyek yang akan dibuka oleh Codex. Bila proyek sudah memiliki aturan/dokumen, baca dan gabungkan secara sadar; jangan menimpa pekerjaan lama.
2. Berikan instruksi pertama di bawah. Ini memberi Codex seluruh konteks hasil akhir tetapi membatasi pekerjaan pertama pada fondasi yang bisa diperiksa.
3. Setelah tahap selesai, periksa skema, pembagian state, query pagination, dan hasil test. Bila ada masalah, minta perbaikan pada tahap itu. Bila sudah sesuai, berikan instruksi lanjut.

## Instruksi pertama siap salin

```text
Baca AGENTS.md, docs/SPEC.md, docs/PLAN.md, dan docs/STATUS.md.

Kerjakan hanya milestone M1: fondasi, arsitektur, skema, dan kontrak/query pagination. Gunakan seluruh SPEC sebagai konteks keputusan, tetapi jangan mengimplementasikan milestone M2–M6 pada tugas ini.

Mulai dengan meninjau workspace/toolchain, lalu perbarui rencana bila diperlukan tanpa mengurangi kebutuhan. Buat matriks docs/REQUIREMENTS.md dengan ID stabil yang memetakan seluruh persyaratan SPEC ke milestone dan bukti penerimaan. Jangan hanya menyalin judul bagian.

Lanjutkan implementasi file proyek sampai kriteria M1 selesai. Prioritaskan batas Provider, penamaan SaleTransaction/sale_transactions, migration/foreign key, uang dengan presisi yang benar, dan keyset pagination dengan tie-breaker/index. Jangan menulis seluruh proyek sebagai kode dalam chat.

Jalankan pemeriksaan M1, perbaiki kegagalan yang dapat diperbaiki, dan perbarui STATUS serta REQUIREMENTS. Pada akhir tugas laporkan file penting, keputusan arsitektur, hasil aktual perintah, batas pengujian, dan pekerjaan yang siap dilakukan pada M2. Jangan mengklaim fitur tahap berikutnya sudah selesai. Jika toolchain menghalangi bagian tertentu, catat dengan jelas dan lanjutkan pekerjaan M1 yang independen.
```

## Instruksi setelah review tahap

```text
Baca ulang AGENTS.md, docs/SPEC.md, docs/PLAN.md, docs/STATUS.md, dan docs/REQUIREMENTS.md.

Kerjakan hanya milestone berikutnya yang saya minta: M2. Gunakan hasil M1, perbaiki dependensi yang diperlukan, dan jangan mengerjakan ulang proyek dari nol. Selesaikan implementasi serta validasi milestone ini, perbarui status/matriks berdasarkan bukti, dan laporkan hasil aktual. Jangan memperluas tugas ke milestone lain.
```

Ganti M2 dengan milestone yang sedang diminta. Untuk melanjutkan tahap yang terhenti, sebutkan milestone yang sama dan minta membaca langkah berikutnya dari STATUS. Tidak perlu menyalin ulang seluruh spesifikasi di setiap pesan.

## Cara menilai hasil

- Periksa file/diff dan jalankan aplikasinya, jangan hanya membaca jawaban chat.
- `Implemented` berbeda dari `verified`; uji printer atau Drive yang belum dijalankan tetap berstatus belum terverifikasi.
- Ringkasan test harus menyebut perintah dan hasil. Keterbatasan lingkungan dicatat, bukan disamarkan sebagai kelulusan.
- Review berfokus pada kebutuhan yang dipetakan di REQUIREMENTS. Temuan baru dicatat agar sesi berikutnya tetap mempunyai konteks.
