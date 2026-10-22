"""Inspect only closed fixture WorkManager metadata after exact v6 restoration.

Transient SQLite copies are deleted by exact names. No business DB, account,
token, input-data payload, OS setting or other application's work is read.
Terminal work proves no pending M5 fixture work at this snapshot, not a prior
active-to-canceled transition or execution under Doze/reboot.
"""
import argparse
import hashlib
import json
import re
import sqlite3
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--evidence', type=Path, required=True)
parser.add_argument('--nonce', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
evidence = args.evidence.resolve()
assert evidence.is_relative_to(root/'docs/evidence/m5-20261016')
assert re.fullmatch(r'poco-worker-status-update-\d{10,20}', evidence.name)
assert re.fullmatch(r'\d{10,20}', args.nonce)
ledger = json.loads((evidence/'update.json').read_text(encoding='utf-8-sig'))
assert ledger['nonce'] == args.nonce and ledger['originalV6Restored']
adb = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', '7f0edea0']
package = 'com.example.kasir_app.integration'

def call(*values):
    return subprocess.run(adb+list(values), capture_output=True, timeout=25)

assert call('get-state').stdout.strip() == b'device'
assert call('shell', 'getprop', 'ro.product.model').stdout.strip() == b'24069PC21G'
assert not call('shell', 'pidof', package).stdout.strip(), 'Fixture active; no live metadata copying'
scratch = root/'build'/f'm5-closing-work-{args.nonce}'
assert scratch.resolve().is_relative_to((root/'build').resolve())
scratch.mkdir(exist_ok=False)
base = scratch/'work.db'
sources = {suffix: f'no_backup/androidx.work.workdb{suffix}' for suffix in ('', '-wal', '-shm', '-journal')}

def read_closed(suffix):
    source = sources[suffix]
    exists = call('shell', 'run-as', package, 'test', '-f', source)
    if exists.returncode == 1 and suffix:
        return None
    assert exists.returncode == 0, 'Work metadata unavailable; no absence inference'
    result = call('exec-out', 'run-as', package, 'cat', source)
    assert result.returncode == 0, 'Own closed work metadata read failed'
    return result.stdout

try:
    original = {}
    for suffix in sources:
        data = read_closed(suffix)
        original[suffix] = hashlib.sha256(data).hexdigest() if data is not None else 'ABSENT'
        if data is not None:
            Path(str(base)+suffix).write_bytes(data)
    assert not call('shell', 'pidof', package).stdout.strip(), 'Worker started during snapshot'
    con = sqlite3.connect(base)
    try:
        assert con.execute('PRAGMA quick_check').fetchone()[0] == 'ok'
        rows = con.execute('''SELECT DISTINCT w.id,w.state FROM WorkSpec w
          LEFT JOIN WorkTag t ON t.work_spec_id=w.id
          LEFT JOIN WorkName n ON n.work_spec_id=w.id
          WHERE t.tag=? OR n.name=? OR n.name LIKE ?''',
          ('kasir-drive-v1', 'kasir-alerts-periodic-v1', 'kasir-m5-live-drive-%')).fetchall()
    finally:
        con.close()
    # Android WorkTypeConverters persisted states: 2 succeeded/3 failed/5 canceled.
    active = sum(state not in (2, 3, 5) for _, state in rows)
    assert active == 0, 'Pending or unknown-state fixture M5 work remains'
    assert not call('shell', 'pidof', package).stdout.strip(), 'Fixture restarted during inspection'
    for suffix in sources:
        data = read_closed(suffix)
        current = hashlib.sha256(data).hexdigest() if data is not None else 'ABSENT'
        assert current == original[suffix], 'Original work metadata changed during inspection'
    report = {
      'device': '7f0edea0', 'package': package, 'nonce': args.nonce,
      'closedWorkMetadataIntegrity': True, 'originalMetadataHashesUnchanged': True,
      'm5WorkCount': len(rows), 'pendingOrUnknownStateCount': active,
      'succeededCount': sum(state == 2 for _, state in rows),
      'failedCount': sum(state == 3 for _, state in rows),
      'canceledCount': sum(state == 5 for _, state in rows),
      'scope': 'Drive-tag, alert unique work and fixture live probes only; no identifiers/payloads retained',
      'limits': 'Snapshot after cleanup; not proof of prior live job cancellation, natural21, reboot or Doze',
    }
    (evidence/'own-m5-work-closed.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(report))
finally:
    for suffix in ('', '-wal', '-shm', '-journal'):
        path = Path(str(base)+suffix)
        if path.exists():
            path.unlink()
    scratch.rmdir()
