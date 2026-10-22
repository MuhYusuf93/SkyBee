"""Accept only the visible PYN-58L USB permission for the isolated test app.

No root/pregrant/default checkbox or guessed remote key sequence. This runs
alongside the authorized one-shot public print and never presses print itself.
"""
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

adb = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe',
       '-s', '192.168.0.102:5555']


def call(*args, timeout=8):
    return subprocess.run(adb + list(args), capture_output=True, timeout=timeout)


assert call('shell', 'getprop', 'ro.product.model').stdout.strip() == b'AX810'
deadline = time.monotonic() + 300
while time.monotonic() < deadline:
    # API30 TV places mCurrentFocus in DisplayContent, not the windows-only dump.
    window = call('shell', 'dumpsys', '-t', '2', 'window', 'displays').stdout.decode('utf-8', 'replace')
    focus = next((line for line in window.splitlines() if 'mCurrentFocus=' in line), '')
    if 'UsbPermissionActivity' not in focus:
        time.sleep(1)
        continue
    capture = call('shell', 'uiautomator', 'dump', '/dev/tty', timeout=12)
    if capture.returncode != 0:
        print(json.dumps({'status': 'BLOCKED_UIAUTOMATOR', 'exit': capture.returncode,
                          'input': 0}), flush=True)
        raise SystemExit(2)
    dump = capture.stdout.decode('utf-8', 'replace')
    if '<hierarchy' not in dump:
        time.sleep(.2)
        continue
    xml = dump[dump.index('<hierarchy'):]
    xml = xml[:xml.index('</hierarchy>') + len('</hierarchy>')]
    tree = ET.fromstring(xml)
    texts = ' '.join(node.get('text', '') for node in tree.iter('node'))
    assert 'kasir_app tests' in texts and 'PYN-58L' in texts, 'Unexpected USB prompt; no input'
    positive = [node for node in tree.iter('node') if node.get('resource-id') == 'android:id/button1'
                and node.get('enabled') == 'true' and node.get('clickable') == 'true']
    assert len(positive) == 1, 'No unambiguous positive permission control'
    match = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', positive[0].get('bounds', ''))
    assert match
    left, top, right, bottom = map(int, match.groups())
    result = call('shell', 'input', 'tap', str((left + right)//2), str((top + bottom)//2))
    assert result.returncode == 0
    print(json.dumps({'status': 'OWN_USB_PERMISSION_POSITIVE_PRESSED_ONCE',
                      'target': 'PYN-58L', 'persistentCheckboxChanged': False}), flush=True)
    break
else:
    print(json.dumps({'status': 'NO_MATCHING_USB_DIALOG_OBSERVED', 'input': 0}), flush=True)
