"""Record the user's seven-version observation without device automation."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
def read(path):
    return path.read_text(encoding='utf-8-sig')
def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

record = {
    'id':'D-MAN15a','date':'2026-10-18','status':'PASS',
    'source':'user manual report: ya',
    'scope':'C29 Poco: automatic left ON; Versions backup Drive displays7archive rows with Select for recovery buttons.',
    'limits':'UI observation only; no new upload/download/restore or account B selection. Conditional PIN prompt not assumed. Independent real retention/native audit evidence remains separate.',
}
destination = root/'docs/evidence/m5-20261018/d-man15a-user-report.json'
assert not destination.exists(), 'Do not record the same manual response twice'
save(destination, record)
step = 'D-MAN15b: choose a different registered test Google account B, authorize Drive if prompted, PIN0001 if locked; inspect pending unsaved account and Use this account. Do not accept yet, upload or restore. Automatic device control remains OFF.'
folders = ['poco-manual-20261016-191759','poco-manual-update-1792156485701',
 'poco-permission-update-1792174330020','poco-export-update-1792178476161',
 'poco-archive-update-1792181574653','poco-notification-update-1792195919961',
 'poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903',
 'poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346',
 'poco-account-ui-update-1792328869099']
for folder in folders:
    path=root/'docs/evidence/m5-20261016'/folder/'handover.json'
    data=json.loads(read(path))
    assert data['automaticDeviceControlActive'] is False
    assert data['fixtureSha256']=='2f114edc869e4466aae6a9788e1b7bb6cda78c90b0528cce0e8a4981ab34cf6e'
    data['manualStep']=step
    data['manualEvidence'].append(record)
    data['manualResults']+=' D-MAN15a seven Drive archive rows with restore-selection buttons PASS user-reported; account B not selected yet.'
    save(path,data)
context=root/'docs/evidence/m5-20261018/c29-update-context.json'
data=json.loads(read(context));assert not data['automaticDeviceControlActive']
data.update(manualStep=step,latestManualEvidence=str(destination));save(context,data)
note='**D-MAN15a PASS manual dilaporkan pengguna,18 Oktober2026:** pada C29 Poco, Backup Drive otomatis dibiarkan ON dan Versi backup Drive menampilkan7baris arsip dengan tombol Pilih untuk pemulihan. Ini observasi UI; tidak ada unggah/unduh/restore baru atau pemilihan akun B. Bukti retensi/worker/native sebelumnya tetap terpisah. Berikut D-MAN15b pilih akun uji berbeda hingga kandidat belum disimpan/Gunakan akun ini, tanpa konfirmasi tujuan dahulu. Kontrol perangkat Off; M5 belum selesai/M6 tidak dimulai; originalAPK6/closing pending. [Bukti](evidence/m5-20261018/d-man15a-user-report.json).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
    path=root/'docs'/name;text=read(path);position=text.index('\n')+1
    path.write_text(text[:position]+'\n'+note+'\n\n'+text[position:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_DRIVE_ACCOUNT_CONTEXT_C29.md']:
    path=root/'docs'/name;path.write_text(read(path).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
print(json.dumps({'manual':'D-MAN15a PASS reported','handovers':11,'control':False,'next':'D-MAN15b'}))
