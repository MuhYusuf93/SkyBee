"""Finalize C25 only after scoped regression, APK and preservation proofs."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
evidence = root / 'docs/evidence/m5-20261016/poco-google-cancel-update-1792226124001'
def read(path):
    return path.read_text(encoding='utf-8-sig')
ledger = json.loads(read(evidence / 'update.json'))
assert ledger['state'] == 'C25 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert ledger['automaticDeviceControlActive'] is True, 'Already handed over; do not replay finalization'
native_poco = list((root / 'docs/evidence/m5-20261016').glob('poco-c25-ui-1792226124001-*'))
assert len(native_poco) == 1
assert '+18: All tests passed!' in read(native_poco[0] / 'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(native_poco[0] / 'isolation.txt')
native_dv = list((root / 'docs/evidence/m5-20261016').glob('c25-ui-1792226124001-*'))
dv_status = 'BLOCKED/unverified'
if not ledger['dv'].startswith('BLOCKED'):
    assert len(native_dv) == 1
    assert '+18: All tests passed!' in read(native_dv[0] / 'runner.log')
    assert json.loads(read(native_dv[0] / 'awake-original.json'))['Restored']
    assert read(evidence / 'dv-legacy-before.txt') == read(evidence / 'dv-legacy-after.txt')
    assert hashlib.sha256((evidence / 'dv-prior.apk').read_bytes()).digest() == hashlib.sha256((evidence / 'dv-restored.apk').read_bytes()).digest()
    dv_status = '18PASS; exact prior APK/default sandbox hashes and awake restored'
before = Path(ledger['beforeEvidence'])
after = Path(ledger['afterEvidence'])
for folder in (before, after):
    assert '+1: All tests passed!' in read(folder / 'runner.log')
    assert 'Success' in read(folder / 'original-restored.log')
assert read(before / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(native_poco[0] / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(evidence / 'public-before.txt') == read(evidence / 'public-after.txt')
assert 'No issues found!' in read(root / 'docs/evidence/m5-20261017/c25-analyze-final.log')
assert '+43: All tests passed!' in read(root / 'docs/evidence/m5-20261017/c25-host-regression.log')
startup = json.loads(read(evidence / 'startup.json'))
assert startup['synthetic_screen_visible'] and startup['startup_error_markers'] == 0
assert hashlib.sha256(Path(ledger['newApk']).read_bytes()).hexdigest() == ledger['fixtureSha256']
assert hashlib.sha256((evidence / 'installed-c25.apk').read_bytes()).hexdigest() == ledger['fixtureSha256']
paths = [root / f'docs/evidence/m5-20261016/{name}/handover.json' for name in (
    'poco-manual-20261016-191759', 'poco-manual-update-1792156485701',
    'poco-permission-update-1792174330020', 'poco-export-update-1792178476161',
    'poco-archive-update-1792181574653', 'poco-notification-update-1792195919961')]
base = json.loads(read(paths[-1]))
original = str(root / 'docs/evidence/m5-20261016/poco-manual-20261016-191759/original-fixture.apk')
manual_failure = json.loads(read(root / 'docs/evidence/m5-20261017/d-man01-before-user-report.json'))
for path in paths + [evidence / 'handover.json']:
    value = json.loads(read(path)) if path in paths else dict(base)
    assert value['originalApk'] == original
    value.update(fixtureApk=ledger['newApk'], fixtureSha256=ledger['fixtureSha256'],
                 restoreBridge=ledger['restoreBridge'], automaticDeviceControlActive=False,
                 startupConfirmed=True, manualPausedByUser=False,
                 manualStep='D-MAN01R cancel real Google picker once; verify inline Dibatalkan and choose-account button, no account selection/upload',
                 manualResults='IN PROGRESS. B-MAN01–18 stated scopes PASS; N-MAN01–06/08 PASS reported, N-MAN07 lockscreen not visible/unverified. D-MAN01 original cancel feedback FAIL retained; C25 SDK mock/native/build/preservation/startup PASS, actual Google retest pending.',
                 restoreOriginalPending=True, closingAuditPending=True,
                 c25Audit={'ledger':str(evidence / 'update.json'), 'host':'43PASS97s',
                           'poco':'18PASS', 'dv':dv_status,
                           'strictInstallAllTablesAndThreeArchivesEqual':True,
                           'localDrivePolicyDisconnected':True,
                           'ordinaryDefaultAndPublicExports':'unchanged on declared checkpoints',
                           'actualGoogleRetest':'pending', 'actualGoogleApi':'UNVERIFIED', 'startup':startup})
    history = value.setdefault('apkHistory', [])
    if not any(item.get('sha256') == ledger['fixtureSha256'] for item in history if isinstance(item, dict)):
        history.append({'checkpoint':'C25','date':'2026-10-17','sha256':ledger['fixtureSha256'],'apk':ledger['newApk'],
                        'scope':'Google cancellation feedback; native SDK mocks, strict data audit and startup; real cancel retest pending'})
    events = value.setdefault('manualEvidence', [])
    if not any(item.get('id') == 'D-MAN01-before' for item in events):
        events.append(manual_failure)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
note = ('**C25 siap retest manual17Oktober2026:** cancel Google sekarang dipetakan khusus canceled→Dibatalkan, '
        'kandidat sementara diinvalidasi sebelum retry; tujuan/consent tersimpan tetap. Host43PASS97s (focused5 subset), '
        'analyzerNoissues6,6s; Poco18PASS; DV '+dv_status+'. Ordinary/fixture/bridge universal/ikon/min24/16KiB/licenses/signature/negativeguard verified; '
        'ordinary tidak dipasang. Strict before/after masing-masing1PASS: seluruh tabel+3archiveSHA sama, fakta2sale/stok/HPP/legacy/ordinary/public2exports '
        'dan localDrivePolicy disconnected/off/no identity PASS pada checkpoint. C25 installed hash cocok dan startup own cashier/0marker PASS. '
        'Kontrol otomatis dihentikan. D-MAN01 feedbackFAIL historis tetap; D-MAN01R actual Google cancel belum. Tidak memilih akun/upload/reset/restore ulang. '
        'OriginalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Detail [C25](M5_GOOGLE_CANCEL_C25.md).**')
for name in ('STATUS.md','REQUIREMENTS.md','PLAN.md','M5_POCO_MANUAL_TEST.md'):
    path = root / 'docs' / name
    first, rest = read(path).split('\n', 1)
    path.write_text(first+'\n\n'+note+'\n'+rest, encoding='utf-8')
requirements = root / 'docs/REQUIREMENTS.md'
rows = read(requirements).splitlines()
for i, row in enumerate(rows):
    if row.startswith('| R13-001 |'):
        row = row.replace('actual restore/real Drive pending; not power-loss proof',
                          'B-MAN12–18 actual local restore reported + C24 safety3archive/native audit PASS; real Drive restore pending; not power-loss proof')
    if row.startswith('| R13-002 |'):
        row = row.replace('Implemented/native fixture scope PASS; SAF fisik dan Drive restore nyata belum terverifikasi; bukan power-loss fisik',
                          'B-MAN12–18 local SAF restore reported + C24 native safety3archives/logo/business23 PASS; real Drive restore/power-loss fisik unverified')
    if row.startswith('| R13-004 |'):
        row = row.replace('GOOGLE_DRIVE_SETUP/M5_TEST_REPORT', 'GOOGLE_DRIVE_SETUP/M5_TEST_REPORT; D-MAN01 cancel generic feedback FAIL→C25 SDK host/native mocks PASS; real retest pending')
    rows[i] = row
requirements.write_text('\n'.join(rows)+'\n', encoding='utf-8')
for name in ('M5_TEST_REPORT.md', 'M5_GOOGLE_CANCEL_C25.md'):
    with (root / 'docs' / name).open('a', encoding='utf-8') as out:
        out.write('\n\n'+note+'\n\nLedger: '+str(evidence / 'update.json')+'\n')
with (root / 'docs/GOOGLE_DRIVE_SETUP.md').open('a', encoding='utf-8') as out:
    out.write('\n\n17Oktober2026: D-MAN01 membuka pemilih Google dan cancel, feedback umum FAIL historis. '
              'C25 mapping canceled→Dibatalkan dan kandidat invalidation host/native mock PASS; akun tersimpan dipertahankan. '
              'Local policy actual sebelum/sesudah update disconnected/off/no identity; belum consent/API/upload Google. '
              'APK fixture terbaru/retst aktual mengikuti ledger C25, tidak mengubah client ID/package/certificate.\n')
tracker = root / 'docs/M5_FIXES_AND_VALIDATION.md'
text = read(tracker)
separator = '| --- | --- | --- | --- | --- |'
row = ('| C25 — aplikasi/pemilih Google | Cancel dipetakan kegagalan umum; kandidat lama dapat tertinggal saat pilihan ulang gagal. '
       '| backup_settings_provider.dart; m5_settings_ui_test.dart; m5_acceptance_audit_test.dart '
       '| SDK canceled reproFAIL→focused5PASS/fullhost43PASS/analyzer6,6s/Poco18; DV '+dv_status+
       '; strict all-table/3archive equality+disconnected policy/startup PASS '
       '| Fixed pada SDK mock/native scope; D-MAN01R Google nyata pending, OAuth/API belum lulus; M5_GOOGLE_CANCEL_C25 |')
tracker.write_text(text.replace(separator, separator+'\n'+row,1), encoding='utf-8')
ledger.update(automaticDeviceControlActive=False, manualStep='D-MAN01R real Google cancel retest pending',
              nativePocoEvidence=str(native_poco[0]), nativeDvEvidence=str(native_dv[0]) if native_dv else None)
ledger['sourceSha256'] = {name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in (
    'lib/features/backup/presentation/backup_settings_provider.dart','test/m5_settings_ui_test.dart','integration_test/m5_acceptance_audit_test.dart')}
(evidence / 'update.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
context = json.loads(read(root / 'docs/evidence/m5-20261017/c25-update-context.json'))
context.update(stage='ready for actual Google cancellation retest',automaticDeviceControlActive=False,ledger=str(evidence/'update.json'),installedSha256=ledger['fixtureSha256'])
(root / 'docs/evidence/m5-20261017/c25-update-context.json').write_text(json.dumps(context,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'handoversUpdated':7,'automaticDeviceControlActive':False,'fixtureSha256':ledger['fixtureSha256'],'realGoogleRetest':'pending'}))
