"""Hash-only scope inventory against the captured M5 baseline, not a Git diff."""
from pathlib import Path
import ast
import hashlib
import json

root = Path(__file__).resolve().parents[3]
baseline = json.loads((Path(__file__).parent / 'source-baseline.json').read_text(encoding='utf-8'))
changed, missing, unchanged = {}, [], []
for name, previous in baseline.items():
    path = root / name
    if not path.is_file():
        missing.append(name)
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != previous:
        changed[name] = {'before': previous, 'after': digest}
    else:
        unchanged.append(name)
new = {}
for folder in ('lib', 'test', 'integration_test', 'packages/kasir_platform', 'assets/third_party', 'tools', 'android/app/src'):
    for path in (root / folder).rglob('*'):
        if not path.is_file() or any(part in ('build', '.dart_tool', '__pycache__', '.cxx') for part in path.parts):
            continue
        name = path.relative_to(root).as_posix()
        if name not in baseline:
            new[name] = hashlib.sha256(path.read_bytes()).hexdigest()
python_sources = list((root / 'tools').glob('*.py'))
for path in python_sources:
    ast.parse(path.read_text(encoding='utf-8-sig'), filename=path.name)
result = {'kind': 'hash inventory only; no complete pre-Realme Git history', 'baseline_files': len(baseline), 'unchanged': unchanged, 'changed': changed, 'missing': missing, 'new_scoped_files': new, 'python_tools_ast_pass': len(python_sources)}
(Path(__file__).parent / 'source-delta.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'baseline': len(baseline), 'unchanged': len(unchanged), 'changed': len(changed), 'missing': missing, 'new_scoped': len(new), 'python_ast_pass': len(python_sources)}))
