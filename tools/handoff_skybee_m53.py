"""Scoped M5.3 SkyBee handoff after full isolated acceptance and committed builds.

Three explicit phases protect named encrypted DB/key/marker files before an
in-place update, authenticate a portable safety archive, preserve/read back its
recovery externally, then perform the specifically authorized one-shot reset.
No whole sandbox clone, uninstall, downgrade, cloud wipe or PIN guessing.
The final wizard remains genuine;100/50 activates only on the user's Finish.
"""
from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, time, uuid, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
ADB = 'C:\\platform-tools\\adb.exe'
DEVICE = '7f0edea0'
PACKAGE = 'com.example.kasir_app.skybee'
SDK = Path('C:\\Users\\ACER\\AppData\\Local\\Android\\Sdk\\build-tools\\36.0.0')

def allowed_reset_change(path, retained_alias=None, biometric_scopes=()):
    if retained_alias and path in ['no_backup/secret-' + retained_alias + suffix for suffix in ['', '.bak', '.new']]:
        return True
    if any((path in ['no_backup/biometric-' + scope + suffix for suffix in ['', '.bak', '.new']] for scope in biometric_scopes)):
        return True
    if re.fullmatch('databases/kasir_app\\.db(?:-wal|-shm|-journal)?', path):
        return True
    if re.fullmatch('no_backup/secret-(?:database-v1|backup-master-v1|backup-origin-v1|backup-retry-v1|drive-policy-v1)(?:[.]bak|[.]new)?', path):
        return True
    if re.fullmatch('no_backup/secret-drive-session-[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}(?:[.]bak|[.]new)?', path):
        return True
    if re.fullmatch('databases/m5_(?:restore|check)_[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}/(?:database\\.db(?:-wal|-shm|-journal)?|manifest\\.json|logo\\.png)', path):
        return True
    if re.fullmatch('databases/m51_report_[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}/(?:sheet[1-9][0-9]*\\.xml|report\\.(?:csv|xlsx))', path):
        return True
    if re.fullmatch('databases/logos/(?:[a-f0-9]{64}|[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})\\.png', path):
        return True
    if re.fullmatch('databases/m5_(?:import_[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}\\.kasirbackup|logo_[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}\\.input)', path):
        return True
    return False

