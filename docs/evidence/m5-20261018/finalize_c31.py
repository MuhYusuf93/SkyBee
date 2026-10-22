"""Finalize C31 only from native/build/preservation evidence, before handover."""
import copy
import hashlib
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[3]
ev = root / 'docs/evidence/m5-20261018'
base = root / 'docs/evidence/m5-20261016'
def read(p): return p.read_text(encoding='utf-8-sig')
def load(p): return json.loads(read(p))
def save(p, v): p.write_text(json.dumps(v, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

context = ev / 'c31-update-context.json'
ledger_path = Path(load(context)['ledger'])
evidence = ledger_path.parent
ledger = load(ledger_path)
assert ledger['state'] == 'C31 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert not ledger['automaticDeviceControlActive'] and 'failure' not in ledger
nonce = ledger['nonce']
poco = list(base.glob(f'poco-c31-ui-{nonce}-*'))
dv = list(base.glob(f'c31-ui-{nonce}-*'))
assert len(poco) == 1 and '+4: All tests passed!' in read(poco[0]/'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(poco[0]/'isolation.txt')
dv_result = ledger['dv']
if not dv_result.startswith('BLOCKED'):
    assert len(dv) == 1 and '+4: All tests passed!' in read(dv[0]/'runner.log')
    assert load(dv[0]/'awake-original.json')['Restored']
    assert read(evidence/'dv-legacy-before.txt') == read(evidence/'dv-legacy-after.txt')
    assert sha(evidence/'dv-prior.apk') == sha(evidence/'dv-restored.apk')
    dv_result = '4PASS SDK/HTTP authorization fixtures on ARM32 SQLCipher; exact prior APK/default hashes/awake restored/read back'
assert '+56: All tests passed!' in read(ev/'c31-host-regression.log')
assert 'No issues found!' in read(ev/'c31-analyze.log')
analyze_seconds = re.search(r'No issues found! \(ran in ([0-9.]+)s\)', read(ev/'c31-analyze.log')).group(1)
assert '+4: All tests passed!' in read(ev/'c31-auth-final-helper.log')
before, after = Path(ledger['beforeEvidence']), Path(ledger['afterEvidence'])
for folder, role in [(before, 'before'), (after, 'after')]:
    output = read(folder/'runner.log')
    assert '+1: All tests passed!' in output
    assert f'M5_ACCOUNT_B_AUDIT {role} integrity/FK/envelope/financial facts/all tables/13archives/policy PASS' in output
    assert re.search(r'^Success$', read(folder/'original-restored.log'), re.M)
assert 'M5_ACCOUNT_B_READ_ONLY listEmpty=true identityDifferentFromA=true priorAFileUnavailable=true disabledRunRejected=true allTablesUnchanged=true' in read(before/'runner.log')
assert read(before/'ordinary-before.txt') == read(after/'ordinary-after.txt')
assert read(poco[0]/'ordinary-before.txt') == read(after/'ordinary-after.txt')
assert read(evidence/'public-before.txt') == read(evidence/'public-after.txt')
assert sha(evidence/'installed-c31.apk') == ledger['fixtureSha256']
startup = load(evidence/'startup.json')
assert startup['synthetic_screen_visible'] and startup['startup_error_markers'] == 0
artifacts = load(Path(ledger['artifactsJson']))
assert artifacts['installed'] is False and artifacts['fixtureDatabase'] == ledger['fixtureDatabase']

audit = {
    'id': 'C31-AUTO', 'date': '2026-10-18', 'status': 'PASS scoped',
    'host': f'56PASS150s on final production source; final fixture-filename helper4PASS2s subset; analyzer{analyze_seconds}s No issues',
    'poco': '4PASS synthetic SDK/HTTP authorization with ARM64 SQLCipher', 'dv': dv_result,
    'strictUpdate': 'before1/after1PASS; all tables/13archives/policy equal after documented fixture PIN metadata baseline; real B connected/autoOff/targetnull,8A jobs retained',
    'build': 'ordinary/fixture/bridge universal/min24/16KiB/icon/license/signature/negative guard verified, ordinary not installed',
    'startup': startup, 'ledger': str(ledger_path),
    'limits': 'SDK-null failure is simulated; real revoked-consent behavior not tested. Natural21/reboot/Doze/in-flight change/OS-job cancellation/other-origin cloud preservation remain unverified. C30-MAN01 labels PASS reported separately. OriginalAPK6 restoration/closing pending.',
}
original = str(base/'poco-manual-20261016-191759/original-fixture.apk')
step = 'D-MAN17: account B remains connected/automaticOFF. Press Putuskan once, verify disconnected status/choose-account only/no upload-auto controls, next target unscheduled, local history8 preserved. No uploads/restore/new accounts. Automatic device control OFF.'
folders = [item['folder'] for item in load(ev/'c30-handover-consistency.json')]
paths = [base/folder/'handover.json' for folder in folders]
template = load(paths[-1])
for p in paths + [evidence/'handover.json']:
    data = load(p) if p in paths else copy.deepcopy(template)
    assert data['originalApk'] == original and data['restoreOriginalPending'] and not data['automaticDeviceControlActive']
    data.update(fixtureApk=ledger['newApk'], fixtureSha256=ledger['fixtureSha256'], restoreBridge=ledger['restoreBridge'],
                automaticDeviceControlActive=False, manualStep=step, restoreOriginalPending=True, closingAuditPending=True, c31Audit=audit)
    data['manualResults'] += ' C31 host56/native4per device/build3/strict13archive and ordinary-default-public preservation/startup PASS; human C30 labels PASS. D-MAN17 disconnect and closing pending.'
    data['manualEvidence'].append(audit)
    history = data.setdefault('apkHistory', [])
    assert not any(isinstance(item, dict) and item.get('checkpoint') == 'C31' for item in history)
    history.append({'checkpoint': 'C31', 'date': '2026-10-18', 'sha256': ledger['fixtureSha256'], 'apk': ledger['newApk'], 'scope': 'SDK silent-null maps to typed needs-auth failure; no account/business/rule changes'})
    save(p, data)
ledger.update(state='C31 native/build/strict preservation/startup PASS; manual disconnect handover ready', automaticDeviceControlActive=False,
              manualStep=step, nativePocoEvidence=str(poco[0]), nativeDvEvidence=str(dv[0]) if dv else None, dv=dv_result)
ledger['sourceSha256'] = {name: sha(root/name) for name in ['lib/features/backup/application/drive_authorization.dart', 'lib/features/backup/application/drive_rest.dart', 'test/m5_drive_authorization_test.dart', 'integration_test/m5_drive_authorization_test.dart']}
save(ledger_path, ledger)
save(context, {'stage': ledger['state'], 'ledger': str(ledger_path), 'automaticDeviceControlActive': False,
               'manualStep': step, 'installedCheckpoint': 'C31', 'installedSha256': ledger['fixtureSha256'],
               'reportedAndAuditedPolicy': 'B connected/autoOFF', 'originalV6RestorationPending': True, 'closingPending': True})
save(ev/'c31-results.json', audit)
save(ev/'c31-handover-consistency.json', [{'folder': p.parent.name, 'control': load(p)['automaticDeviceControlActive'], 'originalPending': load(p)['restoreOriginalPending'], 'currentC31': load(p)['fixtureSha256'] == ledger['fixtureSha256']} for p in paths+[evidence/'handover.json']])
p = ev/'c30-update-context.json'; data = load(p)
data.update(supersededBy=str(context), automaticDeviceControlActive=False, stage='C30 replaced by C31; human C30-MAN01 labels PASS reported; follow superseding context')
save(p, data)
note = ('**C31 siap di Poco,18 Oktober2026:** SDK silent-null kini menjadi kebutuhan '
        'otorisasi ulang nonretry tanpa UI worker. Before2PASS/2FAIL→focused4/full56PASS150s; '
        f'analyzer{analyze_seconds}s No issues; Poco4PASS/DV4PASS pada SDK/HTTP sintetis dengan SQLCipher '
        'native. DV exactAPK/default hashes/awake dipulihkan. Build3 verified, ordinary '
        'tidak dipasang. Audit B nyata sebelum1PASS/strict sesudah1PASS: seluruh tabel,13arsip '
        'dan policy sama sesudah metadata PIN fixture yang didokumentasikan; B connected/Off '
        'dan targetnull,8runA tetap. Ordinary/default/2ekspor sama; startup kasir terlihat '
        'dan0marker pada buffer tersedia. C30-MAN01 label/empty PASS dilaporkan pengguna. '
        'First native3PASS/1FAIL fixturePathRequired adalah helper filename yang diperbaiki, '
        'guard tetap ketat; raw failure disimpan. Final-helper host4PASS adalah subset, '
        'bukan56+4kasus unik. Kontrol otomatis Off; berikut D-MAN17 Putuskan B lalu audit penutup/pemulihan '
        'exact originalAPK6. Real revoked-consent/natural21/reboot/Doze/OS-job cancellation/'
        'in-flight-change/lintas-origin tetap unverified. M5 belum selesai/M6 tidak dimulai. '
        '[C31](M5_SILENT_AUTHORIZATION_C31.md).**')
for name in ['STATUS.md', 'PLAN.md', 'REQUIREMENTS.md', 'M5_POCO_MANUAL_TEST.md']:
    p = root/'docs'/name; text = read(p); i = text.index('\n')+1
    p.write_text(text[:i]+'\n'+note+'\n\n'+text[i:].lstrip('\n'), encoding='utf-8')
for name in ['M5_TEST_REPORT.md', 'M5_IMPLEMENTATION_REPORT.md', 'M5_SILENT_AUTHORIZATION_C31.md']:
    p = root/'docs'/name; p.write_text(read(p).rstrip()+'\n\n'+note+'\n', encoding='utf-8')
p = root/'docs/M5_FIXES_AND_VALIDATION.md'
text = read(p).replace('Fixed host scope; native/build/deploy pending, C30 still installed.', 'Fixed host/native4per device/build3/strict13archive update/startup PASS; C31 installed. Real revoked-consent failure unverified.')
p.write_text(text, encoding='utf-8')
p = root/'docs/REQUIREMENTS.md'
lines = read(p).splitlines()
for n, line in enumerate(lines):
    if line.startswith('| R13-006 |'):
        lines[n] = line.replace('native/deploy pending;', 'native4per device/build3/deployed C31/strict13archive preservation PASS;')
save(ev/'c31-manual-next.json', {'id': 'D-MAN17', 'status': 'PENDING', 'automaticDeviceControlActive': False, 'step': step, 'installedSha256': ledger['fixtureSha256']})
p.write_text('\n'.join(lines)+'\n', encoding='utf-8')
print('C31 native/build/preservation PASS; all13 handovers control Off; exact originalAPK6 retained; D-MAN17 pending')
