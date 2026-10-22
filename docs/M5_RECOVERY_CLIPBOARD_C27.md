# C27 — Salin recovery pada aplikasi utama

18 Oktober 2026. Permintaan pengguna setelah D-MAN07 PASS dilaporkan: tombol Salin yang menghapus spasi/tanda hubung harus tersedia pada aplikasi utama, bukan khusus build uji.

## Perilaku dan arsitektur

- Tombol **Salin ke papan klip / Copy to clipboard** berada bersama tombol Sembunyikan, hanya saat kode baru atau tersimpan ditampilkan dalam gate pengelolaan. Tidak dibatasi `KASIR_INTEGRATION_TEST`; host test tanpa flag menjalankan jalur aplikasi utama ini. Perbedaan masking input khusus fixture tetap terpisah.
- Widget/Provider memegang status UI. `BackupService.copyRecoveryCode` memeriksa akses PIN kembali, memakai normalisasi yang sama dengan konfirmasi/restore, lalu mewajibkan tepat64hex huruf kecil. Spasi, whitespace dan `-` dihapus; karakter salah atau panjang tidak valid ditolak, tidak diperbaiki dengan membuang karakter lain.
- Native Android memvalidasi bentuk canonical sekali lagi dan memerlukan activity dengan fokus. Penulisan clipboard dilakukan pada thread UI melalui channel privat; worker/headless tidak dapat menyalin. Clip diberi penanda sensitif `android.content.extra.IS_SENSITIVE`, kompatibel minSdk24. Tidak meminta permission atau membuat dialog tambahan.
- Penyalinan tidak membaca clipboard, tidak mengubah/menyimpan kode, tidak mencentang persetujuan salinan, tidak membuat backup atau restore, dan tidak mengubah data keuangan/stok. Tidak ada timer aplikasi yang menghapus clipboard pengguna.
- Feedback berhasil/gagal berbahasa Indonesia/Inggris tidak memuat kode atau detail exception upstream. Kode yang disalin tetap harus disimpan pengguna secara pribadi; penanda sensitif bukan enkripsi clipboard atau bukti perilaku seluruh OEM.

## File

`backup_settings_screen.dart`, `backup_settings_provider.dart`, `backup_service.dart`, `KasirPlatformPlugin.java`, ARB dan hasil gen-l10n/helper localization. SPEC/PLAN/STATUS/REQUIREMENTS serta BACKUP_RESTORE mencatat kebutuhan produksi ini.

Fase audit `post_drive_upload` ditambah terpisah dari fase lama: expected4arsip lokal setelah satu upload D-MAN04, satu backup run success dengan account_id cocok terhadap policy secara boolean, policy connected/autoOff serta digest yang sama sebelum/sesudah update. Tidak melemahkan ekspektasi fase post_restore/post_drive_connected lama. Semua ID/account/value tetap privat; marker hanya menyimpan fingerprint/digest.

## Bukti dan batas

- Sebelum implementasi: focused4FAIL18s karena tombol belum tersedia; empat skenario dari satu kebutuhan baru, bukan empat bug aplikasi lama.
- Sesudah: focused4PASS18s. Kasus public synthetic code: canonical, grouped uppercase+whitespace+hyphen, panjang kurang, kegagalan native. UI copy hanya setelah reveal; callback yang tertunda setelah PIN lock tidak mengirim clipboard request, seluruh fingerprint DB tetap, kode/konfigurasi tidak berubah, detail upstream tidak tampil.
- Semua clipboard otomatis memakai sink channel tiruan; tidak membaca/menimpa clipboard OS yang mungkin memuat recovery pengguna. Native suite fixture memakai root/database terpisah, bukan kode recovery nyata. Pengujian clipboard Android nyata dan preview OEM menunggu interaksi manual setelah build/deploy terverifikasi.
- Regresi/analyzer/JVM/native/build dan audit update dicatat ketika hasil tersedia. Aplikasi operasional tidak dipasang pada tahap pemeriksaan; fitur disertakan pada source/build utamanya, dan validasi fisik menggunakan paket terisolasi.
- Pratinjau D-MAN07 telah berhasil sebelum update, tetapi state route akan hilang saat update. Download/validasi perlu diulang memakai tombol Salin sebelum actual Drive restore. Tidak mengganti data aktif sebagai bagian implementasi ini.

## Referensi

