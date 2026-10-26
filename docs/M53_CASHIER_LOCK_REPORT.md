# M5.3 — checkpoint kunci Kasir, belum handoff akhir

Source+12/schema20 setelah onboarding0570137; Paket Eksplorasi Mandiri tetap
+12/schema14 tanpa update/reset/reseed. [Kontrak/invariant](decisions/M53_CASHIER_LOCK.md).
Cashier gate defaultoff, own/refowner PIN tidak grant Kelola/mereset72h, owner fresh
config/disable, manual/screen state, opaque route/cart/tender, dirty Back generic,
late route, attempt/CAS/nonce/SQL rollback dan backup metadata tersedia pada source.

Host32PASS1:23 (gate SQL13/UI6+onboarding13; migration included once). Final gate
acceptance20PASS2:32 overlap; repayment tambahan1PASS12s menolak mutasi terkunci,
retry membayar satu kali tanpa sale/HPP/stok baru. Combined unique gate21 (SQL14,
UI6, populated14→20/interrupted rollback1); native API smoke1 tambahan hanya Android.
Analyzer terakhir No issues6,1s; audit815bilingual/540staticrefs/245originalIDs.
Format381/0changed final. DV22PASS7:01 (SQL14/UI6/migration1/nativeAPI1),598hash lama sama/controlOff/awake
exact, source manifest cocok. Poco22PASS4:07,542hash lama sama/controlOff, sourceidentik. Ordinary/
release final serta in-place update eksplorasi tetap H.

Failure awal compile test memakai API field/nama salah diperbaiki pada fixture,
bukan penghapusan assertion. Domain9PASS52s lalu UI3 awal2PASS1FAIL1:18. Back helper
mengisi TextField pertama (search kasir pada tree transisi) bukan nama barang;
label productName/readiness/dirty/Nav assertions memperbaiki helper. Focused1PASS16s
memeriksa appbar stay dan hardware discard. Run domain/UI berikut18PASS1FAIL1:22
menemukan cache policy lama sesaat sesudah commit: gate muncul lebih dulu daripada
load policy. Source diperbaiki mempublikasi row hasil commit sebelum event gate,
listener merefleksikan perubahan dan nonce diperiksa sesudah final SQL read.
Focused settings1PASS14s, kemudian regresi32PASS dan acceptance20PASS.

Satu perintah repayment pertama berhenti pada native_assets/windows/sqlite3.dll
karena runner FFI lain masih memakai berkas. Tidak menghapus DLL/mengubah ACL;
menunggu runner selesai, memakai API record yang benar dan menjalankan retest1PASS.
Raw logs tetap privat, overlap tidak dijumlah sebagai kasus unik tambahan.

Native widget callbacks/test keyboard/synthetic OS state bukan physical touch,
IME/OEM power-button/biometric enrollment evidence. Source menggunakan flag isolasi/
background-paused dan audited wrapper; seluruh wrapper ditutup. [Validasi terkurasi](evidence/m53-20261026/cashier-lock-validation.json)
dan [source checksum](evidence/m53-20261026/cashier-lock-source-sha256.json) tersedia.
Native integration debug ARM32/ARM64 dibuild; ordinary/release final tetap H.
Remaining C–H aktif, ini tidak menyatakan seluruh M5.3 selesai.
