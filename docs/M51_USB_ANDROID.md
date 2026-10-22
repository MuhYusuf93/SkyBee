# M5.1-F — transport USB Android

**Penutupan21 Oktober2026:** default profil baru6LF dan saved3 terverifikasi
host77 (mencakup queue) serta native Poco1PASS16s melalui output fake; seluruh
392hash lama cocok/controlOff. Ordinary debug0.5.1+8 terbaru sudah di Poco,
release tersedia; [laporan akhir](M51_FINAL_REPORT_20261021.md). Tidak ada cetak
ulang/diagnostik baru saat resume karena printer tidak terhubung. Paper baru
default6 tetap UNVERIFIED. Hasil raster/footer di bawah dipertahankan sebagai
bukti historis, bukan klaim penyebab flush atau paper default6 sudah lulus.

**Checkpoint pindah chat20 Oktober:** v2 sudah1PASS6s/41717byte/11chunk. Logo,
barang dan nominal sesuai dilaporkan pengguna; footer baru terlihat sesudah
feed-only3LF/3byte1PASS4s. Pengguna menjelaskan sebelumnya footer belum tercetak;
belum diketahui posisi internal versus flush. Default profil baru6baris, saved3
tetap; regresi/default6 end-to-end belum lengkap. Runner controlOff dan awake
pulih exact pada bukti. Jangan mengulang marker yang sudah submitted. Titik
lanjut lengkap: [NEXT_SESSION_M51](NEXT_SESSION_M51.md). Paragraf berikut historis.

Checkpoint20 Oktober2026: uji raster/cash pertama SKIPPED0target/0byte karena
kabel dipakai bergantian. Setelah printer disambungkan ulang, izin Android normal
UID10115 diberikan melalui button1 dialog printer yang diamati; request pertama
timeout20detik/0byte, bukan penolakan permanen atau kegagalan cetak. Percobaan
berikutnya FAIL usb_invalid_chunk5s: helper mengirim seluruh raster >4096bytes.
UsbPrinterIo menolak sebelum Link.transfer; antrean produksi sudah memakai
4096bytes. Guard tidak diubah. Marker v1 tetap ada, helper direvisi ke4096bytes
dalam satu output lease dengan marker v2; hasil v2 sedang diverifikasi. Tidak
mengarang paper PASS atau menghapus hasil/marker sebelumnya. Poco sengaja
dicabut sampai verifikasi kertas, lalu kabel dipindah untuk audit/handoff.

19 Oktober2026, source0.5.1+8/schema11. Implementasi adapter tersedia; diagnostik
pendek Android DV81byte/kertas PASS reported, sedangkan skenario fisik lain belum
terverifikasi. USB PC81/81byte dan kertas yang dikonfirmasi
pengguna tetap bukti jalur Windows, bukan bukti Android OTG.

## Kontrak dan kepemilikan

`PrinterUsb.java` menggunakan USB Host resmi, interface printer class7/subclass1,
protocol1/2, alternate0, tepat satu endpoint BULK_OUT. Bukan driver serial vendor.
Tidak root, force-claim, install driver, auto-attach, pilih perangkat pertama,
auto-fallback Bluetooth atau mengubah default aplikasi USB. Feature Host optional
pada manifest, sehingga perangkat tanpa Host tetap dapat memakai kasir/Bluetooth.

Enumerasi dibatasi128device/32interface/32endpoint per device. Izin hanya untuk
pilihan eksplisit saat foreground; request nonce,20detik, grant aktual dan
attachment diperiksa ulang. Satu prompt per attachment, retry eksplisit setelah
denial; hasil terlambat tidak memulihkan sesi PIN. Identitas session UUID berubah
saat reattach. Serial yang layak dan unik di-hash bersama VID/PID/interface untuk
profil persisten; serial generik/duplikat/tidak tersedia memakai identitas sementara.
Ambiguitas ditolak, bukan memilih kandidat diam-diam.

