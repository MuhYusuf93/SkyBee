"""Record disconnect before the user's extra canceled picker; no frozen baseline."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
ev=root/'docs/evidence/m5-20261018'
def read(p):return p.read_text(encoding='utf-8-sig')
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
record={'id':'D-MAN17','date':'2026-10-18','status':'PASS reported scoped',
 'source':'user physical manual report on Poco C31',
 'actual':'Disconnect status/choose-account only/no account-upload-versions-auto controls/next unscheduled/local8history all matched before extra interaction.',
 'additionalInteraction':'User accidentally reopened account selection and returned/canceled without connecting an account.',
 'limits':'Current status text after the extra cancellation was not quoted. Do not treat interval as frozen or infer native policy/OS job cancellation; independent closing audit pending.'}
p=ev/'d-man17-user-report.json';assert not p.exists();save(p,record)
step='D-MAN17 disconnected PASS reported; extra Google picker canceled without connection. Manual finished for now; leave fixture untouched for C32 native regression/closing audit/originalAPK6 restoration. Host-only validation in progress; no device control yet.'
for item in json.loads(read(ev/'c31-handover-consistency.json')):
 p=root/'docs/evidence/m5-20261016'/item['folder']/'handover.json';v=json.loads(read(p));assert not v['automaticDeviceControlActive']
 v['manualEvidence'].append(record);v['manualResults']+=' D-MAN17 disconnect PASS reported; extra chooser canceled/no connection, native closing pending.';v['manualStep']=step;save(p,v)
p=ev/'c31-update-context.json';v=json.loads(read(p));v.update(manualStep=step,latestManualEvidence=str(ev/'d-man17-user-report.json'),newerSourceValidation=str(ev/'c32-update-context.json'));save(p,v)
save(ev/'c32-update-context.json',{'stage':'Host persisted-worker-status UI investigation/fix; native/build/deploy/closing pending', 'automaticDeviceControlActive':False,'installedCheckpoint':'C31','installedSha256':'ab00a7e191f354707a5cf847c04de620ffc6576231cf19ef197b2e6f99620641','priorContext':str(ev/'c31-update-context.json'),'reportedPolicy':'Disconnected after D-MAN17, extra chooser canceled; not yet native verified','manualStep':step,'originalV6RestorationPending':True,'closingPending':True})
note='**D-MAN17 PASS manual dilaporkan pengguna,18 Oktober2026:** Putuskan berhasil, kontrol akun/upload/versi/otomatis hilang, target belum terjadwal dan8riwayat tetap. Sesudahnya pemilih akun sempat dibuka tak sengaja lalu dibatalkan tanpa menghubungkan; teks status akhir tidak dikutip dan metadata tidak diasumsikan beku. Berikut regresi status worker C32 dan audit penutup/pemulihan exact originalAPK6; manual dijeda, kontrol perangkat belum aktif pada persiapan host. M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/d-man17-user-report.json).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 p=root/'docs'/name;t=read(p);i=t.index('\n')+1;p.write_text(t[:i]+'\n'+note+'\n\n'+t[i:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_SILENT_AUTHORIZATION_C31.md']:
 p=root/'docs'/name;p.write_text(read(p).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
print('D-MAN17 and extra canceled picker recorded; C32 host work, no device control')
