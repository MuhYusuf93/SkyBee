"""Collect a bounded release service probe; explicit disposable package only."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--device', required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
assert a.device == '0062112V2210F9B3'
base = [r'C:\Users\ACER\AppData\Local\Android\sdk\platform-tools\adb.exe','-s',a.device]
package = 'com.example.kasir_app.integration'
launcher = package+'/com.example.kasir_app.IntegrationActivity'
def call(*cmd, check=True):
    return subprocess.run(base+list(cmd),capture_output=True,check=check,timeout=40).stdout.decode('utf-8','replace')
assert call('get-state').strip() == 'device'
assert call('shell','cmd','package','resolve-activity','--brief',package).strip().splitlines()[-1] == launcher
call('shell','am','force-stop',package)
call('shell','am','start','-W','-n',launcher)
deadline = time.monotonic()+120
while time.monotonic()<deadline:
    pid = call('shell','pidof',package,check=False).strip()
    if pid.isdigit():
        raw = call('logcat','-d','--pid='+pid,'-v','threadtime')
        matches = re.findall(r'REALME_CHECKOUT (\{[^\n]*\})',raw)
        if matches:
            result = json.loads(matches[-1])
            result.update({'device':a.device,'pid':pid,'mode':'release'})
            (a.output/'checkout-release.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
            (a.output/'pid-checkout-release.log').write_text(raw,encoding='utf-8')
            assert result['passed'] and len(result['samples_us']) == 5 and result['fixture_deleted']
            print(json.dumps(result))
            break
    time.sleep(1)
else:
    raise TimeoutError('Checkout probe did not complete; inspect own PID, do not assume crash/OS cause')