def main():
    if not __debug__:
        raise RuntimeError('Safety checks require Python without optimization (-O)')
    p = argparse.ArgumentParser()
    p.add_argument('action', choices=['prepare', 'external', 'reset'])
    p.add_argument('--directory', type=Path, required=True)
    p.add_argument('--apk', type=Path, required=True)
    p.add_argument('--gate', type=Path, required=True)
    p.add_argument('--source-commit', required=True)
    p.add_argument('--poco-result', type=Path, required=True)
    p.add_argument('--dv-result', type=Path, required=True)
    p.add_argument('--external-directory', type=Path, required=True)
    p.add_argument('--source-manifest', type=Path, required=True)
    p.add_argument('--poco-evidence', type=Path, required=True)
    p.add_argument('--dv-evidence', type=Path, required=True)
    p.add_argument('--confirm-authorized-fresh-exploration', action='store_true')
    a = p.parse_args()
    DIR = a.directory.resolve()
    assert DIR.parent == ROOT / 'build' and DIR.name.startswith('m53-skybee-handoff-')
    DIR.mkdir(exist_ok=True)

    def cmd(*args, timeout=120, sensitive=False):
        r = subprocess.run([str(x) for x in args], capture_output=True, timeout=timeout)
        if r.returncode:
            (DIR / 'private-command-failure.txt').write_bytes(b'Sensitive read failed; output withheld' if sensitive else r.stdout + r.stderr)
            raise RuntimeError('Command failed; private evidence retained, no uninstall/clear fallback')
        return r.stdout

    def adb(*args, timeout=120):
        return cmd(ADB, '-s', DEVICE, *args, timeout=timeout)

    def sha(data):
        return hashlib.sha256(data).hexdigest()

    def file_sha(path):
        return sha(Path(path).read_bytes())

    def js(path):
        return json.loads(Path(path).read_text(encoding='utf-8-sig'))

    def write_json(path, obj):
        Path(path).write_text(json.dumps(obj, indent=2) + '\n', encoding='utf8')

    def read_private(relative):
        assert re.fullmatch('(?:databases|no_backup)/[A-Za-z0-9_./-]+', relative) and '..' not in relative.split('/')
        return cmd(ADB, '-s', DEVICE, 'exec-out', 'run-as', PACKAGE, 'cat', relative, sensitive=True)

    def push_json(relative, value):
        assert relative in ['databases/skybee-m53-handoff.json', 'databases/skybee-m53-external-proof.json']
        name = 'skybee-m53-' + str(uuid.uuid4()) + '.json'
        local = DIR / name
        write_json(local, value)
        remote = '/data/local/tmp/' + name
        adb('push', str(local), remote)
        adb('shell', 'run-as', PACKAGE, 'cp', remote, relative)
        adb('shell', 'rm', remote)

    def hashes(package):
        adb('shell', 'am', 'force-stop', package)
        raw = adb('shell', 'run-as', package, 'find', 'databases', 'no_backup', '-type', 'f', '-exec', 'sha256sum', '{}', '\\;').decode().splitlines()
        result = {}
        for row in raw:
            m = re.fullmatch('([a-f0-9]{64})\\s+(.+)', row)
            assert m
            digest, path = m.groups()
            if re.fullmatch('(?:databases|no_backup)/androidx\\.work\\.workdb(?:-wal|-shm|-journal)?', path) or re.fullmatch('no_backup/(?:database|backup-work|printer-output)\\.gate', path):
                continue
            result[path] = digest
        return result

    def others():
        return {pkg: hashes(pkg) for pkg in ['com.example.kasir_app', 'com.example.kasir_app.integration']}

    def launch():
        adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.example.kasir_app.SkybeeDemoActivity')

    def wait_phase(phase):
        until = time.monotonic() + 600
        while time.monotonic() < until:
            state = json.loads(read_private('databases/skybee-m53-handoff.json'))
            if state.get('phase') == phase:
                return state
            time.sleep(2)
        raise RuntimeError('Handoff phase did not complete; preserve current data and inspect failure')

    def wait_wizard(label, nonce):
        until = time.monotonic() + 120
        while time.monotonic() < until:
            raw = adb('exec-out', 'uiautomator', 'dump', '/dev/tty', timeout=30).decode(errors='replace')
            begin, end = (raw.find('<hierarchy'), raw.rfind('</hierarchy>'))
            if begin >= 0 and end >= begin:
                xml = raw[begin:end + len('</hierarchy>')]
                nodes = [n for n in ET.fromstring(xml).iter('node') if n.get('package') == PACKAGE]
                text = '\n'.join((n.get('text', '') + '\n' + n.get('content-desc', '') for n in nodes))
                if any((x in text for x in ['Penyiapan toko', 'Store setup'])) and any((x in text for x in ['Identitas toko', 'Store identity'])):
                    ready = json.loads(read_private(f'databases/m53_handoff_{nonce}/readiness.json'))
                    assert ready['nonce'] == nonce and ready['onboardingNeeded'] is True and (ready['seedPending'] is True)
                    assert ready['counts'] == {'products': 0, 'sale_transactions': 0, 'management_credentials': 0}
                    assert re.fullmatch('[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', ready['startupId'])
                    (DIR / (label + '-private-hierarchy.xml')).write_text(xml, encoding='utf8')
                    (DIR / (label + '-wizard.png')).write_bytes(adb('exec-out', 'screencap', '-p'))
                    return ready
            time.sleep(1)
        raise RuntimeError('Actual first wizard not verified; no guessed taps or seeding fallback')

    def require_native(path, device, evidence):
        c = js(evidence)
        assert c['run'] == path.parent.name and c['passed'] == 5 and (c['failed'] == 0) and (c['trueExitCode'] == 0) and (c['sourceManifestSha256'] == file_sha(a.source_manifest)) and (c['sourceMatchedAtCapture'] is True)
        r = js(path)
        assert r['nameFilter'] == '' and r['device'] == device and (r['test'] == 'integration_test/m53_exploration_handoff_test.dart') and (r['tests'] == 'PASS') and (r['automaticDeviceControlActive'] is False) and (r['isolation'] == 'Every pre-existing protected file hash unchanged')
    assert a.confirm_authorized_fresh_exploration
    assert adb('get-state').strip() == b'device' and adb('shell', 'getprop', 'ro.product.model').strip() == b'24069PC21G'
    assert cmd('git', 'rev-parse', 'HEAD').decode().strip() == a.source_commit
    assert cmd('git', 'ls-remote', 'origin', 'refs/heads/main').decode().split()[0] == a.source_commit
    require_native(a.poco_result, '7f0edea0', a.poco_evidence)
    require_native(a.dv_result, '192.168.0.101:5555', a.dv_evidence)
    manifest = js(a.source_manifest)
    tracked = set(cmd('git', 'ls-tree', '-r', '--name-only', 'HEAD').decode().splitlines())
    assert 'tools/handoff_skybee_m53.py' in tracked
    for relative, digest in manifest.items():
        if relative == 'test/skybee_upgrade_recovery_test.dart':
            continue
        assert file_sha(ROOT / relative) == digest, relative
        assert relative in tracked or relative == 'android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java', relative
    compiled_dirty = [x for x in cmd('git', 'diff', '--name-only', 'HEAD').decode().splitlines() if x.split('/')[0] in ['lib', 'android', 'packages', 'assets', 'test', 'integration_test', 'tools'] or x in ['pubspec.yaml', 'pubspec.lock']]
    assert not [x for x in compiled_dirty if not Path(x).name.startswith(('gemini_', 'gemini2_'))], 'Uncommitted tested-source delta'
    gate = js(a.gate)
    assert gate['package'] == PACKAGE and gate['version_code'] > 12 and (gate['version_name'] == '0.5.3') and gate['zipalign_16k_pass'] and (gate['sha256'] == file_sha(a.apk))
    result_file = DIR / 'handoff-result.json'
    try:
        if a.action == 'prepare':
            assert not result_file.exists(), 'No blind replay; use saved phase or inspect failed attempt'
            prior_path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
            assert prior_path.startswith('/data/app/') and prior_path.endswith('/base.apk')
            adb('pull', prior_path, str(DIR / 'prior-skybee.apk'))
            badging = cmd(SDK / 'aapt.exe', 'dump', 'badging', DIR / 'prior-skybee.apk').decode()
            m = re.search("versionCode='(\\d+)'", badging)
            assert m and int(m[1]) < gate['version_code']
            cert = cmd(SDK / 'apksigner.bat', 'verify', '--print-certs', DIR / 'prior-skybee.apk').decode()
            assert re.search('Signer #1 certificate SHA-256 digest: ([a-f0-9]{64})', cert)[1] == gate['signing_certificate_sha256']
            protected = others()
            before = hashes(PACKAGE)
            assert 'databases/kasir_app.db' in before
            selected = [x for x in before if re.fullmatch('databases/kasir_app\\.db(?:-wal|-shm|-journal)?', x) or x in ['no_backup/secret-database-v1', 'no_backup/secret-backup-master-v1', 'databases/skybee-demo-seed-v1.json', 'databases/skybee-m52-upgrade-audit.json']]
            for relative in selected:
                data = read_private(relative)
                assert sha(data) == before[relative]
                out = DIR / 'preinstall-scope' / relative
                out.parent.mkdir(parents=True, exist_ok=True)
                out.write_bytes(data)
            assert hashes(PACKAGE) == before
            nonce = str(uuid.uuid4())
            request = {'format': 1, 'request': 'M53-FRESH-100-50', 'package': PACKAGE, 'nonce': nonce, 'phase': 'requested', 'expectedDatabaseSha256': before['databases/kasir_app.db']}
            result = {'status': 'RUNNING', 'sourceCommit': a.source_commit, 'device': DEVICE, 'package': PACKAGE, 'nonce': nonce, 'beforeHashes': before, 'otherBefore': protected, 'installed': False, 'reset': False, 'uninstall': False, 'downgrade': False, 'automaticDeviceControlActive': True, 'apkSha256': gate['sha256'], 'preinstallSnapshotScope': 'Named encrypted DB family + wrapped default key/recovery + seed/audit metadata only; same-installation protection, not portable recovery'}
            write_json(result_file, result)
            push_json('databases/skybee-m53-handoff.json', request)
            adb('install', '-r', str(a.apk), timeout=180)
            result['installed'] = True
            observed = hashes(PACKAGE)
            assert all((observed.get(k) == v for k, v in before.items())), 'Old files changed before first launch'
            installed_path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
            adb('pull', installed_path, str(DIR / 'installed-skybee.apk'))
            assert file_sha(DIR / 'installed-skybee.apk') == gate['sha256']
            launch()
            prepared = wait_phase('awaiting_external_proof')
            result['prepared'] = prepared
            result['status'] = 'EXTERNAL_PROOF_PENDING'
            result['automaticDeviceControlActive'] = False
            write_json(result_file, result)
        elif a.action == 'external':
            result = js(result_file)
            assert result['status'] == 'EXTERNAL_PROOF_PENDING'
            state = json.loads(read_private('databases/skybee-m53-handoff.json'))
            assert state['nonce'] == result['nonce'] and state['phase'] == 'awaiting_external_proof'
            proof = state['prepared']
            bid = proof['backupId']
            assert re.fullmatch('[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}', bid) and proof['nativeCryptoAndBusinessVerified'] is True
            archive = read_private(f'databases/m5_backups/{bid}/{bid}.kasirbackup')
            code = read_private(f"databases/m53_handoff_{result['nonce']}/recovery.txt")
            assert len(code) == 64 and re.fullmatch(b'[a-f0-9]{64}', code) and (sha(code) == proof['recoverySha256']) and (sha(archive) == proof['archiveSha256'])
            external = a.external_directory.resolve()
            assert external.name.startswith('M53-H-') and external.parent == (Path.home() / 'Documents' / 'SkyBee-Backups').resolve() and (not external.exists())
            external.mkdir(parents=True)
            identity = cmd('whoami').decode().strip()
            cmd('icacls', external, '/inheritance:r', '/grant:r', identity + ':(OI)(CI)F', 'SYSTEM:(OI)(CI)F')
            archive_file = external / (bid + '.kasirbackup')
            code_file = external / 'RECOVERY.txt'
            for path, data in [(archive_file, archive), (code_file, code)]:
                with path.open('xb') as f:
                    f.write(data)
                    f.flush()
                    os.fsync(f.fileno())
            assert file_sha(archive_file) == proof['archiveSha256'] and file_sha(code_file) == proof['recoverySha256']
            (external / 'README.txt').write_text('Cadangan toko sebelum reset M5.3. RECOVERY.txt adalah kode portable yang terpisah dari PIN. Simpan kedua file; tanpa recovery cadangan mungkin tidak bisa dipulihkan. Tidak ada data yang dikirim ke cloud oleh proses ini.\n', encoding='utf8')
            receipt = {'nonce': result['nonce'], 'archiveSha256': proof['archiveSha256'], 'recoverySha256': proof['recoverySha256'], 'externalCopyVerified': True}
            push_json('databases/skybee-m53-external-proof.json', receipt)
            result['externalDirectory'] = str(external)
            result['externalCopyVerified'] = True
            result['status'] = 'READY_FOR_AUTHORIZED_RESET'
            write_json(result_file, result)
        else:
            result = js(result_file)
            assert result['status'] == 'READY_FOR_AUTHORIZED_RESET' and result['externalCopyVerified'] is True
            result['automaticDeviceControlActive'] = True
            write_json(result_file, result)
            adb('shell', 'am', 'force-stop', PACKAGE)
            launch()
            state = wait_phase('awaiting_setup')
            result['reset'] = True
            first = wait_wizard('startup1', result['nonce'])
            assert first['storeId'] == state['prepared']['newStore']
            adb('shell', 'am', 'force-stop', PACKAGE)
            launch()
            second = wait_wizard('startup2', result['nonce'])
            assert second['storeId'] == first['storeId'] and second['startupId'] != first['startupId']
            after = hashes(PACKAGE)
            changed = [path for path, digest in result['beforeHashes'].items() if after.get(path) != digest]
            retained_alias = 'retained-backup-' + sha(json.dumps([state['prepared']['oldStore'], state['prepared']['recoverySha256']], separators=(',', ':')).encode())[:48]
            biometric_scopes = [sha((root + '/databases/kasir_app.db').encode()) for root in ['/data/user/0/' + PACKAGE, '/data/data/' + PACKAGE]]
            unexpected = [path for path in changed if not allowed_reset_change(path, retained_alias, biometric_scopes)]
            result['changedOldFiles'] = changed
            result['unexpectedChangedOldFiles'] = unexpected
            assert not unexpected, 'Unexplained old file change; preserve evidence'
            old_archives = {path: digest for path, digest in result['beforeHashes'].items() if path.startswith('databases/m5_backups/')}
            assert all((after.get(path) == digest for path, digest in old_archives.items()))
            archive_id = state['prepared']['backupId']
            assert sha(read_private(f'databases/m5_backups/{archive_id}/{archive_id}.kasirbackup')) == state['prepared']['archiveSha256']
            result['retainedOldArchiveFilesUnchanged'] = len(old_archives)
            result['genuineWizardTwoStartups'] = True
            result['newBusinessActiveNow'] = {'products': 0, 'sale_transactions': 0}
            result['preparedAfterUserFinish'] = {'products': 100, 'sale_transactions': 50, 'registeredCustomers': 8, 'suppliers': 4}
            launch()
            third = wait_wizard('left-ready', result['nonce'])
            assert third['storeId'] == first['storeId']
            result['status'] = 'PASS'
            result['automaticDeviceControlActive'] = False
            assert others() == result['otherBefore']
            result['otherPackagesUnchanged'] = True
            write_json(result_file, result)
    except BaseException:
        if result_file.exists():
            failure = js(result_file)
            failure['status'] = 'FAILED_OR_UNVERIFIED'
            failure['automaticDeviceControlActive'] = False
            write_json(result_file, failure)
        raise
    finally:
        if result_file.exists():
            final = js(result_file)
            final['automaticDeviceControlActive'] = False
            write_json(result_file, final)
    print(json.dumps({'action': a.action, 'status': js(result_file)['status'], 'automaticDeviceControlActive': js(result_file)['automaticDeviceControlActive']}))
if __name__ == '__main__':
    main()
