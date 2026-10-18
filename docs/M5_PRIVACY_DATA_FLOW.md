# Catatan aliran data M5 untuk tindak lanjut M6

Ini catatan implementasi, bukan dokumen legal final atau halaman kebijakan privasi M6.

| Tujuan | Data | Penyimpanan/transfer |
| --- | --- | --- |
| Kasir/persediaan/piutang/laporan | Barang, batch, harga/HPP snapshot, pelanggan/kontak, pembayaran/reversal, audit | Database SQLCipher privat pada satu perangkat aktif |
| Kunci/Google policy | DBkey acak, backuprecoverymaster, accountID/email/permissionID/consentgeneration, resumablesessionURL | WrappedKeystore/noBackup; tidakportable/asset/log. Token hanyaSDK/memori |
| Salin recovery (C27) | Kode recovery yang ditampilkan, dinormalisasi menjadi 64hex tanpa spasi/tanda hubung | Tindakan tombol eksplisit setelah PIN; clipboard sistem Android diberi penanda sensitif. Aplikasi tidak membaca clipboard, mengunggah salinan, atau mencatat nilainya; bukan rotasi/konfirmasi otomatis. Masa simpan/tampilan clipboard mengikuti OS; OEM belum dibuktikan hanya dari source |
| Cetak | Snapshot publik struk, customer/kontak bila ada, logo/header/footer; tanpaHPP | BluetoothSPP hanya printer yang dipilih. Queue/receipt tetaplokal; byteACKbukanpaperproof |
| Notifikasi | Pengingat generik, tidakcustomer/debt/productdetail padalockscreen | OSlocalnotification +daftarprotectedPIN; tidakserverpengembang |
| Backup lokal/Drive | Arsipterenkripsi penuh data toko/logo, versi/provenance; riwayatoperasi dapatmemuataccountpseudonymousID | SAFpilihanpengguna atau appDataFolder akunGoogle yang dikonfirmasi. Namespacefixture berbeda |
| Retensi/pemulihan |7Drivecompleteperstore+origin; localcatalog/safetyarchive | Tidakmenyapuinstalasilain. Restoremeresetconsent/selectedprinter/jobs/legalacceptance danmembuatidentitasauditaktifbaru |

GoogleSignIn/Drive/WorkManager/flutter_local_notifications/platformBluetooth/SAF ditambahkan sesuai fungsi. Tidak menambah ads, analytics, tracking, crashupload, serviceaccount, backend pengembang atau sinkronisasistok. Akses API Google hanya setelah tindakan/consent sesuaialur; jadwaloptin terpisah. Nama SkyBee tidak mengubah package/namaaplikasi saatini. Identitas/kontak/legalacceptance/DataSafety/rilisM6belumdikerjakan.

Backup recovery harusdisimpan pengguna; pengetahuanPIN tidakmendekripsibackup/keyperangkat. AutoBackupAndroid tetapoff/excluded. KebijakanprivasiM6harusmencerminkan implementasifinal dan buktiSDKaktual, termasuk Googletransfer, identifieroperasional, retensilokal, pengelolaanbackup, serta batasKeystore/force-stop/hasilcetakambigu. Tidakmengklaimkepatuhanhukum ataukelulusanreviewstore.

**C27 hasil klarifikasi dan penutupan probe publik, 18 Oktober 2026:** Salin/Tempel canonical PASS manual reported. Pengguna menjelaskan kode yang terlihat adalah teks64hex di halaman setelah Tampilkan kode tersimpan; penetapan FAIL preview sebelumnya dikoreksi, histori disimpan. Redaksi panel Android tetap UNVERIFIED, bukan bug aplikasi/OEM terbukti. Probe memakai handler native produksi dan contoh publik; tiga flag ownLabel/sensitive/plainTextMime true pada laporan pengguna dan log PID sendiri. Tidak membaca payload clipboard/kode recovery atau membuka SQL. APK C27 kembali dengan SHA persis;12hash DB/sidecar ordinary+defaultfixture+campaign sama pada interval probe. Kontrol otomatis Off. Berikut D-MAN07R pilih ulang arsip Drive, Salin/Tempel dengan tombol baru lalu Validasi metadata; belum restore. OriginalAPK6/closing kampanye pending; M5 belum selesai/M6 tidak dimulai. [Bukti klarifikasi/probe](evidence/m5-20261018/c27-public-preview-user-report.json).**
