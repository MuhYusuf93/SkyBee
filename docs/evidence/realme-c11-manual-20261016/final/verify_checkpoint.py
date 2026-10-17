"""Verify retained checkpoint evidence after every test/log writer has stopped.

Never controls Android or opens a database. Loopback VM auth is redacted only
from completed logs; original failure details and digest history are retained.
"""
import ast
import datetime
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[3]


def read_log(file):
    data = file.read_bytes()
    if data.startswith(b'\xff\xfe'):
        return data[2:].decode('utf-16-le'), 'utf-16-le', b'\xff\xfe'
    if data.startswith(b'\xef\xbb\xbf'):
        return data[3:].decode('utf-8'), 'utf-8', b'\xef\xbb\xbf'
    return data.decode('utf-8'), 'utf-8', b''


redaction = []
for file in sorted(evidence.glob('*.log')):
    text, encoding, prefix = read_log(file)
    sanitized = re.sub(r'((?:https?|ws)://(?:127\.0\.0\.1|localhost):\d+/)[^\s/]+/',
                       r'\1[REDACTED_VM_AUTH]/', text)
    if sanitized != text:
        before = hashlib.sha256(file.read_bytes()).hexdigest()
        file.write_bytes(prefix + sanitized.encode(encoding))
        redaction.append({'path': file.name, 'sha256_before': before,
                          'sha256_after': hashlib.sha256(file.read_bytes()).hexdigest(),
                          'encoding_preserved': encoding})
(evidence / 'vm-auth-redaction-ledger.json').write_text(
    json.dumps(redaction, indent=2) + '\n', encoding='utf-8')


def text(name):
    return read_log(evidence / name)[0]


def load(name):
    return json.loads((evidence / name).read_text(encoding='utf-8-sig'))


for name, count in [('windows-checkout-idempotency.log', 1),
                    ('native-checkout-idempotency.log', 1),
                    ('native-cashier-ui-clean-retest.log', 2),
                    ('native-exact-ledger-final.log', 1)]:
    contents = text(name)
    assert 'All tests passed!' in contents, name
    assert re.search(r'\+' + str(count) + r': All tests passed!', contents), name
assert 'No element' in text('native-exact-ledger.log')
assert 'A SemanticsHandle was active' in text('native-cashier-ui.log')
clean_ledger = load('native-clean-retest-ledger.json')
assert len(clean_ledger) == 2 and all(item['Exit'] == 0 for item in clean_ledger)

audits = []
for name in ['native-exact-ledger-retest.log',
             'native-exact-ledger-after-regression.log',
             'native-exact-ledger-final.log']:
    row = json.loads(re.search(r'REALME_POST_MANUAL_AUDIT (\{[^\r\n]+\})', text(name))[1])
    assert row['sales'] == 2 and row['payments'] == row['allocations'] == 4
    assert row['sales_minor'] == 72000 and row['cost_micros'] == 54000000000
    assert row['payments_minor'] == 46000 and row['debt_minor'] == 26000
    assert row['stock_quantity'] == 14 and row['stock_value_micros'] == 126000000000
    assert row['manual_customer_debt_minor'] == 0 and row['draft_quantity'] == 1
    assert row['fk_clean'] and row['reconciled'] and row['quick_check'] == 'ok'
    assert not row['physical_double_submit_verified']
    assert row['financial_and_draft_sha256_before'] == row['financial_and_draft_sha256_after']
    audits.append(row)
assert len({row['financial_and_draft_sha256_after'] for row in audits}) == 1

expected_hash = '969bccdda9605a2e82d137957316f1dbb848075f314532eb479befca21f709f7'
before, after = load('runtime-before.json'), load('runtime-release-restored.json')
for state in [before, after]:
    assert state['installed_sha256'] == expected_hash
    assert not state['talkback_enabled'] and state['font_scale']['stdout'] == '1.0'
    assert state['operational_package']['exit'] == 1
    assert state['operational_package']['stdout'] == ''
assert load('release-apk-verification.json')['sha256'] == expected_hash
restore = load('restore-release.json')
assert restore['InstallExit'] == restore['LaunchExit'] == 0
ui = load('ui-release-restored.json')
labels = [node['label'] for node in ui['nodes']]
assert any('Realme C11 fixture goods' in label and '× 1' in label for label in labels)
assert 'IDR 12.000' in labels and 'Bayar' in labels

baseline = json.loads((root / 'docs/evidence/realme-c11-20261015/final/source-baseline.json')
                      .read_text(encoding='utf-8'))
checked = []
for entry in baseline:
    name = entry['path']
    if name.startswith(('lib/', 'android/app/src/')) or name in (
            'android/app/build.gradle.kts', 'pubspec.yaml', 'pubspec.lock', 'docs/SPEC.md'):
        assert hashlib.sha256((root / name).read_bytes()).hexdigest() == entry['sha256'], name
        checked.append(name)
for name in ['tools/realme_final_probe.py', 'tools/realme_device_probe.py']:
    ast.parse((root / name).read_text(encoding='utf-8'))
ast.parse(Path(__file__).read_text(encoding='utf-8'))

result = {'time': datetime.datetime.now().astimezone().isoformat(),
          'device': '0062112V2210F9B3', 'package': 'com.example.kasir_app.integration',
          'windows_focused_cases_passed': 1, 'native_distinct_closing_cases_passed': 4,
          'native_audit_successful_repetitions': 3, 'historical_163_cases_not_rerun_in_full': True,
          'production_files_unchanged': len(checked), 'python_ast_files': 3,
          'final_audit': audits[-1], 'release_sha256': expected_hash,
          'release_draft_smoke': True, 'talkback_enabled': False, 'font_scale': '1.0',
          'operational_package_absent_before_after': True,
          'ordinary_db_hash_claim': False, 'database_restore_claim': False,
          'pid_logs': [state['pid_log'] for state in [before, after]],
          'exit_reason_counts_before': dict(Counter(re.search(r'reason=(\d+)', line)[1]
              for line in before['exit_info'] if 'reason=' in line)),
          'exit_reason_counts_after': dict(Counter(re.search(r'reason=(\d+)', line)[1]
              for line in after['exit_info'] if 'reason=' in line)),
          'physical_double_submit': 'UNVERIFIED',
          'original_semantics_failure_cause': 'UNVERIFIED_CAUSE; probe overlap suspected',
          'initial_failures_retained': ['analyze.log', 'native-exact-ledger.log', 'native-cashier-ui.log'],
          'redacted_completed_log_files': len(redaction)}
(evidence / 'verification.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
