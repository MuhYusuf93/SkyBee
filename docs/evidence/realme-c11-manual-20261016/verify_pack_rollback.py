"""Compare selective rollback with the saved 15 October source fingerprint."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
baseline = json.loads((root/'docs/evidence/realme-c11-20261015/final/source-baseline.json').read_text(encoding='utf-8-sig'))
known = {row['path']:row['sha256'] for row in baseline}
restored = [
    'lib/features/inventory/presentation/stock_input_fields.dart',
    'lib/features/inventory/presentation/product_detail_screen.dart',
    'lib/features/inventory/presentation/product_form.dart',
    'test/wholesale_packaging_widgets_test.dart',
    'test/support/m31_ui_gaps_suite.dart',
    'integration_test/wholesale_packaging_ui_test.dart',
    'docs/SPEC.md',
]
protected = [
    'lib/features/management/application/pin_hasher.dart',
    'android/app/build.gradle.kts',
    'android/app/src/main/kotlin/com/example/kasir_app/MainActivity.kt',
    'integration_test/management_ui_test.dart',
]
result = {'date':'2026-10-16','method':'SHA256 against saved 15 October final source; no device access',
          'restored':{},'earlier_fixes_preserved':{}}
for name in restored+protected:
    path = root/name
    raw = path.read_bytes()
    expected = known[name]
    if name in restored and hashlib.sha256(raw).hexdigest() != expected:
        lf = raw.replace(b'\r\n',b'\n')
        for candidate in [lf,lf.replace(b'\n',b'\r\n')]:
            if hashlib.sha256(candidate).hexdigest() == expected:
                path.write_bytes(candidate) # only a byte-identical known baseline
                raw = candidate
                break
    actual = hashlib.sha256(raw).hexdigest()
    entry = {'sha256':actual,'baseline_sha256':expected,'matches':actual==expected}
    result['restored' if name in restored else 'earlier_fixes_preserved'][name] = entry
(Path(__file__).resolve().parent/'rollback-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
assert all(row['matches'] for section in ['restored','earlier_fixes_preserved'] for row in result[section].values()), result
print('PASS: 7 restored files byte-identical to pre-proposal baseline; 4 earlier-fix files preserved.')
