# M5.3 — checkpoint onboarding, belum handoff akhir

Source+12/schema19 setelah tracking81d4306; Paket Eksplorasi Mandiri tetap
+12/schema14 tanpa update/reset/reseed. Implementasi mengikuti
[keputusan](decisions/M53_ONBOARDING.md) dan urutan tujuh langkah kontrak.

Wizard identitas, pola tugas, PIN, tracking, fitur, printer dan review mempunyai
ID/EN di setiap langkah. Draft whitelisted non-secret persist dalam DB terenkripsi;
perubahan bahasa tidak menghilangkan input. Autosave serialized tidak menimpa
input yang lebih baru. Step berpindah sesudah flush; indikator saved hanya untuk
revisi yang sudah tersimpan. PIN raw hanya controller RAM, staging memakai KDF
PBKDF2-HMAC-SHA256600k yang sama. Recovery transient harus diakui via opaque proof;
process restart sebelum ack memerlukan prepare ulang. Pattern3 dua PIN berbeda,
semua stok wajib tracked; perubahan pola membatalkan staging sebelumnya.

Finish revalidasi freshness/revision/identitas/credential dan commit seluruh
konfigurasi dengan completed serta audit atomik, kemudian menghapus staging.
Tidak grant Kelola. Background menutup wizard, reset PIN visibility dan recovery
reveal. Toko lama/fixture configured tidak dianggap fresh meski marker0 lama;
marker/data tidak ditulis ulang. Freshness juga memeriksa fakta bisnis, bukan
hanya jumlah produk. Kasir/runtime operasional menunggu finish. Jalur printer
publik terbatas dapat dibuka dan dibatalkan tanpa profil/print baru; printer gagal
atau dilewati tidak menghalangi finish. Portable validation menolak residual
setup staging; restore seluruh M5.3 tetap perlu G.

Bukti host final: `onboarding-acceptance-regression.txt`23PASS34s mencakup
SQL9/UI3/populated14→19 serta interrupted-migration rollback1/cost10. Termasuk
CAS stale, slow autosave, proses tutup, role separation, verifikasi PIN Pemilik/Gudang,
rollback SQL config+credentials dan backup staging. Format366/0changed,
l10n792keys/525staticref/245requirement asli. Analyzer final No issues104,3s setelah helper native diperbaiki.

Raw failure tidak dihapus: domain awal6PASS1FAIL13s karena assert membaca nama
melalui preferences publik (proyeksi tidak memuat nama). Retest menyelesaikan
masalah kedua expected map yang belum menyertakan kolom PIN nullable. Helper
pageBack bawaan memakai tooltip English dan gagal pada UI Indonesia; test
mengetuk BackButton aktual. Upaya acceptance lain dihentikan ketika helper SQL
read hanya runAsync menunggu queued callback di fake zone; wizard sudah mencapai
Kasir menurut diagnostic. Helper kini memompa real IO dan frame secara bounded,
tanpa perubahan assertion/aturan fitur. Run11PASS1FAIL33s berikutnya gagal pada
helper manifest mengacu tabel store_identity yang tidak ada; diperbaiki menjadi
m5_store. Final23PASS bukan penjumlahan seluruh run yang overlap.

Native DV pertama1PASS4FAIL2:04: fixturePathRequired menolak nama sementara
yang mengandung setup, sebelum DB dibuka. Populated migration1PASS; SQL setup
setUpAll dan UI3 gagal akibat guard itu. Nama fixture diperbaiki mengikuti
whitelist numeric yang ada; guard tidak dilonggarkan. Seluruh hash lama sama,
controlOff dan awake DV restored exact (577hash lama).
Retest DV10PASS3FAIL2:54: SQL9 dan migrasi1 PASS, UI pertama mencapai Kasir
lalu assertion async callback berbenturan dengan guarded native pump; helper
then inferred bool/onError void menutupi error awal. Binding pendingFrame juga
menolak dua UI berikutnya. Perbaikan helper saja memakai then<void>/expectSync,
matcher dan data tetap; host3PASS14s. Focused DVUI3PASS1:24,595hash lama sama,
controlOff/awake exact. Semua13 kasus memiliki PASS lintas run; bukan DV13all-pass.
580hash run10PASS3FAIL juga seluruhnya sama. Source snapshot cocok tiap interval.
Poco13PASS2:17,525hash lama sama/controlOff dengan source identik. Baseline577
awal DV tetap cocok pada endpoint focusedUI terakhir. Seluruh wrapper sudah
ditutup. [Bukti terkurasi](evidence/m53-20261026/onboarding-validation.json) dan
[source checksum](evidence/m53-20261026/onboarding-source-sha256.json) tersedia.
Integration debug ARM32/ARM64 berhasil; ordinary/release final serta update user
store tetap H. Native widget callbacks/test keyboard bukan bukti sentuhan atau
IME fisik. Tidak ada klaim cetak kertas/biometrik/periode72jam alami. Batas hardware printer/physical touch tetap seperti di atas. Build/log/DB/key privat tidak dipush.
Remaining B/kunci kasir dan C–H masih aktif; checkpoint tidak menutup M5.3.
