# Catatan aliran data M5 untuk tindak lanjut M6

Ini catatan implementasi, bukan dokumen legal final/persetujuan pengguna M6 dan tidak dipublikasikan.

| Tujuan | Data | Penyimpanan/transfer |
| --- | --- | --- |
| Kasir/persediaan/piutang/laporan | Barang, batch, harga/HPP snapshot, pelanggan/kontak, pembayaran/reversal, audit | Database SQLCipher privat pada satu perangkat aktif |
| Kunci/Google policy | DBkey acak, backuprecoverymaster, accountID/email/permissionID/consentgeneration, resumablesessionURL | WrappedKeystore/noBackup; tidakportable/asset/log. Token hanyaSDK/memori |
| Cetak | Snapshot publik struk, customer/kontak bila ada, logo/header/footer; tanpaHPP | BluetoothSPP hanya printer yang dipilih. Queue/receipt tetaplokal; byteACKbukanpaperproof |
| Notifikasi | Pengingat generik, tidakcustomer/debt/productdetail padalockscreen | OSlocalnotification +daftarprotectedPIN; tidakserverpengembang |
| Backup lokal/Drive | Arsipterenkripsi penuh data toko/logo, versi/provenance; riwayatoperasi dapatmemuataccountpseudonymousID | SAFpilihanpengguna atau appDataFolder akunGoogle yang dikonfirmasi. Namespacefixture berbeda |
| Retensi/pemulihan |7Drivecompleteperstore+origin; localcatalog/safetyarchive | Tidakmenyapuinstalasilain. Restoremeresetconsent/selectedprinter/jobs/legalacceptance danmembuatidentitasauditaktifbaru |

GoogleSignIn/Drive/WorkManager/flutter_local_notifications/platformBluetooth/SAF ditambahkan sesuai fungsi. Tidak menambah ads, analytics, tracking, crashupload, serviceaccount, backend pengembang atau sinkronisasistok. Akses API Google hanya setelah tindakan/consent sesuaialur; jadwaloptin terpisah. Nama SkyBee tidak mengubah package/namaaplikasi saatini. Identitas/kontak/legalacceptance/DataSafety/rilisM6belumdikerjakan.

Backup recovery harusdisimpan pengguna; pengetahuanPIN tidakmendekripsibackup/keyperangkat. AutoBackupAndroid tetapoff/excluded. KebijakanprivasiM6harusmencerminkan implementasifinal dan buktiSDKaktual, termasuk Googletransfer, identifieroperasional, retensilokal, pengelolaanbackup, serta batasKeystore/force-stop/hasilcetakambigu. Tidakmengklaimkepatuhanhukum ataukelulusanreviewstore.
