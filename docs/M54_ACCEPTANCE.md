# Matriks implementasi dan acceptance M5.4

Kontrak lengkap: [M54_REQUEST](decisions/M54_REQUEST.md). `Pending` berarti belum
dibuktikan; baseline M5.3 bukan PASS fitur M5.4. Kasus host, native per-device,
input OS/hardware, Drive nyata dan handoff dicatat terpisah.

| Catatan | Implementasi yang dituju | Bukti wajib | Status/batas |
| --- | --- | --- | --- |
| 1 | Adapter kamera tap-focus/crop/orientasi | supported/fixed-focus, Poco fisik | Area fokus kamera belakang dan fallback terkompilasi pada APK fixture; optik fisik belum diuji |
| 2 | Counter target persisten3/5/8, owner unlock | paralel/restart/rotasi/restore/clock | Implemented, host4+ownerUI PASS; native4+ownerUI Poco/DV PASS; reboot/rotasi lengkap pending |
| 3 | Retur sale/garansi/karantina/refund | 5→1→4, debt-first, race/reversal | Host dan fixture DV/Poco lulus retur parsial, garansi, batas kuantitas, ketergantungan reversal dan refund. Cetak fisik terbuka. |
| 4 | Grafik+tabel laba kotor | bucket/timezone/unknown/export | Host dan DV/Poco lulus batas kalender, periode kosong, biaya belum lengkap, indeks dan ekspor semua halaman. Benchmark Windows 100.000 penjualan tercatat di checkpoint. |
| 5 | QRIS statis konfirmasi manual/split | amount invalidation/cash-only drawer | Host lulus penyimpanan gambar, invalidasi nominal, split dan laci khusus tunai. Split manual dan posting laci lulus fixture DV/Poco. |
| 6 | Foto nota terenkripsi | EXIF/AEAD/orphan/portable restore | Host dan DV/Poco lulus validasi, rollback, kontrol akses dan pemulihan lintas kunci dengan lampiran. Pengambilan foto fisik terbuka. |
| 7 | Recovery24kata/PDF1halaman/QR | vektor BIP39/legacy/render/decode | PIN segar dan pemisahan pemindai lulus host. DV/Poco lulus render PDF ID/EN dan pemulihan arsip. Visual A4 dan payload ZXing diperiksa pada PDF Poco. SAF, Bagikan dan pindai fisik terbuka. |
| 8 | Field invalid pertama | form nyata ID/EN320px/text2 | Host UI2 dan native Poco/DV/Realme lulus |
| 9 | Histori penerimaan tanggal+jam/biaya | unit/currency/pagination/unknown | Host dan DV/Poco lulus migrasi, snapshot biaya per pcs, pemasok, expiry, reversal, biaya kosong dan pagination. |
| 10 | Rak sah atau error eksplisit | add/edit/draft/repository | Host UI/repository PASS; add/edit navigasi lengkap pending |
| 11 | Biaya dan grosir < retail | equality/greater/unknown/pack precision | Host 4 currency dan repository, termasuk biaya referensi sama dengan harga jual; native fondasi Poco/DV; jalur edit referensi native pending |
| 12 | Member nama+HP | normalized phone/nama sama | Host lulus nama, prefix nomor HP, normalisasi unik dan nama sama. Widget checkout memilih hasil nama/nomor. |
| 13 | Pilihan Code128/QR label | dots/quiet zone/58/80/profil | Host lulus margin dan penolakan media sempit. ZXing DV/Poco membaca raster QR dan Code 128 58/80 mm. Cetak fisik terbuka. |
| 14 | Opname manual+scan | replacement/add/NULL0/conflict/batch | Regresi service dan widget host lulus untuk manual, barcode simulasi, 0 eksplisit, Undo, konflik dan pemilihan batch. Scanner fisik terbuka. |
| 15 | Tombol pecahan kembalian | plus/minus/undo/currency/commit | Host lulus editor pecahan ID/EN dan EUR. Fixture DV/Poco lulus penghitungan, validasi, pengurangan dan Undo. |
| 16 | Potongan pembulatan tunai | 86750→86500/split/debt/return | Host dan fixture DV/Poco lulus split, pembulatan turun dan posting kas yang idempoten. Alokasi retur dan piutang juga diuji di host. |
| 17 | Riwayat member | sale/return/payment/date/seek | Host dan DV/Poco lulus riwayat penjualan, retur, refund, dan pelunasan. Widget host memisahkan aksi lihat dan Edit. |
| 18 | Prioritas gate sesuai route | management-only resume/cashier Back | Host dan fixture Poco/DV lulus. Realme lulus gate Kelola, pemulihan draft dan PIN Kasir saat Back. Lifecycle fisik terbuka. |
| 19 | Satu tombol bahasa promo | ID/EN/draft | Host tab/form satu kontrol terlihat dan draft bertahan setelah perubahan bahasa |
| 20 | Tap kategori/detail; Edit terpisah | filter/semantics/no longpress | Host tap terfilter dan tombol Edit terpisah; native arsip/navigasi pending |
| 21 | Sort gudang | name/modified/popularity/seek | Host dan DV/Poco lulus sort, filter gabungan, cursor dan pengurangan retur. Widget ID/EN 320 px skala teks 2 lulus di host. |
| 22 | Hard-delete arsip terproteksi | fresh owner/eligible preview/FK/race | Host dan DV/Poco lulus arsip berlingkup, pembatalan, PIN pemilik, validasi dependensi, FK dan rollback. Widget pratinjau diuji di host. |
| 23 | Drive error tahap spesifik | SDK/native picker/cloud terpisah | Mock SDK di host dan DV/Poco mencakup akun, izin kosong, hasil ambigu, konfigurasi dan callback lama. Pemilih akun dan akses Drive nyata masih terbuka. |
| 24 | Arsip produk semua scope | commit/reopen/undo/stale checkout | Host commit/reopen, scope daftar, pencarian Kasir, Undo, pesan draft lama, histori utuh; Favorit dan native pending |
| 25 | Penerimaan15/12/20 | scan/manual/new product/retry/cash capability | Host lulus untuk 27 scan, pencarian, batal/daftar Sunco, kurang/Undo, konfirmasi idempotent dan pembayaran awal gudang. ID/EN 320 px skala 2 lulus. HID fisik dan acceptance perangkat terbuka. |
| 26 | Draft retur supplier reservasi | 3dari5→2/partial/unknown/untracked | Host dan DV/Poco lulus reservasi, checkout stok bebas, parsial, asal belum diketahui, dan kredit ledger. Perbaikan bind Android lulus tes ulang. Widget barcode dan persetujuan diuji di host. |
| 27 | Produk–supplier many-to-many | migration/no duplicate value | Host dan DV/Poco lulus relasi banyak supplier, backfill data terisi, pencarian dan nilai stok tunggal. Form chip diuji di host. |
| 28 | Tap rak/detail; Edit terpisah | filter/suggestion/draft | Host tap terfilter dan tombol Edit terpisah; suggestion/draft host; native navigasi pending |
| 29 | Pulihkan member | conflict/role/zero new debt | Regresi host memeriksa pemulihan, konflik nomor, akses dan utang lama. |
| 30 | Filter member punya utang | effective current balance | Host lulus saldo efektif sesudah pelunasan dan pengurangan piutang oleh retur. |
| 31 | Sort member | name/new/visits/debt/seek tie | Host lulus sort nama, waktu dibuat, kunjungan dan saldo, serta cursor terikat scope. |
| 32 | Kamera pencarian gudang | permission/no camera/stale callback | Lookup dan callback lama diuji pada suite routing; izin/perangkat fisik belum dibuktikan |
| 33 | Kebijakan kas persisted/clean form | session state/cancel/failure/race | Implemented; host48PASS termasukUI2 ID/EN320/text2; native7 Poco dan7 DV PASS; hash/awake/controlOff PASS |
| 34 | Scanner routing/PIN/modal/Enter | HID+commitText/no truncated PIN | PIN raw/Enter/burst host4 dan native4 fondasi PASS; field/focus/setup/SQL guarded host81unik viaretest PASS; native 21 kasus unik Poco dan 21 DV lulus; HID fisik dan OEM belum teruji |
| 35 | Favorit6–8 | cached stats/active/stock/expired/return | Host lulus cache, 8 slot, kelayakan, reservasi dan penambahan satu pcs per tap. Widget ID/EN lulus fokus dan keranjang. Acceptance native terbuka. |

