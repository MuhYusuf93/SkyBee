> Handoff pengguna; hasil native/root dan kertas berikut dilaporkan pengguna, bukan pengujian aplikasi oleh agent.

# Handoff Hasil Pengujian USB Printer DV8910 — BERHASIL

Saya telah melakukan investigasi dan pengujian cetak USB secara independen melalui PowerShell, ADB LAN, Python, dan program native C, tanpa menggunakan aplikasi integrasi SkyBee.

**HASIL AKHIR: BERHASIL. Printer mengeluarkan struk dan saya telah mengonfirmasi hasil cetaknya sempurna.**

Gunakan temuan ini untuk mengevaluasi dan menyempurnakan modul USB printing SkyBee.

## 1. Identitas perangkat pengujian

### Android target

- **Hardware:** DV8910, rooted dengan Magisk dan unlock bootloader.
- **ADB LAN:** `192.168.0.102:5555`.
- **ABI:** `armeabi-v7a`.
- **Android API:** 30.
- **Identitas firmware yang dilaporkan Android:** DV8947-KIX / AX810 / XLHomeSTB22. Jangan mempermasalahkan identitas firmware ini karena hardware sudah diverifikasi sebagai DV8910.

### Printer

- **Nama perangkat:** PYN-58L.
- **Model printer:** Iware MP-581RL.
- **Manufacturer USB:** GEZHI.
- **Vendor ID:** `0x0483` (1155 desimal).
- **Product ID:** `0x5720` (22304 desimal).
- **Serial USB saat pengujian:** `USB001`.
- **USB printer interface:** Class `7`, Subclass `1`, Protocol `2`.
- **Interface number:** `0`.
- **Alternate setting:** `0`.
- **Bulk OUT:** `0x01`.
- **Bulk IN:** `0x81`.
- **Endpoint type:** Bulk (`2`).
- **Max packet size:** 64 byte.

Node saat pengujian terakhir: `/dev/bus/usb/001/002`. **Jangan hardcode node ini**, karena alamat USB dapat berubah setelah reconnect.

## 2. Kronologi diagnosis

Awalnya printer tidak terdeteksi oleh kernel Linux maupun Android USB Manager.

Hasil pemeriksaan awal:
- USB Host tersedia.
- xHCI dan root hub terdeteksi.
- Belum ada perangkat printer yang terenumerasi.
- Aplikasi integrasi melaporkan **0 printer, 0 pengiriman, dan 0 byte**.

Setelah dilakukan investigasi:

1. Printer ternyata belum dinyalakan pada sebagian pengujian awal.
2. Flashdisk Toshiba TransMemory `0930:6544` berhasil terenumerasi melalui USB Host DV8910.
3. Printer kemudian dinyalakan dan dipasang ke port USB-A yang terbukti berhasil mendeteksi flashdisk.
4. Kernel berhasil mendeteksi printer `0483:5720`.
5. `dumpsys usb` mengonfirmasi Android USB Host Framework mengenali PYN-58L berikut interface dan dua endpoint Bulk.
6. Pesan kernel `Unsupported device` sempat terlihat, tetapi ternyata tidak mencegah enumerasi Android maupun keberhasilan cetak USB secara langsung.

**Kesimpulan:** masalah awal tidak membuktikan adanya kegagalan adapter USB aplikasi. Kondisi daya printer dan koneksi fisik perlu dibedakan dari masalah software.

## 3. Pengujian independen pertama

Saya menggunakan skrip Python dengan program native C yang dikompilasi melalui Android NDK.

Toolchain:
- Python 3.14.7.
- Android NDK 28.2.13676358.
- Target kompilasi: `armv7a-linux-androideabi21`.

Pengujian pertama gagal menemukan printer meskipun printer terdeteksi Android.

Dugaan penyebabnya adalah pembungkusan perintah `su -c` yang tidak membuat seluruh program native dieksekusi sebagai root.

## 4. Pengujian independen kedua — BERHASIL

Skrip revisi:
- `print_dv8910_v2.py`
- `usb_bulk_print.c`

Lokasi saat pengujian: `C:\platform-tools\`.

Perintah:

```powershell
py -3 .\print_dv8910_v2.py
```

Perintah eksekusi native yang berhasil:

```powershell
adb -s 192.168.0.102:5555 shell su -c 'chmod 700 /data/local/tmp/skybee_usb_bulk_once && exec /data/local/tmp/skybee_usb_bulk_once'
```

Output penting:

```text
Program berjalan: uid=0 euid=0
Printer tepat satu: VID:PID 0483:5720; interface 7/1/2; node /dev/bus/usb/001/002
USB Bulk OUT: 100 byte diterima kernel USB. Periksa kertas untuk konfirmasi cetak fisik.
```

**Konfirmasi fisik saya: BERHASIL TERCETAK SEMPURNA.**

Ini membuktikan:
- Jalur USB Host DV8910 berfungsi.
- Printer mampu menerima data USB dari DV8910.
- Endpoint Bulk OUT `0x01` berhasil digunakan.
- Printer benar-benar mengeluarkan hasil cetak.

Program native dijalankan dengan root dan menggunakan mekanisme USBFS. Keberhasilan metode ini **bukan bukti bahwa SkyBee harus memerlukan root**.

**Status handoff: Cetak USB native berhasil dan dikonfirmasi secara fisik. Cetak USB melalui aplikasi SkyBee masih perlu diverifikasi.**

Jika berkas tersedia dalam workspace yang sama, gunakan `C:\platform-tools\print_dv8910_v2.py` dan `C:\platform-tools\usb_bulk_print.c` sebagai referensi pengujian native, bukan sebagai dependensi produksi aplikasi.
