"""Close M5 only after guarded native/build/data/APK/work evidence exists."""
import copy
import hashlib
import json
import re
from pathlib import Path

root=Path(__file__).resolve().parents[3]
ev=root/'docs/evidence/m5-20261018'
base=root/'docs/evidence/m5-20261016'
def read(p):return p.read_text(encoding='utf-8-sig')
def load(p):return json.loads(read(p))
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
context=ev/'c32-update-context.json'
ledger_path=Path(load(context)['ledger']);evidence=ledger_path.parent;ledger=load(ledger_path)
assert ledger['state']=='C32 native/build/strict preservation/startup/final audit/exact original v6 restoration/own M5 work cleanup PASS; docs finalization pending'
assert not ledger['automaticDeviceControlActive'] and 'failure' not in ledger
nonce=ledger['nonce']
poco=list(base.glob(f'poco-c32-ui-{nonce}-*'));dv=list(base.glob(f'c32-ui-{nonce}-*'))
assert len(poco)==1 and '+2: All tests passed!' in read(poco[0]/'runner.log')
assert 'Ordinary DB and sidecar byte hashes unchanged.' in read(poco[0]/'isolation.txt')
dv_result=ledger['dv']
if not dv_result.startswith('BLOCKED'):
 assert len(dv)==1 and '+2: All tests passed!' in read(dv[0]/'runner.log')
 assert load(dv[0]/'awake-original.json')['Restored']
 assert read(evidence/'dv-legacy-before.txt')==read(evidence/'dv-legacy-after.txt')
 assert sha(evidence/'dv-prior.apk')==sha(evidence/'dv-restored.apk')
 dv_result='2PASS43s UI/SQLCipher ARM32; exact prior APK/default hashes/awake restored/read back'
assert '+58: All tests passed!' in read(ev/'c32-host-regression.log')
assert 'No issues found!' in read(ev/'c32-analyze.log')
before,after,final=[Path(ledger[key]) for key in ['beforeEvidence','afterEvidence','finalEvidence']]
for folder,role in [(before,'before'),(after,'after'),(final,'final')]:
 log=read(folder/'runner.log')
 assert '+1: All tests passed!' in log
 assert f'M5_CLOSING_AUDIT {role} integrity/FK/envelope/business23/13archives/disconnected/policy/allTables PASS' in log
 assert re.search(r'^Success$',read(folder/'original-restored.log'),re.M)
assert 'M5_CLOSING_ARCHIVES authenticated13=true workerBusiness23Snapshots8=true historicalFiveProvenancePreviouslyAudited=true noUploadGuard=true allLiveTablesStable=true' in read(before/'runner.log')
assert 'M5_CLOSING_CLOSED_DIGESTS final stored=true' in read(final/'runner.log')
assert read(poco[0]/'ordinary-before.txt')==read(final/'ordinary-after.txt')
closing=load(evidence/'closing-results.json');work=load(evidence/'own-m5-work-closed.json')
assert all(closing[key] is True for key in ['originalV6Restored','legacyHashesSame','campaignClosedHashesSame','ordinaryHashesSame','publicExportsSame','originalNotLaunched'])
assert work['closedWorkMetadataIntegrity'] and work['originalMetadataHashesUnchanged'] and work['pendingOrUnknownStateCount']==0
original=base/'poco-manual-20261016-191759/original-fixture.apk'
assert sha(original)==closing['originalSha256']==sha(evidence/'restored-original-v6.apk')
assert sha(evidence/'installed-c32.apk')==ledger['fixtureSha256']
startup=load(evidence/'startup.json');assert startup['synthetic_screen_visible'] and startup['startup_error_markers']==0
artifacts=load(Path(ledger['artifactsJson']));assert artifacts['installed'] is False and artifacts['fixtureDatabase']==ledger['fixtureDatabase']
assert read(evidence/'public-before.txt')==read(evidence/'public-closing-after.txt')
analyze=re.search(r'No issues found! \(ran in ([0-9.]+)s\)',read(ev/'c32-analyze.log')).group(1)
record={'id':'C32-CLOSING','date':'2026-10-19','status':'PASS available scope; M5 implementation/primary acceptance closed; M6 not started',
 'host':'58PASS159s including focused2 subset; no sum of retries/language vectors/native reuse',
 'analyzer':f'No issues{analyze}s','poco':'2PASS21s persistent worker status UI with native SQLCipher','dv':dv_result,
 'nativeClosing':'One audit testcase in3roles: before13archives authenticated/8worker business23 snapshots; after strict all-table/archive/policy equality; final after release startup alert metadata accounted and own M5 work cancellation requested',
 'data':'2products/2sales; revenue42000/HPP36000/payment22000/debt20000; stock18/value150000; old13archive digests intact; disconnected/autoOff/nextnull',
 'build':'3 universal artifacts verified; ordinary built only, not installed; development signing',
 'restoration':closing,'ownM5Work':work,'releaseStartup':startup,'ledger':str(ledger_path),
 'limits':['Natural21/reboot/Doze/force-stop background delivery unverified','Real revoked-consent condition/in-flight account switch/other-origin real Drive preservation unverified','Real cross-device Drive not exercised; encrypted portable DV-to-Poco proof remains separate','80mm/paper-out/actual ambiguous partial write physical tests unverified','OEM clipboard preview masking/lockscreen notification content/TalkBack physical unverified','Realme unavailable for C31/C32; historical results retained separately','No recovery claim for historical ISSUE-M31-DATA; no M6 release signing/publication']}
