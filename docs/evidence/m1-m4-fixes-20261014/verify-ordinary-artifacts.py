"""Verify copied ordinary artifacts without installing on a device."""
import hashlib,json,subprocess,zipfile
from pathlib import Path
base=Path('docs/evidence/m1-m4-fixes-20261014')
aapt=r'C:\Users\ACER\AppData\Local\Android\sdk\build-tools\36.0.0\aapt.exe'
out=[]
for mode in ('debug','release'):
 p=Path('build/bugfix-20261014')/f'ordinary-{mode}.apk'
 raw=subprocess.check_output([aapt,'dump','badging',str(p)],text=True,encoding='utf-8')
 metadata=[s for s in raw.splitlines() if s.startswith(('package:','application-label:','launchable-activity:'))]
 assert any(s.startswith("package: name='com.example.kasir_app' ") for s in metadata)
 assert "application-label:'kasir_app'" in metadata
 assert any("name='com.example.kasir_app.MainActivity'" in s for s in metadata)
 with zipfile.ZipFile(p) as z:
  dex=[n for n in z.namelist() if n.startswith('classes') and n.endswith('.dex')]
  assert dex and all(b'Lcom/example/kasir_app/IntegrationActivity;' not in z.read(n) for n in dex)
 out.append({'mode':mode,'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'metadata':metadata,'dex_checked':dex,'IntegrationActivity_absent':True,'installed':False})
(base/'ordinary-artifact-verification.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
for x in out: print(x['mode'],'identity/MainActivity/test-class exclusion PASS',x['bytes'],'bytes')
