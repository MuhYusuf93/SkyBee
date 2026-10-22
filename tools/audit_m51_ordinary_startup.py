"""Verify the authorized ordinary handoff without entering protected screens.

The second clean startup runs production bootstrap integrity checks on the
migrated encrypted DB. It does not inspect rows, unlock management or claim a
direct external schema query. Private hierarchy/log artifacts stay in build/.
"""
import json
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIR = pathlib.Path((ROOT / 'build/m51-final-handoff-current.txt').read_text().strip())
assert DIR.parent == ROOT / 'build' and DIR.name.startswith('m51-final-handoff-')
ADB = r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
PACKAGE = 'com.example.kasir_app'
DEVICE = '7f0edea0'


def adb(*args, timeout=45):
    return subprocess.run([ADB, '-s', DEVICE, *args], check=True,
                          capture_output=True, timeout=timeout).stdout


def cashier(label):
    # Bounded accessibility read of the launched application, no taps or PIN.
    for _ in range(4):
        raw = adb('exec-out', 'uiautomator', 'dump', '/dev/tty', timeout=30).decode()
        start, end = raw.find('<hierarchy'), raw.rfind('</hierarchy>')
        if start >= 0 and end >= start:
            xml = raw[start:end + len('</hierarchy>')]
            (DIR / f'{label}-private-hierarchy.xml').write_text(xml, encoding='utf-8')
            tree = ET.fromstring(xml)
            nodes = [n for n in tree.iter('node') if n.get('package') == PACKAGE]
            text = '\n'.join(n.get('text', '') + '\n' + n.get('content-desc', '') for n in nodes)
            checks = {
                'ownPackageVisible': bool(nodes),
                'shoppingList': 'Daftar belanja' in text or 'Shopping list' in text,
                'payAction': 'Bayar' in text or 'Pay' in text,
                'manageAction': 'Kelola' in text or 'Manage' in text,
            }
            if all(checks.values()):
                return checks
        time.sleep(1)
    raise RuntimeError('Ordinary cashier semantics not verified; private hierarchy retained')


def logs(label):
    pid = adb('shell', 'pidof', PACKAGE).decode().strip()
    assert re.fullmatch(r'\d+', pid), 'Expected one ordinary application process'
    raw = adb('logcat', '-d', '--pid=' + pid, '-v', 'brief').decode(errors='replace')
    (DIR / f'{label}-private-logcat.txt').write_text(raw, encoding='utf-8')
    return {'pid': int(pid), 'fatalUnhandledAnrMarkers': len(re.findall(
        r'FATAL EXCEPTION|Unhandled Exception|ANR in ' + re.escape(PACKAGE), raw)),
        'flutterErrorMarkers': len(re.findall(r'^E/flutter', raw, re.MULTILINE)),
        'scope': 'Available PID log buffer only'}


assert not (DIR / 'startup-result.json').exists(), 'Do not overwrite an attempted audit'
handoff = json.loads((DIR / 'handoff-result.json').read_text())
assert handoff['installed'] and handoff['automaticDeviceControlActive'] is False
assert adb('shell', 'getprop', 'ro.product.model').strip() == b'24069PC21G'
result = {'device': DEVICE, 'package': PACKAGE, 'schemaTarget': 13,
          'schemaReadback': 'No external SQL query; production coordinator open required for cashier',
          'managementPrivatePin': 'UNVERIFIED', 'automaticDeviceControlActive': True}
try:
    result['firstCashier'] = cashier('first-startup')
    result['firstLog'] = logs('first-startup')
    adb('shell', 'am', 'force-stop', PACKAGE)
    key_checks = {}
    for name, digest in handoff['beforeHashes'].items():
        if name.startswith('no_backup/secret-'):
            actual = adb('shell', 'run-as', PACKAGE, 'sha256sum', name).decode().split()[0]
            key_checks[name] = actual == digest
    assert key_checks and all(key_checks.values()), 'Wrapped secret changed after startup'
    result['allWrappedSecretsUnchanged'] = True
    result['wrappedSecretFiles'] = len(key_checks)
    header = adb('exec-out', 'run-as', PACKAGE, 'head', '-c', '16', 'databases/kasir_app.db')
    result['databaseStillEncryptedHeader'] = len(header) == 16 and header != b'SQLite format 3\0'
    assert result['databaseStillEncryptedHeader']
    result['secondLaunch'] = adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/.MainActivity').decode().strip()
    result['secondCashier'] = cashier('second-startup')
    result['secondLog'] = logs('second-startup')
    assert result['firstLog']['fatalUnhandledAnrMarkers'] == 0
    assert result['secondLog']['fatalUnhandledAnrMarkers'] == 0
    assert result['firstLog']['flutterErrorMarkers'] == 0
    assert result['secondLog']['flutterErrorMarkers'] == 0
    result['productionBootstrapReopen'] = 'PASS; startup requires integrity/FK/HMAC/cipher checks'
    result['status'] = 'PASS'
finally:
    result['automaticDeviceControlActive'] = False
    (DIR / 'startup-result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
