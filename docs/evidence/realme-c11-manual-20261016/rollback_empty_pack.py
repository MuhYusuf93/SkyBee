"""Withdraw only the 16 October empty-pack proposal, leaving earlier fixes."""
from pathlib import Path

root = Path(__file__).resolve().parents[3]
target = root/'test/support/m31_ui_gaps_suite.dart'
s = target.read_text(encoding='utf-8')
for path in ['product_detail_screen.dart','stock_input_fields.dart']:
    line = "import 'package:kasir_app/features/inventory/presentation/"+path+"';\n"
    assert s.count(line) == 1
    s = s.replace(line,'')
line = "import 'package:kasir_app/features/inventory/domain/stock_input.dart';\n"
assert s.count(line) == 1
s = s.replace(line,'')
start = s.index('\n  Future<void> choosePack(WidgetTester tester) async {')
end = s.index('  for (final above in [true, false]) {', start)
withdrawn = s[start:end]
assert 'initial stock never copies the master pack size' in withdrawn
assert 'requires manual pack size and preserves stored data' in withdrawn
s = s[:start]+s[end:]
target.write_text(s,encoding='utf-8')

target = root/'docs/SPEC.md'
s = target.read_text(encoding='utf-8')
lines = s.splitlines(keepends=True)
matches = [i for i,v in enumerate(lines) if v.startswith('Keputusan pengguna16Oktober2026: pada setiap form baru stok awal,')]
assert len(matches) == 1
lines[matches[0]] = 'Isi per dus mengambil default dari konfigurasi produk jika tersedia, tetapi boleh dikoreksi untuk penerimaan tersebut. Koreksi penerimaan tidak otomatis mengubah konfigurasi produk.\n'
target.write_text(''.join(lines),encoding='utf-8')

target = root/'docs/M31-NOTES.md'
s = target.read_text(encoding='utf-8')
lines = s.splitlines(keepends=True)
matches = [i for i,v in enumerate(lines) if v.startswith('Keputusan16Oktober2026: isi pcs per dus/box pada form')]
assert len(matches) == 1
i = matches[0]
assert lines[i+1].strip() == ''
del lines[i:i+2]
target.write_text(''.join(lines),encoding='utf-8')
print('Removed withdrawn-only regression cases/imports and restored original SPEC/M31 notes. No device commands.')
