# Bukti terkurasi M5.3

[Ringkasan checkpoint A1/B](a1b-validation.json) dan [source checksums](a1b-source-sha256.json).
Ini checkpoint fondasi, bukan acceptance/handoff seluruh M5.3.

Tidak memuat database, key/PIN/token, recovery, kontak pelanggan, APK atau raw log.
Raw gagal/retry dan APK checkpoint disimpan privat di `build/m53` serta direktori
run yang disebut pada [laporan](../../M53_REPORT.md). Hasil sintetis/native dan
endpoint hash dibedakan dari bukti fisik dan logical handoff data pengguna.

[Checkpoint biaya](cost-validation.json) dan [source checksums biaya](cost-source-sha256.json)
menutup6interval native terisolasi, bukan handoff seluruh M5.3.

[Checkpoint tracking](tracking-validation.json) dan [source checksums](tracking-source-sha256.json)
mempertahankan DV16PASS1FAIL serta focused retest, tidak menandainya sebagai satu17PASS.

Onboarding19 ditutup27Oktober: [validasi dan scope](onboarding-validation.json),
[source checksums](onboarding-source-sha256.json). Raw failure tetap privat;
DV13PASS lintas domain/migration+focusedUI, Poco13PASS satu run. B–H masih aktif.

Kunci Kasir20 ditutup27Oktober: [bukti](cashier-lock-validation.json) dan
[source checksums](cashier-lock-source-sha256.json). DV22/Poco22 PASS, seluruh
hash interval sama/controlOff; OS synthetic vs native APItype scope dibedakan.
C–H tetap aktif dan Paket Eksplorasi Mandiri belum diupdate/reset.


## Checkpoint pencarian C schema23 — 28Oktober2026

[Ringkasan](search-validation.json), [DVakhir](search-batched-dv.json),
[Pocoakhir](search-batched-poco.json), [source494](search-source-sha256.json).
Native13 per perangkat PASS, semua680/611hash lama cocok/controlOff/awakeDVexact.
[DVawal11P2F](search-initial-dv.json) dan
[focused UI0P1F](search-focused-ui-failed-dv.json) tetap disimpan, bukan PASS.
Query plan/timings synthetic debug dan beban CCTV tidak diisolasi; lihat
[laporan/batas](../../M53_SEARCH_REPORT.md). D–H/handoff eksplorasi masih aktif.

G2A key rotation: [laporan](../../M53_KEY_ROTATION_REPORT.md), [host](key-rotation-host-checks.json), [source715](key-rotation-source-sha256.json), [Poco67](key-rotation-poco.json), [DV67](key-rotation-dv.json), [guard rejection](key-rotation-dv-guard-rejection.json). G2B/G3/H belum selesai.

G2B ResetToko: [laporan](../../M53_STORE_RESET_REPORT.md), [host awal127](store-reset-host-checks.json), [native gagal asli](store-reset-poco-initial.json), [review checks](store-reset-review-checks.json), [review725](store-reset-review-source-sha256.json), [Poco36](store-reset-poco-review.json), [DV36](store-reset-dv.json). G3/H masih wajib.

G3 portable/resume: [laporan](../../M53_PORTABLE_BACKUP_REPORT.md),
[source732](portable-initial-source-sha256.json), [Poco3PASS](portable-poco.json).
[DV3PASS](portable-dv.json), [host61PASS dan riwayat timeout](portable-host-checks.json).
Kedua perangkat source sama/hash lama sama/controlOff, DV awakeexact. Tidak ada
claim handoff H atau reset toko eksplorasi.

H software/native/build: [laporan](../../M53_EXPLORATION_HANDOFF_REPORT.md),
[initialPoco2PASS3FAIL](exploration-poco-initial.json),
[reviewPoco5PASS](exploration-poco-review.json), [DV5PASS](exploration-dv-review.json),
[source737](exploration-review-source-sha256.json),
[host54/tool5](exploration-host-checks.json), [3APK](exploration-builds.json),
[post-native host-only/tooling delta](exploration-handoff-source-sha256.json).
Actual update/reset user belum dilakukan pada checkpoint ini.
