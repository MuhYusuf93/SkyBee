# G2A — pemulihan berkas dan kunci SQLCipher

1 November2026. Fondasi G2A selesai pada schema37/source715. **Runtime ResetToko
G2B, validasi portable G3 dan handoff H masih wajib.** Tidak ada upgrade/reset/
reseed paket ordinary atau `.skybee`.

Jurnal rotasi memakai DurablePromotion yang sudah ada, dengan shadow key lama/
baru dan immutable witness AES-GCM wrapped sebelum public intent. Witness
mengikat nonce, alias default, hash path/file/key, store IDs, operasi reset atau
same-store replace, dan fingerprint recovery lama. Public JSON tidak berisi key,
PIN atau recovery code. Native AtomicFile kini fsync parent setelah write/delete;
hanya satu alias persis dihapus, bukan wrapping key/enrollment.

Bootstrap recovery mendahului pembacaan alias default. Ciphertext diverifikasi
readonly memakai key eksplisit, integritas, cipher, schema dan store ID, dengan
hash sebelum/sesudah tetap sama. State prepared tidak memakai fallback alias
default; selected hanya menerima matching file/key/store. Key hilang/tamper/file
asing menolak startup tanpa membuat DB/key pengganti. Cleanup terputus dapat
dilanjutkan; late fault setelah journal dihapus diselesaikan dari opaque intent.

ArchiveRecoveryKeys menyimpan recovery lama di alias wrapped terpisah yang
mengikat seluruh store ID+fingerprint (digest192bit untuk batas nama96), memeriksa
readback/konflik sebelum menghapus active code. Toko baru tidak otomatis memperoleh
active backup credential atau layar reveal recovery lama. Salinan di luar aplikasi
masih diperlukan. Reset yang sudah memilih DB baru **tetap diblokir** bila handler
cleanup belum dipasang; fondasi ini tidak mengaku sudah menyelesaikan ResetToko.

| Pemeriksaan | Hasil |
| --- | --- |
| Host |76PASS01:16: journal24, archive keys5, durable promotion5, G1 regression42 |
| Analyzer/formatter |No issues108,5s;620files0changed |
| L10n/PIN |1512paired/926references/245original IDs;106upstream/license match |
| Poco |67PASS08:56;989hash lama sama;controlOff/trueexit0 |
| DV8910 |67PASS12:03;1023hash lama sama;awake exact/controlOff/trueexit0 |

Native67 = pure journal24 + real native SQLCipher/key recovery21 + full G1 native
regression22. Enam belas titik fault mencakup shadows/witness/prepared, semua fase
rename/promote/commit, default/selected, post-selection serta cleanup shadows/
journal/witness. Kasus tambahan menolak witness nonce tamper dan missing prepared
shadow, membuktikan fresh empty reset+old archive authentication, unwired cleanup
blocking, serta exact-alias deletion. Reset baru hanya fixture SQLCipher tertutup;
bukan API runtime dan bukan penghapusan toko pengguna. Full G1 mencakup portable
cross-key, wrapped retention proofs, source leases, HTTP mocks, actual backup-menu
ID/EN320px/text2 dan file/symlink/pending-upload protections.

[Host](evidence/m53-20261026/key-rotation-host-checks.json),
[source manifest](evidence/m53-20261026/key-rotation-source-sha256.json),
[Poco](evidence/m53-20261026/key-rotation-poco.json),
[DV](evidence/m53-20261026/key-rotation-dv.json).
[Guard rejection](evidence/m53-20261026/key-rotation-dv-guard-rejection.json): percobaan
DV awal salah nama define jeda background; guard menghentikan sebelum build/install,
seluruh1023hash lama sama dan awake exact. Diperbaiki pada run terpisah dengan
KASIR_FIXTURE_BACKGROUND_PAUSED=true. Tidak ada guard yang dilemahkan.

Semua native memakai wrapper package `.integration`, --no-uninstall, verified APK,
baseline/final hashes dan akhirnya mematikan kontrol. Input widget sintetis bukan
sentuhan fisik/OEM; HTTP mock bukan Drive nyata; fault hook bukan natural power-cut.
Tidak ada benchmark ARM32/CCTV terisolasi, penurunan KDF atau reset OS/account.
Raw DB/key/PIN/token/log/APK tidak masuk bukti Git.

Berikut G2B: owner reauthentication+final red warning, terminal optional safety
backup, lease ordering backup-work/printer/report/native drain/SQL, idempotent
installation cleanup, fresh worker guard dan genuine onboarding. G3 full portable
A–F dan H in-place/new-store100/50 tetap harus diselesaikan. M5.4/M5.5/M6 di luar scope.
