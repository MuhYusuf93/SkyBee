"""Scoped DV8910 test UI/log/screenshot helper. No global log or system mutation."""
import argparse,json,re,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--action',choices=['inspect','ime-inspect','tap','text','key','screenshot','log','restart'],required=True);p.add_argument('--label');p.add_argument('--value');p.add_argument('--output');a=p.parse_args()
base=[r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe','-s','192.168.0.102:5555'];package='com.example.kasir_app.integration'
def call(*args):return subprocess.run(base+list(args),capture_output=True,check=True,timeout=35).stdout
assert call('get-state').decode().strip()=='device'
if a.action=='restart':
 launcher=call('shell','cmd','package','resolve-activity','--brief',package).decode().strip().splitlines()[-1]
 assert launcher in [package+'/com.example.kasir_app.MainActivity', package+'/com.example.kasir_app.IntegrationActivity'], 'Unexpected fixture launcher'
 call('shell','am','force-stop',package)
 print(call('shell','am','start','-W','-n',launcher).decode());raise SystemExit(0)
if a.action=='log':
 pid=call('shell','pidof',package).decode().strip();assert pid.isdigit()
 data=call('logcat','-d','--pid='+pid,'-v','threadtime');assert a.output
 Path(a.output).write_bytes(('package='+package+' pid='+pid+'\n').encode()+data);print('PID-scoped log saved',pid);raise SystemExit(0)
raw=call('exec-out','uiautomator','dump','/dev/tty').decode('utf-8',errors='replace')
root=ET.fromstring(raw[raw.index('<?xml'):raw.index('</hierarchy>')+len('</hierarchy>')])
nodes=[n for n in root.iter('node') if n.get('package')==package];assert nodes,'Test app UI not visible; no input/screenshot'
focused=call('shell','dumpsys','window').decode('utf-8',errors='replace')
focus=[l for l in focused.splitlines() if 'mCurrentFocus=' in l];assert any(package in l for l in focus),'Test package not focused; no input/screenshot'
labels=[(n.get('text','')+' '+n.get('content-desc','')+' '+n.get('hint','')+' '+n.get('hint-text','')).strip() or ('@edit' if n.get('class')=='android.widget.EditText' else '') for n in nodes]
visible={n.get('package') for n in root.iter('node') if n.get('package')}
assert visible <= {package,'android','com.android.systemui','org.liskovsoft.androidtv.rukeyboard','com.google.android.inputmethod.latin'}, 'Other visible app; no input/screenshot'
ime_dump=call('shell','dumpsys','input_method').decode('utf-8',errors='replace')
ime_matches=re.findall(r'\bmInputShown=(true|false)',ime_dump)
ime_shown=(ime_matches[0]=='true') if len(ime_matches)==1 else None
if a.action=='ime-inspect':
 # Only fixed keyboard key labels, never predictions, user text, or other apps.
 safe=[]
 for n in root.iter('node'):
  label=(n.get('text','')+' '+n.get('content-desc','')).strip()
  if n.get('package') in {'org.liskovsoft.androidtv.rukeyboard','com.google.android.inputmethod.latin'} and re.fullmatch(r'[A-Za-z0-9]|(?i:search|done|enter|go|backspace|space|shift|cancel|cari|selesai)',label):
   safe.append({'key':label,'bounds':n.get('bounds'),'focused':n.get('focused'),'selected':n.get('selected')})
 value={'test_package':package,'system_input_shown':ime_shown,'keyboard_keys_only':safe}
 if a.output:Path(a.output).write_text(json.dumps(value,indent=2),encoding='utf-8')
 print(json.dumps(value));raise SystemExit(0)
if a.action=='inspect':
 safe=[{'label':label,'bounds':n.get('bounds'),'class':n.get('class'),'clickable':n.get('clickable'),'focused':n.get('focused')} for n,label in zip(nodes,labels) if (label or n.get('class')=='android.widget.EditText') and not re.search('recovery|pemulihan|PIN',label,re.I)]
 value={'package':package,'ime_nodes_in_dump':bool(visible & {'org.liskovsoft.androidtv.rukeyboard','com.google.android.inputmethod.latin'}),'system_input_shown':ime_shown,'nodes':safe}
 if a.output:Path(a.output).write_text(json.dumps(value,indent=2),encoding='utf-8')
 print(json.dumps(value,ensure_ascii=True));raise SystemExit(0)
if a.action=='screenshot':
 assert a.output
 assert ime_shown is False,'IME visible/unknown; screenshot not taken'
 assert visible <= {package,'android','com.android.systemui'},'Other visible app/IME; screenshot not taken'
 assert not any(re.search('recovery|pemulihan',s,re.I) for s in labels),'Recovery screen; no screenshot'
 Path(a.output).write_bytes(call('exec-out','screencap','-p'));print('Own-app screenshot saved');raise SystemExit(0)
if a.action=='tap':
 assert a.label
 targets=[n for n,label in zip(nodes,labels) if a.label.casefold() in label.casefold()]
 assert len(targets)==1, 'UI target must be unique'
 match=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',targets[0].get('bounds',''));assert match
 x1,y1,x2,y2=map(int,match.groups());assert x2>x1 and y2>y1
 call('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));print('Tapped observed test UI target')
elif a.action=='text':
 assert a.value is not None;call('shell','input','text',a.value.replace(' ','%s'));print('ADB synthetic text entered; value not logged')
elif a.action=='key':
 assert a.value in ['66','KEYCODE_ENTER','KEYCODE_TAB','KEYCODE_BACK','KEYCODE_DPAD_DOWN','KEYCODE_DPAD_UP','KEYCODE_DPAD_CENTER'];call('shell','input','keyboard','keyevent',a.value);print('ADB synthetic key sent',a.value)
