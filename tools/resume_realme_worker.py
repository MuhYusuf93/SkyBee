"""Resume only an inspected completed Realme probe, without rerunning setup.

Retains the original interval baseline, APK and encrypted snapshot. The reader
may migrate only its exact old probe DB and spend its own remaining retry claim.
Every other pre-existing file remains hash protected; no downgrade or reset.
"""
import argparse
import hashlib
import io
import json
import os
import pathlib
import re
import subprocess
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
ADB = r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
SDK = pathlib.Path(ADB).parent.parent
POWERSHELL = r'C:\Users\ACER\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
FLUTTER = r'C:\Users\ACER\dev\flutter\bin'
DEVICE = '0062112V2210F9B3'
PACKAGE = 'com.example.kasir_app.integration'
parser = argparse.ArgumentParser()
parser.add_argument('--nonce', required=True)
parser.add_argument('--audit', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
args = parser.parse_args()
assert re.fullmatch(r'[0-9]{10,20}', args.nonce)
OUT = args.output.resolve()
assert OUT.parent == ROOT / 'build' and not OUT.exists()
assert args.audit.resolve().is_relative_to(ROOT / 'build')
audit = json.loads(args.audit.read_text())
assert audit['nonce'] == args.nonce and audit['preflight'] == 'PASS'
assert audit['allOldHashesMatch'] and audit['work']['pending'] == 0
assert len(audit['work']['exactNonceRows']) == 1
assert audit['work']['exactNonceRows'][0]['state'] == 2
assert audit['result']['keystoreReopened'] and audit['failure'] == 'ABSENT'
OUT.mkdir()
env = dict(os.environ, PATH=FLUTTER + os.pathsep + os.environ['PATH'], CI='true', FLUTTER_SUPPRESS_ANALYTICS='true')

def run(*command, timeout=60):
    r = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, timeout=timeout)
    if r.returncode:
        (OUT / 'private-command-failure.txt').write_bytes(r.stdout + r.stderr)
        r.check_returncode()
    return r.stdout

def adb(*command):
    return run(ADB, '-s', DEVICE, *command)

def hashes():
    assert not adb('shell', 'pm', 'list', 'packages', 'com.example.kasir_app').decode().splitlines().count('package:com.example.kasir_app')
    adb('shell', 'am', 'force-stop', PACKAGE)
    rows = adb('shell', 'run-as', PACKAGE, 'find', 'databases', 'no_backup', '-type', 'f', '-exec', 'sha256sum', '{}', '\\;').decode().splitlines()
    result = {'ordinary': 'ABSENT'}
    for line in rows:
        m = re.fullmatch(r'([a-f0-9]{64})\s+(.+)', line)
        assert m
        value, path = m.groups()
        if re.fullmatch(r'(?:databases|no_backup)/androidx\.work\.workdb(?:-wal|-shm|-journal)?', path): continue
        if re.fullmatch(r'no_backup/(?:database|backup-work|printer-output)\.gate', path): continue
        result[path] = value
    return result

def safe_runner(label, prepare=False):
    command = [POWERSHELL, '-NoProfile', '-File', str(ROOT / 'tools/test_android.ps1'),
               '-DeviceId', DEVICE, '-AndroidSdkRoot', str(SDK),
               '-TestFiles', 'integration_test/m5_worker_result_test.dart',
               '-AdditionalDartDefines', 'M5_WORKER_NONCE=' + args.nonce,
               '-TargetPlatform', 'android-arm', '-TestTimeout', '5m']
    if prepare: command.append('-PrepareOnly')
    with (OUT / (label + '.log')).open('wb') as log:
        r = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    assert r.returncode == 0, 'Safe worker reader failed; inspect retained log'