`UsbPrinterIo.java` memiliki batas chunk4096byte/timeout5detik. Short/zero/error
write atau detach menjadi hasil ambigu, koneksi sendiri ditutup tanpa retry.
Detach bisa menutup koneksi tanpa menunggu monitor write; exception close tidak
menjatuhkan aplikasi. Tidak mengklaim seluruh printer thermal/serial didukung.

`NativePrinterTransport` memakai `printerConnect`/`printerWrite` berdasarkan
awalan identitas. `PrinterOutputGate` menyerialkan satu dokumen serta penggantian
koneksi dengan recovery print/restore. Printer tetap sesudah commit; kegagalan
output tidak mengubah penjualan, stok, uang atau piutang. Profil kalibrasi dan
transport terpisah; daftar filter/keyset50 konsisten index BINARY/schema11.
UI memiliki pilihan Bluetooth/USB serta pesan izin/koneksi Indonesia–Inggris.

## Bukti dan batas

- JVM19PASS19s keseluruhan, termasuk8kasusUSB: kelas/endpoint, izin ditolak,
  detach sebelum/selama write, partial/timeout tanpa retry, chunk dan close.
- Host awal27PASS58s, USB UI focused2PASS10s; full host UI final35 dan
  alert3PASS05:25 setelah pembetulan helper native lifecycle.
- Realme native7PASS/1FAIL awal: migration terhalang mock platform yang ikut
  menangkap Keystore DB kedua. Scope mock diperbaiki, focused migration1PASS23s.
  Tujuh kasus awal mencakup enumerasi Host aktual tersedia/0target, bukan cetak.
- DV probe awal dan sesudah pergantian port: Host true,0target,0byte,
  `BLOCKED_NO_USB_TARGET`, semua kasus probe SKIPPED. OS hanya memperlihatkan
  root hubs/num_connects0. Tidak menebak penyebab kabel/port/firmware.
  Label PASS generik run pertama dikoreksi secara historis sebagai all-skipped;
  classifier runner kini mencatat SKIPPED.
- Semua hash berkas lama yang dilindungi sama. DV awake dipulihkan/readback exact,
  tidak ada perubahan firmware/sistem/aplikasi lain atau print yang dikirim.
- Permission dialog USB, Android paper, cabut fisik/partial nyata, kertas habis,
  logo/struk panjang dan transport switch fisik: NOT VERIFIED. Probe satu kali
  memakai allowlist VID0483/PID5720 dan marker sebelum write; jangan retry bila
  hasil ambigu. Pemeriksaan kertas baru diminta setelah benar-benar mengirim.

[Bukti DV](evidence/m51-20261019/f-dv-usb-initial-and-port-recheck.json),
[Realme](M5_REALME_CURRENT_AUTOMATED_20261019.md).
Dasar API: [Android USB Host](https://developer.android.com/develop/connectivity/usb/host)
dan [UsbDeviceConnection](https://developer.android.com/reference/android/hardware/usb/UsbDeviceConnection).

## Bukti lanjutan — target kini terdeteksi

Handoff native/root dari pengguna100byte/paper PASS reported disimpan terpisah.
Framework Android kini mengenali1PYN-58L0483:5720. Adapter aplikasi dalam fixture
debug0.5.1+8 berhasil1write/81byte, native1PASS4s; izin dialog biasa/UID10115,
tanpa root. Semua hash lama sama/awake pulih/readback exact dan kontrol Off.
Pada checkpoint pengiriman, paper masih PENDING (konfirmasi di bawah); jangan
menghapus hasil0target lama atau menyamakannya
dengan keadaan target sekarang. Logo/panjang/partial/detach fisik tetap belum
terverifikasi. [Percobaan, helper fokus/izin, identitas APK dan handoff](M51_DV_USB_APP_20261019.md).

Konfirmasi berikutnya: pengguna menjawab “ya” untuk lima baris cetakan aplikasi
yang baru, utuh/jelas/tidak terpotong. **PASS manual reported** untuk diagnostik
pendek tersebut; bukan bukti seluruh skenario USB fisik. Tidak ada reprint.