folders=[item['folder'] for item in load(ev/'c31-handover-consistency.json')]
paths=[base/folder/'handover.json' for folder in folders];template=load(paths[-1])
step='M5 primary acceptance and available validation closed; exact original v6 fixture restored without launch, ordinary/legacy/campaign/exports retained. No automatic device control. Review M5_FINAL_REPORT_20261019; unverified scenarios explicitly remain; M6 not started.'
for p in paths+[evidence/'handover.json']:
 data=load(p) if p in paths else copy.deepcopy(template)
 assert data['originalApk']==str(original) and not data['automaticDeviceControlActive']
 data.update(automaticDeviceControlActive=False,restoreOriginalPending=False,closingAuditPending=False,manualStep=step,
             fixtureApk=str(original),fixtureSha256=closing['originalSha256'],restoredOriginalApkVerified=True,
             restoreBridge=ledger['restoreBridge'],sourceValidationContext=str(context),
             pendingC32Update={'ledger':str(ledger_path),'state':'completed; see closingCompletionEvidence','completed':True},
             lastTestedM5Apk=ledger['newApk'],lastTestedM5Sha256=ledger['fixtureSha256'],closingCompletionEvidence=record)
 data['manualResults']+=' C32 host58/native2per device/build3/13archive authentication/3-role closing/data+work cleanup PASS; exact original v6 restored/no launch; available M5 acceptance closed with documented limits.'
 data['manualEvidence'].append(record)
 data.setdefault('apkHistory',[]).extend([{'checkpoint':'C32 tested','date':'2026-10-19','apk':ledger['newApk'],'sha256':ledger['fixtureSha256']},{'checkpoint':'Exact original v6 restored; no launch','date':'2026-10-19','apk':str(original),'sha256':closing['originalSha256']}])
 save(p,data)
