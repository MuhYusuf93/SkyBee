"""Run only after writers stop; remove transient loopback VM auth, not failures."""
from pathlib import Path
import hashlib
import json
import re

folder = Path(__file__).resolve().parent
ledger = []
for path in sorted(folder.rglob('*.log')):
    before = path.read_bytes()
    encoding = 'utf-16' if before.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig' if before.startswith(b'\xef\xbb\xbf') else 'utf-8'
    decoded = before.decode(encoding)
    cleaned, count = re.subn(r'((?:https?|ws)://(?:127\.0\.0\.1|localhost):\d+/)(?!\[REDACTED_VM_AUTH\])[^\s/]+/', r'\1[REDACTED_VM_AUTH]/', decoded)
    if not count:
        continue
    after = cleaned.encode(encoding)
    path.write_bytes(after)
    ledger.append({'path':path.relative_to(folder).as_posix(), 'encoding':encoding,
                   'matches':count,'before_sha256':hashlib.sha256(before).hexdigest(),
                   'after_sha256':hashlib.sha256(after).hexdigest()})
# Append history, so a later physical-manual follow-up cannot erase this ledger.
target = folder/'vm-auth-redaction-ledger.json'
existing = json.loads(target.read_text()) if target.exists() else []
target.write_text(json.dumps(existing+ledger,indent=2)+'\n',encoding='utf-8')
print(f'Redacted transient VM auth in {len(ledger)} closed log files; encoding retained.')
