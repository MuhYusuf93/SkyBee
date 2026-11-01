# G2B — ResetToko runtime

1 November2026. **Software G2B selesai** pada review source725. G2A dipush50b0b3d.
Native36 kedua perangkat selesai pada source sama. G3 portable seluruh fakta A–F dan H handoff100/50 masih wajib.
[Panduan ID/EN](M53_STORE_RESET_GUIDE.md).

Alur pemilik pada Pengaturan Toko menampilkan peringatan merah, tautan ke alur
cadangan lokal/Drive opsional yang sudah ada, acknowledgement salinan recovery di
luar aplikasi dan konfirmasi akhir terpisah. PIN pemilik baru menerbitkan opaque
single-purpose claim60detik; idle grant/Gudang/boolean UI tidak menjadi authority.
Review mengikat issuer/store ID/database generation, tidak setiap revision SQL
karena verifikasi PIN sendiri menulis DB. Tanpa snapshot terakhir pengguna harus
mengakui keputusan tersebut. Backup gagal membatalkan sebelum promosi.

Lease berurutan backup-work → printer-output/drain → report-work (termasuk ZIP/
logo IO setelah SQL read selesai) → native report cancel/drain → database.
Snapshot safety pilihan memakai frozen source sampai promosi sehingga tidak ada
checkout baru antara backup dan swap. Store baru dibuat melalui migrasi asli ke
schema37, key SQLCipher/store/installation baru, tanpa business/credential/draft
setup lama. Guard genuine onboarding tidak dilemahkan.

Default startup memasang cleanup idempotent untuk journal reset/new selection,
sebelum membuka store baru. Recovery versi lama disimpan dan diverifikasi sebelum
active code dicabut. Local Drive consent diganti generation tanpa account OS
logout, origin/retry/upload alias scoped dibersihkan, hanya binding biometrik app
untuk path DB yang dicabut. Job ID/tag app serta notifikasi app dicabut pada
production. Fixture namespace tidak membatalkan job manual global. Arsip lokal,
retensi metadata, Drive lama, completed SAF exports dan enrollment OS dipertahankan.
Scope cleanup transient memakai canonical private directory, no-follow children,
dan allowlist report/import/restore/logo; tidak menghapus folder asing secara massal.

Native report pause menghalangi admission semua engine dan menunggu stream IO
finally (15detik bounded). Timeout membatalkan reset, bukan mengaku stream sudah
tertutup. Token opaque hanya dapat di-resume oleh pemilik; engine disposal melepas
lease miliknya, activity detach tidak melepas reset di tengah proses. JUnit4
menguji admission, timeout, semua writer finally dan stale token; ini belum bukti
SAF provider/stream fisik yang tertahan di perangkat pengguna.

Full restore inspection/disposal kini memegang backup-work, termasuk failure
cleanup/candidate release tanpa gate reentry. Permintaan lama tidak mengadopsi
unlock baru. Callback kasir lama ditolak berdasarkan generation meski PIN gate
nonaktif. Dispatcher tidak menginisialisasi task pada genuine fresh store;
worker lama yang menyimpan key lama tidak dapat membuka ciphertext baru.
Replacement reason membedakan reset/restore/replace; app reload mempertahankan
injected platform/clock/biometrics/report/printer dependencies.

| Pemeriksaan | Bukti saat ini |
| --- | --- |
| Host awal pure |33PASS00:00 |
| Regresi awal |93PASS1FAIL01:56: stale cashier ditolak tetapi kode pesan berubah; kontrak m53CashierLocked dipulihkan, guard tetap |
| Focused cashier |14PASS01:22 |
| Host gabungan source725 awal |127PASS01:56 |
| Analyzer awal/final |15 style infos222,1s diperbaiki;108,5s bersih |
| Java |ReportDocumentExport/barrier javac Android36/Flutter aktual;JUnit4PASS43ms |
| Format/l10n/PIN |23files0changed;1531paired/939references/245original IDs;106upstream/license sama |
| Native Poco awal |29PASS7FAIL09:30;1066hash lama sama/controlOff/trueexit1 |
| Canonical review |3file delta;focused host5PASS00:00/analyze82,9s bersih/format3/0;native36 PocoPASS07:49/DV PASS10:27 |

Awal native menemukan pemeriksaan spelling public alias vs canonical app-data
root Android menolak storage sah dengan resetRootInvalid. Lima committed-reset
cleanup gagal; UIIDEN telah melalui finalcancel/locked dirtyBack/fresh PIN, lalu
timeout menunggu wizard karena startup tetap fail-closed. Semua22G1native, guard4,
failed-safety abort1 dan rollback2 lulus. Run gagal disimpan utuh sebelum source
berubah; tidak dianggap overall PASS. Fix memvalidasi native private storage sebelum
mutation lalu memakai resolved Directory konsisten, tetap menjaga scope child.
Modeled alias host membuktikan repro dan perbaikan, tanpa klaim Windows symlink.
Fresh fixture-root absence check ditambahkan. Review native36 kedua perangkat kemudian lulus pada source yang sama.

[Host/checks awal](evidence/m53-20261026/store-reset-host-checks.json),
[source awal](evidence/m53-20261026/store-reset-source-sha256.json),
[Poco gagal asli](evidence/m53-20261026/store-reset-poco-initial.json),
[review checks](evidence/m53-20261026/store-reset-review-checks.json),
[review source](evidence/m53-20261026/store-reset-review-source-sha256.json).
Host127 historis tidak diulang untuk delta cleanup3file; focused5 dan full native36
review pada kedua perangkat adalah bukti perubahan itu. Tidak mengklaim full128 pada review.

Tidak ada update/reset/reseed ordinary atau `.skybee`. Native mutasi hanya owned
fixtures/secret namespace pada `.integration`, lewat wrapper verified APK,
backgroundpaused/--no-uninstall dan per-interval preservation audit. Input widget
sintetis bukan sentuhan fisik/OEM. HTTP mock bukan Google Drive nyata. Tidak ada
OS account/enrollment mutation, benchmark CCTV terisolasi, KDF reduction atau
forensic erase claim. APK/raw DB/key/PIN/token/log pribadi tidak masuk Git.

Penutupan native review: Poco36PASS07:49/1199hash lama sama,
DV36PASS10:27/1100hash lama sama/awakeexact. Keduanya controlOff/
trueexit0 dan sourceMatched725. [Poco review](evidence/m53-20261026/store-reset-poco-review.json),
[DV](evidence/m53-20261026/store-reset-dv.json). Native source reviewed identik,
tanpa downgrade/uninstall/ordinary/.skybee mutation. Tidak ada real SAF stalled
provider/OS-job cancellation/cloud claim; namespacefixture menjaga job manual.
G3 dan H masih wajib; jangan berhenti pada checkpoint G2B.
