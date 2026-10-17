"""Count diagnostic markers in own-PID snapshots; not a clean-session claim."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parent
patterns = ['FATAL EXCEPTION','Fatal signal','Unhandled Exception','E/flutter','ANR in','OutOfMemoryError']
result = {'scope':'partial own-PID snapshots, expected SQL injection/capability warnings reviewed separately', 'files':{}}
for path in sorted(root.glob('pid-*.log')):
    raw = path.read_bytes()
    data = raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')
    result['files'][path.name] = {p:len(re.findall(re.escape(p),data)) for p in patterns}
(root/'scoped-log-review.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
