# M5.3 — pencarian produk schema 23

Pencarian/popularitas tahap C tervalidasi pada host, DV8910 dan Poco F6.
Source tetap 0.5.2+12, schema23 belum dirilis pada Paket Eksplorasi Mandiri
0.5.2+12/schema14. D–H masih aktif; ini belum handoff seluruh M5.3.
[Kontrak implementasi](decisions/M53_PRODUCT_SEARCH.md).

Hasil layak jual didahulukan, dengan pengecualian kode/barcode persis yang tetap
pertama dan dinonaktifkan bila tidak layak. Urutan default menghitung transaksi
selesai yang memuat barang dalam rolling30hari, lalu quantity bersih/relevansi/
nama/ID. Reversal penjualan dikecualikan; pelunasan bukan penjualan baru.
Cursor terikat pada query, urutan, epoch, cache, hari/zona dan DBgeneration.
Provider dibatasi48hasil. Debounce, scan berulang, kategori/alias, fokus serta
teks ketika layout wide/narrow berganti tetap diperiksa. Cache backup yang
mengaku mutakhir harus cocok dengan agregat lengkap; stale cache dibangun ulang.

| Pemeriksaan source akhir | Hasil |
|---|---|
| Host regresi terkait | 51 PASS14detik, termasuk17kasus search |
| Fokus kasir M5.2 terarah | 1 PASS13detik |
| Analyzer / formatter | Noissues49,1detik;408file/0changed |
| Audit lokalisasi | 852key bilingual,566referensi,245RIDasli |
| DV8910 ARM32, native SQL11/UI2 | 13 PASS3:31;680hash lama cocok |
| PocoF6 ARM64, native SQL11/UI2 | 13 PASS2:52;611hash lama cocok |

Source494file identik sepanjang kedua run akhir. Kedua wrapper exit0 dan
controlOff; awake DV dipulihkan/readback tepat. Native hanya package integration,
dengan fixture baru bernama numerik dan worker background dipause. Tidak ada
reset, reseed, downgrade atau update package eksplorasi. Hash membuktikan retensi
berkas pada interval ini; migrasi/update in-place eksplorasi masih H.

Pengukuran query aplikasi pada fixture1000produk/2000penjualan/2000item,
warmup1 dan5sampel, dalam native integration debug:

| Platform/source | Seed | Cold index/cache + query | Median warm first/next/far |
|---|---:|---:|---:|
| Windows akhir | 0,467s | 0,044s | 3,247/3,343/3,093ms |
| DV sebelum batching | 10,347s | 101,619s | 1199,682/1219,750/1200,291ms |
| DV sesudah batching | 10,247s | 1,959s | 299,285/299,957/299,466ms |
| Poco sesudah batching | 8,617s | 2,245s | 264,680/281,025/266,458ms |

Dirty products dibaca100/join kategori, aliases keyset250 dan writes batch250;
DTO halaman memakai tiga query dengan whitelist yang sama. EXPLAIN aktual memakai
indeks periode sale_transactions_history, parent item, reversal, kode, token dan
batch. Grouping/countDISTINCT/sorting masih menggunakan temporary B-tree. Far
memakai tuple yang cocok dengan posisi984; test75tie terpisah memeriksa gap dan
duplikat. Tidak mengklaim O(1), peakRAM, release latency atau seluruh dataset.
Pengguna menyebut DV mungkin digunakan live stream CCTV bersamaan; beban tersebut
belum diisolasi dan tidak diubah. Perbandingan bukan bukti penyebab tunggal ARM32.

Riwayat kegagalan dipertahankan:

- Host pertama6PASS3FAIL4s: fixture kurang referencecost untracked, kolom
  kategori/alias salah, zona ujiUTC tidak tersedia. Fixture diperbaiki; retest14
  PASS5s (SQL10/Provider4), lalu tambahan late-lock PASS6s.
- UI host awal0PASS2FAIL10s: reveal lazy hanya sekali memakai extent estimasi.
  Helper dibatasi beberapa langkah, tanpa mematikan skala/keyboard/assertion;
  retest2 PASS11s. Regresi source sebelum optimasi82 PASS58s.
- DV pertama11PASS2FAIL6:53: SQL lulus, UI menunggu query pertama. Benchmark
  memperlihatkan cold/warm lambat, sehingga panggilan SQL dibatch. Semua666hash
  lama tetap sama/controlOff/awakeexact; bukan suitePASS.
- Focused DV setelah batching0PASS1FAIL1:11 masih menunggu query pertama;
  semua679hash lama sama/controlOff/awakeexact. Helper kini menerapkan resize,
  reveal field lazy pada route aktif, lalu assert textclient mengirim query.
  App panel juga mengambil query Provider saat dibuatulang. Roundtrip1000/320,
  ID/EN320px2x+keyboard, help/sort/paging/unavailable code lulus pada dua native.
- Satu host invocation13gagal ketika UPSERT menargetkan dua kolom, padahal PK
  asli mencakup product_id/term/priority. INSERTignore asli dipertahankan;
  MINpriority dan alias301baris diuji. Retest13 PASS12s, final51PASS di atas.
- Analyzer awal8info158,8s, lalu3info/warning9,2s dirapikan. Source akhir bersih.

[Ringkasan bukti](evidence/m53-20261026/search-validation.json),
[DVakhir](evidence/m53-20261026/search-batched-dv.json),
[Pocoakhir](evidence/m53-20261026/search-batched-poco.json),
[DVawal](evidence/m53-20261026/search-initial-dv.json),
[focused gagal](evidence/m53-20261026/search-focused-ui-failed-dv.json), dan
[source checksum](evidence/m53-20261026/search-source-sha256.json).
Raw log tetap privat. Input widget/reveal/resize bukan gesture fisik atau IME OEM.
Restore portable semua penambahan, build ordinary/release serta handoff masih G/H.
