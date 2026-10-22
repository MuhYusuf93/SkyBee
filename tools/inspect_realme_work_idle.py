"""Closed own WorkManager metadata only; never read payload columns or cancel jobs.

Fail closed if any existing task is pending, before a probe changes the shared
callback handle. Device DB/sidecars are read twice for snapshot consistency;
private scratch copies are removed by exact names after the read-only query.
"""
import hashlib
import json
import sqlite3
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parents[1]
scratch = root / 'build' / f'realme-work-idle-{time.time_ns()}'
scratch.mkdir()
assert scratch.resolve().is_relative_to((root / 'build').resolve())
adb = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe',
       '-s', '0062112V2210F9B3']
package = 'com.example.kasir_app.integration'


def call(*args):
    return subprocess.run(adb + list(args), capture_output=True, timeout=25)


assert call('shell', 'getprop', 'ro.product.model').stdout.strip() == b'RMX3231'
assert not call('shell', 'pidof', package).stdout.strip(), 'Fixture must be stopped'
bases = []
for parent in ('databases', 'no_backup'):
    candidate = f'{parent}/androidx.work.workdb'
    exists = call('shell', 'run-as', package, 'test', '-f', candidate)
    assert exists.returncode in (0, 1), 'Own work metadata unavailable'
    if exists.returncode == 0:
        bases.append(candidate)
assert len(bases) <= 1, 'Ambiguous work database'
summary = {'device': 'RMX3231', 'pending': 0, 'source': 'NO_WORK_DATABASE'}
local = scratch / 'work.db'
files = [Path(str(local) + suffix) for suffix in ('', '-wal', '-shm', '-journal')]
try:
    if bases:
        def read(suffix):
            source = bases[0] + suffix
            exists = call('shell', 'run-as', package, 'test', '-f', source)
            assert exists.returncode in (0, 1)
            if exists.returncode == 1:
                assert suffix
                return None
            result = call('exec-out', 'run-as', package, 'cat', source)
            assert result.returncode == 0
            return result.stdout

        before = {}
        for file, suffix in zip(files, ('', '-wal', '-shm', '-journal')):
            data = read(suffix)
            before[suffix] = hashlib.sha256(data).hexdigest() if data is not None else None
            if data is not None:
                file.write_bytes(data)
        assert not call('shell', 'pidof', package).stdout.strip()
        connection = sqlite3.connect(local.as_uri() + '?mode=ro', uri=True)
        try:
            assert connection.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
            states = dict(connection.execute('SELECT state,COUNT(*) FROM WorkSpec GROUP BY state'))
        finally:
            connection.close()
        for suffix in before:
            data = read(suffix)
            assert (hashlib.sha256(data).hexdigest() if data is not None else None) == before[suffix]
        assert not call('shell', 'pidof', package).stdout.strip()
        pending = sum(count for state, count in states.items() if state not in (2, 3, 5))
        summary = {'device': 'RMX3231', 'pending': pending, 'terminal': sum(states.values()) - pending,
                   'source': 'CLOSED_CONSISTENT_WORK_DATABASE'}
    (scratch / 'summary.json').write_text(json.dumps(summary), encoding='utf-8')
    print(json.dumps(summary))
    assert summary['pending'] == 0, 'Existing work pending; callback probe blocked'
finally:
    for file in files:
        if file.exists():
            file.unlink()
