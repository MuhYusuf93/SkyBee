# Matriks implementasi dan acceptance M5.4

Kontrak lengkap: [M54_REQUEST](decisions/M54_REQUEST.md). `Pending` berarti belum
dibuktikan; baseline M5.3 bukan PASS fitur M5.4. Kasus host, native per-device,
input OS/hardware, Drive nyata dan handoff dicatat terpisah.

| Catatan | Implementasi yang dituju | Bukti wajib | Status/batas |
| --- | --- | --- | --- |
| 1 | Adapter kamera tap-focus/crop/orientasi | supported/fixed-focus, Poco fisik | Area fokus kamera belakang dan fallback terkompilasi pada APK fixture; optik fisik belum diuji |
| 2 | Counter target persisten3/5/8, owner unlock | paralel/restart/rotasi/restore/clock | Implemented, host4+ownerUI PASS; native4+ownerUI Poco/DV PASS; reboot/rotasi lengkap pending |
| 3 | Retur sale/garansi/karantina/refund | 5→1→4, debt-first, race/reversal | Host lulus untuk retur parsial, refund tunai/eksternal, garansi, lookup tanggal, serta penyerahan unit karantina ke supplier. Cetak fisik dan native terbuka. |
| 4 | Grafik+tabel laba kotor | bucket/timezone/unknown/export | Pending |
| 5 | QRIS statis konfirmasi manual/split | amount invalidation/cash-only drawer | Host lulus untuk penyimpanan gambar, split, invalidasi nominal, dan laci khusus tunai. Uji perangkat terbuka. |
| 6 | Foto nota terenkripsi | EXIF/AEAD/orphan/portable restore | Pending |
| 7 | Recovery24kata/PDF1halaman/QR | vektor BIP39/legacy/render/decode | Codec/UI/copy dan HKDF host PASS; PDF/share/scan khusus belum |
| 8 | Field invalid pertama | form nyata ID/EN320px/text2 | Host UI2 dan native Poco/DV PASS |
| 9 | Histori penerimaan tanggal+jam/biaya | unit/currency/pagination/unknown | Pending |
| 10 | Rak sah atau error eksplisit | add/edit/draft/repository | Host UI/repository PASS; add/edit navigasi lengkap pending |
| 11 | Biaya dan grosir < retail | equality/greater/unknown/pack precision | Host 4 currency dan repository, termasuk biaya referensi sama dengan harga jual; native fondasi Poco/DV; jalur edit referensi native pending |
| 12 | Member nama+HP | normalized phone/nama sama | Pending |
| 13 | Pilihan Code128/QR label | dots/quiet zone/58/80/profil | Pending |
| 14 | Opname manual+scan | replacement/add/NULL0/conflict/batch | Pending |
| 15 | Tombol pecahan kembalian | plus/minus/undo/currency/commit | Host lulus pada editor pecahan ID/EN dan pecahan EUR. Native terbuka. |
| 16 | Potongan pembulatan tunai | 86750→86500/split/debt/return | Host lulus untuk alokasi potongan, QRIS Rp50.000, kas bersih Rp36.500, piutang dan retur. Native terbuka. |
| 17 | Riwayat member | sale/return/payment/date/seek | Pending |
| 18 | Prioritas gate sesuai route | management-only resume/cashier Back | Implemented, host gate/dirty/back PASS; native7 Poco/DV PASS; OEM lengkap pending |
| 19 | Satu tombol bahasa promo | ID/EN/draft | Host tab/form satu kontrol terlihat dan draft bertahan setelah perubahan bahasa |
| 20 | Tap kategori/detail; Edit terpisah | filter/semantics/no longpress | Host tap terfilter dan tombol Edit terpisah; native arsip/navigasi pending |
| 21 | Sort gudang | name/modified/popularity/seek | Pending |
| 22 | Hard-delete arsip terproteksi | fresh owner/eligible preview/FK/race | Pending |
| 23 | Drive error tahap spesifik | SDK/native picker/cloud terpisah | Pending; OAuth paket perlu diperiksa |
| 24 | Arsip produk semua scope | commit/reopen/undo/stale checkout | Host commit/reopen, scope daftar, pencarian Kasir, Undo, pesan draft lama, histori utuh; Favorit dan native pending |
| 25 | Penerimaan15/12/20 | scan/manual/new product/retry/cash capability | Host lulus untuk 27 scan, pencarian, batal/daftar Sunco, kurang/Undo, konfirmasi idempotent dan pembayaran awal gudang. ID/EN 320 px skala 2 lulus. HID fisik dan acceptance perangkat terbuka. |
| 26 | Draft retur supplier reservasi | 3dari5→2/partial/unknown/untracked | Host lulus untuk 5→3+2 lintas supplier, parsial, reversal, asal belum diketahui, observasi untracked dan UI barcode 320 px skala 2. Klaim tanpa nota tersimpan tertunda. Persetujuan klaim ini dan perangkat terbuka. |
| 27 | Produk–supplier many-to-many | migration/no duplicate value | Host lulus untuk migrasi data terisi, filter dua supplier, form chip, arsip, backup dan nilai stok tunggal. Native terbuka. |
| 28 | Tap rak/detail; Edit terpisah | filter/suggestion/draft | Host tap terfilter dan tombol Edit terpisah; suggestion/draft host; native navigasi pending |
| 29 | Pulihkan member | conflict/role/zero new debt | Pending |
| 30 | Filter member punya utang | effective current balance | Pending |
| 31 | Sort member | name/new/visits/debt/seek tie | Pending |
| 32 | Kamera pencarian gudang | permission/no camera/stale callback | Lookup dan callback lama diuji pada suite routing; izin/perangkat fisik belum dibuktikan |
| 33 | Kebijakan kas persisted/clean form | session state/cancel/failure/race | Implemented; host48PASS termasukUI2 ID/EN320/text2; native7 Poco dan7 DV PASS; hash/awake/controlOff PASS |
| 34 | Scanner routing/PIN/modal/Enter | HID+commitText/no truncated PIN | PIN raw/Enter/burst host4 dan native4 fondasi PASS; field/focus/setup/SQL guarded host81unik viaretest PASS; native 21 kasus unik Poco dan 21 DV lulus; HID fisik dan OEM belum teruji |
| 35 | Favorit6–8 | cached stats/active/stock/expired/return | Pending |

Migrasi populated37→baru, backup lintas key+attachment, formatter/analyze/l10n,
buildABI16KiB/signature/license dan preservation per interval masih Pending.
Poco/DV tersedia pada audit awal; Realme belum terhubung. Tidak ada klaim uji
fisik/Drive/cetakan/biometrik/reboot hanya dari widget atau model waktu.

Bukti dan failure awal: [M54_FOUNDATION_REPORT](M54_FOUNDATION_REPORT.md).
85kasusunik host melalui runs/retests bukan acceptance seluruh M5.4.
