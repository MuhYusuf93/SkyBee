"""Record actual account acceptance UI; retain device controls OFF."""
import json
from pathlib import Path

root=Path(__file__).resolve().parents[3]
def read(path): return path.read_text(encoding='utf-8-sig')
def save(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
record={'id':'D-MAN15c','date':'2026-10-18','status':'PASS','source':'user manual report: ya',
 'scope':'C29 Poco: account B accepted once, destination privately correct, saved/automatic-off status, switch OFF, target not scheduled, pending controls gone and previous7Drive rows cleared without refresh.',
 'limits':'Actual acceptance and UI invalidation reported; not yet a request for account B versions or proof of cloud isolation/job cancellation/unchanged SQL. No upload, automatic opt-in or restore performed in this step.'}
destination=root/'docs/evidence/m5-20261018/d-man15c-user-report.json'
assert not destination.exists();save(destination,record)
step='D-MAN16: while account B connected and automatic OFF, request Drive versions once; report actual count/empty notice/error without identity. Do not select files, upload, enable automatic, switch accounts or restore. Device control OFF.'
folders=['poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346','poco-account-ui-update-1792328869099']
for folder in folders:
 path=root/'docs/evidence/m5-20261016'/folder/'handover.json';data=json.loads(read(path))
 assert data['automaticDeviceControlActive'] is False
 data['manualStep']=step;data['manualEvidence'].append(record)
 data['manualResults']+=' D-MAN15c account B accepted/automatic OFF/target cleared/old7remote rows cleared without refresh PASS user-reported; B listing/cloud isolation still pending.'
 save(path,data)
context=root/'docs/evidence/m5-20261018/c29-update-context.json';data=json.loads(read(context))
assert not data['automaticDeviceControlActive']
data.update(manualStep=step,latestManualEvidence=str(destination),reportedPolicyState='account B connected, automatic OFF; native state not yet audited');save(context,data)
note='**D-MAN15c PASS manual dilaporkan pengguna,18 Oktober2026:** pada C29 Poco, tujuan akun B dikonfirmasi sekali, status Akun tujuan disimpan/otomatis nonaktif, switch Off, target belum terjadwal, kandidat sementara hilang dan7baris arsip A kosong tanpa refresh. Ini validasi fisik UI C29 sesudah ganti akun, bukan bukti daftar cloud B, cancel job OS atau SQL/policy native. Berikut D-MAN16 muat Versi backup Drive pada B dan laporkan jumlah/keadaan kosong/error; jangan unggah/restore/aktifkan otomatis. Kontrol perangkat Off; M5 belum selesai/M6 tidak dimulai; originalAPK6/closing pending. [Bukti](evidence/m5-20261018/d-man15c-user-report.json).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 path=root/'docs'/name;text=read(path);position=text.index('\n')+1
 path.write_text(text[:position]+'\n'+note+'\n\n'+text[position:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_DRIVE_ACCOUNT_CONTEXT_C29.md']:
 path=root/'docs'/name;path.write_text(read(path).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
path=root/'docs/M5_FIXES_AND_VALIDATION.md';text=read(path)
text=text.replace('Fixed pada cakupan otomatis/native mocks; real second-account UI pending; M5_DRIVE_ACCOUNT_CONTEXT_C29','Fixed otomatis/native mocks; real account B accept/old-list invalidation/autoOff/target clear PASS manual D-MAN15c; B cloud listing/isolation pending; M5_DRIVE_ACCOUNT_CONTEXT_C29')
path.write_text(text,encoding='utf-8')
print(json.dumps({'manual':'D-MAN15c PASS reported','control':False,'next':'D-MAN16'}))
