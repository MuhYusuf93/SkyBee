"""Generate public synthetic PBKDF2 vectors independently of Dart/Android."""
import hashlib
import json
from pathlib import Path

vectors = [
    ('pin:0001', list(range(32))),
    ('recovery:' + 'A' * 32, list(reversed(range(32)))),
    ('pin:00é1', list(range(128, 160))),
]
data = [{'label': f'vector-{i + 1}', 'input': value, 'salt': salt,
         'sha256_pbkdf2_600000_256': hashlib.pbkdf2_hmac('sha256', value.encode('utf-8'), bytes(salt), 600000, 32).hex()}
        for i, (value, salt) in enumerate(vectors)]
path = Path(__file__).resolve().parent / 'synthetic-pin-vectors.json'
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print('Generated three independent synthetic vectors; not user credentials')
