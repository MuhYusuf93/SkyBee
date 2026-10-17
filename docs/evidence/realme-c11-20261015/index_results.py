"""Index only observed test results; keeps partial/failed runs distinct."""
from pathlib import Path
import ast
import hashlib
import json
import re

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
index = {}
for log in sorted(evidence.rglob('*.log')):
    raw = log.read_bytes()
    encoding = 'utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
    data = raw.decode(encoding, errors='replace')
    # Redact only transient loopback VM auth URLs. Keep ports/timestamps/errors.
    sanitized = re.sub(r'((?:https?|ws)://(?:127\.0\.0\.1|localhost):\d+/)[^\s/]+/', r'\1[REDACTED_VM_AUTH]/', data)
    # Indexing must never rewrite a log while the native queue is appending.
    # Final redaction is a separate step after all writers have stopped.
    finals = re.findall(r'(\d+:\d+) \+(\d+)(?: ~([0-9]+))?: All tests passed!', sanitized)
    counts = re.findall(r'\d+:\d+ \+(\d+)', sanitized)
    entry = {
        'exit_markers': re.findall(r'(?:Flutter|Runner)Exit=-?\d+', sanitized),
        'source_encoding': encoding,
        'all_passed_reporter': bool(finals),
        'passed_count': int(finals[-1][1]) if finals else None,
        'skipped_count': int(finals[-1][2] or 0) if finals else None,
        'elapsed_reporter': finals[-1][0] if finals else None,
        'last_reported_pass_count': int(counts[-1]) if counts else None,
        'failure_marker': 'Some tests failed.' in sanitized or 'Test failed.' in sanitized,
        'test_events': re.findall(r'^\d+:\d+ \+\d+(?: -\d+)?(?: ~\d+)?: (.+)$', sanitized, re.M),
    }
    index[log.relative_to(evidence).as_posix()] = entry
(evidence / 'suite-evidence-index.json').write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')

baseline = json.loads((evidence / 'source-baseline.json').read_text(encoding='utf-8-sig'))
changed = []
for row in baseline:
    target = root / row['path']
    if not target.exists() or hashlib.sha256(target.read_bytes()).hexdigest() != row['sha256']:
        changed.append(row['path'])
syntax = []
for path in sorted((root / 'tools').glob('*.py')):
    ast.parse(path.read_text(encoding='utf-8-sig'), filename=str(path))
    syntax.append(path.relative_to(root).as_posix())
(evidence / 'source-check.json').write_text(json.dumps({
    'baseline_files': len(baseline), 'changed_existing': changed,
    'python_ast_pass': syntax,
}, indent=2) + '\n', encoding='utf-8')
native = {}
expected = {
    'database_test', 'management_inventory_test', 'cashier_sql_test',
    'wholesale_packaging_sql_test', 'reports_corrections_sql_test',
    'm4_storage_test', 'locale_currency_test', 'protected_reads_test',
    'bugfix_regression_test', 'management_ui_test', 'cashier_ui_test',
    'localization_ui_test', 'wholesale_packaging_ui_test',
    'm31_ui_gaps_test', 'm4_ui_test', 'realme_acceptance_test',
    'realme_value_input_test',
}
for name, row in index.items():
    match = re.fullmatch(r'native-(.+?)(?:-attempt\d+)?\.log', name)
    if match and match[1] in expected and row['all_passed_reporter']:
        native[match[1]] = row['passed_count']  # Never add retries/experiments.
post = {}
for name, row in index.items():
    match = re.fullmatch(r'post-pin-realme/(.+?)(?:-attempt\d+)?\.log', name)
    if match and match[1] in expected and row['all_passed_reporter']:
        post['post-pin-realme/'+match[1]+'.log'] = row['passed_count']
dv = {name: row['passed_count'] for name, row in index.items()
      if name.startswith('post-pin-dv/') and row['all_passed_reporter']}
totals = {'pre_pin_realme_core': native, 'pre_pin_realme_core_count': sum(native.values()),
          'post_pin_realme_core': post, 'post_pin_realme_core_count': sum(post.values()),
          'post_pin_realme_core_expected_suites': len(expected), 'post_pin_dv': dv,
          'post_pin_dv_count': sum(dv.values()),
          'final_crypto_contract': index.get('native-pin-mbedtls-attempt3.log'),
          'pre_manual_integrity': index.get('native-realme_integrity-pre-manual.log'),
          'after_cycles_integrity': index.get('native-realme_integrity-after-cycles.log'),
          'final_integrity': index.get('native-realme_manual_integrity_test.log')}
integrity = totals['final_integrity'] or totals['after_cycles_integrity'] or totals['pre_manual_integrity'] or {}
crypto = totals['final_crypto_contract'] or {}
totals['post_pin_realme_unique_functional_count'] = (
    sum(post.values()) + (crypto['passed_count'] if crypto.get('all_passed_reporter') else 0)
    + (integrity['passed_count'] if integrity.get('all_passed_reporter') else 0))
(evidence / 'functional-totals.json').write_text(json.dumps(totals, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'completed_native_suites': native, 'observed_native_pass_count': sum(native.values()),
                  'post_pin_realme_count':sum(post.values()), 'post_pin_dv_count':sum(dv.values()),
                  'changed_existing_sources': changed, 'python_ast_files': len(syntax)}, indent=2))
