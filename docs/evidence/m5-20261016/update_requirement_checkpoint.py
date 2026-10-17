"""Record the M5 decision and implementation mapping without renumbering IDs."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[3]
spec = root / 'docs/SPEC.md'
text = spec.read_text(encoding='utf-8')
text = text.replace('dan SQLite melalui `sqflite` untuk Android.', 'dan SQLite terenkripsi SQLCipher melalui adapter kompatibel `sqflite` untuk Android (keputusan M5, 16 Oktober 2026).')
old_printer = 'Model printer saya belum ditentukan: pilih dependency yang terawat dan sesuai versi Flutter, jelaskan cakupan Bluetooth Classic/BLE yang benar-benar didukung, dan catat kebutuhan uji perangkat nyata.'
new_printer = 'Target utama Iware MP-581RL/RPP02N 58 mm melalui Bluetooth Classic SPP; gunakan adapter native yang sesuai versi Android/Flutter, dokumentasikan kemampuan aktual dan uji kertas nyata. BLE/USB serta hardware 80 mm belum didukung atau dibuktikan oleh profil generik saja.'
text = text.replace(old_printer, new_printer)
old_crypto = 'Jika arsip tidak terenkripsi, nyatakan dengan benar. Jika menambahkan enkripsi opsional, gunakan standar autentikasi kriptografi yang benar, kunci pemulihan yang dapat dipakai di perangkat baru, dan jangan memakai PIN empat digit sebagai satu-satunya kunci.'
new_crypto = 'Arsip wajib terenkripsi dan terautentikasi sesuai keputusan M5: recovery kuat yang portable, terpisah dari PIN empat digit dan key Keystore instalasi. Tidak ada fallback arsip plaintext; kehilangan recovery dapat membuat backup tidak dapat dipulihkan.'
text = text.replace(old_crypto, new_crypto)
spec.write_text(text, encoding='utf-8')

matrix = root / 'docs/REQUIREMENTS.md'
text = matrix.read_text(encoding='utf-8').replace(old_printer, new_printer).replace(old_crypto, new_crypto)
old_ids = re.findall(r'^\| (R\d+-\d+) \|', text, re.M)
lines = []
for line in text.splitlines():
    match = re.match(r'^\| (R(12|13|14)-\d+) \|', line)
    if match:
        fields = line.split('|')
        requirement = match[1]
        if requirement.startswith('R12-'):
            fields[-4] = ' features/printer; ReceiptLayout/PrintQueue/StoreLogoService; native PrinterBluetooth; PRINTER_SETUP_AND_CALIBRATION '
            fields[-3] = ' m5_print_queue 7 cas; manifest/logo 5 cas; settings UI; M5_TEST_REPORT, PRINTER_TEST_REPORT_M5 '
            fields[-2] = ' Implemented; automated fake/layout PASS, ClassicSPP/Iware paper/permissions physical UNVERIFIED '
        elif requirement.startswith('R13-'):
            fields[-4] = ' features/backup; EncryptedDatabase/DurablePromotion/BackupService/BackupValidation; PortableArchive/SAF; DriveRest/DriveBackupService/BackupScheduler '
            fields[-3] = ' Native DV backup WAL/concurrency 1 PASS, migration faults 5 PASS; JVM archive 6 PASS; Windows Drive mocks/calendar; M5_TEST_REPORT '
            fields[-2] = ' Implemented; native subset PASS; latest restore faults/SAF physical/real OAuth/Drive/cross-device UNVERIFIED '
        elif requirement in ('R14-001', 'R14-002', 'R14-003'):
            fields[-4] = ' features/alerts; AlertService/AndroidAlertNotifications/M5Runtime; private notification payload and PIN route '
            fields[-3] = ' m5_alerts_test 3 PASS threshold/rearm/calendar/dedup; native worker FLN init PASS; M5_TEST_REPORT '
            fields[-2] = ' Implemented; automated sink PASS; actual permission/tap/OEM delivery UNVERIFIED '
        line = '|'.join(fields)
    lines.append(line)
text = '\n'.join(lines) + '\n'
new_ids = re.findall(r'^\| (R\d+-\d+) \|', text, re.M)
assert old_ids == new_ids and len(set(new_ids)) == 244
checkpoint = '''**Pembaruan M5 — 16 Oktober 2026 setelah reboot Realme:** modul M5 tersedia dalam file, validasi akhir masih berlangsung. SQLCipher domain Realme **88 PASS**, manual DB+sidecar unchanged dan original APK restored; DV backup WAL/concurrency1 PASS/migration faults5 PASS/worker lintas PID1 PASS. Profile ARM32 sebanding tersedia pada M5_TEST_REPORT. Implementasi dan bukti R12/R13/R14 diperbarui di matriks tanpa mengubah 244 ID. Printer kertas/OAuth Drive/ARM64 Poco/lintas perangkat belum terverifikasi; pending/aktif pada checkpoint lama di bawah adalah histori. Tidak memulai M6.

'''
text = text.replace('# Matriks persyaratan', '# Matriks persyaratan', 1)
first, separator, rest = text.partition('\n')
matrix.write_text(first + '\n\n' + checkpoint + rest.lstrip('\n'), encoding='utf-8')

plan = root / 'docs/PLAN.md'
text = plan.read_text(encoding='utf-8')
first, separator, rest = text.partition('\n')
checkpoint = '''**Rencana M5 terbaru, 16 Oktober 2026:** implementasi fondasi SQLCipher, printer/preview/queue, alerts, backup lokal/restore dan Drive/WorkManager telah tersedia. Realme native domain88 PASS setelah reboot; source/tes/perbaikan dan batas bukti dicatat pada M5_IMPLEMENTATION_REPORT/M5_TEST_REPORT. Selesaikan tes fault restore/UI native serta retest DV adapter; analyzer/full Windows; build ordinary dan fixture release universal beserta ABI/16KiB/lisensi; kemudian validasi Poco ARM64/Iware/Google nyata saat pengguna menyediakan HP. Jangan menganggap implementasi sama dengan acceptance hardware/OAuth. Pulihkan semua awake settings DV, pertahankan DB manual Realme dan exact APK original. M6 tetap di luar lingkup. Checkpoint awal berikut dipertahankan sebagai histori.

'''
plan.write_text(first + '\n\n' + checkpoint + rest.lstrip('\n'), encoding='utf-8')
print('Updated SPEC, PLAN, REQUIREMENTS; original 244 IDs preserved.')
