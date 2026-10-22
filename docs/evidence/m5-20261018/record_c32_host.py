"""Persist host evidence while native/build/closing are still in progress."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
ev=root/'docs/evidence/m5-20261018'
def read(p):return p.read_text(encoding='utf-8-sig')
assert '+58: All tests passed!' in read(ev/'c32-host-regression.log')
assert 'No issues found! (ran in 41.3s)' in read(ev/'c32-analyze.log')
note='**C32 host PASS,19 Oktober2026:** status error worker tersimpan belum dirender saat route dibuka kembali. Getter/pesan historis perangkat ID/EN ditambahkan tanpa mutasi SQL/policy. Repro final-helper2FAIL9s→focused2PASS10s/full58PASS159s, analyzer final41.3s No issues. First before/after lazy-finder failures disimpan, tidak disamakan dengan bug tambahan. Poco/DV terdeteksi ulang; native UI/build/audit13arsip/disconnected/closing sedang dijalankan, belum klaim lulus. D-MAN17 dan pembatalan pemilih tambahan tetap reported; jeda bukan baseline beku. M5 belum selesai/M6 tidak dimulai. [C32](M5_PERSISTED_WORKER_STATUS_C32.md), [context](evidence/m5-20261018/c32-update-context.json).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 p=root/'docs'/name;t=read(p);assert note not in t;i=t.index('\n')+1;p.write_text(t[:i]+'\n'+note+'\n\n'+t[i:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_IMPLEMENTATION_REPORT.md']:
 p=root/'docs'/name;p.write_text(read(p).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
p=root/'docs/M5_FIXES_AND_VALIDATION.md';t=read(p);anchor='| C31 — status silent authorization |';assert anchor in t
row='| C32 — kegagalan worker tidak tampil | backup_schedule.error_code dibaca overview tetapi tidak dirender; failure sebelum run dibuat tidak ada pada daftar run. | BackupSettingsProvider/Screen,2key ID/EN,settings UI tests | Final-helper omission2FAIL9s→focused2PASS10s/full58PASS159s; analyzer41.3s No issues; no SQL/UI writes, null clears/PIN hides | Fixed host scope; native/build/closing pending. M5_PERSISTED_WORKER_STATUS_C32 |\n'
p.write_text(t.replace(anchor,row+anchor,1),encoding='utf-8')
p=root/'docs/LESSONS-LEARNED.md';t=read(p);lesson='83. Status error sebelum pembuatan backup_runs tetap perlu projection dari backup_schedule setelah route dimuat ulang. Jangan mengandalkan pesan foreground atau mengatribusikan error historis kepada akun baru. Pisahkan bug rendering dari finder lazy: pump/scroll ke anchor yang sudah ada, reproduksi omission dengan helper final, lalu pulihkan source sendiri byte-identik. Jeda/pemilih akun batal bukan baseline beku; tutup dengan baseline sesudah PIN, seluruh hash selama inspeksi, autentikasi arsip dan pemeriksaan work milik fixture saja.\n'
assert lesson not in t;p.write_text(t.rstrip()+'\n\n'+lesson,encoding='utf-8')
(ev/'c32-host-results.json').write_text(json.dumps({'date':'2026-10-19','host':'58PASS159s; focused2PASS10s subset','before':'final-helper omitted-rendering2FAIL9s; earlier lazy-finder failures retained separately','analyzer':'No issues41.3s','nativeBuildClosing':'pending; see current pipeline context','report':'docs/M5_PERSISTED_WORKER_STATUS_C32.md'},indent=2)+'\n',encoding='utf-8')
print('C32 host evidence recorded; native/build/closing not assumed complete')
