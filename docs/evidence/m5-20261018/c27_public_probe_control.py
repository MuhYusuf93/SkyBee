import hashlib,json,re,subprocess,sys,time
from pathlib import Path
root=Path(__file__).resolve().parents[3]
adb=Path(r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe')
python=Path(sys.executable)
serial='7f0edea0';package='com.example.kasir_app.integration'
prior=root/'build/m5-acceptance-20261018-153754/kasir-app-0.5.0-m5-isolated-release.apk'
bridge=root/'build/m5-acceptance-20261018-153754/kasir-app-0.5.0-m5-restore-bridge-debug.apk'
expected='0ec0734a306d177ecd329d74274ed3938bef7debcdfa4bd7d05fd017d3a6e3e1'
context=root/'docs/evidence/m5-20261018/c27-preview-context.json'
folders=['poco-manual-20261016-191759','poco-manual-update-1792156485701','poco-permission-update-1792174330020','poco-export-update-1792178476161','poco-archive-update-1792181574653','poco-notification-update-1792195919961','poco-google-cancel-update-1792226124001','poco-drive-config-update-1792309347903','poco-recovery-copy-update-1792312363867']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def command(*args):
 r=subprocess.run([str(adb),'-s',serial,*args],capture_output=True,text=True,encoding='utf-8',errors='replace')
 if r.returncode:raise RuntimeError('Scoped ADB command failed: '+repr(args[:4]))
 return r.stdout.strip()
def hashes():
 rows={}
 for pkg,names in [(package,['kasir_app.db','m5_acceptance_1792150309449.db']),('com.example.kasir_app',['kasir_app.db'])]:
  for name in names:
   for suffix in ['', '-wal','-shm','-journal']:
    path='databases/'+name+suffix
    r=subprocess.run([str(adb),'-s',serial,'shell','run-as',pkg,'test','-f',path],capture_output=True)
    if r.returncode==1:rows[pkg+'/'+path]='ABSENT';continue
    if r.returncode:raise RuntimeError('Raw file access unavailable; no DB open fallback.')
    value=command('shell','run-as',pkg,'sha256sum',path).split()[0]
    assert re.fullmatch('[a-f0-9]{64}',value)
    rows[pkg+'/'+path]=value
 return rows
def install(path,log):
 text=command('install','-r','-d',str(path)); log.write_text(text+'\n',encoding='utf-8')
 assert 'Success' in text

def sync(e,state,active):
 for folder in folders:
  p=root/'docs/evidence/m5-20261016'/folder/'handover.json'
  d=json.loads(p.read_text(encoding='utf-8-sig'));d['automaticDeviceControlActive']=active
  d['temporaryClipboardProbe']={'state':state,'ledger':str(e/'ledger.json'),'noDatabaseOpen':True,'priorC27RestorePending':state!='C27 restored; raw hashes equal'}
  d['manualStep']='Public-only clipboard preview probe; do not open normal recovery/Drive menus until exact C27 restored.' if state!='C27 restored; raw hashes equal' else 'C27 restored; wait for instructions before real recovery validation/Drive restore.'
  p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 context.write_text(json.dumps({'ledger':str(e/'ledger.json'),'state':state,'automaticDeviceControlActive':active},indent=2)+'\n',encoding='utf-8')

def start():
 assert not context.exists(),'Existing probe context; do not replay.'
 assert command('get-state')=='device'
 assert command('shell','getprop','ro.product.model')=='24069PC21G'
 assert digest(prior)==expected
 e=root/'docs/evidence/m5-20261018'/('c27-public-preview-'+str(time.time_ns()//1000000));e.mkdir()
 installed=command('shell','pm','path',package)
 assert re.fullmatch(r'package:/data/app/[^\r\n]+/base.apk',installed)
 command('pull',installed[len('package:'):],str(e/'installed-before.apk'))
 assert digest(e/'installed-before.apk')==expected,'Installed C27 differs; no replacement.'
 probe=e/'public-preview-release.apk'
 import shutil
 shutil.copy2(root/'build/app/outputs/flutter-apk/app-release.apk',probe)
 for name,path in [('probe',probe),('bridge',bridge)]:
  subprocess.run([str(python),str(root/'tools/verify_m5_apk.py'),'--apk',str(path),'--kind','fixture','--abis','arm64-v8a' if name=='probe' else 'armeabi-v7a,arm64-v8a,x86_64','--output',str(e/(name+'-verified.json'))],check=True,capture_output=True)
 certs=[]
 signer=root/'../..' # no shell/path interpolation; existing SDK verifier only
 sdk=adb.parents[1]
 for path in [prior,bridge,probe]:
  r=subprocess.run([str(sdk/'build-tools/36.0.0/apksigner.bat'),'verify','--print-certs',str(path)],capture_output=True,text=True,check=True)
  certs.append(re.search(r'Signer #1 certificate SHA-256 digest: ([a-f0-9]+)',r.stdout).group(1))
 assert len(set(certs))==1
 ledger={'state':'starting','automaticDeviceControlActive':True,'noDatabaseOpen':True,'prior':str(prior),'priorSha256':expected,'bridge':str(bridge),'probe':str(probe),'probeSha256':digest(probe),'recoveryOrClipboardPayloadRead':False,'publicCopyRequiresUserTap':True}
 def save(): (e/'ledger.json').write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8')
 save();sync(e,'starting',True)
 bridgeInstalled=False
 try:
  command('shell','am','force-stop','com.example.kasir_app')
  install(bridge,e/'bridge-install.log');bridgeInstalled=True
  before=hashes()
  assert before[package+'/databases/m5_acceptance_1792150309449.db']!='ABSENT'
  (e/'raw-before.json').write_text(json.dumps(before,indent=2)+'\n',encoding='utf-8')
  install(probe,e/'probe-install.log')
  (e/'start.log').write_text(command('shell','am','start','-W','-f','0x10008000','-n',package+'/com.example.kasir_app.IntegrationActivity')+'\n',encoding='utf-8')
  ledger['state']='Public probe ready; waiting for explicit user tap and panel report'
  ledger['automaticDeviceControlActive']=False
  save();sync(e,ledger['state'],False)
  print('PUBLIC PROBE READY: '+str(e))
 except Exception:
  if bridgeInstalled:
   install(bridge,e/'error-bridge.log')
   if (e/'raw-before.json').exists():
    after=hashes();(e/'error-raw-after.json').write_text(json.dumps(after,indent=2)+'\n',encoding='utf-8')
    ledger['errorRawEqual']=after==json.loads((e/'raw-before.json').read_text())
   install(prior,e/'error-c27-restored.log')
  ledger['state']='BLOCKED; prior C27 restoration attempted, inspect ledger'
  ledger['automaticDeviceControlActive']=False;save();sync(e,ledger['state'],False)
  raise
if __name__=='__main__':start()
