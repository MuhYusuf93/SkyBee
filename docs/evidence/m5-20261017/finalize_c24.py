"""Record only verified C24 results; preserve manual history and original v6 APK."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
evidence = root / 'docs/evidence/m5-20261016/poco-notification-update-1792195919961'
ledger = json.loads((evidence / 'update.json').read_text(encoding='utf-8-sig'))
assert ledger['state'].startswith('C24 strict install preservation + production startup + actual restore safety audit PASS;')
post = Path(ledger['postRestoreEvidence'])
assert 'All tests passed!' in (post / 'runner.log').read_text(encoding='utf-8-sig')
assert 'PASS count=3' in (post / 'runner.log').read_text(encoding='utf-8-sig')
assert (post / 'isolation.txt').read_text(encoding='utf-8-sig').strip() == 'Ordinary DB and sidecar byte hashes unchanged.'
startup = json.loads((evidence / 'startup.json').read_text())
assert startup['synthetic_screen_visible'] and startup['startup_error_markers'] == 0
assert (evidence / 'startup-before-safety.json').is_file()
apk = Path(ledger['newApk'])
assert hashlib.sha256(apk.read_bytes()).hexdigest() == ledger['fixtureSha256']
assert hashlib.sha256((evidence / 'final-installed.apk').read_bytes()).hexdigest() == ledger['fixtureSha256']
dv = Path(ledger['dvProbe'])
assert json.loads((dv / 'awake-original.json').read_text(encoding='utf-8-sig'))['Restored']

handovers = [root / f'docs/evidence/m5-20261016/{name}/handover.json' for name in (
    'poco-manual-20261016-191759', 'poco-manual-update-1792156485701',
    'poco-permission-update-1792174330020', 'poco-export-update-1792178476161',
    'poco-archive-update-1792181574653')]
original_apk = str(root / 'docs/evidence/m5-20261016/poco-manual-20261016-191759/original-fixture.apk')
base = json.loads(handovers[-1].read_text(encoding='utf-8-sig'))
for file in handovers + [evidence / 'handover.json']:
    value = json.loads(file.read_text(encoding='utf-8-sig')) if file in handovers else dict(base)
    assert value['originalApk'] == original_apk
    value.update(fixtureApk=str(apk), fixtureSha256=ledger['fixtureSha256'],
                 restoreBridge=ledger['restoreBridge'], automaticDeviceControlActive=False,
                 startupConfirmed=True, manualStep='N-MAN01 notification permission denial/in-app warning; manual handover, no automatic input',
                 manualResults='IN PROGRESS. B-MAN01–18 declared scopes PASS user-reported, first failures retained. C24 release initialization and actual restored campaign/safety audit PASS. Remaining three groups: notifications, real Google Drive, closing.',
                 restoreOriginalPending=True, closingAuditPending=True,
                 c24Audit={'ledger':str(evidence / 'update.json'), 'postRestoreEvidence':str(post),
                           'archivesAuthenticated':3, 'businessTablesPreserved':23,
                           'startupSetupErrorCleared':True, 'deviceDefaultsVerified':True,
                           'strictInstallAllTablesAndThreeArchivesEqual':True,
                           'recoveryValueCaptured':False, 'startup':startup,
                           'notificationOsDelivery':'UNVERIFIED', 'realGoogleDrive':'UNVERIFIED'})
    history = value.setdefault('apkHistory', [])
    if not any(item.get('sha256') == ledger['fixtureSha256'] for item in history if isinstance(item, dict)):
        history.append({'checkpoint':'C24', 'date':'2026-10-17', 'sha256':ledger['fixtureSha256'], 'apk':str(apk),
                        'scope':'notification release icon/startup recovery; strict install audit and post-restore safety PASS'})
    file.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

note = ('**C24 selesai pada cakupan perbaikan17Oktober2026:** ikon release hilang direpro invalid_icon lalu initPASS Poco/DV; '
        'keep.xml dan gate APK mencegah pengulangan. Host10PASS15s, analyzerbersih, ordinary/fixture/bridge verified; ordinary tidak dipasang. '
        'Strict install before/after masing-masing1PASS3s: semua tabel+3arsip identik. Actual post_restore audit1PASS: integrity/FK/cipher/reconcile, '
        '23business hashes/2receipts/keuangan-stok, autentikasi3arsip termasuk safety pre-swap/profil+fullqueue, logo dan reset device defaults/Drive '
        'PASS; setup error null setelah startup produksi tanpa SQL repair/reset/restore ulang. Ordinary/default/public2exports unchanged pada checkpoint. '
        'DV priorAPK dan awake1/900000/0 restored/readback. B17/18 tetap PASS reportedmanual. Kontrol otomatis Poco berhenti; '
        'N-MAN01 deny notification berikutnya. Sisa3kelompok: notifikasi, real Drive, closing. M5 belum selesai/M6 tidak dimulai. '
        'Detail [C24](M5_NOTIFICATION_RELEASE_C24.md).**')
for name in ('STATUS.md', 'REQUIREMENTS.md', 'PLAN.md', 'M5_POCO_MANUAL_TEST.md'):
    file = root / 'docs' / name
    text = file.read_text(encoding='utf-8-sig')
    first, rest = text.split('\n', 1)
    file.write_text(first+'\n\n'+note+'\n'+rest, encoding='utf-8')
file = root / 'docs/REQUIREMENTS.md'
rows = file.read_text(encoding='utf-8').splitlines()
for i, row in enumerate(rows):
    if row.startswith('| R13-0') and any(row.startswith(f'| R13-{number:03} |') for number in range(10,17)):
        row = row.replace('M5_TEST_REPORT | Implemented/native fixture scope PASS; SAF fisik dan Drive restore nyata belum terverifikasi; bukan power-loss fisik |',
                          'M5_TEST_REPORT; B-MAN08–18 reported; C24 actual post_restore/safety3archives/business23/nativePASS | Implemented; SAF/manual restore + native safety audit PASS on fixture; real Drive restore/power-loss fisik unverified |')
    if row.startswith('| R14-00'):
        row = row.replace('C24 runtime/post_restore audit pending;', 'C24 runtime recovery/post_restore audit PASS;')
        row = row.replace('AndroidAlertNotifications', 'AndroidStockNotifications')
    if row.startswith('| R16-016 |'):
        row = row.replace('Rencana: unit/SQL/widget/integration/performance suites', 'BackupService/BackupValidation/DurablePromotion; SQLCipher and portable authenticated archives')
        row = row.replace('Rencana: Jalankan skenario acceptance klausul ini pada milestone pemilik', 'B-MAN08–18 reported; C24 actual restore audit safety3archives/business23/logo/financials; native fault regression historical; M5_NOTIFICATION_RELEASE_C24')
        row = row.replace('| pending |', '| Verified on stated manual/native fixture scopes; real Drive restore/physical power-loss unverified |')
    rows[i] = row
file.write_text('\n'.join(rows)+'\n', encoding='utf-8')
with (root / 'docs/M5_TEST_REPORT.md').open('a', encoding='utf-8') as file:
    file.write('\n\n'+note+'\n')
with (root / 'docs/M5_NOTIFICATION_RELEASE_C24.md').open('a', encoding='utf-8') as file:
    file.write('\n\n## Hasil akhir checkpoint\n\n'+note+'\n\nLedger terperinci: '+str(evidence / 'update.json')+
               '. Uji sebelum/sesudah instalasi adalah dua fase kasus yang sama, bukan dua fitur unik. '
               'Audit post_restore menambah satu verification audit/attempt melalui PIN fixture sebelum freeze; inspeksi3arsip tidak mengubah fingerprint DB live sesudah freeze. '
               'Tidak mengumpulkan recovery value. Semua rawfailure awal dipertahankan.\n')
ledger['automaticDeviceControlActive'] = False
ledger['manualStep'] = 'N-MAN01 notification denial; three manual groups remain'
ledger['finalStartup'] = startup
(evidence / 'update.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'handoversUpdated':len(handovers)+1, 'automaticDeviceControlActive':False,
                  'fixtureSha256':ledger['fixtureSha256'], 'remainingGroups':3}))
