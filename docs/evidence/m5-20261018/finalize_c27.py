"""Finalize C27 after scoped tests and a fresh post-upload update audit."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]


def read(path):
    return path.read_text(encoding='utf-8-sig')


context = root / 'docs/evidence/m5-20261018/c27-update-context.json'
evidence = Path(json.loads(read(context))['ledger']).parent
ledger = json.loads(read(evidence / 'update.json'))
assert ledger['state'] == 'C27 native regression/build/strict preservation/startup PASS; manual handover not finalized'
assert ledger['automaticDeviceControlActive'] is True
nonce = ledger['nonce']
poco = list((root / 'docs/evidence/m5-20261016').glob(f'poco-c27-ui-{nonce}-*'))
dv = list((root / 'docs/evidence/m5-20261016').glob(f'c27-ui-{nonce}-*'))
assert len(poco) == 1
assert '+6: All tests passed!' in read(poco[0] / 'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(poco[0] / 'isolation.txt')
dv_status = ledger['dv']
if not dv_status.startswith('BLOCKED'):
    assert len(dv) == 1 and '+6: All tests passed!' in read(dv[0] / 'runner.log')
    assert json.loads(read(dv[0] / 'awake-original.json'))['Restored']
    assert read(evidence / 'dv-legacy-before.txt') == read(evidence / 'dv-legacy-after.txt')
    assert hashlib.sha256((evidence / 'dv-prior.apk').read_bytes()).digest() == hashlib.sha256((evidence / 'dv-restored.apk').read_bytes()).digest()
    dv_status = '6PASS focused recovery UI; prior APK/default hashes and awake restored/read back'
assert '+38: All tests passed!' in read(root / 'docs/evidence/m5-20261018/c27-host-regression.log')
assert 'No issues found!' in read(root / 'docs/evidence/m5-20261018/c27-analyze.log')
jvm = json.loads(read(root / 'docs/evidence/m5-20261018/c27-jvm-results/summary.json'))
assert jvm['tests'] == 11 and jvm['errors'] == jvm['failures'] == 0
before, after = Path(ledger['beforeEvidence']), Path(ledger['afterEvidence'])
for folder, role in ((before, 'before'), (after, 'after')):
    assert '+1: All tests passed!' in read(folder / 'runner.log')
    assert f'M5_ACCEPTANCE_AUDIT post_drive_upload {role} integrity/FK/legacy/facts PASS' in read(folder / 'runner.log')
    assert 'Success' in read(folder / 'original-restored.log')
assert read(before / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(poco[0] / 'ordinary-before.txt') == read(after / 'ordinary-after.txt')
assert read(evidence / 'public-before.txt') == read(evidence / 'public-after.txt')
startup = json.loads(read(evidence / 'startup.json'))
assert startup['synthetic_screen_visible'] and startup['startup_error_markers'] == 0
for apk in (Path(ledger['newApk']), evidence / 'installed-c27.apk'):
    assert hashlib.sha256(apk.read_bytes()).hexdigest() == ledger['fixtureSha256']
folders = ('poco-manual-20261016-191759', 'poco-manual-update-1792156485701',
           'poco-permission-update-1792174330020', 'poco-export-update-1792178476161',
           'poco-archive-update-1792181574653', 'poco-notification-update-1792195919961',
           'poco-google-cancel-update-1792226124001', 'poco-drive-config-update-1792309347903')
paths = [root / f'docs/evidence/m5-20261016/{folder}/handover.json' for folder in folders]
base = json.loads(read(paths[-1]))
original = str(root / 'docs/evidence/m5-20261016/poco-manual-20261016-191759/original-fixture.apk')
step = 'C27-MAN01 re-download listed Drive archive, use new Copy button privately, paste and validate metadata only; do not restore yet'
audit = {'ledger': str(evidence / 'update.json'), 'host': '38PASS124s; focused4 subset',
         'analyzer': 'No issues22.3s', 'jvm': '11PASS, compilation/existing plugin regressions',
         'poco': '6PASS focused recovery UI', 'dv': dv_status,
         'clipboardScope': 'Automatic tests use mock sink only; actual Android clipboard and OEM preview pending manual proof',
         'ordinaryFeature': 'Copy button unconditional; ordinary flag=false host tests and verified ordinary release build; not installed',
         'strictUpdateAllTablesAndFourArchivesEqual': True,
         'oneSuccessfulRunSameAccountAndConnectedAutoOffPolicyDigestEqual': True,
         'baselineScope': 'Fresh post-upload quiescent update interval; not equality across human session',
         'ordinaryDefaultAndPublicExports': 'unchanged on declared endpoints; DV ordinary absent',
         'realDrive': 'D-MAN04–07 upload/list/download/authenticated preview PASS reported before update; local successful run independently checked; actual restore pending',
         'startup': startup}
for path in paths + [evidence / 'handover.json']:
    value = json.loads(read(path)) if path in paths else dict(base)
    assert value['originalApk'] == original and value['restoreOriginalPending']
    assert value['automaticDeviceControlActive'] is True
    value.update(fixtureApk=ledger['newApk'], fixtureSha256=ledger['fixtureSha256'],
                 restoreBridge=ledger['restoreBridge'], automaticDeviceControlActive=False,
                 startupConfirmed=True, manualStep=step, restoreOriginalPending=True,
                 closingAuditPending=True, c27Audit=audit)
    value['manualResults'] = base['manualResults'] + ' C27 production Copy feature host/native mock/build/preservation PASS; actual copy/paste and Drive restore pending.'
    history = value.setdefault('apkHistory', [])
    assert not any(item.get('checkpoint') == 'C27' for item in history if isinstance(item, dict))
    history.append({'checkpoint': 'C27', 'date': '2026-10-18', 'sha256': ledger['fixtureSha256'],
                    'apk': ledger['newApk'], 'scope': 'Production recovery Copy feature; actual OS clipboard still pending manual'})
    value['postUploadAuditNote'] = 'C27 post_drive_upload before/after independently checked4archives and1success run; old phases still historical. No restore performed.'
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
note = ('**C27 siap uji clipboard manual, 18 Oktober 2026:** tombol Salin tersedia pada kode baru/tersimpan dalam PIN gate, '
        'termasuk aplikasi utama; hasil canonical64hex tanpa spasi/tanda hubung, tidak rotasi/simpan/auto-confirm. '
        'Native Android foreground menandai clip sensitif; feedback ID/EN tanpa kode. Host38PASS124s (focused4 subset), '
        'analyzerNoissues22,3s/JVM11PASS; Poco6PASS focused recovery UI; DV ' + dv_status + '. '
        'Tes otomatis memakai sink clipboard tiruan, tidak membaca/menimpa clipboard OS. '
        'Build ordinary/fixture/bridge verified universal/min24/ikon/16KiB/licenses/signature/negative guard; ordinary tidak dipasang. '
        'Audit post_drive_upload before/after masing-masing1PASS: semua tabel dan4arsip sama pada interval pembaruan baru, '
        'satu run sukses/account cocok, policy connected/autoOff/digest sama, fakta2sale/stok/HPP/integrity/FK/legacy/ordinary/public2exports sesuai. '
        'C27 installed SHA cocok dan startup own cashier/0marker pada buffer diperiksa. Kontrol otomatis Off. '
        'D-MAN07 sebelum update tetap PASS reported; download/validasi perlu diulang dengan tombol Salin. Clipboard/paste OEM dan actual Drive restore belum lulus. '
        'OriginalAPK6/closing pending; M5 belum selesai/M6 tidak dimulai. Detail [C27](M5_RECOVERY_CLIPBOARD_C27.md).**')
for name in ('STATUS.md', 'REQUIREMENTS.md', 'PLAN.md', 'M5_POCO_MANUAL_TEST.md'):
    path = root / 'docs' / name
    first, rest = read(path).split('\n', 1)
    path.write_text(first + '\n\n' + note + '\n' + rest, encoding='utf-8')
for name in ('M5_TEST_REPORT.md', 'M5_RECOVERY_CLIPBOARD_C27.md', 'BACKUP_RESTORE.md'):
    with (root / 'docs' / name).open('a', encoding='utf-8') as out:
        out.write('\n\n' + note + '\n\nLedger: ' + str(evidence / 'update.json') + '\n')
p = root / 'docs/REQUIREMENTS.md'
t = read(p).replace('Focused4PASS18s dengan clipboard sink tiruan, callback setelah lock dan fingerprint DB; regresi/native/build sedang berjalan',
                    'Focused4 subset/fullhost38PASS; native6 per device pada recovery UI, JVM11PASS, ordinary+fixture build verified dan post-upload preservation audit PASS')
t = t.replace('Implemented source; belum deploy/clipboard fisik terverifikasi',
              'Implemented source+ordinary build; fixture C27 deployed; actual clipboard/paste/OEM pending manual')
p.write_text(t, encoding='utf-8')
p = root / 'docs/M5_FIXES_AND_VALIDATION.md'
t = read(p)
separator = '| --- | --- | --- | --- | --- |'
row = ('| C27 — kebutuhan produksi/clipboard | Seleksi/copy manual64hex rawan kurang/lebih blok; pengguna meminta tombol Salin pada aplikasi utama. '
       '| backup_service/settings Provider/Screen; KasirPlatformPlugin.java; ARB/localization; m5_settings_ui_test; audit phase post_drive_upload '
       '| Sebelum4FAIL karena fitur belum ada→focused4/full38PASS, analyzer/JVM11, native recovery6 per device, build ordinary+fixture/audit4archive+1run+policy digest/startup PASS '
       '| Implemented pada jalur produksi; clipboard otomatis mocked, OS copy/paste/OEM belum dibuktikan; actual Drive restore pending. M5_RECOVERY_CLIPBOARD_C27 |')
p.write_text(t.replace(separator, separator + '\n' + row, 1), encoding='utf-8')
ledger.update(state='C27 checks/preservation PASS; manual clipboard handover ready', automaticDeviceControlActive=False,
              manualStep=step, nativePocoEvidence=str(poco[0]), nativeDvEvidence=str(dv[0]) if dv else None, dv=dv_status)
ledger['sourceSha256'] = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in (
    'lib/features/backup/application/backup_service.dart', 'lib/features/backup/presentation/backup_settings_provider.dart',
    'lib/features/backup/presentation/backup_settings_screen.dart',
    'packages/kasir_platform/android/src/main/java/com/example/kasir_platform/KasirPlatformPlugin.java',
    'lib/l10n/app_en.arb', 'lib/l10n/app_id.arb', 'lib/l10n/localization.dart',
    'test/m5_settings_ui_test.dart', 'integration_test/m5_acceptance_audit_test.dart')}
(evidence / 'update.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
context.write_text(json.dumps({'stage': 'C27 manual clipboard handover ready', 'ledger': str(evidence / 'update.json'),
                              'automaticDeviceControlActive': False, 'manualStep': step, 'installedSha256': ledger['fixtureSha256'],
                              'originalV6RestorationPending': True, 'closingPending': True}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'handoversUpdated': 9, 'automaticDeviceControlActive': False,
                  'installedSha256': ledger['fixtureSha256'], 'actualClipboard': 'pending manual', 'ordinary': 'feature included; build-only'}))