ledger.update(state='M5 primary acceptance closed; exact original v6 verified restored; documented unverified scenarios remain',automaticDeviceControlActive=False,originalV6Restoration='verified complete without launch',manualStep=step,nativePocoEvidence=str(poco[0]),nativeDvEvidence=str(dv[0]) if dv else None,closingAuditPending=False)
ledger['sourceSha256']={name:sha(root/name) for name in ['lib/features/backup/presentation/backup_settings_provider.dart','lib/features/backup/presentation/backup_settings_screen.dart','lib/l10n/app_id.arb','lib/l10n/app_en.arb','lib/l10n/localization.dart','test/m5_settings_ui_test.dart','integration_test/m5_closing_audit_test.dart','tools/inspect_m5_closing_work.py']}
save(ledger_path,ledger);save(ev/'c32-results.json',record)
save(context,{'stage':ledger['state'],'ledger':str(ledger_path),'automaticDeviceControlActive':False,'installedCheckpoint':'exact original fixture v6, not launched','installedSha256':closing['originalSha256'],'lastTestedM5Apk':ledger['newApk'],'originalV6RestorationPending':False,'closingPending':False,'m6Started':False,'unverified':record['limits']})
save(ev/'c32-handover-consistency.json',[{'folder':p.parent.name,'control':load(p)['automaticDeviceControlActive'],'originalPending':load(p)['restoreOriginalPending'],'closingPending':load(p)['closingAuditPending'],'originalRestored':load(p)['fixtureSha256']==closing['originalSha256']} for p in paths+[evidence/'handover.json']])
p=ev/'c31-update-context.json';v=load(p);v.update(supersededBy=str(context),automaticDeviceControlActive=False,stage='C31 superseded by C32 closing; follow completion context');save(p,v)
ordinary=str(Path(artifacts['ordinary'])).replace('\\','/')
fixture=str(Path(artifacts['fixture'])).replace('\\','/')
report=f'''# Laporan akhir implementasi dan acceptance utama M5

19 Oktober 2026. **M5 selesai dalam cakupan implementasi dan pemeriksaan yang
tersedia; M6 belum dimulai.** Skenario yang belum terverifikasi tetap terbuka di
bawah. Tidak ada publikasi, push Git, penggantian nama/applicationId produksi,
reset/uninstall database, atau pemasangan APK ordinary pada kampanye ini.

## Perubahan terakhir dan bukti

| Temuan | Sebelum → sesudah | Status |
| --- | --- | --- |
| C30: daftar cloud bercampur secara visual dengan riwayat lokal | B cloud0/8run lokal; heading/konteks akun/empty-page ID–EN; otomatis+audit B dan C30-MAN01 manual PASS | Fixed UI; riwayat tetap |
| C31: silent Google SDK null menjadi error umum | 2PASS/2FAIL→host4/full56; Poco4/DV4 SDK/HTTP sintetis; exception needs-auth nonretry tanpa UI worker | Fixed; kondisi revoke Google nyata belum diuji |
| C32: kegagalan worker persisten tidak tampil setelah reload | Repro helper final2FAIL9s→focused2PASS10s/full58PASS159s; Poco2PASS21s/DV2PASS43s | Fixed; status historis perangkat tidak diatribusikan ke akun baru |
| Helper C31/32 | fixturePathRequired/lazy finder dipisahkan dari bug aplikasi; nama fixture/pump/scroll diperbaiki, raw failure dipertahankan | CLOSED TEST BUG, guard tidak dilonggarkan |

Detail gejala, penyebab, dampak, file dan log:
[C30](M5_DRIVE_HISTORY_CONTEXT_C30.md), [C31](M5_SILENT_AUTHORIZATION_C31.md),
[C32](M5_PERSISTED_WORKER_STATUS_C32.md), [seluruh perbaikan](M5_FIXES_AND_VALIDATION.md).

## Arsitektur dan file penting

Provider tetap scoped pada layar/alur; service/repository memiliki transaksi,
aturan bisnis, transport dan persistensi. SQLCipher memakai key instalasi acak
terproteksi Keystore, terpisah dari PIN. Migrasi/snapshot/promosi staging dan
recovery diuji pada fixture, tidak dijalankan pada ordinary DB pengguna.
Arsip portable terautentikasi memakai recovery kuat terpisah dari key perangkat.

Printer memakai snapshot commit dan antrean idempotent; kegagalan/copy tidak
menciptakan sale atau mengurangi stok. Peringatan mengevaluasi batch/stok
terpisah dari sink Android; notifikasi generik dan route detail melalui PIN.
Drive tetap opsional appDataFolder dengan scope minimum, store/origin namespace,
consent generation guard, retensi7 sesudah verifikasi, dan retry harian terbatas
yang bertahan restart. Target21:00 bersifat best effort, bukan janji waktu tepat.

| Modul | File utama |
| --- | --- |
| SQLCipher/key/migrasi | lib/data/database/encrypted_database.dart, durable_promotion.dart |
| Snapshot/arsip/safety/restore | lib/features/backup/application/backup_service.dart |
| OAuth/Drive/consent/retensi | lib/features/backup/application/drive_authorization.dart, drive_rest.dart, drive_backup_service.dart |
| Jadwal/backoff | lib/features/backup/application/backup_scheduler.dart, backup_retry_store.dart |
| Antrean printer | lib/features/printer/application/print_queue_service.dart |
| Peringatan | lib/features/alerts/application/alert_service.dart, android_stock_notifications.dart |
| Perbaikan UI C30–32 | lib/features/backup/presentation/backup_settings_provider.dart, backup_settings_screen.dart, lib/l10n |
| Batas native/perlindungan rahasia | packages/kasir_platform/android/src/main/java/com/example/kasir_platform/KasirPlatformPlugin.java |

## Pemeriksaan akhir aktual

- Host final:58PASS159s, analyzer No issues {analyze}s, formatter selesai.
  Focused2 adalah subset; native menggunakan kembali testcase bahasa yang sama.
- UI native C32: Poco F6 ARM64/API36 2PASS21s; DV8910 ARM32/API30 2PASS43s.
  Ini SDK/HTTP/worker-state sintetis pada SQLCipher native, bukan Google revoke nyata.
- Audit penutup: satu testcase dalam3role. Before mengautentikasi13arsip dan
  memverifikasi8snapshot worker terhadap23tabel bisnis; kelima arsip historis
  mempertahankan provenance yang sudah diverifikasi. Seluruh hash live tetap
  selama inspeksi setelah metadata autentikasi fixture yang dicatat.
- After: seluruh tabel/13arsip/policy identik pada interval pemasangan tanpa
  startup. Final: startup release terlihat/0marker error pada buffer tersedia;
  metadata evaluasi alert dipisahkan dan field stabil store/alert tetap sama.
- Drive disconnected/otomatisOff/targetnull setelah D-MAN17 dan pembatalan
  pemilih tambahan diverifikasi native. Delapan run sukses tetap ada.
- WorkManager fixture setelah cleanup: {work['m5WorkCount']}catatan M5,
  pending/unknown0; database metadata tertutup/integrity/hash tetap. Ini snapshot
  sesudah cleanup, bukan bukti transisi pembatalan job aktif sebelumnya.
- Tiga APK universal/minSdk24/ABI ARM32+ARM64+x64, alignment16KiB, identitas,
  icon/license/signature dan negative isolation guard terverifikasi. Development
  signing; signing distribusi/Play merupakan pekerjaan M6.

## Keadaan data dan perangkat

| Fakta kampanye sintetis | Nilai akhir |
| --- | --- |
| Barang/penjualan | 2/2, dua nomor struk berbeda |
| Penjualan/HPP/laba kotor | 42.000/36.000/6.000 IDR |
| Pembayaran/piutang | 22.000/20.000 IDR |
| Stok fisik/kedaluwarsa/nilai | 18/0/150.000 IDR |
| Arsip lokal | 13, digest awal tetap; seluruhnya terautentikasi |
| Printer/notifikasi aplikasi | Profil kosong/Off, pengingat5hari |

APK fixture v6 asli dikembalikan byte-identik dengan install-r-d, **tanpa launch**.
Keempat file legacy, file kampanye tertutup, ordinary dan dua ekspor publik sama
pada interval penutupan. Kampanye SQLCipher8 tetap tersimpan; APK v6 tidak dibuka
untuk membaca/migrasikannya. Aplikasi ordinary tidak dipasang ulang atau dibuka
oleh audit. DV kembali ke APK/pengaturan awake asal dengan readback. Tidak ada
klaim pemulihan data historis ISSUE-M31-DATA dari pelestarian kampanye ini.

## Manual dan integrasi nyata — dipisahkan dari tes otomatis

Printer Poco/Iware58mm: koneksi, unicode/logo/font18/24/32, struk grosir/piutang,
pencegahan cetak pertama berulang, SALINAN, gagal printer mati/reconnect dan
rekonsiliasi dilaporkan PASS oleh pengguna. Notifikasi izin/tap PIN/dedup/rearm/
disable serta backup lokal/export/restore dan Drive manual/restore dilaporkan
PASS sesuai laporan masing-masing; audit native terpisah tersedia pada
[M5_TEST_REPORT](M5_TEST_REPORT.md). D-MAN17 PASS dilaporkan, tambahan pemilih
dibatalkan dicatat dan keadaan disconnected diverifikasi ulang native.

Headless Google nyata:8upload terverifikasi, retensi7 dan PID worker berbeda
dengan pemicu ADB terkontrol; bukan eksekusi alami21:00. Audit B nyata:
identitas berbeda dari A, list0, file A unavailable lewat B, autoOff menolak run.
Portabilitas arsip terenkripsi DV→Poco dibuktikan terpisah dari Google lintas
perangkat. Hasil Realme/historis tetap bertanggal semula, tidak dihitung sebagai
rerun C32. Lihat [worker nyata](M5_LIVE_DRIVE_WORKER_20261018.md).

## Batas pemeriksaan dan pekerjaan berikutnya

- Natural21:00/reboot/Doze/force-stop delivery, revoke Google nyata,
  account-switch in-flight dan pelestarian origin lain di Drive nyata belum
  terverifikasi. Mock/generation guards/controlled worker bukan pengganti bukti itu.
- Drive lintas perangkat nyata belum dilakukan; akun/perangkat kedua yang cocok
  belum digunakan. Jangan menambah akun pribadi pada Realme pinjaman.
- Printer80mm/paper-out/partial-write ambigu fisik, redaksi panel clipboard OEM,
  konten notifikasi lockscreen dan TalkBack fisik belum terverifikasi.
- Realme tidak tersedia untuk patch C31/C32. Runtime ordinary/OAuth identitas
  distribusi dan signing rilis belum divalidasi pada aplikasi pengguna.

Berikutnya pengguna meninjau M5. M6 menunggu instruksi eksplisit; hasil di atas
tidak menyatakan seluruh aplikasi siap publikasi atau semua skenario lulus.

## Artefak

- [APK M5 aplikasi utama]({ordinary}) — build verified, belum dipasang.
- [APK M5 uji terakhir]({fixture}) — tested lalu diganti kembali dengan v6 asli.
- [Ledger dan bukti penutup]({str(ledger_path).replace(chr(92),'/')}).
- [STATUS](STATUS.md), [REQUIREMENTS](REQUIREMENTS.md), [LESSONS-LEARNED](LESSONS-LEARNED.md).
'''
(root/'docs/M5_FINAL_REPORT_20261019.md').write_text(report,encoding='utf-8')
note='**M5 acceptance utama ditutup,19 Oktober2026:** C32 host58PASS159s/analyzer'+analyze+'s No issues; Poco2/DV2 UI native PASS. Audit before/after/final mengautentikasi13arsip,8snapshot worker/23tabel bisnis, strict interval seluruh tabel+policy+arsip sama, startup/alert metadata diperiksa. Disconnected/Off/targetnull; nol work M5 pending pada snapshot sesudah cleanup. Exact originalAPK6 fixture kembali tanpa launch; ordinary/legacy/campaign/ekspor hash terpelihara dan DV awake/APK asal pulih. Manual D-MAN17 dan pembatalan tambahan tetap reported, diverifikasi native terpisah. M5 selesai pada cakupan tersedia; natural21/reboot/Doze/revoke nyata/80mm/OEM/TalkBack dan batas lain tetap UNVERIFIED. M6 tidak dimulai. [Laporan akhir](M5_FINAL_REPORT_20261019.md).**'
for name in ['STATUS.md','PLAN.md','REQUIREMENTS.md','M5_POCO_MANUAL_TEST.md']:
 p=root/'docs'/name;t=read(p);i=t.index('\n')+1;p.write_text(t[:i]+'\n'+note+'\n\n'+t[i:].lstrip('\n'),encoding='utf-8')
