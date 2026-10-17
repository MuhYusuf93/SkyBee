"""Copy only the completed synthetic encrypted DV archive and fact digests."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--nonce', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[0-9]{10,20}', args.nonce)
root = Path(__file__).resolve().parents[1]
output = root / 'docs/evidence/m5-20261016' / ('cross-transfer-' + args.nonce)
output.mkdir(exist_ok=False)
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', '192.168.0.102:5555']
device_root = 'databases/m5_cross_' + args.nonce
for name in ('archive.kasirbackup', 'expected.json'):
    path = device_root + '/' + name
    data = subprocess.run(base + ['exec-out', 'run-as', 'com.example.kasir_app.integration', 'cat', path], capture_output=True, check=True, timeout=40).stdout
    assert 0 < len(data) < (64 * 1024 * 1024 if name == 'archive.kasirbackup' else 65536)
    remote = subprocess.run(base + ['shell', 'run-as', 'com.example.kasir_app.integration', 'sha256sum', path], capture_output=True, check=True, timeout=20).stdout.decode().split()[0]
    assert hashlib.sha256(data).hexdigest() == remote
    (output / name).write_bytes(data)
facts = json.loads((output / 'expected.json').read_text(encoding='utf-8'))
assert facts['nonce'] == args.nonce and len(facts['tables']) == 18
archive = (output / 'archive.kasirbackup').read_bytes()
result = {'source_device': '192.168.0.102:5555', 'nonce': args.nonce, 'archive_bytes': len(archive), 'archive_sha256': hashlib.sha256(archive).hexdigest(), 'synthetic_fact_tables': len(facts['tables'])}
(output / 'transfer.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
