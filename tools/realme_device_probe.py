"""Explicit-target own-app UI/log probe; ADB input is synthetic, not physical.

Run UIAutomator actions only after native testWidgets suites have finished.
Even read-only UI dumps request platform accessibility semantics and can alter
the framework's outstanding-handle accounting during a live test. For in-test
diagnostics use the separate own-PID log action, without a UI dump.
"""
import argparse
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--action', choices=['inspect', 'tap', 'key', 'text', 'screenshot', 'log', 'restart'], required=True)
parser.add_argument('--label')
parser.add_argument('--value')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
assert args.device == '0062112V2210F9B3', 'This probe is scoped to the confirmed Realme'
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', args.device]
package = 'com.example.kasir_app.integration'

def call(*command):
    return subprocess.run(base + list(command), capture_output=True, check=True, timeout=40).stdout

assert call('get-state').decode().strip() == 'device'
if args.action == 'restart':
    launcher = call('shell', 'cmd', 'package', 'resolve-activity', '--brief', package).decode().strip().splitlines()[-1]
    assert launcher == package + '/com.example.kasir_app.IntegrationActivity'
    call('shell', 'am', 'force-stop', package)
    print(call('shell', 'am', 'start', '-W', '-n', launcher).decode())
    raise SystemExit(0)
if args.action == 'log':
    pid = call('shell', 'pidof', package).decode().strip()
    assert pid.isdigit() and args.output
    data = call('logcat', '-d', '--pid=' + pid, '-v', 'threadtime').decode('utf-8', 'replace')
    data = re.sub(r'(https?://(?:127\.0\.0\.1|localhost):\d+/)[^\s/]+/', r'\1[REDACTED_VM_AUTH]/', data)
    args.output.write_text('package=' + package + ' pid=' + pid + '\n' + data, encoding='utf-8')
    print('Own-PID log saved', pid)
    raise SystemExit(0)
raw = call('exec-out', 'uiautomator', 'dump', '/dev/tty').decode('utf-8', 'replace')
root = ET.fromstring(raw[raw.index('<?xml'):raw.index('</hierarchy>') + len('</hierarchy>')])
nodes = [node for node in root.iter('node') if node.get('package') == package]
assert nodes, 'Own test UI not visible; no input/screenshot'
window = call('shell', 'dumpsys', 'window').decode('utf-8', 'replace')
assert any(package in line for line in window.splitlines() if 'mCurrentFocus=' in line), 'Own test activity not focused'
labels = [(node.get('text', '') + ' ' + node.get('content-desc', '')).strip() for node in nodes]
ime = call('shell', 'dumpsys', 'input_method').decode('utf-8', 'replace')
shown = re.findall(r'\bmInputShown=(true|false)', ime)
ime_shown = shown[0] == 'true' if len(shown) == 1 else None
if args.action == 'inspect':
    sensitive_screen = any(re.search(r'\bPIN\b|recovery|pemulihan', label, re.I) for label in labels)
    safe = []
    for node, label in zip(nodes, labels):
        if node.get('password') == 'true' or (sensitive_screen and node.get('class') == 'android.widget.EditText'):
            label = '[REDACTED CREDENTIAL FIELD]'
        elif sensitive_screen and re.search(r'\b[a-fA-F0-9]{32}\b|^\d{4,8}$', label):
            label = '[REDACTED FIXTURE CREDENTIAL]'
        safe.append({'label': label, 'bounds': node.get('bounds'), 'class': node.get('class'),
                     'clickable': node.get('clickable'), 'focused': node.get('focused')})
    result = {'package': package, 'system_input_shown': ime_shown, 'nodes': safe}
    if args.output:
        args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result))
elif args.action == 'screenshot':
    assert args.output and ime_shown is False, 'IME shown/unknown; no screenshot of predictions'
    assert not any(re.search(r'\bPIN\b|recovery|pemulihan', label, re.I) for label in labels), 'Credential screen; no screenshot'
    visible = {node.get('package') for node in root.iter('node') if node.get('package')}
    assert visible <= {package, 'android', 'com.android.systemui'}, 'Other app visible; no screenshot'
    args.output.write_bytes(call('exec-out', 'screencap', '-p'))
    print('Own synthetic-app screenshot saved')
elif args.action == 'tap':
    assert args.label
    targets = [node for node, label in zip(nodes, labels) if label == args.label]
    assert len(targets) == 1, 'Target must match one observed own-app label exactly'
    bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', targets[0].get('bounds', ''))
    assert bounds
    x1, y1, x2, y2 = map(int, bounds.groups())
    assert x2 > x1 and y2 > y1
    call('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
    print('Tapped observed synthetic-app node')
elif args.action == 'text':
    assert args.value is not None
    assert any(node.get('class') == 'android.widget.EditText' and node.get('focused') == 'true' for node in nodes), 'No own focused editable field'
    call('shell', 'input', 'text', args.value.replace(' ', '%s'))
    print('ADB synthetic text entered; value not logged')
elif args.action == 'key':
    assert args.value in ['KEYCODE_ENTER', 'KEYCODE_BACK', 'KEYCODE_TAB', 'KEYCODE_HOME']
    call('shell', 'input', 'keyboard', 'keyevent', args.value)
    print('ADB synthetic key sent', args.value)
