# Jadwal supplier dan pengingat H-1

Review29Oktober16:13: pemicu supplier sekarang memakai event commit khusus dari
writer supplier dan izin notifikasi; inventory/settings terkait juga memicu
rekonsiliasi. Edit keranjang tidak memindai seluruh ledger supplier. Uji runtime
aktual membandingkan generation cache setelah12edit cart dan commit kunjungan;
rollback tidak mengirim event. Ringkasan tanggal kunjungan berikutnya menghitung
planned>=hari toko secara independen dari halaman histori lampau. Kembali dari
jadwal memperbarui tanggal tanpa menimpa pilihan izin tempo yang belum disimpan.
Delta ini host20 terverifikasi; native45 sebelumnya pada source652-platform,
regresi jadwal delta disertakan pada bundle native F. Tidak ada klaim benchmark
atau penyebab terkait CCTV dari perubahan ini.

Schema34 menambah kunjungan dengan projection saat ini dan riwayat revisi
append-only, preferensi pengingat tagihan append-only, serta cache job yang
dapat dibangun ulang. Jadwal tidak membuat penerimaan, invoice atau pembayaran;
tanggal kunjungan terpisah dari effective_due tagihan. Gudang/owner boleh
mencatat kunjungan, hanya owner mengubah preferensi jatuh tempo atau membuka
daftar keuangan. CAS, operation key/payload dan grant/database generation
mencegah overwrite usang dan write setelah hak akses berubah.

Kunjungan menyimpan supplier, snapshot nama, tanggal kalender, jam opsional,
catatan opsional, status planned/completed/cancelled dan pilihan pengingat.
Beberapa jadwal disimpan dengan daftar20/cursor date+ID berkonteks supplier,
filter, generation dan revision. Default planned menampilkan tanggal terawal;
history tetap ada pada filter lain. Kalender memperbolehkan tanggal hari ini
dan historis. Tidak memakai minimum besok dari expiry. Jam kunjungan tidak
menggeser jam pengingat. Bentuk pendek memakai area gulir yang membangun semua
field, dirty Back dan gate privasi tersendiri; unlock tidak memuat ulang isian.

H-1 dihitung pada **hari kalender sebelumnya pukul09.00 timezone toko**. Belum
ada pengaturan jam pengingat umum sehingga default09.00 digunakan. Kunjungan
20Nov menghasilkan19Nov, due25Nov menghasilkan24Nov. DST, ganti bulan/tahun
dan timezone tidak dihitung dengan menambah/mengurangi24jam. Target terlewat
yang baru dibuat tidak dijadwalkan dan tidak dikirim catch-up. Badge dalam
aplikasi tetap menandai kebutuhan perhatian; tagihan hari ini/terlambat tetap
terlihat dari fakta, terlepas dari keberhasilan worker.

Memakai **dispatcher WorkManager yang sudah ada**, local notification plugin
yang sudah diinisialisasi, dan satu jenis one-off task baru. Worker persediaan
periodik juga merekonsiliasi supplier; tidak ada dispatcher/periodic worker
kedua dan tidak meminta izin exact-alarm. Foreground startup/resume membangun
ulang job; commit finansial/jadwal hanya merekonsiliasi supplier, tidak memicu
scan penuh stok. Supplier jobs memakai unique name dengan fingerprint store,
object, target, zone dan identitas toko. Perubahan saldo sebagian tidak masuk
fingerprint sehingga tidak membuat job/notifikasi per cicilan.

Saat worker berjalan, baca ulang sumber dan preferensi, store/zone/identitas,
saldo efektif termasuk kredit/reversal, jam target dan hari H-1. Lunas/void,
kunjungan selesai/batal, preferensi off atau sumber hilang membatalkan job dan
notifikasi. Target/due/zone/nama toko berubah membatalkan versi lama. Job lama
tidak boleh memakai data toko lain setelah restore. Cache tidak membuktikan
saldo; projection invoice bersama merupakan authority yang sama dengan UI.
Nama WorkManager dan ID notifikasi yang dibatalkan dibatasi namespace supplier.

IPC dijalankan sesudah fakta bisnis commit, dengan DB lease untuk mencegah
evaluasi lama menimpa yang baru. Cache/OS yang gagal tidak membatalkan simpan
bisnis. Claim delivered_target ditulis **sebelum** show: sifatnya at-most-once,
bukan jaminan exactly-once antara SQLite dan Android. Crash pada celah tersebut
dapat melewatkan notifikasi; status/error dan badge perlu perhatian menjadi
fallback, tanpa retry show tanpa batas. Notifikasi lama dibatalkan sesudah hari
H-1; delivered target tetap tombstone untuk mencegah kirim ulang saat reopen.

Startup membatalkan namespace job supplier lalu mendaftarkan target masa depan
yang sesuai data sekarang. WorkManager sendiri menyimpan job melewati reboot;
force-stop, pembatasan baterai dan penolakan izin bisa menunda/menghilangkannya.
Target lampau tidak didaftarkan kembali saat aplikasi dibuka. Jangan menjanjikan
waktu tepat-menit atau H-1 alami dari bukti synthetic clock/native registration.
Tombstone delivered bertahan; restore memakai data yang dipulihkan dan runtime
yang baru, bukan grant sesi atau job milik toko sebelumnya.

Lock-screen text berisi jenis pengingat dan nama supplier maksimal80karakter,
tanpa nomor invoice/nominal/customer. Android visibility private, payload hanya
supplier-reminders. Tap/cold-launch menuju overview melalui gate pengelolaan;
owner due-list dan detail invoice tetap gate owner. Tidak membawa grant/PIN
melalui deep link. Izin hanya diminta pada alur pengaturan yang sudah ada, bukan
oleh worker. Opsi per dokumen tidak menyalakan izin/global consent diam-diam.

Backup validation memeriksa kunjungan/projection terhadap sequence dan snapshot
riwayat, typed dates/time/status/role serta preferensi pengingat invoice.
Tidak menganggap cache platform sebagai fakta keuangan. Migrasi aditif tidak
memasukkan receipt lama sebagai invoice/utang/kunjungan baru.
