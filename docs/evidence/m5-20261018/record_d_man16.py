"""Separate reported cloud-list emptiness from local job-history observations."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
def read(p):return p.read_text(encoding='utf-8-sig')
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
record={'id':'D-MAN16','date':'2026-10-18','status':'PASS reported scoped; UI ambiguity under investigation',
 'source':'user manual report', 'actual':'Account B Drive archive list empty;8 Verified complete/date rows below it, also seen for prior account.',
 'sourceInspection':'Provider.load reads runs from local DriveBackupService.history/backup_runs without account filtering; screen renders s.runs separately from s.remote. Eight rows consistent with earlier8real uploads, not8cloud archives on B.',
 'limits':'No independent native B identity/list or business audit in this step. No cloud mixing established. History lacks an explicit local/cross-account section heading; prepare C30 UI repro, no data deletion/filtering.'}
p=root/'docs/evidence/m5-20261018/d-man16-user-report.json';assert not p.exists();save(p,record)
step='Manual paused: C30 host repro/labels for local backup job history versus destination cloud list. Leave account B connected/automatic OFF; no uploads/restore. Device automation not active until explicit test phase.'
folders=['poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346','poco-account-ui-update-1792328869099']
for folder in folders:
 p=root/'docs/evidence/m5-20261016'/folder/'handover.json';v=json.loads(read(p));assert not v['automaticDeviceControlActive']
 v['manualStep']=step;v['manualEvidence'].append(record);v['manualResults']+=' D-MAN16 B cloud list empty,8local history rows reported; source confirms separate local history stream. C30 UI clarity repro pending.';save(p,v)
p=root/'docs/evidence/m5-20261018/c29-update-context.json';v=json.loads(read(p));v.update(manualStep=step,latestManualEvidence='docs/evidence/m5-20261018/d-man16-user-report.json');save(p,v)
note='**D-MAN16 akun B kosong dilaporkan pengguna,18 Oktober2026:** delapan baris Berhasil diverifikasi/tanggal juga terlihat. Source membuktikan s.remote berasal Drive API dan s.runs berasal backup_runs lokal semua akun; delapan pekerjaan konsisten checkpoint worker sebelumnya, bukan bukti delapan arsip B. Tampilan belum memberi heading/konteks akun riwayat lokal; C30 repro dan penjelasan UI disiapkan, tanpa menghapus riwayat atau mengubah retensi. Belum audit native B/isolation. Manual dijeda; perangkat belum dikontrol otomatis; B connected/autoOff dilaporkan. M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/d-man16-user-report.json).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 p=root/'docs'/name;t=read(p);i=t.index('\n')+1;p.write_text(t[:i]+'\n'+note+'\n\n'+t[i:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_DRIVE_ACCOUNT_CONTEXT_C29.md']:
 p=root/'docs'/name;p.write_text(read(p).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
print('D-MAN16 scoped manual report recorded; no device control')
