"""Normalize the completed PowerShell ledger; never run while its writer runs."""
from pathlib import Path
import json

path = Path(__file__).resolve().parent / 'functional-run-results.json'
data = json.loads(path.read_text(encoding='utf-8-sig'))
rows = []
def visit(value):
    if isinstance(value, list):
        for item in value:
            visit(item)
    elif isinstance(value, dict) and 'suite' in value:
        rows.append(value)
    elif isinstance(value, dict) and 'value' in value:
        visit(value['value'])
    else:
        raise ValueError('Unexpected ledger shape')
visit(data)
path.write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
print('Normalized completed ledger:', len(rows), 'records; original per-suite logs retained')
