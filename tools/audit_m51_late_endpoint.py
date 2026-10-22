"""Close the interrupted Poco audit without rewriting its historical result.

Only quiesces the two authorized application packages and reads protected file
hashes. A mismatch is retained as evidence; it never resets or repairs data.
"""
import datetime
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
PRIOR = ROOT / 'build/m51-candidate-before-20261020-021458'
ADB = r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
DEVICE = '7f0edea0'


def adb(*args):
    return subprocess.run([ADB, '-s', DEVICE, *args], check=True,
                          capture_output=True, timeout=60).stdout.decode().strip()


assert adb('get-state') == 'device'
assert adb('shell', 'getprop', 'ro.product.model') == '24069PC21G'
before = json.loads((PRIOR / 'before.json').read_text(encoding='utf-8-sig'))
after = {}
for package in ('com.example.kasir_app', 'com.example.kasir_app.integration'):
    packages = adb('shell', 'pm', 'list', 'packages', package).splitlines()
    if f'package:{package}' not in packages:
        after[package] = 'ABSENT'
        continue
    adb('shell', 'am', 'force-stop', package)
    lines = adb('shell', 'run-as', package, 'find', 'databases', 'no_backup',
                '-type', 'f', '-exec', 'sha256sum', '{}', '\\;').splitlines()
    for line in lines:
        match = re.fullmatch(r'([a-f0-9]{64})\s+(.+)', line)
        assert match, 'Invalid digest response'
        digest, name = match.groups()
        if re.fullmatch(r'(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?', name):
            continue
        if re.fullmatch(r'no_backup/(?:database|backup-work|printer-output)\.gate', name):
            continue
        after[f'{package}/{name}'] = digest
mismatches = [name for name, digest in before.items() if after.get(name) != digest]
stamp = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=7)))
output = PRIOR / ('late-after-' + stamp.strftime('%Y%m%d-%H%M%S') + '.json')
assert not output.exists()
result = {'device': DEVICE, 'capturedAt': stamp.isoformat(), 'beforeFile': 'before.json',
          'preExistingFiles': len(before), 'afterHashes': after,
          'mismatches': mismatches, 'allPreExistingHashesMatch': not mismatches,
          'historicalTestResultUnchanged': True, 'automaticDeviceControlActive': False}
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'preExistingFiles': len(before), 'mismatches': len(mismatches),
                  'allPreExistingHashesMatch': not mismatches,
                  'automaticDeviceControlActive': False, 'evidence': str(output)}))
raise SystemExit(bool(mismatches))