assert adb('get-state').strip() == b'device'
assert adb('shell', 'getprop', 'ro.product.model').strip() == b'RMX3231'
before = hashes()
original = json.loads((ROOT / f'build/realme-current-worker-{args.nonce}/before.json').read_text(encoding='utf-8-sig'))
assert all(before.get(path) == value for path, value in original.items())
assert before == json.loads((args.audit.parent / 'closed-before.json').read_text()), 'Device changed since inspected audit'
(OUT / 'before.json').write_text(json.dumps(before, indent=2))
apk_path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
assert apk_path.startswith('/data/app/') and apk_path.endswith('/base.apk')
adb('pull', apk_path, str(OUT / 'prior-fixture.apk'))
snapshot = adb('exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', 'databases', 'no_backup', 'shared_prefs')
assert 0 < len(snapshot) < 200 * 1024 * 1024
(OUT / 'private-closed-sandbox.tar').write_bytes(snapshot)
with tarfile.open(fileobj=io.BytesIO(snapshot)) as archive:
    for path, value in before.items():
        if path != 'ordinary':
            assert hashlib.sha256(archive.extractfile(path).read()).hexdigest() == value
assert hashes() == before
allowed = {f'databases/m5_worker_{args.nonce}.db', f'no_backup/secret-test-m51-{args.nonce}-backup-retry-v1'}
assert allowed <= before.keys() and not allowed.intersection(original)
result = {'device': DEVICE, 'nonce': args.nonce, 'tests': 'RUNNING',
          'automaticDeviceControlActive': True, 'reset': False, 'downgrade': False,
          'setupReplayed': False, 'originalProtectedEntries': len(original),
          'allowedOwnFixtureChanges': sorted(allowed), 'isolation': 'NOT CHECKED'}
try:
    safe_runner('prepare', prepare=True)
    apk = ROOT / 'build/app/outputs/flutter-apk/app-debug.apk'
    badging = run(str(SDK / 'build-tools/36.0.0/aapt.exe'), 'dump', 'badging', str(apk)).decode()
    assert "package: name='com.example.kasir_app.integration' versionCode='9' versionName='0.5.2'" in badging
    for file in (OUT / 'prior-fixture.apk', apk):
        signature = run(str(SDK / 'build-tools/36.0.0/apksigner.bat'), 'verify', '--print-certs', str(file)).decode()
        assert '002029d011716641cfb6c8490df92d309920c38be4150770ed14423dd37fcd4c' in signature
    installed = adb('install', '-r', str(apk))
    assert b'Success' in installed
    (OUT / 'install.log').write_bytes(installed)
    assert hashes() == before, 'Closed data changed before reader'
    # Preserve independently observed terminal state before WorkManager prunes
    # its multi-day-old record. This is not a substitute for executing a job.
    proof_path = f'databases/m5_worker_{args.nonce}.terminal-proof.json'
    exists = subprocess.run([ADB, '-s', DEVICE, 'shell', 'run-as', PACKAGE, 'test', '-f', proof_path], capture_output=True)
    assert exists.returncode == 1, 'Never overwrite retained terminal evidence'
    terminal_proof = json.dumps({
        'nonce': args.nonce, 'state': 'succeeded', 'capturedBeforeReader': True,
        'workId': audit['work']['exactNonceRows'][0]['id'],
        'attempts': audit['work']['exactNonceRows'][0]['attempts'],
        'setupSha256': before[f'databases/m5_worker_{args.nonce}.setup.json'],
        'resultSha256': before[f'databases/m5_worker_{args.nonce}.result.json'],
    }, sort_keys=True).encode('ascii')
    transfer = subprocess.run([ADB, '-s', DEVICE, 'shell', '-T', 'run-as', PACKAGE,
                               'sh', '-c', f"'cat > {proof_path}'"], input=terminal_proof,
                              capture_output=True, timeout=30)
    assert transfer.returncode == 0
    assert adb('exec-out', 'run-as', PACKAGE, 'cat', proof_path) == terminal_proof
    safe_runner('reader')
    result['tests'] = 'PASS'
except Exception:
    result['tests'] = 'FAILED_OR_BLOCKED'
    raise
finally:
    try:
        after = hashes()
        (OUT / 'after.json').write_text(json.dumps(after, indent=2))
        changed = [p for p,v in before.items() if after.get(p) != v]
        assert set(changed) <= allowed, 'Unexpected retained file mutation'
        assert all(after.get(p) == v for p,v in original.items()), 'Original checkpoint file changed'
        result['changedOwnFiles'] = changed
        result['isolation'] = 'Every original checkpoint file unchanged; only two exact own-probe files may migrate/claim'
    finally:
        result['automaticDeviceControlActive'] = False
        (OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
