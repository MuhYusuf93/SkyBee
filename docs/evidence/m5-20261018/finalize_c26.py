"""Publish the C26 handover only after recorded tests and preservation gates."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
evidence = root / 'docs/evidence/m5-20261016/poco-drive-config-update-1792309347903'


def read(path):
    return path.read_text(encoding='utf-8-sig')


ledger = json.loads(read(evidence / 'update.json'))
assert ledger['state'] == 'C26 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert ledger['automaticDeviceControlActive'] is True
nonce = ledger['nonce']
native_poco = list((root / 'docs/evidence/m5-20261016').glob(f'poco-c26-ui-{nonce}-*'))
assert len(native_poco) == 1
assert '+20: All tests passed!' in read(native_poco[0] / 'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(native_poco[0] / 'isolation.txt')
native_dv = list((root / 'docs/evidence/m5-20261016').glob(f'c26-ui-{nonce}-*'))
dv_status = ledger['dv']
if not dv_status.startswith('BLOCKED'):
    assert len(native_dv) == 1
    assert '+20: All tests passed!' in read(native_dv[0] / 'runner.log')
    assert json.loads(read(native_dv[0] / 'awake-original.json'))['Restored']
    assert read(evidence / 'dv-legacy-before.txt') == read(evidence / 'dv-legacy-after.txt')
    assert hashlib.sha256((evidence / 'dv-prior.apk').read_bytes()).digest() == hashlib.sha256((evidence / 'dv-restored.apk').read_bytes()).digest()
    dv_status = '20PASS; exact prior APK/default sandbox hashes and awake restored/read back'
before, after = Path(ledger['beforeEvidence']), Path(ledger['afterEvidence'])
for folder, role in ((before, 'before'), (after, 'after')):
    assert '+1: All tests passed!' in read(folder / 'runner.log')
    assert f'M5_ACCEPTANCE_AUDIT post_drive_connected {role} integrity/FK/legacy/facts PASS' in read(folder / 'runner.log')
    assert 'Success' in read(folder / 'original-restored.log')
assert read(before / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(native_poco[0] / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(evidence / 'public-before.txt') == read(evidence / 'public-after.txt')
assert '+34: All tests passed!' in read(root / 'docs/evidence/m5-20261017/c26-host-regression.log')
assert 'No issues found!' in read(root / 'docs/evidence/m5-20261018/c26-analyze-audit-phase.log')
startup = json.loads(read(evidence / 'startup.json'))
assert startup['synthetic_screen_visible'] and startup['startup_error_markers'] == 0
for apk in (Path(ledger['newApk']), evidence / 'installed-c26.apk'):
    assert hashlib.sha256(apk.read_bytes()).hexdigest() == ledger['fixtureSha256']
paths = [root / f'docs/evidence/m5-20261016/{folder}/handover.json' for folder in (
    'poco-manual-20261016-191759', 'poco-manual-update-1792156485701',
    'poco-permission-update-1792174330020', 'poco-export-update-1792178476161',
    'poco-archive-update-1792181574653', 'poco-notification-update-1792195919961',
    'poco-google-cancel-update-1792226124001')]
base = json.loads(read(paths[-1]))
original = str(root / 'docs/evidence/m5-20261016/poco-manual-20261016-191759/original-fixture.apk')
step = 'D-MAN04 one manual Drive backup on confirmed test account; automatic switch remains Off; report status, no restore'
audit = {
    'ledger': str(evidence / 'update.json'), 'host': '34PASS128s',
    'analyzer': 'No issues6.6s final audit phase; prior resumed37.9s',
    'poco': '20PASS', 'dv': dv_status,
    'strictUpdateAllTablesAndThreeArchivesEqual': True,
    'savedDrivePolicyConnectedAutoOffAndDigestEqual': True,
    'baselineScope': 'Fresh quiescent update interval after reported browsing; not equality across human session',
    'ordinaryDefaultAndPublicExports': 'endpoint hashes unchanged on declared checkpoints',
    'realIdentityAcceptance': 'D-MAN03R PASS user report on C25, confirmed local connected/autoOff in native audit',
    'realUploadListDownloadRestore': 'UNVERIFIED', 'startup': startup,
}
for path in paths + [evidence / 'handover.json']:
    value = json.loads(read(path)) if path in paths else dict(base)
    assert value['originalApk'] == original and value['restoreOriginalPending']
    assert value['automaticDeviceControlActive'] is True
    value.update(fixtureApk=ledger['newApk'], fixtureSha256=ledger['fixtureSha256'],
                 restoreBridge=ledger['restoreBridge'], automaticDeviceControlActive=False,
                 startupConfirmed=True, manualPausedByUser=False, manualStep=step,
                 restoreOriginalPending=True, closingAuditPending=True, c26Audit=audit,
                 sourceOnlyC26='C26 installed and verified; no longer source-only')
    value['manualResults'] = base['manualResults'] + ' C26 host/native/build/connected-policy preservation/startup PASS; Drive upload/list/download/restore pending.'
    history = value.setdefault('apkHistory', [])
    assert not any(x.get('checkpoint') == 'C26' for x in history if isinstance(x, dict))
    history.append({'checkpoint': 'C26', 'date': '2026-10-18', 'sha256': ledger['fixtureSha256'],
                    'apk': ledger['newApk'], 'scope': 'Specific sanitized Drive configuration feedback, connected policy preservation; no real upload'})
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
note = ('**C26 siap lanjut manual, 18 Oktober 2026:** feedback API-disabled/forbidden dibedakan tanpa respons mentah. '
        'Host34PASS128s, analyzer finalNoissues6,6s; Poco20PASS; DV ' + dv_status + '. '
        'Build universal ordinary/fixture/bridge, ikon/min24/16KiB/licenses/signature/negative guard PASS; ordinary tidak dipasang. '
        'Audit post_drive_connected before/after masing-masing1PASS: seluruh tabel dan3arsip identik pada interval baseline baru, '
        'akun tetap connected/autoOff dan digest policy sama, fakta2sale/stok/HPP/integrity/FK serta rawlegacy/ordinary/public2exports sesuai. '
        'Tidak mengklaim semua tabel sama sepanjang pengguna melihat-lihat. C26 installed SHA cocok; own cashier startup/0error marker pada buffer diperiksa. '
        'Kontrol otomatis dihentikan. D-MAN03R accept setelah API aktif tetap PASS reported; belum upload/list/download/restore Drive nyata. '
        'Berikut D-MAN04 satu backup manual dengan switch auto tetap Off. OriginalAPK6/closing pending, M5 belum selesai/M6 tidak dimulai. '
        'Detail [C26](M5_DRIVE_CONFIGURATION_C26.md).**')
for name in ('STATUS.md', 'REQUIREMENTS.md', 'PLAN.md', 'M5_POCO_MANUAL_TEST.md'):
    path = root / 'docs' / name
    first, rest = read(path).split('\n', 1)
    path.write_text(first + '\n\n' + note + '\n' + rest, encoding='utf-8')
for name in ('M5_TEST_REPORT.md', 'GOOGLE_DRIVE_SETUP.md', 'M5_DRIVE_CONFIGURATION_C26.md'):
    with (root / 'docs' / name).open('a', encoding='utf-8') as out:
        out.write('\n\n' + note + '\n\nLedger: ' + str(evidence / 'update.json') + '\n')
with (root / 'docs/STATUS.md').open('a', encoding='utf-8') as out:
    out.write('\n\n18 Oktober 2026 — Git lokal kini tersedia setelah pengguna melaporkan upload public. '
              'HEAD sudah mencakup source C26 awal. Index lokal melacak68APK+1arsip fixture (4.613.638.302byte); '
              'ignore baru hanya mencegah artefak baru. Salinan pemulihan lokal tetap dipertahankan, index/commit/push/history tidak diubah. '
              'Remote/isi rahasia belum diaudit. Detail [pemeriksaan Git](GIT_PUBLIC_REPOSITORY_CHECK_20261018.md).\n')
requirements = root / 'docs/REQUIREMENTS.md'
matrix = read(requirements).replace(
    'D-MAN03R accept/saved+autoOff PASS reported setelah enable pada C25 yang sama',
    'D-MAN03R accept/saved+autoOff PASS reported setelah enable pada C25 yang sama; C26 native policy connected/autoOff dan digest unchanged pada strict update PASS')
requirements.write_text(matrix, encoding='utf-8')
tracker = root / 'docs/M5_FIXES_AND_VALIDATION.md'
text = read(tracker)
separator = '| --- | --- | --- | --- | --- |'
row = ('| C26 — konfigurasi lingkungan + feedback aplikasi | Drive API belum Enabled dilaporkan; accept berhasil pada C25 setelah enable. '
       'Aplikasi meratakan error API-disabled dan forbidden. Exact HTTP lama tidak direkam. '
       '| drive_rest.dart; backup_settings_provider.dart; ARB/generated/localization; m5_drive_failure_test.dart; m5_settings_ui_test.dart; m5_acceptance_audit_test.dart '
       '| Host2FAIL/1PASS→34PASS; analyzer; Poco20PASS; DV ' + dv_status + '; build/strict fresh-baseline all-table+3archive+connected-policy equality/startup PASS '
       '| Feedback fixed pada cakupan teruji; konfigurasi enable dan D-MAN03R PASS reported; actual upload/list/download/restore pending. M5_DRIVE_CONFIGURATION_C26 |')
tracker.write_text(text.replace(separator, separator + '\n' + row, 1), encoding='utf-8')
ledger.update(state='C26 checks and preservation PASS; manual handover ready', automaticDeviceControlActive=False,
              manualStep=step, nativePocoEvidence=str(native_poco[0]),
              nativeDvEvidence=str(native_dv[0]) if native_dv else None, dv=dv_status)
ledger['sourceSha256'] = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in (
    'lib/features/backup/application/drive_rest.dart', 'lib/features/backup/presentation/backup_settings_provider.dart',
    'lib/l10n/app_en.arb', 'lib/l10n/app_id.arb', 'lib/l10n/localization.dart',
    'test/m5_drive_failure_test.dart', 'test/m5_settings_ui_test.dart', 'integration_test/m5_acceptance_audit_test.dart')}
(evidence / 'update.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(root / 'docs/evidence/m5-20261018/c26-update-context.json').write_text(json.dumps({
    'stage': 'C26 manual handover ready', 'ledger': str(evidence / 'update.json'),
    'automaticDeviceControlActive': False, 'manualStep': step, 'installedSha256': ledger['fixtureSha256'],
    'originalV6RestorationPending': True, 'closingPending': True}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'handoversUpdated': 8, 'automaticDeviceControlActive': False,
                  'installedSha256': ledger['fixtureSha256'], 'dv': dv_status}))
