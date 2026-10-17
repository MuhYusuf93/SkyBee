"""Read-only, explicitly targeted preflight; never dumps other apps' logs/data."""
import argparse
import datetime
import hashlib
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
adb = Path(r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe')
base = [str(adb), '-s', args.device]

def run(*command):
    result = subprocess.run(base + list(command), capture_output=True, timeout=40)
    return {'exit': result.returncode, 'stdout': result.stdout.decode('utf-8', 'replace').strip(),
            'stderr': result.stderr.decode('utf-8', 'replace').strip()}

assert run('get-state')['stdout'] == 'device', 'Explicit device unavailable; no mutation'
properties = ['ro.product.manufacturer', 'ro.product.model', 'ro.product.name',
              'ro.product.marketname', 'ro.product.device', 'ro.build.version.release',
              'ro.build.version.sdk', 'ro.build.version.security_patch',
              'ro.product.cpu.abilist', 'ro.product.cpu.abi', 'ro.soc.model',
              'ro.hardware', 'ro.build.fingerprint']
data = {'time': datetime.datetime.now().astimezone().isoformat(), 'serial': args.device,
        'method': 'read-only explicit ADB; no root/settings changes',
        'properties': {p: run('shell', 'getprop', p) for p in properties}}
for name, command in {
    'memory': ('shell', 'cat', '/proc/meminfo'),
    'storage': ('shell', 'df', '-k', '/data'),
    'screen_size': ('shell', 'wm', 'size'),
    'screen_density': ('shell', 'wm', 'density'),
    'font_scale': ('shell', 'settings', 'get', 'system', 'font_scale'),
    'battery': ('shell', 'dumpsys', 'battery'),
    'thermal': ('shell', 'dumpsys', 'thermalservice'),
    'keyboard': ('shell', 'settings', 'get', 'secure', 'default_input_method'),
    'talkback_package': ('shell', 'pm', 'path', 'com.google.android.marvin.talkback'),
    'operational_package': ('shell', 'pm', 'path', 'com.example.kasir_app'),
    'test_package': ('shell', 'pm', 'path', 'com.example.kasir_app.integration'),
    'operational_pid': ('shell', 'pidof', 'com.example.kasir_app'),
}.items():
    data[name] = run(*command)
keyboard = data['keyboard']['stdout'].split('/')[0]
if re.fullmatch(r'[a-zA-Z0-9_.]+', keyboard) and keyboard != 'null':
    dump = run('shell', 'dumpsys', 'package', keyboard)['stdout']
    data['keyboard_version'] = [l.strip() for l in dump.splitlines()
                                if re.match(r'\s*version(?:Name|Code)=', l)]
cpu = run('shell', 'cat', '/proc/cpuinfo')['stdout']
data['cpu_metadata'] = [l for l in cpu.splitlines()
                        if l.startswith(('processor', 'Hardware', 'CPU architecture', 'model name'))]
if data['operational_package']['stdout']:
    data['operational_sandbox'] = run('shell', 'run-as', 'com.example.kasir_app', 'pwd')
    data['operational_db_listing'] = run('shell', 'run-as', 'com.example.kasir_app', 'ls', '-l', 'databases')
    if not data['operational_pid']['stdout']:
        for filename in ['kasir_app.db', 'kasir_app.db-journal', 'kasir_app.db-wal', 'kasir_app.db-shm']:
            data['operational_' + filename] = run('shell', 'run-as', 'com.example.kasir_app',
                                                'sha256sum', 'databases/' + filename)
    else:
        data['operational_hash_note'] = 'Active process; no force-stop or consistency/hash claim'
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: data[k] for k in ['serial', 'properties', 'storage', 'screen_size',
                                     'screen_density', 'font_scale', 'keyboard', 'keyboard_version',
                                     'operational_package', 'test_package'] if k in data}, indent=2))

root = Path(__file__).resolve().parents[1]
sources = [p for folder in ['lib', 'android/app', 'test', 'integration_test', 'tools']
           for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts]
sources += [root / p for p in ['pubspec.yaml', 'pubspec.lock', 'AGENTS.md', 'docs/SPEC.md']]
(args.output.parent / 'source-baseline.json').write_text(json.dumps([
    {'path': p.relative_to(root).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
    for p in sorted(sources)], indent=2) + '\n', encoding='utf-8')
