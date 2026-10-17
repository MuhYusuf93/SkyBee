"""Add M5 semantic message metadata; keep the existing audit strict."""
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
messages={
 'driveRetryLimitReached':('Backup otomatis dihentikan setelah tiga percobaan gagal. Periksa koneksi dan coba backup manual. Jadwal hari berikutnya tetap aktif.','Automatic backup stopped after three failed attempts. Check the connection and try a manual backup. The next daily schedule remains active.'),
 'm5Connect':('Hubungkan','Connect'),
 'm5Connecting':('Menghubungkan printer…','Connecting printer…'),
 'm5Connected':('Terhubung ke printer','Connected to printer'),
 'm5ConnectionFailed':('Koneksi printer gagal. Periksa printer dan coba lagi.','Printer connection failed. Check the printer and try again.'),
 'm5ConnectionNotChecked':('Koneksi printer belum diperiksa','Printer connection has not been checked'),
 'm5CheckConnection':('Periksa koneksi','Check connection'),
 'm5BluetoothUnavailable':('Bluetooth tidak tersedia pada perangkat ini','Bluetooth is unavailable on this device'),
 'm5BluetoothDisabled':('Bluetooth mati. Aktifkan melalui pengaturan perangkat.','Bluetooth is off. Enable it in device settings.'),
 'm5BluetoothPermissionHelp':('Izin perangkat sekitar (lokasi pada Android lama) diperlukan saat memakai printer. Jika dialog izin tidak muncul lagi, periksa izin aplikasi di Pengaturan Android.','Nearby devices permission (location on older Android) is needed when using the printer. If the permission dialog no longer appears, check app permissions in Android Settings.'),
 'm5OpenSourceLicenses':('Lisensi perangkat lunak','Open source licenses'),
 'm5CopyWarning':('Periksa kertas yang sudah keluar. Data terkirim tidak menjamin hasil cetak, dan cetak ulang bisa menghasilkan struk rangkap. Lanjutkan sebagai SALINAN?','Check any paper already printed. Sent data does not confirm printing, and reprinting can produce duplicates. Continue as SALINAN (copy)?'),
 'm5DatabaseNewerSchema':('Database berasal dari versi aplikasi lebih baru. Gunakan versi yang sesuai; data tidak diganti.','This database requires a newer app version. Use a compatible version; data was not replaced.'),
 'm5LogoSize':('Ukuran logo dalam area cetak','Logo size within printable area'),
 'm5LineGap':('Jarak antarbaris','Line spacing'),
 'm5ChooseLogo':('Pilih logo toko','Choose shop logo'),
 'm5ApplyLogo':('Gunakan logo terpilih','Apply selected logo'),
 'm5RemoveLogo':('Sembunyikan logo toko','Remove shop logo'),
 'm5PrintSending':('Sedang mengirim data cetak','Sending print data'),
 'm5ReceiptPreview':('Pratinjau struk','Receipt preview'),
 'm5HideCode':('Sembunyikan kode pemulihan','Hide recovery code'),
 'm5LastAttempt':('Percobaan backup terakhir','Last backup attempt'),
 'm5LastSuccess':('Backup berhasil terakhir','Last successful backup'),
 'm5NextTarget':('Target backup berikutnya (waktu toko)','Next backup target (shop time)'),
 'm5NotScheduled':('Belum terjadwal','Not scheduled'),
 'm5RunRunning':('Sedang diproses','In progress'),
 'm5RunCompleted':('Berhasil diverifikasi','Verified complete'),
 'm5RunFailed':('Gagal; belum menjadi backup berhasil','Failed; not a successful backup'),
 'm5RunUnknown':('Status perlu diperiksa','Status needs review'),
 'm5RestoreContents':('Isi arsip dan identitas toko','Archive contents and shop identity'),
 'm5RestoreCurrent':('Toko saat ini','Current shop'),
}
for language,index in [('id',0),('en',1)]:
 path=root/f'lib/l10n/app_{language}.arb'
 data=json.loads(path.read_text(encoding='utf-8'))
 for key,values in messages.items():data[key]=values[index]
 for key in list(data):
  if (key.startswith('m5') or key in messages) and '@'+key not in data:
   data['@'+key]={'description':f'M5 printer, alerts or backup interface: {key}.'}
 path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
path=root/'lib/l10n/localization.dart'
source=path.read_text(encoding='utf-8')
for key in messages:
 if f"'{key}' =>" not in source:source=source.replace('    _ => key,',f"    '{key}' => l.{key},\n    _ => key,")
path.write_text(source,encoding='utf-8')
