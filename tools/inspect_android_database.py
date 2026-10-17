"""Closed ordinary debug DB fingerprints, never row/PIN/customer values.

Read-only after a scoped force-stop. Refuses WAL or a nonzero rollback journal
header rather than copying an inconsistent main file. DELETE/TRUNCATE/PERSIST
cannot be distinguished from the main-file header. This is not M5 backup.
"""
import argparse
import hashlib
import json
import pathlib
import sqlite3
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True)
parser.add_argument('--device', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--compare')
args = parser.parse_args()
package = 'com.example.kasir_app'
base = [args.adb, '-s', args.device]


def command(*parts):
    return subprocess.run(base + list(parts), capture_output=True, check=True, timeout=30).stdout


assert command('get-state').decode().strip() == 'device'
root = command('shell', 'run-as', package, 'pwd').decode().strip()
assert root in ('/data/user/0/com.example.kasir_app', '/data/data/com.example.kasir_app')
command('shell', 'am', 'force-stop', package)
raw = command('exec-out', 'run-as', package, 'cat', root + '/databases/kasir_app.db')
assert raw.startswith(b'SQLite format 3\x00')
assert raw[18:20] == b'\x01\x01', 'WAL database needs a proper consistent snapshot; main-file-only proof refused'
journal_path = root + '/databases/kasir_app.db-journal'
journal_probe = subprocess.run(base + ['shell', 'run-as', package, 'test', '-e', journal_path], capture_output=True, timeout=30)
assert journal_probe.returncode in (0, 1), 'Cannot inspect rollback journal'
journal_present = journal_probe.returncode == 0
if journal_present:
    journal_header = command('exec-out', 'run-as', package, 'head', '-c', '28', journal_path)
    assert not any(journal_header), 'Nonzero rollback journal header; main-file-only proof refused'
prior = json.loads(pathlib.Path(args.compare).read_text(encoding='utf-8')) if args.compare else None


def digest_rows(database, table, columns):
    def quote(name):
        return '"' + name.replace('"', '""') + '"'
    def value(item):
        if isinstance(item, bytes):
            return {'blob_sha256': hashlib.sha256(item).hexdigest()}
        return item
    # Sort digest representations for a stable multiset, independent of rowid
    # or index changes. No raw row is written to the evidence file or console.
    rows = [json.dumps([value(v) for v in row], ensure_ascii=True, separators=(',', ':'))
            for row in database.execute('SELECT ' + ','.join(map(quote, columns)) + ' FROM ' + quote(table))]
    return len(rows), hashlib.sha256('\n'.join(sorted(rows)).encode()).hexdigest()


with tempfile.TemporaryDirectory(prefix='kasir_db_inspect_') as directory:
    snapshot = pathlib.Path(directory) / 'closed.db'
    snapshot.write_bytes(raw)
    database = sqlite3.connect(snapshot.as_uri() + '?mode=ro', uri=True)
    version = database.execute('PRAGMA user_version').fetchone()[0]
    quick = database.execute('PRAGMA quick_check').fetchall()
    foreign_keys = database.execute('PRAGMA foreign_key_check').fetchall()
    assert quick == [('ok',)] and not foreign_keys, 'Integrity/foreign key failure'
    names = [r[0] for r in database.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
    tables = {}
    for name in names:
        columns = [r[1] for r in database.execute('PRAGMA table_info("' + name.replace('"', '""') + '")')]
        compared_columns = prior['tables'][name]['columns'] if prior and name in prior['tables'] else columns
        assert set(compared_columns) <= set(columns), 'Old columns missing: ' + name
        count, digest = digest_rows(database, name, compared_columns)
        tables[name] = {'columns': compared_columns, 'count': count, 'row_values_sha256': digest}
    if prior:
        for name, old in prior['tables'].items():
            assert name in tables and tables[name]['count'] == old['count'] and tables[name]['row_values_sha256'] == old['row_values_sha256'], 'Old values changed: ' + name
    database.close()

result = {'package': package, 'device': args.device, 'schema': version, 'bytes': len(raw),
          'database_sha256': hashlib.sha256(raw).hexdigest(),
          'journal_mode': 'rollback family; runtime DELETE/TRUNCATE/PERSIST not distinguished',
          'rollback_journal_present': journal_present, 'rollback_journal_header_zero_or_absent': True,
          'quick_check': 'ok', 'foreign_key_violations': 0, 'tables': tables,
          'old_table_values_preserved': bool(prior)}
pathlib.Path(args.output).write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps({k: result[k] for k in ('package', 'schema', 'bytes', 'database_sha256', 'quick_check', 'foreign_key_violations', 'old_table_values_preserved')}))
