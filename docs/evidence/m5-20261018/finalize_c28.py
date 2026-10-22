"""Finalize C28 only after all recorded checks and safe deployment have passed."""
import copy,hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[3]
def read(p):return p.read_text(encoding='utf-8-sig')
context=root/'docs/evidence/m5-20261018/c28-update-context.json'
evidence=Path(json.loads(read(context))['ledger']).parent
ledger=json.loads(read(evidence/'update.json'))
assert ledger['state']=='C28 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert ledger['automaticDeviceControlActive'] is False
assert 'failure' not in ledger
nonce=ledger['nonce']
poco=list((root/'docs/evidence/m5-20261016').glob(f'poco-c28-ui-{nonce}-*'));dv=list((root/'docs/evidence/m5-20261016').glob(f'c28-ui-{nonce}-*'))
assert len(poco)==1 and '+1: All tests passed!' in read(poco[0]/'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(poco[0]/'isolation.txt')
dvStatus=ledger['dv']
if not dvStatus.startswith('BLOCKED'):
 assert len(dv)==1 and '+1: All tests passed!' in read(dv[0]/'runner.log')
 assert json.loads(read(dv[0]/'awake-original.json'))['Restored']
 assert read(evidence/'dv-legacy-before.txt')==read(evidence/'dv-legacy-after.txt')
 assert hashlib.sha256((evidence/'dv-prior.apk').read_bytes()).digest()==hashlib.sha256((evidence/'dv-restored.apk').read_bytes()).digest()
 dvStatus='1PASS schedule UI mock; exact prior APK/default hashes and awake restored/read back'
assert '+48: All tests passed!' in read(root/'docs/evidence/m5-20261018/c28-host-regression.log')
assert '+1: All tests passed!' in read(root/'docs/evidence/m5-20261018/c28-schedule-host-focused.log')
analyze=read(root/'docs/evidence/m5-20261018/c28-analyze.log');assert 'No issues found!' in analyze
before,after=Path(ledger['beforeEvidence']),Path(ledger['afterEvidence'])
for folder,role in [(before,'before'),(after,'after')]:
 assert '+1: All tests passed!' in read(folder/'runner.log')
 assert f'M5_ACCEPTANCE_AUDIT post_drive_opt_in {role} integrity/FK/legacy/facts PASS' in read(folder/'runner.log')
 assert 'Success' in read(folder/'original-restored.log')
assert read(poco[0]/'ordinary-before.txt')==read(before/'ordinary-before.txt')==read(after/'ordinary-after.txt')
assert read(evidence/'public-before.txt')==read(evidence/'public-after.txt')
startup=json.loads(read(evidence/'startup.json'));assert startup['synthetic_screen_visible'] and startup['startup_error_markers']==0
for file in [Path(ledger['newApk']),evidence/'installed-c28.apk']:
 assert hashlib.sha256(file.read_bytes()).hexdigest()==ledger['fixtureSha256']
folders=['poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867']
paths=[root/'docs/evidence/m5-20261016'/name/'handover.json' for name in folders]
base=json.loads(read(paths[-1]));original=str(root/'docs/evidence/m5-20261016/poco-manual-20261016-191759/original-fixture.apk')
step='C28-MAN01: inspect active auto schedule, switch OFF verify status target clears without refresh; ON/confirm verify target21 returns without refresh; no manual upload. Do not claim actual job execution.'
audit={'id':'C28-AUTO','date':'2026-10-18','source':'host/native/build/fresh strict update checks','status':'PASS','host':'48PASS133s, focused1 subset','poco':'1PASS schedule UI mock','dv':dvStatus,'analyzer':re.search(r'No issues found! \(ran in ([0-9.]+)s\)',analyze).group(1)+'s No issues','strictUpdate':'before1PASS/after1PASS, all tables/5archives/policy digest equal; real account connected and autoON, target21 persisted, no backup_runs/new uploads','build':'ordinary/fixture/bridge universal verified min24/16KiB/icon/licenses/signature/negative guard; ordinary not installed','limits':'D-MAN14 original phone UI PASS reported; stale-overview bug reproduced separately host. Native UI uses fake Keystore/WorkManager only; actual21delivery/headlessGoogle/reboot/Doze/OEM preview not proven','startup':startup,'ledger':str(evidence/'update.json')}
for path in paths+[evidence/'handover.json']:
 d=json.loads(read(path)) if path in paths else copy.deepcopy(base)
 assert d['originalApk']==original and d['restoreOriginalPending'] and d['automaticDeviceControlActive'] is False
 d.update(fixtureApk=ledger['newApk'],fixtureSha256=ledger['fixtureSha256'],restoreBridge=ledger['restoreBridge'],automaticDeviceControlActive=False,manualStep=step,restoreOriginalPending=True,closingAuditPending=True,c28Audit=audit)
 d['manualResults']+=' C28 host/native schedule UI/build/strict5archive connected-autoON preservation/startup PASS; physical OFF/ON refresh retest pending.'
 d['manualEvidence'].append(audit)
 history=d.setdefault('apkHistory',[]);assert not any(isinstance(x,dict) and x.get('checkpoint')=='C28' for x in history)
 history.append({'checkpoint':'C28','date':'2026-10-18','sha256':ledger['fixtureSha256'],'apk':ledger['newApk'],'scope':'Refresh schedule projection after switch; no business change; physical retest pending'})
 path.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
ledger.update(state='C28 checks/preservation PASS; manual schedule handover ready',automaticDeviceControlActive=False,manualStep=step,nativePocoEvidence=str(poco[0]),nativeDvEvidence=str(dv[0]) if dv else None,dv=dvStatus)
ledger['sourceSha256']={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ['lib/features/backup/presentation/backup_settings_provider.dart','test/m5_settings_ui_test.dart','integration_test/m5_acceptance_audit_test.dart','android/app/src/integrationFixture/kotlin/com/example/kasir_app/IntegrationActivity.kt']}
(evidence/'update.json').write_text(json.dumps(ledger,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
context.write_text(json.dumps({'stage':'C28 manual schedule handover ready','ledger':str(evidence/'update.json'),'automaticDeviceControlActive':False,'manualStep':step,'installedSha256':ledger['fixtureSha256'],'originalV6RestorationPending':True,'closingPending':True},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
priorContext=root/'docs/evidence/m5-20261018/c27-update-context.json'
priorValue=json.loads(read(priorContext))
priorValue.update(supersededBy=str(context),automaticDeviceControlActive=False,stage='C27 replaced by C28; follow superseding context for current handover')
priorContext.write_text(json.dumps(priorValue,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
(root/'docs/evidence/m5-20261018/c28-results.json').write_text(json.dumps(audit,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
note='**C28 siap retest manual, 18 Oktober 2026:** projection target dimuat ulang dari service setelah switch; host48PASS133s (focused1 subset), analyzer '+audit['analyzer']+'; Poco1PASS; DV '+dvStatus+'. Native UI memakai plugin tiruan, bukan upload/job OS nyata. Build ordinary/fixture/bridge verified universal/min24/16KiB/icon/license/signature/negative guard; ordinary tidak dipasang. Strict before/after1+1PASS: seluruh tabel+5arsip+digestpolicy sama, real account connected/autoON dan target21 tersimpan, backup_runs kosong/tidak ada unggah tambahan. C28 installed hash cocok dan own cashier startup/0marker pada buffer diperiksa; kontrol otomatis Off. D-MAN14 pada C27 tetap PASS reported, bukan gagal karena label zona waktu toko. Retest fisik OFF/ON tanpa refresh berikutnya; actual21delivery/headlessGoogle/retensi/lintas akun/reboot/Doze dan closing belum selesai. OriginalAPK6 pending; M5 belum selesai/M6 tidak dimulai. [Laporan](M5_DRIVE_SCHEDULE_UI_C28.md).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 p=root/'docs'/name;s=read(p);pos=s.index('\n')+1;p.write_text(s[:pos]+'\n'+note+'\n\n'+s[pos:].lstrip('\n'),encoding='utf-8')
for name in ['M5_DRIVE_SCHEDULE_UI_C28.md','M5_TEST_REPORT.md','M5_IMPLEMENTATION_REPORT.md']:
 p=root/'docs'/name;p.write_text(read(p).rstrip()+'\n\n'+note+'\n\nLedger: '+str(evidence/'update.json')+'\n',encoding='utf-8')
p=root/'docs/M5_FIXES_AND_VALIDATION.md';s=read(p);target='| C27 — kebutuhan produksi/clipboard |';assert target in s;s=s.replace(target,'| C28 — status jadwal | Host persisted target21 tetapi route overview null; D-MAN14 HP PASS reported terpisah. | BackupSettingsProvider.automatic reload overview; UI test fake WorkManager; opt-in phase audit | Before1FAIL5s→focused1/full48PASS; 2helperfail lazy/notice scroll retained; native1per device, build3 and strict preservation PASS | App UI fixed; manual OFF/ON retest pending; M5_DRIVE_SCHEDULE_UI_C28 |\n'+target);p.write_text(s,encoding='utf-8')
p=root/'docs/LESSONS-LEARNED.md';p.write_text(read(p).rstrip()+'\n\n77. Mutasi backend dan job registration bukan bukti projection route sudah diperbarui. C28 host persisted target21 namun overview null; muat ulang melalui service, jangan menjadwalkan ulang/ubah zona demi label. Pertahankan manual D-MAN14 PASS sebagai bukti terpisah. Helper perlu scrollable form ber-key karena notice sukses menambahkan scrollable lebih awal; StateError/lazy0 bukan failure produk baru. Uji ON/registration dan OFF/cancel/target-clear, seluruh tabel lain sama, tanpa Google/job OS pada widgettest.\n',encoding='utf-8')
# Restore only build-generated report, clean before this serialized pipeline.
p=root/'android/build/reports/problems/problems-report.html';p.write_bytes(subprocess.check_output(['git','show','HEAD:android/build/reports/problems/problems-report.html']))
r=subprocess.run(['git','diff','--check'],capture_output=True,text=True);assert r.returncode==0,r.stdout
print(json.dumps({'handovers':10,'automaticDeviceControlActive':False,'installedC28':ledger['fixtureSha256'],'host48':True,'ordinaryBuildOnly':True}))
