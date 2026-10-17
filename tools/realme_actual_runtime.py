"""Actual app startup/memory probe: explicit test package, no settings changes.

Activity TotalTime is distinct from the slower UIAutomator observation bound.
All input is synthetic and must never be reported as physical manual input.
"""
import argparse
import datetime
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--mode', choices=['profile', 'release'], required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
assert args.device == '0062112V2210F9B3'
package = 'com.example.kasir_app.integration'
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', args.device]
launcher = package + '/com.example.kasir_app.IntegrationActivity'
args.output.mkdir(parents=True, exist_ok=True)
source_root = Path(__file__).resolve().parents[1]
catalogs = [json.loads((source_root / f'lib/l10n/app_{lang}.arb').read_text(encoding='utf-8')) for lang in ['id','en']]
result = {'device': args.device, 'mode': args.mode, 'package': package,
          'time': datetime.datetime.now().astimezone().isoformat(),
          'launches': [], 'memory': [], 'details': [], 'failures': [], 'physical_input': False,
          'method': 'actual KasirApp; am start -W + UIAutomator observation; no profiler/recording/forced GC'}

def call(*cmd, check=True):
    return subprocess.run(base + list(cmd), capture_output=True, check=check, timeout=45).stdout.decode('utf-8', 'replace')

def save():
    (args.output / f'actual-{args.mode}.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')

def pid():
    value = call('shell', 'pidof', package, check=False).strip()
    assert value.isdigit(), 'Own PID absent'
    return value

def nodes():
    focus = call('shell', 'dumpsys', 'window')
    assert any(package in s for s in focus.splitlines() if 'mCurrentFocus=' in s), 'Own activity not focused'
    raw = call('exec-out', 'uiautomator', 'dump', '/dev/tty')
    tree = ET.fromstring(raw[raw.index('<?xml'):raw.index('</hierarchy>')+len('</hierarchy>')])
    return [n for n in tree.iter('node') if n.get('package') == package]

def label(node):
    return (node.get('text','')+' '+node.get('content-desc','')).strip()

def wait_ui():
    deadline = time.monotonic()+60
    while time.monotonic()<deadline:
        current = nodes()
        labels = [label(n) for n in current]
        if any(re.search(r'Bayar|Pay|Belanja berikutnya|Next basket', s) for s in labels):
            return current
        time.sleep(1)
    raise TimeoutError('Actual cashier/receipt not observed within bound')

def tap(choices):
    current = nodes()
    matches = [n for n in current if label(n) in choices]
    assert len(matches)==1, 'Observed target not unique: '+str(choices)
    coords = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', matches[0].get('bounds',''))
    assert coords
    x1,y1,x2,y2=map(int,coords.groups())
    call('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    time.sleep(.5)

def memory(tag):
    process = pid()
    raw = call('shell','dumpsys','meminfo',process)
    path = args.output / f'memory-actual-{args.mode}-{tag}.log'
    path.write_text(raw, encoding='utf-8')
    row={'tag':tag,'pid':process,'log':path.name}
    for field,pattern in [('pss_kib',r'TOTAL PSS:\s*(\d+)'),('rss_kib',r'TOTAL RSS:\s*(\d+)'),('swap_pss_kib',r'TOTAL SWAP PSS:\s*(\d+)')]:
        match=re.search(pattern,raw)
        row[field]=int(match[1]) if match else None
    result['memory'].append(row)
    save()

try:
    assert call('get-state').strip()=='device'
    assert call('shell','cmd','package','resolve-activity','--brief',package).strip().splitlines()[-1]==launcher
    for kind in ['cold']*3+['warm']*3:
        before=call('shell','pidof',package,check=False).strip()
        if kind=='cold':
            call('shell','am','force-stop',package)
        else:
            nodes() # own focus guard before Home
            call('shell','input','keyevent','KEYCODE_HOME')
            time.sleep(1)
        timer=time.monotonic()
        activity=call('shell','am','start','-W','-n',launcher)
        wait_ui()
        current=pid()
        sample={'kind':kind,'pid':current,'previous_pid':before,'am_start':activity.strip(),
                'ui_observation_bound_seconds':time.monotonic()-timer,
                'actual_kind':'cold_after_background_process_change' if kind=='warm' and before!=current else kind}
        result['launches'].append(sample)
        save()
        print('Actual',args.mode,kind,current,flush=True)
    current=wait_ui()
    if any(label(n) in ['Next basket','Belanja berikutnya'] for n in current):
        tap(['Next basket','Belanja berikutnya'])
    memory('cashier-initial')
    tap(['Kelola','Manage'])
    time.sleep(.5)
    fields=[n for n in nodes() if n.get('class')=='android.widget.EditText']
    assert len(fields)==1, 'Expected one own PIN field'
    coords=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', fields[0].get('bounds',''))
    assert coords
    x1,y1,x2,y2=map(int,coords.groups())
    call('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    call('shell','input','text','0001') # public, synthetic fixture only; never printed
    call('shell','input','keyevent','KEYCODE_BACK') # hide IME
    # Submit label is read from the actual UI, not coordinate guessed.
    tap(['Buka pengelolaan','Open management'])
    time.sleep(5)
    for cycle in range(1,4):
        for route in [('Gudang','Inventory'),('Riwayat penjualan','Sale history'),('Laporan','Reports')]:
            tap(list(route))
            time.sleep(1)
            # Only list views; no edits, corrections, credentials or payments.
            observed = nodes()
            expected_name = ('Realme C11 fixture goods' if route[1]=='Inventory' else
                             'Synthetic Realme C11 customer' if route[1]=='Sale history' else None)
            if expected_name:
                rows = [n for n in observed if n.get('clickable')=='true' and expected_name in label(n)]
                detail = {'cycle':cycle,'route':route[1],'observed_unique_row':len(rows)==1}
                if len(rows)==1:
                    tap([label(rows[0])])
                    time.sleep(1)
                    captions = [c['m31BaseStock' if route[1]=='Inventory' else 'm3CostSnapshot']+':' for c in catalogs]
                    assert any(label(n).startswith(caption) for n in nodes() for caption in captions), 'Detail content not observed'
                    call('shell','input','keyevent','KEYCODE_BACK')
                    time.sleep(.5)
                    detail['opened_and_returned']=True
                result['details'].append(detail)
            call('shell','input','keyevent','KEYCODE_BACK')
            time.sleep(.5)
        memory(f'cycle-{cycle}-management')
    nodes()
    call('shell','input','keyevent','KEYCODE_HOME')
    time.sleep(1)
    call('shell','am','start','-W','-n',launcher)
    locked_captions = [c['managementLocked'] for c in catalogs]
    deadline = time.monotonic()+20
    while time.monotonic()<deadline:
        if any(label(n) in locked_captions for n in nodes()):
            result['android_home_relock_observed'] = True
            break
        time.sleep(.5)
    assert result.get('android_home_relock_observed'), 'Protected route did not visibly relock after Android Home'
    call('shell','input','keyevent','KEYCODE_BACK')
    wait_ui()
    memory('cashier-after-cycles')
    output=call('logcat','-d','--pid='+pid(),'-v','threadtime')
    output=re.sub(r'((?:https?|ws)://(?:127\.0\.0\.1|localhost):\d+/)[^\s/]+/',r'\1[REDACTED_VM_AUTH]/',output)
    (args.output / f'pid-actual-{args.mode}.log').write_text(output,encoding='utf-8')
    result['completed']=True
except Exception as error:
    result['failures'].append({'type':type(error).__name__,'message':str(error),'status':'UNVERIFIED_CAUSE'})
    result['completed']=False
    raise
finally:
    save()
