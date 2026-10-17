"""Read-only, fixed Poco sandbox startup check, before human account/backup use.

Never stores full UI, keyboard text, account selectors, recovery codes or images.
Run only after automated widget tests have ended and before manual handover.
"""
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--evidence', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
evidence = args.evidence.resolve()
assert evidence.is_relative_to(root / 'docs/evidence/m5-20261016')
assert (evidence / 'handover.json').is_file()
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', '7f0edea0']
package = 'com.example.kasir_app.integration'

def call(*values):
    return subprocess.check_output(base + list(values), timeout=35).decode('utf-8', errors='replace')

assert call('shell', 'getprop', 'ro.product.model').strip() == '24069PC21G'
deadline = time.monotonic() + 90
visible = False
while time.monotonic() < deadline:
    focused = call('shell', 'dumpsys', 'window')
    lines = [line for line in focused.splitlines() if 'mCurrentFocus=' in line]
    if not any(package in line for line in lines):
        time.sleep(2)
        continue  # no global UI capture when another surface owns focus
    raw = call('exec-out', 'uiautomator', 'dump', '/dev/tty')
    if '<?xml' not in raw or '</hierarchy>' not in raw:
        time.sleep(2)
        continue
    hierarchy = ET.fromstring(raw[raw.index('<?xml'):raw.index('</hierarchy>') + len('</hierarchy>')])
    own = [node for node in hierarchy.iter('node') if node.get('package') == package]
    visible = any('UJI COBA M5' in (node.get('text', '') + node.get('content-desc', '')) for node in own)
    if visible:
        break
    time.sleep(2)
pid = call('shell', 'pidof', package).strip()
assert pid.isdigit(), 'Own fixture PID unavailable'
log = call('logcat', '-d', '--pid=' + pid, '-v', 'threadtime')
(evidence / 'startup-own-pid.log').write_text(log, encoding='utf-8')
error_lines = [line for line in log.splitlines() if re.search(r'FATAL EXCEPTION|Unhandled Exception|Directionality\.of|No Directionality widget|E/flutter', line)]
result = {'package': package, 'pid': int(pid), 'synthetic_screen_visible': visible,
          'startup_error_markers': len(error_lines), 'scope': 'startup only; not printer, Google, restore or full release acceptance'}
(evidence / 'startup.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result))
assert visible and not error_lines, 'Startup not confirmed or error markers found; inspect own PID evidence'
