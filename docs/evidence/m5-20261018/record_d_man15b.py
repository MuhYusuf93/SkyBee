"""Record pending second-account selection; no device or Google automation."""
import json
from pathlib import Path

root=Path(__file__).resolve().parents[3]
def read(path): return path.read_text(encoding='utf-8-sig')
def save(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
record={'id':'D-MAN15b','date':'2026-10-18','status':'PASS','source':'user manual report: ya',
 'scope':'Different test account B privately checked by user; pending unsaved selection and Use this account visible on C29 Poco.',
 'limits':'Not yet accepted/stored. No second-account list, upload, download, restore or isolation proof. Conditional Google consent and PIN prompts not assumed to have appeared. No identity/token logged.'}
destination=root/'docs/evidence/m5-20261018/d-man15b-user-report.json'
assert not destination.exists()
save(destination,record)
step='D-MAN15c: accept pending account B once; inspect saved/correct destination, automatic OFF, target not scheduled, old7Drive archive rows and pending account controls gone without refresh. No upload, versions reload or restore. Device control OFF.'
folders=['poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346','poco-account-ui-update-1792328869099']
for folder in folders:
 path=root/'docs/evidence/m5-20261016'/folder/'handover.json';data=json.loads(read(path))
 assert data['automaticDeviceControlActive'] is False
 data['manualStep']=step;data['manualEvidence'].append(record)
 data['manualResults']+=' D-MAN15b different account B pending/unsaved/use-account UI PASS user-reported; acceptance and isolation not yet tested.'
 save(path,data)
context=root/'docs/evidence/m5-20261018/c29-update-context.json';data=json.loads(read(context))
assert not data['automaticDeviceControlActive']
data.update(manualStep=step,latestManualEvidence=str(destination));save(context,data)
note='**D-MAN15b PASS manual dilaporkan pengguna,18 Oktober2026:** akun uji kedua yang berbeda telah dipilih dan diperiksa pribadi; Pilihan akun belum disimpan/Gunakan akun ini terlihat pada C29 Poco. Tujuan B belum dikonfirmasi; tidak membuktikan penyimpanan policy, daftar B atau isolasi cloud. Dialog izin/PIN kondisional tidak diasumsikan muncul. Berikut D-MAN15c konfirmasi sekali, periksa tujuan B/otomatis Off/target belum terjadwal dan daftar7versi lama kosong tanpa refresh. Jangan unggah/restore. Kontrol perangkat Off; M5 belum selesai/M6 tidak dimulai; originalAPK6/closing pending. [Bukti](evidence/m5-20261018/d-man15b-user-report.json).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 path=root/'docs'/name;text=read(path);position=text.index('\n')+1
 path.write_text(text[:position]+'\n'+note+'\n\n'+text[position:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_DRIVE_ACCOUNT_CONTEXT_C29.md']:
 path=root/'docs'/name;path.write_text(read(path).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
print(json.dumps({'manual':'D-MAN15b PASS reported','control':False,'next':'D-MAN15c'}))
