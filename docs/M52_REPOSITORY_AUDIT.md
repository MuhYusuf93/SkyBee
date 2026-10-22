# Audit repository M5.2 — 22 Oktober 2026

Status saat catatan ini ditulis: cleanup commit **f0f8baf** sudah dibuat;
**feature commit/push belum dilakukan**. Syarat acceptance DV sudah dipenuhi24PASS,
tambahan publicform2PASS dan helper upgrade nyata3PASS; final build/scan sedang
ditutup sebelum pengiriman.
Repository `MuhYusuf93/SkyBee`, branch `main`, remote `origin`. Fetch22Oktober
membuktikan HEAD/origin sama `e76ddc7`; tidak ada reset/clean/stash/rewrite.

## Klasifikasi dan preservasi

| Kategori artefak lokal yang dikecualikan | File | Ukuran/keterangan |
| --- | ---: | --- |
| APK hasil build/duplikat | 68 | 4.613.031.107 byte logis |
| Arsip backup terenkripsi | 1 | 607.195 byte |
| Log mentah | 197 | 1.375.473 byte |
| Screenshot evidence mentah | 7 | 561.781 byte |
| Laporan cache Android build | 1 | 129.908 byte |
| Dump mentah JobScheduler scoped | 1 | 6.771 byte |
| Total | 275 | 4.615.712.235 byte logis |

Sebanyak274file yang sebelumnya tracked dikeluarkan memakai
`git update-index --force-remove --stdin` atas daftar path hasil audit,
**tanpa menghapus worktree**. Satu dump JobScheduler ternyata belum pernah
tracked pada HEAD; rule ignore mencegahnya ikut commit pertama kali. Jadi
275artefak tercakup kebijakan ini, dengan274deletion index. Seluruh275file dibaca
sebelum/sesudah dan hash SHA256 tetap sama. Daftar path/kategori/ukuran/hash:
[manifest terkurasi](evidence/m52-20261022/repository-untracked.json).
APK/build yang dipakai pengembangan tetap tersedia lokal dan diabaikan Git.

Source Flutter/native, migration, lockfile, localization, vendor+license+
provenance, fixture kecil sintetis, script/runbook tetap. JSON/Markdown,
hash baseline TXT, JUnit XML dan script bukti yang relevan dipertahankan;
tidak menghapus evidence/JSON/PNG aset aplikasi secara menyeluruh. Referensi
historis ke log/APK mentah sekarang merujuk salinan lokal yang diabaikan;
reproduksi memakai script/runbook, laporan/manifest terkurasi tetap di Git.

`.gitignore` menolak APK/AAB, DB/sidecar/backup, keystore lokal, local.properties,
cache, log serta capture mentah di evidence. Ikon/aset aplikasi tetap dilacak.
Tidak menerbitkan GitHub Release assets.

Ukuran di atas menjumlahkan salinan file yang banyak berulang, bukan ukuran
transfer Git. Packed Git yang diukur sebelumnya sekitar174,6MB. Cleanup commit
biasa **tidak menghapus blob history** atau menjamin clone langsung mengecil.

## Scan secret dan keterbatasan

Gitleaks8.30.1 diambil dari release resmi `gitleaks/gitleaks`; checksum arsip
diverifikasi terhadap checksum release. Eksekusi lokal, tidak mengunggah source.
Report memakai redaction100% dan disimpan privat pada `build/m52-checkpoint/`.

History command memakai `git --all`, batas file8MB. Tool melaporkan5commit/
18,72MB dipindai, sementara `git log --all` memuat9commit. Hasil20temuan berulang
pada10lokasi di2commit diklasifikasi; bukan klaim setiap blob/commit/binary
sudah diaudit secara menyeluruh.

Scan kandidat final sesudah opsi feed3 menyalin1568tracked+untrackednonignored
files (0excluded oleh batas8MB),10,58MB dipindai,10temuan `generic-api-key`
yang sama; path/line seluruhnya cocok klasifikasi terdahulu:

| Lokasi/kategori | Jumlah lokasi | Penilaian |
| --- | ---: | --- |
| MbedTLS PROVENANCE file SHA256 | 3 | False positive; hash diverifikasi terhadap vendor file aktual |
| Laporan M5, kalimat Keystore/SQLCipher | 1 | False positive; uraian dokumentasi, bukan credential |
| Baseline source SHA256 | 5 | False positive; digest file sumber/metadata |
| Cross-transfer fixture `sourceKeyDigest` | 1 | False positive; digest SHA256 kunci fixture, bukan kunci/credential |

Tidak ada credential nyata terkonfirmasi dalam scope ini. Tidak memasukkan
allowlist global yang menyembunyikan temuan; raw finding tetap ada teredaksi.
Binary APK/arsip lama tidak dibongkar/dekripsi oleh scan ini. Bila kelak ditemukan
secret riil di history, penghapusan commit terbaru bukan revoke/rotate; tindakan
pemilik akun dan keputusan history terpisah tetap diperlukan. Tidak ada
force-push, penghapusan refs atau history rewrite.

Audit key terstruktur pada JSON evidence menemukan hanya salt vektor PIN
sintetis publik. Generator `create_pin_vectors.py` memakai urutan byte tetap
dan input publik untuk verifikasi PBKDF2 independen; dipertahankan sebagai test
vector. Tidak menyalin credential/row/data eksplorasi Skybee ke evidence publik.

## Pengiriman

Update aktual: hygiene `f0f8baf` dan feature
`41b34308c81fd1b464f6efc9e81e7682004bd1c8` sudah dikirim ke origin/main dan
hash remote diverifikasi sama. Pengguna memberi persetujuan langsung di chat
sesudah pemeriksaan otomatis semula menolak otorisasi yang dianggap hanya dari
dokumen. Perbaikan race audit upgrade dibuat sesudah pemasangan pertama
dihentikan guard; akan diperiksa/dipindai dan dikirim melalui commit biasa
berikutnya. Tidak force-push atau menulis ulang histori.

Paragraf pending berikut merupakan checkpoint sebelum pengiriman feature.

Acceptance DV sudah lulus sebelum commit. Fetch terbaru membuktikan HEAD dan
origin/main tidak divergen (0/0), remote tepat MuhYusuf93/SkyBee dan branch main.
Staging fitur terpilih, review diff dan scan kandidat final masih pending;
hash commit/push aktual dicatat setelah operasi berhasil.

Commit hygiene `f0f8baf` berisi tepat274deletion yang cocok manifest, `.gitignore`
dan manifest preservasi. Tidak menghapus worktree/history atau memuat fitur
setengah jadi. HEAD kini satu commit di depan origin sebelum pengiriman fitur.
