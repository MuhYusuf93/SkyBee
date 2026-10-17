"""Bounded process-restart/smoke checks on a verified isolated Realme harness.

No operational package, root, reboot, settings mutation or global log access.
Cold/warm Activity timing and service-ready timing are distinct measurements.
"""
import argparse
import datetime
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--mode', choices=['profile', 'release'], required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
assert args.device == '0062112V2210F9B3'
package = 'com.example.kasir_app.integration'
launcher = package + '/com.example.kasir_app.IntegrationActivity'
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', args.device]
args.output.mkdir(parents=True, exist_ok=True)

def call(*command, check=True):
    return subprocess.run(base + list(command), capture_output=True, check=check, timeout=45).stdout.decode('utf-8', 'replace')

assert call('get-state').strip() == 'device'
assert call('shell', 'cmd', 'package', 'resolve-activity', '--brief', package).strip().splitlines()[-1] == launcher
results = {'time': datetime.datetime.now().astimezone().isoformat(), 'mode': args.mode,
           'device': args.device, 'package': package, 'method': 'own process force-stop; not reboot/crash/powerloss',
           'launches': [], 'failures': [], 'ordinary_touched': False}

def save():
    (args.output / f'runtime-{args.mode}.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')

def pid():
    value = call('shell', 'pidof', package, check=False).strip()
    assert value.isdigit(), 'Own process absent'
    return value

def own_log():
    return call('logcat', '-d', '--pid=' + pid(), '-v', 'threadtime')

def wait_stage(expected=None, required_field=None):
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        output = own_log()
        matches = re.findall(r'REALME_SMOKE (\{[^\n]*\})', output)
        if matches:
            stage = json.loads(matches[-1])
            if stage['stage'] == 'failed':
                raise RuntimeError('Harness assertion/operation failed: ' + stage.get('error_type', 'unknown'))
            if (expected is None or stage['stage'] in expected) and (required_field is None or required_field in stage):
                return stage
        time.sleep(1)
    raise TimeoutError('Bounded stage wait expired; cause unverified')

def launch(kind, expected=None):
    before = call('shell', 'pidof', package, check=False).strip()
    if kind == 'cold':
        call('shell', 'am', 'force-stop', package)
    else:
        window = call('shell', 'dumpsys', 'window')
        assert any(package in line for line in window.splitlines() if 'mCurrentFocus=' in line)
        call('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    start = time.monotonic()
    activity = call('shell', 'am', 'start', '-W', '-n', launcher)
    stage = wait_stage(expected)
    current_pid = pid()
    actual_kind = kind
    if kind == 'warm' and before != current_pid:
        actual_kind = 'cold_after_background_process_change'
    sample = {'kind': kind, 'actual_kind': actual_kind, 'previous_pid': before, 'pid': current_pid,
              'am_start': activity.strip(), 'stage_ready_seconds': time.monotonic() - start,
              'stage': stage}
    results['launches'].append(sample)
    save()
    print(kind, stage['stage'], 'pid=' + sample['pid'], flush=True)
    return stage

def tap(label):
    window = call('shell', 'dumpsys', 'window')
    assert any(package in line for line in window.splitlines() if 'mCurrentFocus=' in line)
    raw = call('exec-out', 'uiautomator', 'dump', '/dev/tty')
    root = ET.fromstring(raw[raw.index('<?xml'):raw.index('</hierarchy>') + len('</hierarchy>')])
    nodes = [n for n in root.iter('node') if n.get('package') == package and
             (n.get('text', '') + ' ' + n.get('content-desc', '')).strip() == label]
    assert len(nodes) == 1, 'Own observed UI label not unique: ' + label
    match = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', nodes[0].get('bounds', ''))
    assert match
    x1, y1, x2, y2 = map(int, match.groups())
    call('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))

try:
    initial = launch('cold', {'draft_seeded', 'draft_recovered', 'committed_recovered'})
    if initial['stage'] in {'draft_seeded', 'draft_recovered'}:
        recovered = launch('cold', {'draft_recovered'})
        assert recovered['draft_quantity'] == 3 and recovered['stock'] == 20 and recovered['management_locked']
        tap('COMMIT FIXTURE')
        wait_stage({'committed_before_acknowledgement'})
    for _ in range(3):
        restored = launch('cold', {'committed_recovered'})
        assert restored['sales'] == 1 and restored['debt'] == 26000 and restored['stock'] == 17
        assert restored['cost'] == 27000 and restored['gross_profit'] == 9000
        assert restored['retry_same_sale'] and restored['reconciled'] and restored['management_locked']
    for _ in range(3):
        launch('warm', {'committed_recovered'})
    tap('MEASURE DEBOUNCED SEARCH')
    results['debounced_search'] = wait_stage({'committed_recovered'}, 'debounced_search_5_samples_us')
    process = pid()
    (args.output / f'memory-{args.mode}-harness.log').write_text(call('shell', 'dumpsys', 'meminfo', process), encoding='utf-8')
    tap('OPEN CASHIER')
    time.sleep(4)
    raw_ui = call('exec-out', 'uiautomator', 'dump', '/dev/tty')
    ui_root = ET.fromstring(raw_ui[raw_ui.index('<?xml'):raw_ui.index('</hierarchy>') + len('</hierarchy>')])
    own_labels = [(n.get('text', '') + ' ' + n.get('content-desc', '')).strip()
                  for n in ui_root.iter('node') if n.get('package') == package]
    assert any(re.search(r'Pay|Bayar|Sale saved|Penjualan berhasil disimpan|Next basket|Belanja berikutnya', label, re.I)
               for label in own_labels), 'Actual cashier/receipt nodes not observed'
    results['actual_cashier_labels'] = own_labels
    output = own_log()
    output = re.sub(r'(https?://(?:127\.0\.0\.1|localhost):\d+/)[^\s/]+/', r'\1[REDACTED_VM_AUTH]/', output)
    (args.output / f'pid-{args.mode}-runtime.log').write_text('package=' + package + ' pid=' + process + '\n' + output, encoding='utf-8')
    (args.output / f'memory-{args.mode}-actual-cashier.log').write_text(call('shell', 'dumpsys', 'meminfo', process), encoding='utf-8')
    results['runtime_assertions_passed'] = True
    results['actual_cashier_opened'] = True
except Exception as error:
    results['failures'].append({'type': type(error).__name__, 'message': str(error), 'status': 'UNVERIFIED_CAUSE'})
    results['runtime_assertions_passed'] = False
    save()
    raise
finally:
    save()
