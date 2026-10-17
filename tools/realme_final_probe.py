"""Read-only final checkpoint for the confirmed Realme and isolated test APK.

Only aggregate settings and own-package logs are saved. This helper never sends
input, installs/uninstalls, stops processes, changes settings, or reads DB rows.
"""
import argparse
import datetime
import hashlib
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--output', required=True, type=Path)
args = parser.parse_args()
assert args.device == '0062112V2210F9B3'
package = 'com.example.kasir_app.integration'
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', args.device]


def run(*command):
    process = subprocess.run(base + list(command), capture_output=True, timeout=45)
    return {'exit': process.returncode,
            'stdout': process.stdout.decode('utf-8', 'replace').strip(),
            'stderr': process.stderr.decode('utf-8', 'replace').strip()}


assert run('get-state')['stdout'] == 'device'
args.output.parent.mkdir(parents=True, exist_ok=True)
enabled = run('shell', 'settings', 'get', 'secure', 'enabled_accessibility_services')
assert enabled['exit'] == 0
result = {'time': datetime.datetime.now().astimezone().isoformat(),
          'serial': args.device, 'package': package, 'method': 'read-only explicit ADB',
          'talkback_enabled': any('com.google.android.marvin.talkback/' in service
                                  for service in enabled['stdout'].split(':')),
          'font_scale': run('shell', 'settings', 'get', 'system', 'font_scale'),
          'operational_package': run('shell', 'pm', 'path', 'com.example.kasir_app'),
          'fixture_package': run('shell', 'pm', 'path', package),
          'fixture_pid': run('shell', 'pidof', package)}
paths = result['fixture_package']['stdout'].splitlines()
assert len(paths) == 1 and paths[0].startswith('package:/data/app/')
assert '/' + package + '-' in paths[0] and paths[0].endswith('/base.apk')
result['installed_apk_hash'] = run('shell', 'sha256sum', paths[0][len('package:'):])
digest = result['installed_apk_hash']['stdout'].split()[0]
assert result['installed_apk_hash']['exit'] == 0 and re.fullmatch('[a-f0-9]{64}', digest)
result['installed_sha256'] = digest
pid = result['fixture_pid']['stdout']
if pid.isdigit():
    log = run('logcat', '-d', '--pid=' + pid, '-v', 'threadtime')
    assert log['exit'] == 0
    data = re.sub(r'(https?://(?:127\.0\.0\.1|localhost):\d+/)[^\s/]+/',
                  r'\1[REDACTED_VM_AUTH]/', log['stdout'])
    target = args.output.with_suffix('.pid.log')
    target.write_text(f'package={package} pid={pid}\n{data}\n', encoding='utf-8')
    fatal = [line for line in data.splitlines()
             if re.search(r'\bFATAL EXCEPTION\b|\bFatal signal\b|\bOutOfMemoryError\b|'
                          r'Unhandled Exception|ANR in ' + re.escape(package), line)]
    result['pid_log'] = {'path': str(target), 'lines': len(data.splitlines()),
                         'fatal_markers': len(fatal),
                         'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                         'scope': 'available own-PID ring buffer only; not full history'}
exit_info = run('shell', 'dumpsys', 'activity', 'exit-info', package)
result['exit_info_status'] = exit_info['exit']
# Keep only own package records and numeric reason/timestamp metadata.
result['exit_info'] = [line.strip() for line in exit_info['stdout'].splitlines()
                       if re.search(r'ApplicationExitInfo|timestamp=|reason=|status=|'
                                    r'importance=|pid=|process=' + re.escape(package), line)]
args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'serial': args.device, 'talkback_enabled': result['talkback_enabled'],
                  'font_scale': result['font_scale']['stdout'],
                  'operational_package_present': bool(result['operational_package']['stdout']),
                  'installed_sha256': digest, 'pid_log': result.get('pid_log')}))
