"""In-place Skybee v8 -> v9 handoff after passing DV acceptance and ordinary push.

Retains a verified closed same-installation sandbox snapshot and prior APK.
Never uninstalls, clears, seeds, changes OS settings or retries an installation.
The app proves old logical facts before any runtime work; bytes can migrate.
"""
import argparse
import hashlib
import io
import json
import pathlib
import re
import subprocess
import tarfile
import time
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
ADB = r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
SDK = pathlib.Path(ADB).parent.parent / 'build-tools/36.0.0'
DEVICE = '7f0edea0'
PACKAGE = 'com.example.kasir_app.skybee'
parser = argparse.ArgumentParser()
parser.add_argument('--directory', type=pathlib.Path, required=True)
parser.add_argument('--dv-result', type=pathlib.Path, required=True)
parser.add_argument('--source-commit', required=True)
args = parser.parse_args()
DIR = args.directory.resolve()
assert DIR.parent == ROOT / 'build' and DIR.name.startswith('m52-skybee-')
assert not (DIR / 'handoff-result.json').exists(), 'Inspect previous attempt; no blind replay'


def run(*command, timeout=60):
    result = subprocess.run(command, capture_output=True, timeout=timeout)
    if result.returncode:
        (DIR / 'private-command-failure.txt').write_bytes(result.stdout + result.stderr)
        result.check_returncode()
    return result.stdout


def adb(*command, timeout=60):
    return run(ADB, '-s', DEVICE, *command, timeout=timeout)


def hashes(package):
    adb('shell', 'am', 'force-stop', package)
    rows = adb('shell', 'run-as', package, 'find', 'databases', 'no_backup', '-type', 'f', '-exec', 'sha256sum', '{}', '\\;').decode().splitlines()
    result = {}
    for line in rows:
        match = re.fullmatch(r'([a-f0-9]{64})\s+(.+)', line)
        assert match
        digest, path = match.groups()
        if re.fullmatch(r'(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?', path):
            continue
        if re.fullmatch(r'no_backup/(?:database|backup-work|printer-output)\.gate', path):
            continue
        result[path] = digest
    return result


def protected():
    return {package: hashes(package) for package in ('com.example.kasir_app', 'com.example.kasir_app.integration')}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hierarchy(label):
    raw = adb('exec-out', 'uiautomator', 'dump', '/dev/tty', timeout=30).decode()
    start, end = raw.find('<hierarchy'), raw.rfind('</hierarchy>')
    assert start >= 0 and end >= start, 'Hierarchy unavailable; no guessed tap'
    xml = raw[start:end + len('</hierarchy>')]
    (DIR / f'{label}-private-hierarchy.xml').write_text(xml, encoding='utf-8')
    tree = ET.fromstring(xml)
    return [node for node in tree.iter('node') if node.get('package') == PACKAGE]


def text(nodes):
    return '\n'.join(node.get('text', '') + '\n' + node.get('content-desc', '') for node in nodes)


def wait_ui(label, required):
    until = time.monotonic() + 120
    while time.monotonic() < until:
        nodes = hierarchy(label)
        value = text(nodes)
        if all(any(option in value for option in alternatives) for alternatives in required):
            return nodes
        time.sleep(1)
    raise RuntimeError(f'{label} semantics not verified; no reset/reseed fallback')


def tap(nodes, alternatives):
    candidates = [node for node in nodes if node.get('text') in alternatives or node.get('content-desc') in alternatives]
    assert len(candidates) == 1, 'Target absent/ambiguous; no guessed tap'
    bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', candidates[0].get('bounds', ''))
    assert bounds
    x1, y1, x2, y2 = map(int, bounds.groups())
    assert x2 > x1 and y2 > y1
    adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))


assert adb('get-state').strip() == b'device'
assert adb('shell', 'getprop', 'ro.product.model').strip() == b'24069PC21G'
commit = run('git', '-C', str(ROOT), 'rev-parse', 'HEAD').decode().strip()
assert re.fullmatch('[0-9a-f]{40}', args.source_commit) and commit == args.source_commit
remote = run('git', '-C', str(ROOT), 'ls-remote', 'origin', 'refs/heads/main').decode().split()[0]
assert remote == commit, 'Latest tested source must already be pushed'
assert not run('git', '-C', str(ROOT), 'diff', '--name-only', '--', 'lib', 'android', 'packages', 'pubspec.yaml', 'pubspec.lock').strip(), 'Build sources changed after commit'
dv = json.loads(args.dv_result.read_text(encoding='utf-8-sig'))
assert dv['device'] == '192.168.0.102:5555' and dv['tests'] == 'PASS'
assert dv['test'] == 'integration_test/m52_acceptance_test.dart'
assert dv['automaticDeviceControlActive'] is False and dv['isolation'] == 'Every pre-existing protected file hash unchanged'
apk = DIR / 'skybee-kasir-0.5.2-debug.apk'
gate = json.loads((DIR / 'skybee-apk.json').read_text())
assert gate['package'] == PACKAGE and gate['version_code'] == 9 and gate['version_name'] == '0.5.2'
assert gate['android_debug_certificate'] and gate['zipalign_16k_pass'] and digest(apk) == gate['sha256']
path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
adb('pull', path, str(DIR / 'prior-skybee.apk'))
prior_badging = run(str(SDK / 'aapt.exe'), 'dump', 'badging', str(DIR / 'prior-skybee.apk')).decode()
assert f"package: name='{PACKAGE}' versionCode='8' versionName='0.5.1'" in prior_badging
signature = run(str(SDK / 'apksigner.bat'), 'verify', '--print-certs', str(DIR / 'prior-skybee.apk')).decode()
prior_cert = re.search(r'Signer #1 certificate SHA-256 digest: ([a-f0-9]{64})', signature)
assert prior_cert and prior_cert[1] == gate['signing_certificate_sha256']
other_before = protected()
before = hashes(PACKAGE)
assert 'databases/kasir_app.db' in before and 'no_backup/secret-database-v1' in before
marker = 'databases/skybee-demo-seed-v1.json'
seed = adb('exec-out', 'run-as', PACKAGE, 'cat', marker)
assert json.loads(seed)['status'] == 'complete' and hashlib.sha256(seed).hexdigest() == before[marker]
folders = adb('shell', 'run-as', PACKAGE, 'ls').decode().splitlines()
selected = [folder for folder in ('databases', 'files', 'no_backup', 'shared_prefs', 'app_flutter') if folder in folders]
snapshot = adb('exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', *selected)
assert 0 < len(snapshot) < 200 * 1024 * 1024
(DIR / 'closed-private-sandbox.tar').write_bytes(snapshot)
with tarfile.open(fileobj=io.BytesIO(snapshot)) as archive:
    for member in archive:
        assert not member.name.startswith('/') and '..' not in pathlib.PurePosixPath(member.name).parts
    for name, expected in before.items():
        assert hashlib.sha256(archive.extractfile(name).read()).hexdigest() == expected
