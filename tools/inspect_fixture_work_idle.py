"""Read only closed integration WorkManager metadata, never business DBs/keys.

Copy only the exact WorkManager DB and its sidecars into private build scratch;
verify source digests twice and delete the scratch bytes in finally. Fail closed
on pending work, inconsistent files or an unknown confirmed device identity.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True, choices=['7f0edea0', '192.168.0.101:5555', '192.168.0.102:5555'])
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
adb = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', args.device]
package = 'com.example.kasir_app.integration'


def call(*parts):
    return subprocess.run(adb + list(parts), capture_output=True, timeout=30)


def checked(*parts):
    result = call(*parts)
    assert result.returncode == 0, 'Metadata operation failed'
    return result.stdout


model = checked('shell', 'getprop', 'ro.product.model').decode().strip()
assert model == ('24069PC21G' if args.device == '7f0edea0' else 'AX810')
if model == 'AX810':
    assert checked('shell', 'getprop', 'ro.product.device').strip() == b'DV8947-KIX'
checked('shell', 'am', 'force-stop', package)
assert not call('shell', 'pidof', package).stdout.strip()
bases = []
for folder in ('databases', 'no_backup'):
    source = f'{folder}/androidx.work.workdb'
    result = call('shell', 'run-as', package, 'test', '-f', source)
    assert result.returncode in (0, 1), 'Cannot inspect own work metadata'
    if result.returncode == 0:
        bases.append(source)
assert len(bases) <= 1, 'Ambiguous WorkManager database'
summary = {'device': args.device, 'pending': 0, 'source': 'NO_WORK_DATABASE'}
if bases:
    def read(suffix):
        source = bases[0] + suffix
        exists = call('shell', 'run-as', package, 'test', '-f', source)
        assert exists.returncode in (0, 1)
        if exists.returncode == 1:
            assert suffix
            return None
        return checked('exec-out', 'run-as', package, 'cat', source)

    # TemporaryDirectory stays in ignored private build; no raw metadata output.
    with tempfile.TemporaryDirectory(prefix='m53-work-', dir=root / 'build') as scratch:
        local = Path(scratch) / 'work.db'
        before = {}
        for suffix in ('', '-wal', '-shm', '-journal'):
            raw = read(suffix)
            before[suffix] = None if raw is None else hashlib.sha256(raw).hexdigest()
            if raw is not None:
                Path(str(local) + suffix).write_bytes(raw)
        assert not call('shell', 'pidof', package).stdout.strip()
        connection = sqlite3.connect(local.as_uri() + '?mode=ro', uri=True)
        try:
            assert connection.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
            states = dict(connection.execute('SELECT state, COUNT(*) FROM WorkSpec GROUP BY state'))
        finally:
            connection.close()
        for suffix, digest in before.items():
            raw = read(suffix)
            assert (None if raw is None else hashlib.sha256(raw).hexdigest()) == digest
        assert not call('shell', 'pidof', package).stdout.strip()
        summary = {'device': args.device, 'pending': sum(n for state, n in states.items() if state not in (2, 3, 5)), 'source': 'CLOSED_CONSISTENT_WORK_DATABASE'}
print(json.dumps(summary))
assert summary['pending'] == 0, 'Existing fixture work pending; do not install tests'
