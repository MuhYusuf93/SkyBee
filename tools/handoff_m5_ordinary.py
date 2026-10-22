"""One authorized development handoff; no reset/uninstall/downgrade fallback.

Closed sandbox archive stays under ignored build/. Wrapped secrets only retain
same-installation recovery; this is not a portable backup or Keystore export.
The user's 19-Oct explicit dummy-data authorization permits proceeding without
a newly prepared portable archive. Never reuse this assumption for another run.
"""
import hashlib
import io
import json
import pathlib
import re
import subprocess
import tarfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIR = pathlib.Path((ROOT / 'build/m51-handoff-current.txt').read_text().strip())
assert DIR.parent == ROOT / 'build' and DIR.name.startswith('m51-handoff-')
ADB = r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe'
SDK = pathlib.Path(r'C:\Users\ACER\AppData\Local\Android\sdk\build-tools\36.0.0')
TARGET = '7f0edea0'
PACKAGE = 'com.example.kasir_app'
APK = DIR / 'kasir-app-0.5.0-m5-ordinary-debug.apk'


def run(*args, timeout=60):
    return subprocess.run(args, capture_output=True, check=True, timeout=timeout).stdout


def adb(*args, timeout=60):
    return run(ADB, '-s', TARGET, *args, timeout=timeout)


def hashes():
    # No credentials or row content are included in public metadata.
    result = {}
    for folder in ('databases', 'no_backup'):
        names = adb('shell', 'run-as', PACKAGE, 'ls', folder).decode().splitlines()
        for name in names:
            if folder == 'databases' or name.startswith('secret-'):
                path = f'{folder}/{name}'
                probe = adb('shell', 'run-as', PACKAGE, 'sha256sum', path).decode().split()[0]
                assert re.fullmatch('[a-f0-9]{64}', probe)
                result[path] = probe
    return result


assert not (DIR / 'handoff-result.json').exists(), 'Already attempted; inspect, do not blindly replay.'
assert adb('get-state').strip() == b'device'
assert adb('shell', 'getprop', 'ro.product.model').strip() == b'24069PC21G'
gate = json.loads((DIR / 'debug-apk.json').read_text())
assert gate['package'] == PACKAGE
assert hashlib.sha256(APK.read_bytes()).hexdigest() == gate['sha256']
new_cert = run(str(SDK / 'apksigner.bat'), 'verify', '--print-certs', str(APK)).decode()
old_cert = (DIR / 'prior-signature.txt').read_text(encoding='utf-8-sig')
cert = r'Signer #1 certificate SHA-256 digest: ([a-f0-9]{64})'
assert re.search(cert, new_cert).group(1) == re.search(cert, old_cert).group(1)
badging = run(str(SDK / 'aapt.exe'), 'dump', 'badging', str(APK)).decode()
assert "package: name='com.example.kasir_app' versionCode='7'" in badging
assert "name='com.example.kasir_app.MainActivity'" in badging
adb('shell', 'am', 'force-stop', PACKAGE)
before = hashes()
assert 'databases/kasir_app.db' in before
folders = adb('shell', 'run-as', PACKAGE, 'ls').decode().splitlines()
selected = [x for x in ('databases', 'files', 'no_backup', 'shared_prefs', 'app_flutter') if x in folders]
snapshot = adb('exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', *selected)
assert 0 < len(snapshot) < 200 * 1024 * 1024
(DIR / 'closed-private-sandbox.tar').write_bytes(snapshot)
with tarfile.open(fileobj=io.BytesIO(snapshot)) as archive:
    for member in archive:
        assert not member.name.startswith('/') and '..' not in pathlib.PurePosixPath(member.name).parts
    for path, digest in before.items():
        assert hashlib.sha256(archive.extractfile(path).read()).hexdigest() == digest
assert hashes() == before, 'App restarted while taking snapshot; stop before install.'
result = {'device': TARGET, 'package': PACKAGE, 'mode': 'debug development',
          'dummyDataPermission': 'User explicitly allowed deletion if needed; no deletion used',
          'portableBackup': 'NOT CREATED; same-installation closed snapshot only',
          'beforeHashes': before, 'apkSha256': gate['sha256'], 'dataReset': False,
          'snapshotTarSha256': hashlib.sha256(snapshot).hexdigest(),
          'automaticDeviceControlActive': True, 'installed': False}
(DIR / 'handoff-result.json').write_text(json.dumps(result, indent=2))
installed = adb('install', '-r', str(APK), timeout=180).decode()
assert 'Success' in installed
result['installed'] = True
result['afterInstallHashes'] = hashes()
assert result['afterInstallHashes'] == before, 'Data changed during install before launch.'
path = adb('shell', 'pm', 'path', PACKAGE).decode().strip().removeprefix('package:')
adb('pull', path, str(DIR / 'installed-m5.apk'))
assert hashlib.sha256((DIR / 'installed-m5.apk').read_bytes()).hexdigest() == gate['sha256']
result['launch'] = adb('shell', 'am', 'start', '-W', '-n', PACKAGE + '/.MainActivity').decode().strip()
result['automaticDeviceControlActive'] = False
(DIR / 'handoff-result.json').write_text(json.dumps(result, indent=2))
print(json.dumps({'installed': True, 'package': PACKAGE, 'mode': result['mode'],
                  'apkSha256': gate['sha256'], 'closedFilesPreservedBeforeLaunch': True,
                  'reset': False, 'launchRequested': True}))