assert hashes(PACKAGE) == before, 'Sandbox changed during snapshot; stop before install'
result = {'package': PACKAGE, 'device': DEVICE, 'sourceCommit': commit, 'version': '0.5.2+9',
          'installed': False, 'status': 'RUNNING', 'automaticDeviceControlActive': True,
          'reset': False, 'uninstall': False, 'reseed': False,
          'apkSha256': gate['sha256'], 'beforeHashes': before,
          'snapshotSha256': hashlib.sha256(snapshot).hexdigest(),
          'snapshotScope': 'closed same-installation snapshot; not portable Keystore recovery'}
result_file = DIR / 'handoff-result.json'
result_file.write_text(json.dumps(result, indent=2))
try:
    output = adb('install', '-r', str(apk), timeout=180)
    (DIR / 'install.log').write_bytes(output)
    assert b'Success' in output
    result['installed'] = True
    assert hashes(PACKAGE) == before, 'Data changed before first launch'
    result['closedFilesPreservedBeforeLaunch'] = True
    path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
    adb('pull', path, str(DIR / 'installed-skybee.apk'))
    assert digest(DIR / 'installed-skybee.apk') == gate['sha256']
    result['installedApkHashMatches'] = True
    cashier_labels = [('Daftar belanja', 'Shopping list'), ('Kelola', 'Manage')]
    for label in ('first-startup', 'second-startup'):
        adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.example.kasir_app.SkybeeDemoActivity')
        wait_ui(label, cashier_labels)
        proof = json.loads(adb('exec-out', 'run-as', PACKAGE, 'cat', 'databases/skybee-m52-upgrade-audit.json'))
        assert proof['status'] == 'complete' and proof['allExistingFactsMatch'] and proof['fromVersion'] == 13 and proof['toVersion'] == 14
        assert hashlib.sha256(adb('exec-out', 'run-as', PACKAGE, 'cat', marker)).hexdigest() == before[marker]
        result[label] = True
    (DIR / 'migration-proof.json').write_text(json.dumps(proof, indent=2))
    nodes = hierarchy('before-public-printer')
    tap(nodes, ('Printer Bluetooth / USB', 'Bluetooth / USB printer'))
    nodes = wait_ui('public-printer', [('Printer Bluetooth / USB', 'Bluetooth / USB printer'), ('Bluetooth',)])
    assert not any(word in text(nodes) for word in ('PIN', 'Kode pemulihan', 'Recovery code'))
    result['publicPrinterWithoutPin'] = True
    adb('shell', 'input', 'keyevent', '4')
    nodes = wait_ui('cashier-before-gate', cashier_labels)
    tap(nodes, ('Kelola', 'Manage'))
    wait_ui('management-gate', [('PIN',)])
    result['managementGateVisible'] = True
    adb('shell', 'input', 'keyevent', '4')
    wait_ui('ready-cashier', cashier_labels)
    after = hashes(PACKAGE)
    assert after['no_backup/secret-database-v1'] == before['no_backup/secret-database-v1']
    assert after[marker] == before[marker]
    result['wrappedDatabaseKeyAndSeedMarkerUnchanged'] = True
    adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.example.kasir_app.SkybeeDemoActivity')
    wait_ui('final-ready', cashier_labels)
    pid = adb('shell', 'pidof', PACKAGE).decode().strip()
    assert re.fullmatch(r'\d+', pid)
    log = adb('logcat', '-d', '--pid=' + pid, '-v', 'brief').decode(errors='replace')
    (DIR / 'private-logcat.txt').write_text(log, encoding='utf-8')
    assert not re.search(r'FATAL EXCEPTION|Unhandled Exception|ANR in ' + re.escape(PACKAGE) + r'|^E/flutter', log, re.MULTILINE)
    result['status'] = 'PASS'
finally:
    try:
        other_after = protected()
        result['otherPackagesUnchanged'] = all(all(other_after[package].get(path) == value for path, value in values.items()) for package, values in other_before.items())
        assert result['otherPackagesUnchanged']
    finally:
        result['automaticDeviceControlActive'] = False
        result_file.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: result[key] for key in ('status', 'package', 'version', 'installed', 'otherPackagesUnchanged', 'automaticDeviceControlActive')}))
