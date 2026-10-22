"""Record the human C30 observation and derive the guarded C31 runner."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[3]
ev = root / 'docs/evidence/m5-20261018'
def read(p): return p.read_text(encoding='utf-8-sig')
def save(p, value): p.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
record = {
    'id': 'C30-MAN01', 'date': '2026-10-18', 'status': 'PASS reported scoped',
    'source': 'user physical manual report on Poco C30',
    'actual': 'Destination Drive archive section explicitly empty; local device history has8 Verified complete/date rows, all labelled another/previous destination account.',
    'limits': 'Help paragraph not quoted separately. No new SQL/API audit or OS-job cancellation evidence from this human step. B/automaticOFF last native checkpoint kept; no fresh native policy assertion here.',
}
p = ev / 'c30-man01-user-report.json'
assert not p.exists()
save(p, record)
step = 'C30-MAN01 labels/empty state PASS reported. Manual paused for C31 native4 per device/build/fresh B strict audit. No human fixture interaction during automatic queue; no uploads/restore/reset.'
for entry in json.loads(read(ev / 'c30-handover-consistency.json')):
    p = root / 'docs/evidence/m5-20261016' / entry['folder'] / 'handover.json'
    data = json.loads(read(p)); assert not data['automaticDeviceControlActive']
    data['manualEvidence'].append(record)
    data['manualResults'] += ' C30-MAN01 destination empty/local8other-account labels PASS reported by user.'
    data['manualStep'] = step
    save(p, data)
for name in ['c30-update-context.json', 'c31-update-context.json']:
    p = ev / name; data = json.loads(read(p)); assert not data['automaticDeviceControlActive']
    data.update(manualStep=step, latestManualEvidence=str(ev / 'c30-man01-user-report.json'))
    save(p, data)
note = '**C30-MAN01 PASS manual dilaporkan pengguna,18 Oktober2026:** heading arsip tujuan menunjukkan halaman kosong; riwayat perangkat berisi8status sukses/tanggal dengan label akun lain/sebelumnya. Paragraf bantuan tidak dikutip terpisah. Tidak ada unggah/restore baru atau bukti cancel job OS dari langkah ini. Berikut C31 native/build/audit; manual dijeda selama antrean, M5 belum selesai/M6 tidak dimulai. [Bukti](evidence/m5-20261018/c30-man01-user-report.json).**'
for name in ['STATUS.md', 'PLAN.md', 'REQUIREMENTS.md', 'M5_POCO_MANUAL_TEST.md']:
    p = root / 'docs' / name; text = read(p); i = text.index('\n')+1
    p.write_text(text[:i]+'\n'+note+'\n\n'+text[i:].lstrip('\n'), encoding='utf-8')
for name in ['M5_TEST_REPORT.md', 'M5_DRIVE_HISTORY_CONTEXT_C30.md']:
    p = root / 'docs' / name; p.write_text(read(p).rstrip()+'\n\n'+note+'\n', encoding='utf-8')
p = root / 'docs/REQUIREMENTS.md'
text = read(p)
text = text.replace('physical C30 labels pending', 'physical C30 labels PASS reported C30-MAN01')
text = text.replace('physical labels pending', 'physical labels PASS reported C30-MAN01')
p.write_text(text, encoding='utf-8')
p = root / 'docs/M5_FIXES_AND_VALIDATION.md'
text = read(p).replace('physical C30 labels pending.', 'physical C30 labels PASS reported C30-MAN01.')
p.write_text(text, encoding='utf-8')

source = read(ev / 'c30_pipeline.ps1')
source = source.replace('c30', 'c31').replace('C30', 'C31')
source = source.replace('C29', 'C30').replace('prior-c29', 'prior-c30')
source = source.replace('2f114edc869e4466aae6a9788e1b7bb6cda78c90b0528cce0e8a4981ab34cf6e', '928bb4515fec95f6453335c4dabf56812ae976b4a2832138fa7c548a424bb1d4')
source = source.replace('poco-history-ui-update-', 'poco-silent-auth-update-')
source = source.replace('integration_test/m5_settings_ui_test.dart', 'integration_test/m5_drive_authorization_test.dart')
assert source.count("-NameFilter 'Drive '") == 2
source = source.replace("-NameFilter 'Drive ' ", '')
anchor = "'poco-account-ui-update-1792328869099'))"
assert anchor in source
source = source.replace(anchor, "'poco-account-ui-update-1792328869099','poco-history-ui-update-1792331546910'))")
source = source.replace('native UI completed', 'native SDK-null authorization completed')
assert "m5_drive_authorization_test.dart" in source and 'm5_settings_ui_test.dart' not in source
assert source.count('poco-history-ui-update-1792331546910') == 1
(ev / 'c31_pipeline.ps1').write_text(source, encoding='utf-8')
print('C30 manual report recorded; C31 guarded pipeline prepared; no device control yet')
