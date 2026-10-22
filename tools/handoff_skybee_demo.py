"""Install the user-requested standalone demo, never replacing other packages.

Native integration tests still use their safe runner. This script installs an
actual debug application with no test framework or integration entrypoint.
"""
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIR = pathlib.Path((ROOT / 'build/skybee-demo-current.txt').read_text().strip())
assert DIR.parent == ROOT / 'build' and DIR.name.startswith('skybee-demo-')
ADB = r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
DEVICE = '7f0edea0'
PACKAGE = 'com.example.kasir_app.skybee'
APK = DIR / 'skybee-kasir-0.5.1-debug.apk'
RESUME = sys.argv[1:] == ['--resume-installed']
assert not sys.argv[1:] or RESUME, 'Unsupported arguments'
PREFIX = 'resumed-' if RESUME else ''
RESULT_FILE = DIR / (PREFIX + 'handoff-result.json')


def adb(*args, timeout=60):
    response = subprocess.run([ADB, '-s', DEVICE, *args], capture_output=True, timeout=timeout)
    if response.returncode:
        (DIR / (PREFIX + 'failed-adb-output.txt')).write_bytes(response.stdout + response.stderr)
        response.check_returncode()
    return response.stdout


def protected_hashes():
    """Close only existing kasir packages and retain every business/key digest."""
    result = {}
    for package in ('com.example.kasir_app', 'com.example.kasir_app.integration'):
        assert f'package:{package}' in adb('shell', 'pm', 'list', 'packages', package).decode().splitlines()
        adb('shell', 'am', 'force-stop', package)
        lines = adb('shell', 'run-as', package, 'find', 'databases', 'no_backup',
                    '-type', 'f', '-exec', 'sha256sum', '{}', '\\;').decode().splitlines()
        for line in lines:
            match = re.fullmatch(r'([a-f0-9]{64})\s+(.+)', line)
            assert match, 'Invalid hash response'
            digest, path = match.groups()
            if re.fullmatch(r'(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?', path):
                continue
            if re.fullmatch(r'no_backup/(?:database|backup-work|printer-output)\.gate', path):
                continue
            result[f'{package}/{path}'] = digest
    return result


def read_seed():
    marker = 'databases/skybee-demo-seed-v1.json'
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        probe = subprocess.run([ADB, '-s', DEVICE, 'shell', 'run-as', PACKAGE,
                                'cat', marker], capture_output=True, timeout=10)
        if probe.returncode == 0:
            try:
                value = json.loads(probe.stdout)
                if value.get('status') == 'complete':
                    return value, hashlib.sha256(probe.stdout).hexdigest()
            except json.JSONDecodeError:
                pass
        time.sleep(2)
    raise RuntimeError('Demo initialization did not complete; no reset/reinstall fallback')


def cashier(label):
    for _ in range(4):
        raw = adb('exec-out', 'uiautomator', 'dump', '/dev/tty', timeout=30).decode()
        start, end = raw.find('<hierarchy'), raw.rfind('</hierarchy>')
        if start >= 0 and end >= start:
            xml = raw[start:end + len('</hierarchy>')]
            (DIR / f'{label}-private-hierarchy.xml').write_text(xml, encoding='utf-8')
            tree = ET.fromstring(xml)
            nodes = [n for n in tree.iter('node') if n.get('package') == PACKAGE]
            text = '\n'.join(n.get('text', '') + '\n' + n.get('content-desc', '') for n in nodes)
            checks = {name: name in text for name in ('toko skybee', 'Daftar belanja', 'Bayar', 'Kelola')}
            if nodes and all(checks.values()):
                return checks
        time.sleep(1)
    raise RuntimeError('Skybee cashier semantics not verified')


assert not RESULT_FILE.exists(), 'Inspect prior attempt; do not blindly replay'
assert adb('get-state').strip() == b'device'
assert adb('shell', 'getprop', 'ro.product.model').strip() == b'24069PC21G'
present = f'package:{PACKAGE}' in adb('shell', 'pm', 'list', 'packages', PACKAGE).decode().splitlines()
assert present == RESUME, 'Initial install requires absent package; resume requires an installed package'
if RESUME:
    prior = json.loads((DIR / 'handoff-result.json').read_text())
    assert prior['installed'] is False and prior['allProtectedHashesMatch'] is True
    assert 'Success' in (DIR / 'install-retry.log').read_text(encoding='utf-8-sig')
