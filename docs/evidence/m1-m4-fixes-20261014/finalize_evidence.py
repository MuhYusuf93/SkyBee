"""Check stored evidence; this script does not contact or mutate Android devices."""
from pathlib import Path
import ast
import hashlib
import json
import re

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
index_path = evidence / 'suite-evidence-index.json'
index = json.loads(index_path.read_text(encoding='utf-8-sig'))
for filename in ['analyze-final-6.log', 'format-final-6.log',
                 'localization-audit-final-2.log', 'powershell-parse-final.log']:
    content = (evidence / filename).read_text(encoding='utf-8-sig')
    index[filename] = {
        'exit_markers': re.findall(r'(?:Flutter|Dart|Python)Exit=\d+', content),
        'native_suites': [], 'host_aggregate_pass_count': None,
        'adb_offline': False, 'interrupted': False, 'failure_marker': False,
    }
index_path.write_text(json.dumps(index, indent=2) + '\n', encoding='utf-8')

def count(filename, suite=None):
    entry = index[filename]
    matches = [s for s in entry['native_suites'] if suite is None or s['file'] == suite]
    assert matches and all(s['all_passed'] for s in matches), filename
    return sum(s['passed_count'] for s in matches)

poco = count('poco-native-final.log') + count('poco-protected-reads.log')
dv = sum(count(f) for f in [
    'dv-pagination-retry.log', 'dv-migration-retry.log', 'dv-cashier-final.log',
    'dv-database-final.log', 'dv-locale-ui-retest.log', 'dv-wholesale-ui-final.log',
    'dv-gaps-ui-final.log', 'dv-m4-ui-final.log',
])
dv += sum(s['passed_count'] for s in index['dv-native.log']['native_suites'] if s['all_passed'])
partial = next(s for s in index['dv-native.log']['native_suites']
               if s['file'] == 'management_inventory_test.dart')
assert not partial['all_passed'] and partial['last_reported_pass_count'] == 12
dv += 12  # Completed cases only; pagination/migration are independent focused retests.
emulator = count('emulator-native-final.log', 'bugfix_regression_test.dart')
emulator += sum(count(f) for f in [
    'emulator-independent-database_test.log', 'emulator-bootstrap-management_ui_test.log',
    'emulator-bootstrap-cashier_ui_test.log', 'emulator-independent-localization_ui_test.log',
    'emulator-wholesale-repeat.log', 'emulator-independent-m31_ui_gaps_test.log',
    'emulator-independent-m4_ui_test.log', 'emulator-independent-protected_reads_test.log',
])
windows = index['windows-final-auth.log']['host_aggregate_pass_count']
assert (windows, poco, dv, emulator) == (173, 128, 74, 30)
assert index['windows-benchmarks.log']['host_aggregate_pass_count'] == 2
assert count('dv-benchmark-final.log') == 1

def db_hashes(filename):
    value = (evidence / filename).read_text(encoding='utf-8-sig')
    hashes = dict((name, digest) for digest, name in re.findall(
        r'([a-f0-9]{64})\s+(databases/kasir_app\.db(?:-journal)?)', value))
    # The emulator initial log records a zero-byte journal, not its digest.
    # Derive the empty-file digest explicitly; do not call it a measured hash.
    if 'databases/kasir_app.db-journal' not in hashes:
        assert re.search(r'^-rw\S*\s+1\s+\S+\s+\S+\s+0\s+\S+\s+\S+\s+kasir_app.db-journal$', value, re.M)
        hashes['databases/kasir_app.db-journal'] = hashlib.sha256(b'').hexdigest()
    return hashes

poco_before, poco_after = db_hashes('poco-ordinary-before.log'), db_hashes('poco-ordinary-after.log')
emu_before, emu_after, emu_final = (db_hashes(f) for f in [
    'emulator-ordinary-before.log', 'emulator-ordinary-after.log', 'emulator-ordinary-final.log'])
assert len(poco_before) == len(emu_before) == 2
assert poco_before == poco_after and emu_before == emu_after == emu_final
cleanup = json.loads((evidence / 'emulator-owned-cleanup.json').read_text(encoding='utf-8-sig'))
assert len(cleanup['deleted']) == 8 and not cleanup['remaining'] and not cleanup['ordinary_touched']
negative = json.loads((evidence / 'isolation-negative-build-result.json').read_text(encoding='utf-8-sig'))
assert negative['ExpectedRejected'] and negative['ActualBuildExit'] == 1 and not negative['InstallAttempted']