[Android: menandai clipboard sensitif](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste#sensitive_content). Tidak mengklaim auto-clear, redaksi preview OEM, paste fisik atau restore lulus hanya dari source/compile.


**C27 siap uji clipboard manual, 18 Oktober 2026:** tombol Salin tersedia pada kode baru/tersimpan dalam PIN gate, termasuk aplikasi utama; hasil canonical64hex tanpa spasi/tanda hubung, tidak rotasi/simpan/auto-confirm. Native Android foreground menandai clip sensitif; feedback ID/EN tanpa kode. Host38PASS124s (focused4 subset), analyzerNoissues22,3s/JVM11PASS; Poco6PASS focused recovery UI; DV 6PASS focused recovery UI; prior APK/default hashes and awake restored/read back. Tes otomatis memakai sink clipboard tiruan, tidak membaca/menimpa clipboard OS. Build ordinary/fixture/bridge verified universal/min24/ikon/16KiB/licenses/signature/negative guard; ordinary tidak dipasang. Audit post_drive_upload before/after masing-masing1PASS: semua tabel dan4arsip sama pada interval pembaruan baru, satu run sukses/account cocok, policy connected/autoOff/digest sama, fakta2sale/stok/HPP/integrity/FK/legacy/ordinary/public2exports sesuai. C27 installed SHA cocok dan startup own cashier/0marker pada buffer diperiksa. Kontrol otomatis Off. D-MAN07 sebelum update tetap PASS reported; download/validasi perlu diulang dengan tombol Salin. Clipboard/paste OEM dan actual Drive restore belum lulus. OriginalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Detail [C27](M5_RECOVERY_CLIPBOARD_C27.md).**

Ledger: C:\Users\ACER\Documents\Proyek\kasir_app\codex-kasir-kit\docs\evidence\m5-20261016\poco-recovery-copy-update-1792312363867\update.json

## C27-MAN01: hasil fisik dan temuan preview

**C27-MAN01 hasil manual, 18 Oktober 2026:** tombol Salin dan Tempel canonical tanpa seleksi manual PASS dilaporkan pengguna. Namun kode terbaca pada panel kecil Android segera sesudah Salin (klarifikasi pengguna), sehingga perlindungan preview FAIL reported; penyebab belum ditentukan. Source telah memasang penanda sensitif resmi; belum membuktikan metadata yang diterima OS atau perilaku OEM. Reproduksi lanjutan memakai contoh publik dan metadata saja, tanpa membaca payload clipboard/kode recovery/database. Validasi/restore Drive dijeda. Kontrol otomatis Off; M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/c27-man01-user-report.json).**

Implementasi key mengikuti [dokumentasi Android](https://developer.android.com/privacy-and-security/risks/secure-clipboard-handling). Flag adalah rendering hint; source/compile tidak membuktikan redaksi nyata. Probe fixture berikutnya memakai payload publik hardcoded dan handler produksi yang sama; diagnostic channel hanya tersedia di IntegrationActivity dan membaca ClipDescription (label/mime/boolean), tidak pernah Item/text/URI. Tidak mengubah flow aplikasi utama atau database, tidak otomatis menyalin saat startup. Pengguna menekan tombol contoh publik secara eksplisit, yang mengganti clipboard.

**C27 probe preview publik siap di Poco, 18 Oktober 2026:** analyzer No issues9,3s; build release ARM64 fixture melalui safe PrepareOnly PASS39,4s; APK/min24/ABI/16KiB/ikon/license/sertifikat diverifikasi. APK C27 hash cocok disimpan, baseline mentah12berkas DB/sidecar ordinary+defaultfixture+campaign direkam tanpa membuka SQL melalui bridge yang sudah diverifikasi. Probe sementara memakai handler Salin produksi dan hanya contoh publik setelah tap pengguna; kanal diagnosis khusus IntegrationActivity membaca ClipDescription/boolean saja, tidak payload clipboard. Belum ada hasil tap/metadata atau pembandingan hash akhir. Kontrol otomatis Off. Pengguna diminta melaporkan redaksi panel dan3boolean; C27 dipulihkan persis sesudah probe. Restore Drive tetap dijeda; originalAPK6/closing kampanye masih pending.**

Bukti interval: docs/evidence/m5-20261018/c27-public-preview-1792313866375. Native OS preview/metadata menunggu pengguna; tidak mengklaim bug OEM atau perbaikan source hanya dari source resmi. Persiapan/build ini bukan pengulangan38test atau6nativecase.

**C27 hasil klarifikasi dan penutupan probe publik, 18 Oktober 2026:** Salin/Tempel canonical PASS manual reported. Pengguna menjelaskan kode yang terlihat adalah teks64hex di halaman setelah Tampilkan kode tersimpan; penetapan FAIL preview sebelumnya dikoreksi, histori disimpan. Redaksi panel Android tetap UNVERIFIED, bukan bug aplikasi/OEM terbukti. Probe memakai handler native produksi dan contoh publik; tiga flag ownLabel/sensitive/plainTextMime true pada laporan pengguna dan log PID sendiri. Tidak membaca payload clipboard/kode recovery atau membuka SQL. APK C27 kembali dengan SHA persis;12hash DB/sidecar ordinary+defaultfixture+campaign sama pada interval probe. Kontrol otomatis Off. Berikut D-MAN07R pilih ulang arsip Drive, Salin/Tempel dengan tombol baru lalu Validasi metadata; belum restore. OriginalAPK6/closing kampanye pending; M5 belum selesai/M6 tidak dimulai. [Bukti klarifikasi/probe](evidence/m5-20261018/c27-public-preview-user-report.json).**

**D-MAN07R PASS manual dilaporkan pengguna, 18 Oktober 2026:** setelah C27 dikembalikan, pengguna memilih ulang arsip Drive yang sama; tombol Salin→Sembunyikan→Tempel→Validasi menghasilkan status arsip terautentikasi/tervalidasi dan metadata toko sintetis/2barang/2sale/schema8/IDR/AsiaJakarta sesuai. Ini bukti end-to-end copy/paste hingga autentikasi arsip menurut laporan pengguna; belum restore penuh atau audit unduhan mandiri. Preview panel Android tetap UNVERIFIED; koreksi atribusi sebelumnya tetap berlaku. Berikut D-MAN08 restore penuh hanya package integration pada pratinjau ini, dengan safety backup/checkbox/dialog final dan verifikasi relock PIN. Kontrol otomatis Off; originalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/d-man07r-user-report.json).**
