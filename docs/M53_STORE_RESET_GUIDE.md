# G2B — alur hapus data toko

1 November2026. Software runtime dan UI ID/EN diverifikasi pada fixture native kedua perangkat;
batas bukti perangkat/SAF/Drive tetap dijelaskan dalam laporan. G2A fondasi sudah ditutup pada commit50b0b3d.

Pemilik membuka Pengaturan Toko → Hapus seluruh data toko di perangkat ini.
Peringatan merah menyebut barang, transaksi, pelanggan dan pengaturan akan hilang.
Menu Buat dan periksa cadangan membuka alur backup yang sama: lokal atau Google
Drive opsional, beserta pemeriksaan arsip dan kode pemulihan. Keberhasilan Drive
nyata tetap bergantung pada akun/perangkat; tidak dijamin dari HTTP fixture.

Simpan dan periksa salinan kode pemulihan portabel di luar aplikasi. PIN bukan
kode backup. Default arsip lokal/Drive dipertahankan. Recovery lama dipertahankan
wrapped secara internal sebelum active code dicabut, tanpa layar reveal otomatis
untuk PIN toko baru. Metadata retensi tetap di luar DB dan tidak dihapus reset.

Jika kode aktif sudah dikonfigurasi, pilihan cadangan lokal terakhir default aktif.
Snapshot ini dibekukan di bawah lease sampai reset commit sehingga tidak ada
checkout baru di antara snapshot dan penggantian file. Gagal backup membatalkan
reset. Menolak snapshot memerlukan acknowledgement eksplisit. Setelah meninjau
konfirmasi akhir terpisah, pemilik memasukkan ulang PIN; grant idle saja atau
akses Gudang tidak mencukupi. Expiry selama operasi panjang membatalkan sebelum
commit. KDF/grace/security tidak dilonggarkan.

Toko baru memakai SQLCipher key/identitas baru dan schema37 kosong melalui
migrasi asli. Kunci salah/cleanup terputus menolak bootstrap sampai pemulihan
selesai, bukan membuat DB pengganti. Wizard benar-benar kosong; tidak ada marker
palsu untuk menyembunyikan data lama. Sesudah reset, izin Drive lokal, pengaturan,
PIN/grants, app biometric binding dan worker harus disiapkan ulang. Akun Google
OS, enrollment biometrik, aplikasi lain, arsip cloud dan ekspor SAF yang sudah
selesai bukan target penghapusan. Tidak menjanjikan erase forensik flash/cloud.

English: Owner Settings → Delete all store data on this device. Review the red
warning, create/check a local or optional Drive backup, and keep a checked copy
of the portable recovery code outside the app. Review the separate final
confirmation and re-enter the owner PIN. An optional final local snapshot is
created while writes are frozen; failure cancels reset. Existing local/Drive
archives remain. The new encrypted store starts genuine initial setup with a
new key and identity, and no inherited local app authorization. OS accounts,
biometric enrollment, other apps and completed user exports are outside scope.

Verified synthetic scope: runtime fixtures and UI ID/EN320px/text2/locked dirty
Back/fresh PIN/genuine wizard, full36 on Poco+DV with preservation/finally checks. G3 portable A–F and
H handoff100/50 remain active work. No ordinary/.skybee reset has occurred.
