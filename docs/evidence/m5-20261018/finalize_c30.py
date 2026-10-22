"""Finalize only after C30 native/build/real-B audit and safe deployment."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

root=Path(__file__).resolve().parents[3]
def read(p):return p.read_text(encoding='utf-8-sig')
def load(p):return json.loads(read(p))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

context=root/'docs/evidence/m5-20261018/c30-update-context.json'
evidence=Path(load(context)['ledger']).parent;ledger=load(evidence/'update.json')
assert ledger['state']=='C30 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert ledger['automaticDeviceControlActive'] is False and 'failure' not in ledger
nonce=ledger['nonce'];base_evidence=root/'docs/evidence/m5-20261016'
poco=list(base_evidence.glob(f'poco-c30-ui-{nonce}-*'));dv=list(base_evidence.glob(f'c30-ui-{nonce}-*'))
assert len(poco)==1 and '+7: All tests passed!' in read(poco[0]/'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(poco[0]/'isolation.txt')
dv_status=ledger['dv']
if not dv_status.startswith('BLOCKED'):
 assert len(dv)==1 and '+7: All tests passed!' in read(dv[0]/'runner.log')
 assert load(dv[0]/'awake-original.json')['Restored']
 assert read(evidence/'dv-legacy-before.txt')==read(evidence/'dv-legacy-after.txt')
 assert sha(evidence/'dv-prior.apk')==sha(evidence/'dv-restored.apk')
 dv_status='7PASS Drive/history UI mocks; exact prior APK/default hashes/awake restored/read back'
assert '+52: All tests passed!' in read(root/'docs/evidence/m5-20261018/c30-host-regression.log')
assert '+7: All tests passed!' in read(root/'docs/evidence/m5-20261018/c30-drive-focused-final.log')
analyze=read(root/'docs/evidence/m5-20261018/c30-analyze.log');assert 'No issues found!' in analyze
before,after=Path(ledger['beforeEvidence']),Path(ledger['afterEvidence'])
for folder,role in [(before,'before'),(after,'after')]:
 output=read(folder/'runner.log')
 assert '+1: All tests passed!' in output
 assert f'M5_ACCOUNT_B_AUDIT {role} integrity/FK/envelope/financial facts/all tables/13archives/policy PASS' in output
 assert re.search(r'^Success$',read(folder/'original-restored.log'),re.M)
assert 'M5_ACCOUNT_B_READ_ONLY listEmpty=true identityDifferentFromA=true priorAFileUnavailable=true disabledRunRejected=true allTablesUnchanged=true' in read(before/'runner.log')
assert read(before/'ordinary-before.txt')==read(after/'ordinary-after.txt')
assert read(poco[0]/'ordinary-before.txt')==read(after/'ordinary-after.txt')
assert read(evidence/'public-before.txt')==read(evidence/'public-after.txt')
assert sha(evidence/'installed-c30.apk')==ledger['fixtureSha256']
startup=load(evidence/'startup.json');assert startup['synthetic_screen_visible'] and startup['startup_error_markers']==0

folders=['poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346','poco-account-ui-update-1792328869099']
paths=[base_evidence/folder/'handover.json' for folder in folders];base=load(paths[-1])
original=str(base_evidence/'poco-manual-20261016-191759/original-fixture.apk')
step='C30-MAN01: account B/automatic OFF; request Drive versions once. Verify empty-page notice, device-local history heading/help,8Verified complete rows labelled Another/previous account. No upload/restore/disconnect yet. Automatic device control OFF.'
audit={'id':'C30-AUTO','date':'2026-10-18','status':'PASS','source':'host/native UI mocks/build/fresh strict update',
 'host':'52PASS146s; focused7 strengthened-language/state cases subset','poco':'7PASS Drive/history UI mocks','dv':dv_status,
 'analyzer':re.search(r'No issues found! \(ran in ([0-9.]+)s\)',analyze).group(1)+'s No issues',
 'strictUpdate':'before1PASS/after1PASS; all tables/13archives/policy identical after documented fixture PIN metadata baseline; account B connected/autoOFF;8A-run identities distinct from B',
 'build':'ordinary/fixture/bridge universal min24/16KiB/icon/licenses/signature/negative guard verified; ordinary not installed',
 'startup':startup,'ledger':str(evidence/'update.json'),
 'limits':'Physical C30 label retest pending. Natural21/reboot/Doze/other-origin cloud preservation/OS-job cancellation/in-flight-account-change remain unverified.'}
b_audit={'id':'D-AUTO-ACCOUNT-B01','date':'2026-10-18','status':'PASS scoped','source':'real Poco accepted B account; API read-only and disabled-run guard',
 'actual':'B permission identity distinct from8A records; B namespace empty; prior verified A archive ID unavailable through B; headless operation rejected while autoOFF, no new run/archive; whole DB unchanged after public PIN metadata baseline',
 'pinMetadata':'Fixture0001 auth changed only credential/audit tables; all business hashes unchanged. No secret/identity payload reported.',
 'ledger':str(evidence/'update.json'),'evidence':str(before/'runner.log'),
 'limits':'Not a concurrent positive readback on A or cross-device Google test. Does not prove Android OS job cancellation, Doze/reboot or in-flight account change.'}
for path in paths+[evidence/'handover.json']:
 data=load(path) if path in paths else copy.deepcopy(base)
 assert data['originalApk']==original and data['restoreOriginalPending'] and not data['automaticDeviceControlActive']
 data.update(fixtureApk=ledger['newApk'],fixtureSha256=ledger['fixtureSha256'],restoreBridge=ledger['restoreBridge'],automaticDeviceControlActive=False,manualStep=step,restoreOriginalPending=True,closingAuditPending=True,c30Audit=audit)
 data['manualResults']+=' D-AUTO-ACCOUNT-B01 B0files/Aidentity distinct/Afile unavailable/autoOFF rejects run/read-only all tables stable PASS; C30 host52/native7per device/build/strict13archive preservation/startup PASS; physical labels pending.'
 data['manualEvidence'].extend([b_audit,audit])
 history=data.setdefault('apkHistory',[]);assert not any(isinstance(item,dict) and item.get('checkpoint')=='C30' for item in history)
 history.append({'checkpoint':'C30','date':'2026-10-18','sha256':ledger['fixtureSha256'],'apk':ledger['newApk'],'scope':'Separate cloud archive list/empty-page and local cross-account upload history, ID/EN context labels; no history deletion/business changes'})
 save(path,data)
ledger.update(state='C30 checks/real B audit/preservation PASS; manual history handover ready',automaticDeviceControlActive=False,manualStep=step,nativePocoEvidence=str(poco[0]),nativeDvEvidence=str(dv[0]) if dv else None,dv=dv_status)
ledger['sourceSha256']={name:sha(root/name) for name in ['lib/features/backup/presentation/backup_settings_provider.dart','lib/features/backup/presentation/backup_settings_screen.dart','lib/l10n/localization.dart','lib/l10n/app_id.arb','lib/l10n/app_en.arb','test/m5_settings_ui_test.dart','integration_test/m5_account_b_audit_test.dart']}
save(evidence/'update.json',ledger)
save(context,{'stage':ledger['state'],'ledger':str(evidence/'update.json'),'automaticDeviceControlActive':False,'manualStep':step,'installedSha256':ledger['fixtureSha256'],'reportedAndAuditedPolicy':'B connected/automaticOFF','originalV6RestorationPending':True,'closingPending':True})
p=root/'docs/evidence/m5-20261018/c29-update-context.json';v=load(p);v.update(supersededBy=str(context),automaticDeviceControlActive=False,stage='C29 replaced by C30; follow superseding context');save(p,v)
save(root/'docs/evidence/m5-20261018/c30-results.json',audit);save(root/'docs/evidence/m5-20261018/account-b-results.json',b_audit)
note='**C30 siap di Poco,18 Oktober2026:** daftar cloud dipisahkan dari riwayat lokal semua akun, pesan halaman kosong/konteks tujuan id-en ditambahkan tanpa menghapus8catatan. Repro2FAIL9s→focused2PASS9s/fullhost52PASS146s; strengthened7subsetPASS32s; analyzer '+audit['analyzer']+'; Poco7PASS/DV '+dv_status+'. Native UI memakai SDK/HTTP tiruan. Audit B nyata before1PASS: identitas berbeda dari8runA, list0, IDA unavailable padaB, autoOff menolak run tanpa unggah dan semua tabel tetap setelah metadata PIN fixture yang didokumentasikan. Strict after1PASS: semua tabel/13arsip/policy sama; B connected/Off dan targetnull. Ordinary/default/2ekspor hash sama; build3 universal verified, ordinary tidak dipasang. Release own cashier terlihat/0marker pada buffer. Kontrol otomatis Off; C30-MAN01 retest heading/empty/8labelakunlain berikutnya. Natural21/reboot/Doze/lintas-origin/job cancellation OS belum terbukti; originalAPK6/closing pending. M5 belum selesai/M6 tidak dimulai. [C30](M5_DRIVE_HISTORY_CONTEXT_C30.md).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 p=root/'docs'/name;t=read(p);i=t.index('\n')+1;p.write_text(t[:i]+'\n'+note+'\n\n'+t[i:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_IMPLEMENTATION_REPORT.md','M5_DRIVE_HISTORY_CONTEXT_C30.md']:
 p=root/'docs'/name;p.write_text(read(p).rstrip()+'\n\n'+note+'\n\nLedger: '+str(evidence/'update.json')+'\n',encoding='utf-8')
p=root/'docs/REQUIREMENTS.md';rows=[]
for line in read(p).splitlines():
 if line.startswith('| M5-DRIVE |'):
  line='| M5-DRIVE | Consent/appDataFolder/account/retention7/manual+auto21:00 | D-AUTO-LIVE01 real controlled headless8/retention7; D-MAN15a-c/16 and D-AUTO-ACCOUNT-B01 real B read-only; C30 host52/native7per device/strict13archive update | B0files, identity distinct from8A jobs, prior A file unavailable on B, disabled run guard PASS scoped; physical C30 labels pending; natural21/OS cancellation/reboot/Doze/other-origin/in-flight-account-change UNVERIFIED |'
 elif line.startswith('| R13-004 |') or line.startswith('| R13-005 |'):
  parts=line.split('|');parts[-3]=parts[-3].rstrip()+'; C30/real B audit native before1PASS and strict after1PASS13archives '
  parts[-2]=' Implemented; real A manual/worker/retention and B read-only separation/autoOFF rejects run PASS scoped. C29 change-account UI PASS manual D-MAN15c; C30 local-history clarity host52/native7per device PASS, physical labels pending. Natural21/reboot/Doze/in-flight-account-change/OS cancellation unverified. '
  line='|'.join(parts)
 rows.append(line)
p.write_text('\n'.join(rows)+'\n',encoding='utf-8')
p=root/'docs/M5_FIXES_AND_VALIDATION.md';t=read(p);anchor='| C29 — konteks akun Drive |';assert anchor in t
t=t.replace(anchor,'| C30 — konteks riwayat lokal | B cloud kosong,8catatan sukses lokal terlihat tanpa heading/konteks akun; bukan8arsipB. | BackupSettingsScreen/Provider,7key ID/EN, UI tests/native B audit | Repro2FAIL9s→focused2PASS9s/full52PASS; native7per device; B read-only+strict update1+1PASS13archives;3build/startup/preservation PASS | UI clarified without deleting history; physical C30 labels pending. M5_DRIVE_HISTORY_CONTEXT_C30 |\n'+anchor);p.write_text(t,encoding='utf-8')
p=root/'docs/LESSONS-LEARNED.md';p.write_text(read(p).rstrip()+'\n\n80. Delapan status sukses lokal dan tujuh arsip cloud adalah himpunan berbeda. D-MAN16 B kosong/8status bukan bukti kebocoran akun: telusuri history SQL vs API, beri heading/konteks tujuan, jangan hapus/filter sejarah agar angka sama. Pesan kosong hanya sesudah respons list sukses dan berlaku halaman. Uji label id/en literal, akun saat ini/lain/tidak tercatat, semua fingerprint tetap. Audit B memakai baseline baru sesudah PIN publik dengan hanya metadata credential/audit berubah; B0/A-ID unavailable/Off guard bukan bukti readback A serentak atau cancel job OS. Jangan mencetak payload metadata ketika negative assertion gagal; assert boolean dan kode error terbatas.\n',encoding='utf-8')
p=root/'android/build/reports/problems/problems-report.html';p.write_bytes(subprocess.check_output(['git','show','HEAD:android/build/reports/problems/problems-report.html']))
r=subprocess.run(['git','diff','--check'],capture_output=True,text=True);assert r.returncode==0,r.stdout
print(json.dumps({'handovers':12,'control':False,'installedC30':ledger['fixtureSha256'],'host52':True,'realBReadOnlyAudit':True,'originalV6RestorationPending':True}))
