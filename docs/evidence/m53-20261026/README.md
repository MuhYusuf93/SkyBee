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