gate = json.loads((DIR / 'apk-verification.json').read_text())
assert gate['package'] == PACKAGE and gate['version_code'] == 8
assert gate['launcher'] == 'com.example.kasir_app.SkybeeDemoActivity'
assert gate['android_debug_certificate'] and gate['zipalign_16k_pass']
assert hashlib.sha256(APK.read_bytes()).hexdigest() == gate['sha256']
before = protected_hashes()
if RESUME:
    prior_before = json.loads((DIR / 'protected-before.json').read_text())
    assert all(before.get(k) == v for k, v in prior_before.items()), 'Prior interval hashes differ'
(DIR / (PREFIX + 'protected-before.json')).write_text(json.dumps(before, indent=2))
result = {'package': PACKAGE, 'device': DEVICE, 'label': 'skybee kasir',
          'installed': False, 'automaticDeviceControlActive': True,
          'reset': False, 'uninstall': False, 'apkSha256': gate['sha256'],
          'resumedAfterSeparateSuccessfulInstall': RESUME}
try:
    RESULT_FILE.write_text(json.dumps(result, indent=2))
    if not RESUME:
        assert 'Success' in adb('install', str(APK), timeout=180).decode()
    result['installed'] = True
    print('Skybee standalone debug installed; initializing its own demo data.', flush=True)
    path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
    adb('pull', path, str(DIR / 'installed-skybee.apk'))
    assert hashlib.sha256((DIR / 'installed-skybee.apk').read_bytes()).hexdigest() == gate['sha256']
    result['installedApkHashMatches'] = True
    result['launch'] = adb('shell', 'am', 'start', '-W', '-n',
                           PACKAGE + '/com.example.kasir_app.SkybeeDemoActivity').decode().strip()
    seed, marker_hash = read_seed()
    assert seed['counts']['products'] == 100 and seed['counts']['activeProducts'] == 95
    assert seed['pinConfiguredAndVerified'] and seed['businessReconciliation'] == 'PASS'
    result['seed'] = seed
    result['cashier'] = cashier('first-startup')
    # Reopen proves the populated app stays usable and the one-time marker is
    # retained. Do not compare DB bytes across normal startup metadata writes.
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/com.example.kasir_app.SkybeeDemoActivity')
    result['secondCashier'] = cashier('second-startup')
    _, reopened_hash = read_seed()
    assert reopened_hash == marker_hash
    result['seedMarkerUnchangedAfterReopen'] = True
    pid = adb('shell', 'pidof', PACKAGE).decode().strip()
    assert re.fullmatch(r'\d+', pid)
    raw = adb('logcat', '-d', '--pid=' + pid, '-v', 'brief').decode(errors='replace')
    (DIR / 'private-logcat.txt').write_text(raw, encoding='utf-8')
    result['pidLog'] = {'pid': int(pid), 'fatalUnhandledAnrMarkers': len(re.findall(
        r'FATAL EXCEPTION|Unhandled Exception|ANR in ' + re.escape(PACKAGE), raw)),
        'flutterErrorMarkers': len(re.findall(r'^E/flutter', raw, re.MULTILINE))}
    assert result['pidLog']['fatalUnhandledAnrMarkers'] == 0 and result['pidLog']['flutterErrorMarkers'] == 0
    result['status'] = 'PASS'
finally:
    try:
        after = protected_hashes()
        (DIR / (PREFIX + 'protected-after.json')).write_text(json.dumps(after, indent=2))
        result['protectedPreExistingFiles'] = len(before)
        result['allProtectedHashesMatch'] = all(after.get(k) == v for k, v in before.items())
        assert result['allProtectedHashesMatch'], 'Existing kasir data changed; inspect evidence'
    finally:
        result['automaticDeviceControlActive'] = False
        RESULT_FILE.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