Pada 9 November 2026 WIB, DV8910 lulus 35 kasus unik dari dua interval.
Poco lulus 22 kasus acceptance dan 13 kasus keluaran sebelumnya. Semua
audit hash terlindungi cocok. Cadangan skema 54 dengan lampiran pulih
lintas kunci dan fixture arsip format lama bermigrasi. Analyzer,
lokalisasi, lisensi dan APK biasa tiga ABI dengan alignment 16 KiB lulus.
Realme C11 lulus 35 kasus acceptance, 48 pemeriksaan alur/input, dan
satu benchmark SQLCipher. Hash berkas terlindungi cocok. Perbaikan
terbatas pada alat uji, sehingga pengujian regresi aplikasi tambahan di
DV8910/Poco tidak diperlukan. `.skybee` 0.5.4+14 terpasang in-place
di Poco dan mencapai Kasir pada dua cold start. Uji fisik, Drive nyata,
dan APK Uji Teman masih terbuka.
Rincian interval dan bukti tersedia di [checkpoint](M54_CHECKPOINT.md).

Backup manual Drive 0.5.4+15 memperbaiki penguncian ulang saat membuat
snapshot. Fixture Poco membuktikan ekspor terenkripsi, verifikasi
upload simulasi, dan pengulangan tanpa duplikasi. Upload ulang pada
akun Google pengguna belum terverifikasi.

Pada 0.5.4+16, peringatan penolakan arsip untuk stok terlacak dan
pencarian angka `066` lulus regresi host serta fixture DV8910 dan Poco.
Setelah arsip berhasil, barang berpindah dari daftar aktif ke Arsip dan
keluar dari pencarian Kasir.

Bukti dan failure awal: [M54_FOUNDATION_REPORT](M54_FOUNDATION_REPORT.md).
85kasusunik host melalui runs/retests bukan acceptance seluruh M5.4.
