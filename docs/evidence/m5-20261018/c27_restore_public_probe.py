"""Close the PUBLIC preview interval only after its manual result is recorded."""
import json,re
from pathlib import Path
from c27_public_probe_control import root,context,package,prior,bridge,expected,command,hashes,install,digest,sync
report=root/'docs/evidence/m5-20261018/c27-public-preview-user-report.json'
assert report.exists(),'Public-only manual report must be saved before closing this interval.'
c=json.loads(context.read_text(encoding='utf-8-sig'));e=Path(c['ledger']).parent
ledger=json.loads((e/'ledger.json').read_text(encoding='utf-8-sig'))
assert ledger['state']=='Public probe ready; waiting for explicit user tap and panel report'
assert c['automaticDeviceControlActive'] is False
assert digest(prior)==expected
ledger['automaticDeviceControlActive']=True;ledger['state']='Closing public-only probe; no clipboard read'
(e/'ledger.json').write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8');sync(e,ledger['state'],True)
# Only the probe's own PID and its boolean-only marker; never a recovery UI dump.
pid=command('shell','pidof',package)
if re.fullmatch(r'[0-9]+',pid):
 text=command('logcat','-d','--pid='+pid,'-s','flutter:I','*:S')
 records=[]
 for line in text.splitlines():
  if 'M5_PUBLIC_CLIPBOARD_METADATA ' in line:
   flags=json.loads(line.split('M5_PUBLIC_CLIPBOARD_METADATA ',1)[1])
   assert set(flags)=={'ownLabel','sensitive','plainTextMime'} and all(type(v) is bool for v in flags.values())
   records.append(flags)
 (e/'metadata-only.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
install(bridge,e/'closing-bridge-install.log')
after=hashes();(e/'raw-after.json').write_text(json.dumps(after,indent=2)+'\n',encoding='utf-8')
before=json.loads((e/'raw-before.json').read_text(encoding='utf-8-sig'))
ledger['rawFilesEqual']=after==before
# Restore C27 even on a hash mismatch; never repair/delete/reset data here.
install(prior,e/'c27-restored.log')
installed=command('shell','pm','path',package)
assert re.fullmatch(r'package:/data/app/[^\r\n]+/base.apk',installed)
command('pull',installed[len('package:'):],str(e/'installed-restored.apk'))
assert digest(e/'installed-restored.apk')==expected
ledger['priorC27RestoredExact']=True
ledger['automaticDeviceControlActive']=False
ledger['state']='C27 restored; raw hashes equal' if after==before else 'C27 restored; raw hash mismatch UNRESOLVED'
(e/'ledger.json').write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8');sync(e,ledger['state'],False)
assert after==before,'Preserve mismatch evidence; no DB reset or repair allowed.'
print('C27 exact APK restored; 12 DB/sidecar endpoint hashes equal; no clipboard payload read.')
