"""Read only the nonce's WorkManager job mapping; never open business DBs.

Transient copies of the closed WorkManager SQLite files are removed exactly by
name. The report includes the test task/job mapping, not arbitrary work payloads.
"""
import argparse
import json
import re
import sqlite3
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--evidence', type=Path, required=True)
parser.add_argument('--adb', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
evidence = args.evidence.resolve()
if not evidence.is_relative_to(root / 'docs' / 'evidence' / 'm5-20261018'):
    raise SystemExit('Unexpected evidence directory')
nonce = json.loads((evidence / 'setup.json').read_text(encoding='utf-8-sig'))['nonce']
if not re.fullmatch(r'\d{10,20}', nonce):
    raise SystemExit('Invalid nonce')
adb = [str(args.adb), '-s', '7f0edea0']
package = 'com.example.kasir_app.integration'
def adb_read(*command):
    return subprocess.run(adb + list(command), capture_output=True, timeout=15)
if adb_read('shell', 'pidof', package).stdout.strip():
    raise SystemExit('Process is active; do not copy a live WorkManager database')
scratch = root / 'build' / f'm5-live-workmeta-{nonce}'
scratch.mkdir(exist_ok=False)
base = scratch / 'work.db'
paths = []
try:
    for suffix in ('', '-wal', '-shm'):
        source = f'no_backup/androidx.work.workdb{suffix}'
        exists = adb_read('shell', 'run-as', package, 'test', '-f', source)
        if exists.returncode == 1 and suffix:
            continue
        if exists.returncode:
            raise SystemExit('Work metadata file unavailable')
        data = adb_read('exec-out', 'run-as', package, 'cat', source)
        if data.returncode:
            raise SystemExit('Work metadata read failed')
        path = Path(str(base) + suffix)
        path.write_bytes(data.stdout)
        paths.append(path)
    if adb_read('shell', 'pidof', package).stdout.strip():
        raise SystemExit('Worker started during metadata copy; discard snapshot')
    con = sqlite3.connect(base)
    try:
        rows = con.execute('SELECT n.name,s.system_id FROM WorkName n JOIN SystemIdInfo s ON n.work_spec_id=s.work_spec_id WHERE n.name=?', (f'kasir-m5-live-drive-{nonce}',)).fetchall()
    finally:
        con.close()
    if len(rows) != 1:
        raise SystemExit('Unique nonce job mapping unavailable')
    report = {'nonce': nonce, 'taskName': rows[0][0], 'systemJobId': rows[0][1], 'scope': 'Closed fixture WorkManager metadata only; no app/business DB opened'}
    (evidence / 'nonce-job-id.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))
finally:
    for suffix in ('', '-wal', '-shm', '-journal'):
        path = Path(str(base) + suffix)
        if path.exists():
            path.unlink()
    scratch.rmdir()