artifacts = json.loads((evidence / 'ordinary-artifact-verification.json').read_text(encoding='utf-8-sig'))
for artifact in artifacts:
    target = root / artifact['path'].replace('\\', '/')
    assert hashlib.sha256(target.read_bytes()).hexdigest() == artifact['sha256']
    assert artifact['IntegrationActivity_absent'] and not artifact['installed']

python_tools = sorted((root / 'tools').glob('*.py'))
for path in python_tools:
    ast.parse(path.read_text(encoding='utf-8-sig'), filename=str(path))
(evidence / 'python-ast-final.log').write_text(
    '\n'.join(str(p.relative_to(root)) + ' AST PASS' for p in python_tools) + '\n', encoding='utf-8')

analysis = (evidence / 'analyze-final-6.log').read_text(encoding='utf-8-sig')
assert 'No issues found! (ran in 7.5s)' in analysis and 'FlutterExit=0' in analysis
for name in ['M1_M4_BUGFIX_REPORT.md', 'STATUS.md', 'REQUIREMENTS.md']:
    target = root / 'docs' / name
    value = target.read_text(encoding='utf-8')
    value = value.replace('`analyze-final-6.log`:hasil akhir dicatat setelah proses selesai.',
                          '`analyze-final-6.log`:No issues found/7,5s/exit0.')
    value = value.replace('analyze akhir dicatat pada laporan.', 'analyzeNoissues7,5s/exit0.')
    value = value.replace('analyze akhir15Oktober pada laporan', 'analyzeNoissues7,5s/exit0 pada15Oktober')
    value = value.replace('PASS formatter/audit/syntax;', 'PASS formatter/analyze/audit/syntax;')
    value = value.replace('Main/journal ordinary Poco dan emulator sama sebelum/sesudah;',
                          'Poco main/journal hash sama sebelum/sesudah; emulator mainhash sama dan journal0byte sebelum/sesudah/final;')
    value = value.replace('Main/journal ordinary sama sebelum/sesudah/final',
                          'Mainhash ordinary sama sebelum/sesudah/final; journal0byte awal/akhir (digestawal tidak direkam, digestkosong akhir terukur)')
    value = value.replace('Emulator main471040 SHA bad683d0…/journal0 SHAe3b0c442… tetap sebelum/sesudah/final.',
                          'Emulator main471040 SHA bad683d0… sama sebelum/sesudah/final; journal0byte awal/akhir, digestkosong e3b0c442… terukur sesudah/final, tidak direkam awal.')
    value = value.replace('hash ordinary Poco/emulator main+journal tetap',
                          'Poco main+journal hash tetap; emulator mainhash tetap/journal0byte awal–akhir')
    target.write_text(value, encoding='utf-8', newline='\n')

coverage = {
    'finalized_local_date': '2026-10-15', 'test_local_date': '2026-10-14',
    'functional_unique_per_target': {'Windows': windows, 'Poco F6': poco, 'DV8910': dv, 'Emulator': emulator},
    'benchmark_separate': {'Windows': 2, 'DV8910': 1},
    'not_a_single_all_pass_runner': ['DV8910', 'Emulator'],
    'dv_management_coverage': '12 completed partial cases + focused pagination1 + migration1; retry3 excluded',
    'poco_baseline_hashes_unchanged': poco_before,
    'emulator_baseline_hashes_unchanged': emu_before,
    'emulator_initial_journal_evidence': 'zero-byte file metadata; empty SHA256 derived, not measured until after/final',
    'ordinary_artifact_hashes_match': True,
    'python_ast_files': len(python_tools),
    'remaining_limits': ['OEM keyboard/clipboard/physical scanner', 'TalkBack',
        'full release runtime', 'reboot/powerloss', 'peak RAM', 'operational backup/restore M5',
        'intermittent emulator frame/handshake and DV transport exact causes'],
}
(evidence / 'final-verification.json').write_text(json.dumps(coverage, indent=2) + '\n', encoding='utf-8')

