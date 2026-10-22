"""Publish evidence/handover only after the serialized C29 pipeline succeeds."""
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[3]
def read(path):
    return path.read_text(encoding='utf-8-sig')
def load(path):
    return json.loads(read(path))
def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

context = root / 'docs/evidence/m5-20261018/c29-update-context.json'
evidence = Path(load(context)['ledger']).parent
ledger = load(evidence / 'update.json')
assert ledger['state'] == 'C29 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert ledger['automaticDeviceControlActive'] is False and 'failure' not in ledger
nonce = ledger['nonce']
base_evidence = root / 'docs/evidence/m5-20261016'
poco = list(base_evidence.glob(f'poco-c29-ui-{nonce}-*'))
dv = list(base_evidence.glob(f'c29-ui-{nonce}-*'))
assert len(poco) == 1 and '+2: All tests passed!' in read(poco[0] / 'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(poco[0] / 'isolation.txt')
dv_status = ledger['dv']
if not dv_status.startswith('BLOCKED'):
    assert len(dv) == 1 and '+2: All tests passed!' in read(dv[0] / 'runner.log')
    assert load(dv[0] / 'awake-original.json')['Restored']
    assert read(evidence / 'dv-legacy-before.txt') == read(evidence / 'dv-legacy-after.txt')
    assert sha(evidence / 'dv-prior.apk') == sha(evidence / 'dv-restored.apk')
    dv_status = '2PASS account UI mocks; exact prior APK/default hashes/awake restored and read back'
host = read(root / 'docs/evidence/m5-20261018/c29-host-regression.log')
assert '+50: All tests passed!' in host
analyze = read(root / 'docs/evidence/m5-20261018/c29-analyze.log')
assert 'No issues found!' in analyze
before, after = Path(ledger['beforeEvidence']), Path(ledger['afterEvidence'])
for folder, role in [(before, 'before'), (after, 'after')]:
    output = read(folder / 'runner.log')
    assert '+1: All tests passed!' in output
    assert f'M5_ACCEPTANCE_AUDIT post_drive_worker {role} integrity/FK/legacy/facts PASS' in output
    assert 'successfulRuns=8 uniqueRemoteIds=8 localArchives=13' in output
    assert re.search(r'^Success$', read(folder / 'original-restored.log'), re.M)
assert read(before / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(poco[0] / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(evidence / 'public-before.txt') == read(evidence / 'public-after.txt')
assert sha(evidence / 'installed-c29.apk') == ledger['fixtureSha256']
startup = load(evidence / 'startup.json')
assert startup['synthetic_screen_visible'] and startup['startup_error_markers'] == 0
live_path = root / 'docs/evidence/m5-20261018/live-drive-1792327725515'
live = load(live_path / 'ledger.json')
assert all(live[key] for key in ['ordinaryHashesEqual','legacyHashesEqual','publicBackupHashesEqual','exactC28Restored'])
assert '+1: All tests passed!' in read(live_path / 'reader.log')
result = load(live_path / 'result.json')
assert result['verifiedUploads'] == 8 and result['retainedCount'] == 7 and result['otherScopeCount'] == 0

folders = ['poco-manual-20261016-191759','poco-manual-update-1792156485701',
 'poco-permission-update-1792174330020','poco-export-update-1792178476161',
 'poco-archive-update-1792181574653','poco-notification-update-1792195919961',
 'poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903',
 'poco-recovery-copy-update-1792312363867','poco-schedule-ui-update-1792317053346']
paths = [base_evidence / folder / 'handover.json' for folder in folders]
base = load(paths[-1])
original = str(base_evidence / 'poco-manual-20261016-191759/original-fixture.apk')
step = 'D-MAN15a: leave automatic ON, load current account A Drive versions and inspect7rows without upload/restore. Next D-MAN15b/c choose a different registered test account B and accept after PIN if prompted; verify old consent drops OFF, page/cursor and target cleared. Human Google selection only, no automatic input.'
audit = {'id':'C29-AUTO','date':'2026-10-18','status':'PASS',
 'source':'host/native mocks/build/strict update', 'host':'50PASS; focused2 subset',
 'poco':'2PASS account UI mocks','dv':dv_status,
 'analyzer':re.search(r'No issues found! \(ran in ([0-9.]+)s\)',analyze).group(1)+'s No issues',
 'strictUpdate':'before1PASS/after1PASS; all tables/13archives/policy unchanged;8success/8unique remote IDs; connected/automaticON',
 'build':'ordinary/fixture/bridge universal min24/16KiB/icon/licenses/signature/negative guard verified; ordinary not installed',
 'startup':startup,'ledger':str(evidence / 'update.json'),
 'limits':'Account B OAuth not yet tested; native cases fake SDK/HTTP/WorkManager. Natural21/reboot/Doze/other origin cloud preservation unverified.'}
live_audit = {'id':'D-AUTO-LIVE01','date':'2026-10-18','status':'PASS scoped',
 'source':'real Poco headless worker controlled dispatch and Google HTTP',
 'result':result,'ledger':str(live_path / 'ledger.json'),
 'limits':'run -s own nonce job; not natural21. No other origin in baseline, not proof of cross-origin preservation. Two same-key callers headless in one worker, not manual and OS worker in separate processes.'}
for path in paths + [evidence / 'handover.json']:
    data = load(path) if path in paths else copy.deepcopy(base)
    assert data['originalApk'] == original and data['restoreOriginalPending'] and not data['automaticDeviceControlActive']
    data.update(fixtureApk=ledger['newApk'],fixtureSha256=ledger['fixtureSha256'],restoreBridge=ledger['restoreBridge'],
      automaticDeviceControlActive=False,manualStep=step,restoreOriginalPending=True,closingAuditPending=True,c29Audit=audit)
    data['manualResults'] += ' D-AUTO-LIVE01 real controlled headless8uploads/retention7 PASS; C29 host50/native2per device/build/strict13archive preservation/startup PASS. Real second-account test pending.'
    data['manualEvidence'].extend([live_audit,audit])
    history=data.setdefault('apkHistory',[])
    assert not any(isinstance(item,dict) and item.get('checkpoint')=='C29' for item in history)
    history.append({'checkpoint':'C29','date':'2026-10-18','sha256':ledger['fixtureSha256'],'apk':ledger['newApk'],'scope':'Clear remote account page/cursor and reload target after accept/disconnect; no business change'})
    save(path,data)
ledger.update(state='C29 checks/preservation PASS; second-account manual handover ready',automaticDeviceControlActive=False,manualStep=step,nativePocoEvidence=str(poco[0]),nativeDvEvidence=str(dv[0]) if dv else None,dv=dv_status)
ledger['sourceSha256']={name:sha(root/name) for name in ['lib/features/backup/presentation/backup_settings_provider.dart','test/m5_settings_ui_test.dart','integration_test/m5_acceptance_audit_test.dart','integration_test/m5_live_drive_probe_app.dart']}
save(evidence / 'update.json',ledger)
save(context,{'stage':ledger['state'],'ledger':str(evidence/'update.json'),'automaticDeviceControlActive':False,'manualStep':step,'installedSha256':ledger['fixtureSha256'],'originalV6RestorationPending':True,'closingPending':True})
old_context=root/'docs/evidence/m5-20261018/c28-update-context.json'
old=load(old_context);old.update(supersededBy=str(context),automaticDeviceControlActive=False,stage='C28 replaced by C29; follow superseding context');save(old_context,old)
save(root/'docs/evidence/m5-20261018/c29-results.json',audit)
save(root/'docs/evidence/m5-20261018/live-drive-results.json',live_audit)

note='**C29 siap di Poco,18 Oktober2026:** stale versi/cursor akun dan target sesudah accept/disconnect direpro2FAIL8s→focused2PASS8s/fullhost50PASS (subset), analyzer '+audit['analyzer']+'; Poco2PASS/DV '+dv_status+'. Native UI menggunakan SDK/HTTP/WorkManager tiruan. Ordinary/fixture/bridge universal verified; ordinary tidak dipasang. Strict before1/after1PASS: semua tabel/13arsip/policy identik,8run success/8remoteIDunik, real consent/autoOn terjaga. Own cashier release terlihat/0error marker pada buffer. Worker Google nyata terpisah8upload/retensi7/native reader1PASS3s/preservasi ordinary/default/ekspor PASS dengan pemicu ADB -s hanya nonce, bukan natural21. C28-MAN01R OFF/ON PASS manual; berikut D-MAN15 ganti akun B tanpa upload/restore. Kontrol otomatis Off; originalAPK6/closing pending. Natural21/reboot/Doze/lintas-origin nyata belum terverifikasi. M5 belum selesai/M6 tidak dimulai. [C29](M5_DRIVE_ACCOUNT_CONTEXT_C29.md), [worker](M5_LIVE_DRIVE_WORKER_20261018.md).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
    path=root/'docs'/name; text=read(path);position=text.index('\n')+1
    path.write_text(text[:position]+'\n'+note+'\n\n'+text[position:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_IMPLEMENTATION_REPORT.md','M5_DRIVE_ACCOUNT_CONTEXT_C29.md']:
    path=root/'docs'/name;path.write_text(read(path).rstrip()+'\n\n'+note+'\n\nLedger: '+str(evidence/'update.json')+'\n',encoding='utf-8')
path=root/'docs/REQUIREMENTS.md';text=read(path)
rows=[]
for line in text.splitlines():
    if line.startswith('| M5-DRIVE |'):
        line='| M5-DRIVE | Consent/appDataFolder/account/retention7/manual+auto21:00 | DriveRest/DriveBackupService/DrivePolicy/BackupScheduler; SDK/mock/calendar/retry; D-MAN01R–14/C28-MAN01R reported; real restore native5archive audit; D-AUTO-LIVE01; C29 host50/native2per device/strict13archive update | Real consent/upload/list/download/restore + controlled new-PID OAuth8uploads/retention7 PASS scoped. Second real account pending; natural21/reboot/Doze/other-origin cloud preservation UNVERIFIED. C29 stale page/cursor/target fixed automated/native mocks |'
    elif line.startswith('| M5-ALERT |'):
        line='| M5-ALERT | Peringatan persediaan/batch/dedup/notifikasi/PIN | AlertService/AndroidStockNotifications/M5Runtime; host3PASS/headless plugin initialization; N-MAN01–08 reports in M5_POCO_MANUAL_TEST | Poco permission deny/allow, generic notification/tap PIN, no-spam/rearm/cancel PASS reported N01–06/08. N07 lockscreen notification not visible, so lockscreen content inspection UNVERIFIED; OEM/reboot/Doze limits remain |'
    elif line.startswith('| M5-BACKUP |'):
        line='| M5-BACKUP | Snapshot/portable authenticated archive/SAF/safety restore/recovery | BackupService/PortableArchive/SAF/DurablePromotion; WAL/concurrency/fault native; DV→Poco18digest; B-MAN01–18/local and D-MAN04–11/Drive manual+independent safety audits; C29 strict13archive preservation | Local export/keyboard/cancel/wrong-code/auth/restore/safety manual+native PASS scoped; real Drive roundtrip/manual+native5archive safety audit PASS. Current13local archives hashes verified/unchanged across C29 update; power-loss physical and closing original APK restoration pending |'
    elif line.startswith('| M5-ENC |'):
        line=line.replace('latest universal release/manual acceptance pending','universal ordinary/fixture/bridge package/min24/16KiB verified; ordinary not installed; physical power-loss/M6 signing outside evidence')
    if any(line.startswith('| '+key+' |') for key in ['R13-003','R13-004','R13-005','R13-006','R13-007','R13-008']):
        parts=line.split('|')
        parts[-3]=parts[-3].rstrip()+'; D-AUTO-LIVE01 real worker8uploads/retention7/reader1PASS3s, C29 host50/native2per device/strict13archive PASS '
        parts[-2]=' Implemented; consent/SAF and real Drive restore manual+native PASS; real controlled headless OAuth/upload/retention7 PASS scoped. C29 account context fixed automated/native mocks; actual account B pending. Natural21/reboot/Doze and actual other-origin preservation UNVERIFIED. '
        line='|'.join(parts)
    rows.append(line)
path.write_text('\n'.join(rows)+'\n',encoding='utf-8')
path=root/'docs/M5_FIXES_AND_VALIDATION.md';text=read(path)
anchor='| C28 — status jadwal |'
assert anchor in text
text=text.replace(anchor,'| C29 — konteks akun Drive | Versi A tertinggal sesudah menerima B; cursor tetap sesudah disconnect; target projection usang. Bukan bukti salah-upload cloud. | BackupSettingsProvider acceptAccount/disconnect; SDK/HTTP/workmanager fixtures; post_drive_worker audit | 2FAIL8s→focused2PASS8s/fullhost50PASS; Poco2PASS13s/DV2PASS25s; 3build verified; strict13archive/all-table/policy before/after1+1PASS | Fixed pada cakupan otomatis/native mocks; real second-account UI pending; M5_DRIVE_ACCOUNT_CONTEXT_C29 |\n'+anchor)
text=text.replace('App UI fixed; manual OFF/ON retest pending; M5_DRIVE_SCHEDULE_UI_C28','App UI fixed; C28-MAN01R manual OFF/ON PASS reported (static-help clarification retained); M5_DRIVE_SCHEDULE_UI_C28')
path.write_text(text,encoding='utf-8')
path=root/'docs/LESSONS-LEARNED.md'
path.write_text(read(path).rstrip()+'\n\n79. Konfirmasi akun baru tidak otomatis menginvalidasi route lama. C29 dua repro host menunjukkan remote A di bawah tujuan B dan cursor tersisa sesudah disconnect. Bersihkan page/cursor hanya sesudah operasi akun berhasil, muat ulang projection target sesudah scheduler refresh, dan pertahankan consent serta seluruh tabel lain. Mock service/HTTP/SDK tidak membuktikan akun Google B nyata; serahkan build terverifikasi dan uji akun manusia terpisah. Salah path file retry pada full regression bukan bug aplikasi: simpan47PASS+1loadingFAIL dan ulang enam file benar, hitung50kasus final tanpa menjumlah retry/subset.\n',encoding='utf-8')
path=root/'android/build/reports/problems/problems-report.html'
path.write_bytes(subprocess.check_output(['git','show','HEAD:android/build/reports/problems/problems-report.html']))
check=subprocess.run(['git','diff','--check'],capture_output=True,text=True)
assert check.returncode==0,check.stdout
print(json.dumps({'handovers':11,'automaticDeviceControlActive':False,'installedC29':ledger['fixtureSha256'],'host50':True,'realHeadlessUploads':8,'retained':7,'originalV6RestorationPending':True}))