for name in ['M5_TEST_REPORT.md','M5_IMPLEMENTATION_REPORT.md','M5_PERSISTED_WORKER_STATUS_C32.md']:
 p=root/'docs'/name;p.write_text(read(p).rstrip()+'\n\n'+note+'\n',encoding='utf-8')
p=root/'docs/M5_FIXES_AND_VALIDATION.md';t=read(p).replace('Fixed host scope; native/build/closing pending.', 'Fixed host58/native2per device/build3/3-role13archive closing PASS; exact original v6 restored.');p.write_text(t,encoding='utf-8')
p=root/'docs/REQUIREMENTS.md';lines=read(p).splitlines()
current_status={
 'R01-005':'Implemented; optional disconnected local operation, real OAuth/manual Drive restore and controlled headless8/retention7 verified on documented scopes. No sync. Natural21/revoke/other-origin/cross-device Google remain unverified.',
 'R03-003':'Implemented; management PIN/restore re-lock and notification tap gate PASS automatic and user-reported scopes. Closing uses public fixture PIN only; no ordinary credential access.',
 'R08-013':'Implemented; printing follows committed sale. Physical first/copy/failure/reconnect plus independent two-sale stock/HPP/debt audit PASS on Poco58mm. Partial-write/paper-out/80mm physical unverified.',
 'R09-008':'Implemented with per-batch remaining quantity/calendar window and alert evaluation/dedup tests; default5days/config preserved. Low-stock OS manual delivery PASS; actual dated-expiry OS delivery not separately verified.',
 'R13-003':'Implemented; real A manual/restore/controlled worker/retention and B read-only separation PASS scoped; D-MAN17 disconnect confirmed native; final13archive/3-role audit and original v6 restoration PASS. See final report for unverified scenarios.',
 'R13-004':'Implemented; real appDataFolder OAuth/upload/list/download/restore on integration identity, B0/A-file unavailable separation PASS; local export retained. Ordinary distribution OAuth/runtime not installed or validated.',
 'R13-005':'Implemented; explicit consent/defaultOff, manual On/Off/change-account/disconnect PASS reported; native disconnected guard and post-cleanup no M5 pending work PASS. Prior live OS cancellation transition/in-flight switch unverified.',
 'R13-006':'Implemented; calendar/UTC/DST/catch-up/retry and schedule projection verified; real headless8 uploads after controlled trigger PASS. C31 needs-auth boundary/C32 persistent UI verified with SDK mocks/native SQLCipher. Natural21/reboot/Doze unverified.',
 'R13-007':'Implemented; real manual/8headless verified uploads and retention7 PASS; C32 persistent last automatic failure ID/EN/no raw code/PIN gate PASS. Other-origin real preservation and natural scheduler execution unverified.',
 'R13-008':'Implemented; unique8remote IDs/origin namespace/guard and retention scopes verified. Real other-origin baseline was0, so cross-origin preservation claim remains unverified; no sync implemented.',
 'R13-009':'Implemented setup documentation; integration OAuth/certificate/API configuration and real Google scopes verified. API-not-enabled was environment configuration; no invented credentials. Ordinary distribution signing/OAuth remains M6 validation.',
 'R13-017':'Implemented in main source/build; canonical64hex copy/PIN gate/manual paste-and-authentication PASS; public native sensitive metadata3true. OEM preview masking unverified after user clarification. Exact original fixture v6 now restored intentionally.',
 'R16-016':'Implemented; local SAF and real Drive restore user-reported plus independent native safety/business23/logo verification PASS; closing13archives authenticated. Physical power-loss during restore unverified; failure recovery covered by isolated fault tests.',
 'R16-017':'Implemented/tested on isolated migration/domain fixtures and documented permission-denial/configuration/manual scopes. Ordinary DB deliberately not migrated during tests. Further OEM/accessibility/distribution scenarios remain unverified.',
 'R16-018':'M2 PIN/session and M5 opt-in/worker/restore sanitization verified on documented scopes. Final offline legal documents/content/consent publication work in M6 remains pending; no M6 completion claim.',
}
for n,line in enumerate(lines):
 parts=line.split('|')
 if len(parts)>7 and parts[1].strip() in current_status:
  parts[-2]=' '+current_status[parts[1].strip()]+' '
  parts[-3]+='; C32 host58/native2per device/13archive3-role audit; [final report](M5_FINAL_REPORT_20261019.md) '
  lines[n]='|'.join(parts)
 elif line.startswith('| M5-DRIVE |'):
  lines[n]=line.rstrip()[:-1]+' C32 closing: host58/native2per device/build3/13archives authenticated/3-role data audit PASS; D-MAN17 disconnected native confirmed; exact original v6 restored, no M5 pending work at cleanup snapshot; see M5_FINAL_REPORT_20261019 for unverified limits. |'
p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('M5 primary acceptance closed with explicit limits; all14 handovers control Off/original restored/closing complete; M6 not started')
