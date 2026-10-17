"""Remove only exact recorded fixture DB names from the DV8910 test sandbox.

The test package was absent before this task. Run only after evidence capture;
no operational package, root, recursive delete, wildcard, or global cleanup.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
parser.add_argument('--output', required=True)
args = parser.parse_args()
package = 'com.example.kasir_app.integration'
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe',
        '-s', '192.168.0.102:5555']


def call(*command):
    return subprocess.run(base + list(command), check=True, capture_output=True,
                          timeout=30).stdout.decode('utf-8').strip()


assert call('get-state') == 'device'
root = call('shell', 'run-as', package, 'pwd')
assert root in ('/data/user/0/' + package, '/data/data/' + package)
if args.apply:
    call('shell', 'am', 'force-stop', package)
    assert not subprocess.run(base + ['shell', 'pidof', package],
                              capture_output=True, timeout=30).stdout.strip()
names = call('shell', 'run-as', package, 'ls', 'databases').splitlines()
allowed = re.compile(
    r'(?:kasir_app|dv8910_restart_20261014|(?:m1_integration|m2_integration|'
    r'm3_integration|m31_integration|locale|locale_ui|m2_ui|m3_ui|m31_ui|'
    r'm31_gaps|m4_ui|m4_sql|m4_storage|dv8910_perf|m4_large)_[0-9_]+)'
    r'\.db(?:-journal|-wal|-shm)?')
assert all(allowed.fullmatch(name) for name in names), 'Unknown DB file; stop'
ledger = {'serial': base[2], 'package': package, 'sandbox': root,
          'mode': 'apply' if args.apply else 'inspect', 'exact_names': names,
          'deleted': [], 'root_used': False, 'production_touched': False}
# Save exact targets before mutation, then update after each successful removal.
destination = Path(args.output)
destination.write_text(json.dumps(ledger, indent=2), encoding='utf-8')
if args.apply:
    for name in names:
        assert call('shell', 'run-as', package, 'pwd') == root
        call('shell', 'run-as', package, 'rm', 'databases/' + name)
        ledger['deleted'].append(name)
        destination.write_text(json.dumps(ledger, indent=2), encoding='utf-8')
    ledger['remaining_database_files'] = call(
        'shell', 'run-as', package, 'ls', 'databases').splitlines()
    assert not ledger['remaining_database_files']
    destination.write_text(json.dumps(ledger, indent=2), encoding='utf-8')
print(json.dumps(ledger, indent=2))