(evidence / 'README.md').write_text('''# Bukti audit/perbaikan M1–M4 termasuk M3.1

Tes 14 Oktober 2026; laporan/pemeriksaan statis difinalisasi 15 Oktober. Rincian temuan dan batas bukti: [laporan](../../M1_M4_BUGFIX_REPORT.md). File sebelum/sesudah, failure, retry dan interruption tetap dipertahankan.

| Target | Kasus fungsi unik PASS | Bukti utama |
| --- | --- | --- |
| Windows |173; dua benchmark opt-in SKIP pada fungsi, dua benchmark PASS terpisah |windows-final-auth.log, windows-benchmarks.log |
| Poco F6 /7f0edea0 |128=113SQL/Provider+15UI |poco-native-final.log (127/14suite), poco-protected-reads.log (1) |
| DV8910 /192.168.0.102:5555 |74=59SQL/Provider+15UI; satu benchmark menengah terpisah |dv-native.log (11selesai+12managementpartial), dv-pagination-retry.log (1), dv-migration-retry.log (1), dv-cashier-final.log (30), dv-database-final.log (11), dv-locale-ui-retest.log (1), dv-wholesale-ui-final.log (1), dv-gaps-ui-final.log (4), dv-m4-ui-final.log (2) |
| Emulator /emulator-5554 |30=15SQL/Provider+15UI |emulator-native-final.log (7), emulator-independent-database_test.log (11), emulator-bootstrap-management_ui_test.log (1), emulator-bootstrap-cashier_ui_test.log (2), emulator-independent-localization_ui_test.log (1), emulator-wholesale-repeat.log (1), emulator-independent-m31_ui_gaps_test.log (4), emulator-independent-m4_ui_test.log (2), emulator-independent-protected_reads_test.log (1) |

Angka target tidak dijumlah menjadi unique produk. DV/emulator berasal dari run independen, bukan satu all-pass runner; retry3 DV, wholesale repeat, focused host7 dan cold-frame diagnosis1 tidak dihitung lagi. Suite SQL penuh yang tidak diulang pada DV tercantum pada laporan. Frame starvation/handshake emulator dan ADBoffline DV tidak memiliki diagnosis internal yang pasti meski retest lulus.

- `suite-evidence-index.json`: per-log suite/last reported count/exit; partial berbeda dari all_passed.
- `final-verification.json`: pemeriksaan hitungan, hash baseline operasional dan hash salinan APK tersimpan.
- `source-change-audit.json`:7file aplikasi,81file baseline sama,2delta routing uji sebelumnya; schema/business math tidak berubah.
- `format-final-6.log`, `analyze-final-6.log`, `localization-audit-final-2.log`, `python-ast-final.log`, `powershell-parse-final.log`: hasil pemeriksaan terakhir.
- `ordinary-artifact-verification.json`: APK debug/release biasa, ID/label/launcher/seluruhDEX; salinan di build/bugfix-20261014, tidak diinstall ordinary.
- `isolation-negative-build-result.json`: expected Gradle rejection exit1/tanpa install, entrypoint uji tanpa flag.
- `poco-ordinary-before/after.log`: main+journal hash cocok. `emulator-ordinary-before/after/final.log`: mainhash cocok, journal0byte awal/akhir; digestawal journal tidak direkam, digestkosong terukur sesudah/final. DV ordinary absent awal/akhir; tidak ada DBhash preservation DV.
- `emulator-owned-cleanup.json`:8exact owned files integration dihapus, remaining kosong; ordinary tidak disentuh. `dv-fixture-final.log`:DBdiruji kosong; APKuji dipertahankan.
- `scoped-log-summary.json`:15snapshotPID, rentang buffer terbatas;0fatal tidak berarti seluruh log bersih. `debug-uri-redactions.json`:auth URI VM sementara disunting pada bukti baru.
- `windows-benchmark-data.json`, `dv-benchmark-data.json`:rawplan/samples. Debug/1warmup5samples; bukan fullrelease/peakRAM/SLA.

MAN-USER-01 adalah laporan manual pengguna historis. Synthetic UI/ADB bukan keyboard OEM/scanner/TalkBack. Release build bukan full release runtime. Backup/restore/printer/Drive tetap M5/M6, belum dikerjakan. Database lama insiden M3.1 tetap missing/unrecovered; baseline preservation dan cleanup fixture bukan restore.
''', encoding='utf-8')

manifest = []
for path in sorted(evidence.iterdir()):
    if path.is_file() and path.name != 'artifact-manifest.json':
        manifest.append({'name': path.name, 'bytes': path.stat().st_size,
                         'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
(evidence / 'artifact-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(f'PASS: counts Windows{windows}/Poco{poco}/DV{dv}/emulator{emulator}; hashes retained; APK hashes match; Python AST{len(python_tools)}; {len(manifest)} evidence files indexed.')
