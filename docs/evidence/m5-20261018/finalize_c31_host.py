"""Record host-only validation; never imply the human's C30 APK was replaced."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[3]
ev = root / 'docs/evidence/m5-20261018'
def read(path):
    return path.read_text(encoding='utf-8-sig')
def save(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

regression = read(ev / 'c31-host-regression.log')
assert re.search(r'\+56: All tests passed!', regression)
analyze = read(ev / 'c31-analyze.log')
assert 'No issues found!' in analyze
duration = re.search(r'No issues found! \(ran in ([0-9.]+)s\)', analyze).group(1)
elapsed = re.search(r'(\d+:\d+) \+56: All tests passed!', regression).group(1)
result = {
    'id': 'C31-HOST', 'date': '2026-10-18', 'status': 'PASS host scope',
    'before': '2PASS/2FAIL2s: SDK null StateError and generic UI; scheduler assertion not reached before patch',
    'focusedAfter': '4PASS2s; real transport/source/provider/scheduler with synthetic SDK/HTTP and fresh FFI DB',
    'regression': f'56PASS{elapsed}; focused4 is a subset, not extra cases',
    'analyzer': f'No issues {duration}s',
    'deviceControl': False, 'installedCheckpoint': 'C30',
    'remaining': 'C30-MAN01 physical labels pending; C31 native Poco/DV/build/deployment/strict data audit pending. Real Google revoked-consent behavior unverified. OriginalAPK6 restoration/closing pending.',
}
p = ev / 'c31-host-results.json'
assert not p.exists()
save(p, result)
p = ev / 'c31-update-context.json'
context = json.loads(read(p))
assert context['installedCheckpoint'] == 'C30' and not context['automaticDeviceControlActive']
context.update(stage='C31 host4/full56/analyzer PASS; native/build/deploy pending; C30 physical retest pending', hostResults=str(ev / 'c31-host-results.json'))
save(p, context)
p = ev / 'c30-update-context.json'
context = json.loads(read(p))
assert not context['automaticDeviceControlActive']
context['newerSourceValidation'] = str(ev / 'c31-update-context.json')
save(p, context)

consistency = json.loads(read(ev / 'c30-handover-consistency.json'))
assert len(consistency) == 12
for entry in consistency:
    p = root / 'docs/evidence/m5-20261016' / entry['folder'] / 'handover.json'
    data = json.loads(read(p))
    assert not data['automaticDeviceControlActive'] and data['restoreOriginalPending']
    assert data['fixtureSha256'] == '928bb4515fec95f6453335c4dabf56812ae976b4a2832138fa7c548a424bb1d4'
    data['c31HostAudit'] = result
    data['sourceValidationContext'] = str(ev / 'c31-update-context.json')
    save(p, data)

note = ('**C31 host PASS,18 Oktober2026:** silent Google SDK null sebelumnya menjadi '
        'StateError/kegagalan umum (2PASS/2FAIL2s). Exception khusus dipetakan ke '
        'driveNeedsAuthorization nonretry, tanpa UI worker; focused4PASS2s/full56PASS'
        + elapsed + ' (subset), analyzer ' + duration + 's No issues. Jalur UI seluruh '
        'hash DB tetap; penjadwal hanya backup_schedule berubah, tanpa HTTP nyata/unggah '
        'atau sukses palsu. Native/build/deploy C31 belum dilakukan. C30 tetap terpasang '
        'dan C30-MAN01 label riwayat sedang menunggu pengguna, kontrol perangkat Off. '
        'Real revoked-consent/natural21/reboot/Doze belum terverifikasi; originalAPK6 '
        'restoration/closing pending. M5 belum selesai/M6 tidak dimulai. '
        '[C31](M5_SILENT_AUTHORIZATION_C31.md).**')
for name in ['STATUS.md', 'PLAN.md', 'REQUIREMENTS.md', 'M5_POCO_MANUAL_TEST.md']:
    p = root / 'docs' / name
    body = read(p)
    assert note not in body
    i = body.index('\n') + 1
    p.write_text(body[:i] + '\n' + note + '\n\n' + body[i:].lstrip('\n'), encoding='utf-8')
for name in ['M5_TEST_REPORT.md', 'M5_IMPLEMENTATION_REPORT.md']:
    p = root / 'docs' / name
    p.write_text(read(p).rstrip() + '\n\n' + note + '\n', encoding='utf-8')
p = root / 'docs/M5_SILENT_AUTHORIZATION_C31.md'
p.write_text(read(p).rstrip() + '\n\nRegresi gabungan tujuh file: **56 PASS ' + elapsed + '**; empat focused adalah '
             'subset. Analyzer **No issues ' + duration + 's**. Bukti '
             '`evidence/m5-20261018/c31-host-regression.log` dan `c31-analyze.log`. '
             'Native/build/deploy tetap pending; C30 di Poco tidak diganti.\n', encoding='utf-8')
p = root / 'docs/M5_FIXES_AND_VALIDATION.md'
body = read(p)
anchor = '| C30 — konteks riwayat lokal |'
assert anchor in body
row = ('| C31 — status silent authorization | SDK null dilempar StateError sehingga kebutuhan '
       'otorisasi menjadi kegagalan umum; bukan kegagalan Google nyata yang dilaporkan. '
       '| drive_authorization.dart/drive_rest.dart; SDK/HTTP fixture + provider/scheduler '
       '| Before2PASS/2FAIL2s→focused4PASS2s/full56PASS; analyzer clean; whole DB stable '
       'on UI, only schedule changes on one nonretry scheduled attempt '
       '| Fixed host scope; native/build/deploy pending, C30 still installed. M5_SILENT_AUTHORIZATION_C31 |\n')
body = body.replace(anchor, row + anchor, 1)
p.write_text(body, encoding='utf-8')
p = root / 'docs/REQUIREMENTS.md'
body = read(p)
lines = body.splitlines()
for n, line in enumerate(lines):
    if line.startswith('| R13-006 |'):
        # Append evidence without rewriting previous actual results or the requirement.
        line = line.rstrip().replace('actual account B pending.', 'actual account B read-only separation PASS C30; in-flight change/OS cancellation unverified.')
        lines[n] = line[:-1] + ' C31: SDK-null repro2FAIL, fixed host4/full56PASS; '
        lines[n] += 'needs-auth UI/scheduler/no false success, native/deploy pending; '
        lines[n] += 'B real read-only separation already audited C30 (see R13-004/005). |'
p.write_text('\n'.join(lines) + '\n', encoding='utf-8')
p = root / 'docs/LESSONS-LEARNED.md'
lesson = ('81. HTTP401 coverage does not prove silent Google SDK coverage. Official SDK '
          'null means interaction required when prompts are disabled. A StateError with '
          'the right text still misses typed UI/scheduler mapping. Reproduce the actual '
          'SDK boundary, map only a specific payload-free exception, preserve unknown '
          'configuration failures, assert no interactive calls/HTTP and no false success '
          'or repeated same-day attempt. Test before stopped at UI; do not claim scheduler '
          'before evidence that never ran. Host fixtures are not real revoked-token proof, '
          'and editing source does not update the C30 APK handed to the human.\n')
assert lesson not in read(p)
p.write_text(read(p).rstrip() + '\n\n' + lesson, encoding='utf-8')
print('C31 host recorded; C30 installed and all12 device-control flags Off; native/build/closing pending')
