"""Publish observed automatic results; physical acceptance stays explicitly open."""
from pathlib import Path
import json

e = Path(__file__).resolve().parent
docs = e.parents[1]
totals = json.loads((e/'functional-totals.json').read_text())
metrics = json.loads((e/'metrics-summary.json').read_text())
actual = metrics['actual-release']
checkout = json.loads((e/'checkout-release.json').read_text())
assert checkout['passed'] and checkout['fixture_deleted'] and len(checkout['samples_us']) == 5
assert actual['completed'] and not actual['failures']
assert totals['post_pin_realme_core_count'] == 158
assert totals['post_pin_dv_count'] == 17
assert totals['post_pin_realme_unique_functional_count'] == 163
assert totals['after_cycles_integrity']['all_passed_reporter']
report = docs/'REALME_C11_FINAL_M1_M4_TEST_REPORT.md'
text = report.read_text(encoding='utf-8')
edits = {
    '**IN PROGRESS — belum merupakan penerimaan seluruh skenario.**': '**Pemeriksaan otomatis selesai; acceptance fisik masih terbuka.** Gboard/touch/TalkBack dan lockscreen belum dilaporkan pengguna; tugas keseluruhan belum diberi PASS.',
    '11PASS, native-database_test.log; expected injected migration error dipisahkan dari assertionfailure': '11PASS sebelum dan sesudah backend; post-pin-realme/database_test.log. Expected injected migration error dipisahkan dari assertionfailure',
    '14PASS/12:33, native-management_inventory_test.log; KDFdebug600k26388ms': '14PASS sebelum/12:33 dan sesudah/01:50; post-pin-realme/management_inventory_test.log. Baseline KDFdebug600k26388ms',
    '30PASS/00:53, native-cashier_sql_test.log': '30PASS sebelum/00:53 dan sesudah/00:52; post-pin-realme/cashier_sql_test.log',
    '14PASS/07:19, native-wholesale_packaging_sql_test.log': '14PASS sebelum/07:19 dan sesudah/01:17; post-pin-realme/wholesale_packaging_sql_test.log',
    '8 PASS sebelum backend; regresi pascaperubahan sedang berjalan': '8 PASS sebelum dan sesudah backend; post-pin-realme/{bugfix_regression_test,protected_reads_test}.log',
    '4 PASS sebelum backend; synthetic Flutter bukan bukti interaksi fisik; retest akhir pending': '4 PASS sebelum dan sesudah backend; managementUI original FAIL pointermiss lalu attempt2 PASS, dihitung sekali; synthetic Flutter bukan fisik',
    '7 PASS sebelum backend, termasuk satu wholesale retest; dua rawFAIL tetap disimpan; retest akhir pending': '7 PASS sebelum dan sesudah backend; dua rawFAIL grosir tetap disimpan, attempt3 dan postPIN PASS; narrow/wide/2x sintetis bukan font perangkat',
    'Windows/native suite2kasus PASS (host00:08/native01:50); retest pascaperubahan pending': 'Dua acceptance PASS Windows/native; postPIN native dua PASS/00:25, realme_acceptance_test.log; contoh pelunasan tidak menambah sale/HPP/laba',
    'Windows/native suite2kasus PASS; exact333333+666667micros dan sold-out value0; retest akhir pending': 'Termasuk dua acceptance tersebut: exact333333+666667 micro-minor, sold-out value0; postPIN PASS, tidak dihitung dua kali',
    'Baseline profile serial PASS untuk draft/commit/retry/3cold+3warm; setelah backend dan release pending': 'Baseline draft/restart/postcommit PASS; sesudah backend profile/release masing-masing4cold+3warm PASS, actual cashier release3cold+3warm/routecycles/relock PASS. runtime-*.json, actual-release.json',
    'KDF Dart26,10s vs native3,06–3,08s (5sampel); debugPSS209MiB satu snapshot; actual cycles pending': 'KDF Dart26,10s vs native3,06–3,08s; profile/release PIN dan actual release route PSS di tabel bawah. Tidak mengklaim peak atau tidak ada leak',
    'Process restart profile baseline PASS; lockscreen fisik dan release akhir belum diperiksa': 'Restart harness profile/release PASS; actual Android Home saat management unlocked lalu gate terkunci PASS. Release tanpa INTERNET permission tetap menjalankan alur lokal; airplane/lockscreen fisik NOT TESTED',
    'Preflight packageabsence verified; akhir belum diperiksa': 'Ordinary absent awal/akhir; build biasa3ABI/fixtureARM32 verified. Nonce fixtures dibersihkan pemilik suite; fixture manual tetap dipertahankan. Detail ledger/preflight akhir di bawah',
    '**Status: fungsi/kompatibilitas terbukti, regresi perangkat dan profile/release akhir masih berjalan.**': '**Status: CLOSED pada reproduksi KDF ARM32; 158core Realme, kontrak4, Windows179, DV17subset dan profile/release runtime lulus.**',
    'Regresi akhir pada backend baru pending.': 'Regresi wholesaleUI pada backend baru PASS01:22.',
    'Profile/release smallfixture dan pengamatan memori route sedang disiapkan.': 'Profile/release smallfixture dan routecycles aktual release selesai; angka serta batas metode di bawah.',
    'Poco belum terhubung pada discovery; DV dan emulator tersedia untuk regresi relevan jika perubahan domain diperlukan.': 'Poco dan emulator tidak terhubung pada discovery terbaru; runtime ARM64 terbaru belum terverifikasi. DV siap dan 17 kasus terkait backend/PIN lulus, bukan pengulangan seluruh suite DV.',
    'langkah manual akan diberikan pada package uji setelah otomatis selesai agar tidak bertabrakan.': 'paket release aktual dan langkah REALME_C11_MANUAL_TEST.md disiapkan setelah otomatis agar tidak bertabrakan.',
    'Status akhir belum ditetapkan.': 'Status keseluruhan: AUTOMATIC COMPLETE / MANUAL PENDING, bukan seluruh skenario PASS. Final integrity setelah interaksi manusia menunggu hasil pengguna.',
}
for before, after in edits.items():
    assert before in text, before
    text = text.replace(before,after)

text += '''

## Penutupan kelompok temuan tambahan

### RC-F04 — TEST/ENV: pointer Save pengelolaan belum hit-testable

PostPIN managementUI original FAIL02:32/exit1 pada tap180,524; harga15000 belum muncul dan form edit masih terlihat. Snapshot own UI/IMEfalse serta rect Save disimpan (management-ui-missed-tap.json). Pembelian/restock/average9000 sebelumnya telah lolos, bukan bukti kerusakan stok. Helper integration_test/management_ui_test.dart memakai bounded4s hitTestable wait, ensureVisible bila perlu, dan tetap mempertahankan warning serta seluruh assert harga/undo/background lock. Attempt2 PASS01:09/exit0, marker M2_HIT_WAIT benar-benar terjadi. Status CLOSED untuk target helper; overlay/transition internal tepatnya belum dibuktikan, tidak menyatakan bug Save aplikasi atau OS. Original FAIL tidak dihapus/dihitung sebagai PASS.

### RC-F05 — APP/BUILD: narrow APK mengiklankan ABI tanpa engine

Profile pertama setelah CMake build sukses tetapi gate ABI menolak sebelum install. KDF tiga ABI ikut dikemas sedangkan Flutter engine/app hanya ARM32. Dampaknya paket berpotensi dipilih pada ABI yang tidak mempunyai engine sesuai; bukan crash Realme yang telah diamati. Bukti profile-mixed-abi-rejected.json/build-smoke-profile-mixed-abi.log. Gradle kini membatasi kompilasi CMake sesuai target-platform Flutter, default universal tetap ARM32/ARM64/x64. Tidak menaikkan minSdk24 atau menghapus ABI produksi. Sesudahnya fixture profile/release ARM32 dan ordinary debug/release tiga ABI lulus AAPT, JNI exports, ELF LOAD16KiB, lisensi dan APK zipalign-P16; release native benar-benar dijalankan. Status CLOSED build/artifact dan ARM32 runtime; runtime ARM64 terbaru NOT TESTED, pemeriksaan ini bukan sertifikasi seluruh plugin/perangkat16KiB.

### RC-F06 — TEST/ENV: NotificationShade mengambil fokus

Profile sempat menyelesaikan empat cold lalu gagal guard sebelum warm: PID hidup, Awake, own mFocusedApp tetapi mCurrentFocus NotificationShade. runtime-profile-after-pin-focus-blocked.json/log dan profile-focus-failure-window.log disimpan. Pengguna menutup panel; retry profile lengkap empat cold/tiga warm + debounce + actual receipt PASS. Tidak ada input ke panel, perubahan sistem, atau SKIPPED_SYSTEM. Status RESOLVED external focus blocker; rawhelper UNVERIFIED_CAUSE pada percobaan semula tetap, bukan diagnosis crash atau OS rusak.

## Hasil otomatis setelah perubahan terakhir

Windows179PASS/2opt-inSKIP (windows-post-pin.log); Realme158core ulang17suite +4crypto +1integrity=163kasus fungsi unik, benchmark1terpisah. Sebelum backend juga158corePASS; jangan menjumlah sebelum/sesudah, retry, vektor dalam satu test atau pre/final integrity berulang. Ledger asli post-pin-realme/results.json tetap mencatat satu failed managementUI, retest terpisah. DV17subsetPASS terdiri1native-vector+14management+1protected-read+1CAS. Histori Poco128/DV74/emulator30 audit sebelumnya tetap historis; bukan hasil runtime backend baru pada semua target.

Integritas sebelum manual: schema7/quick_check ok/FK0/reconciled true, satu sale dan satu payment, penjualan36000/HPP27000000000micro-minor/profit9000000000micro-minor/pembayaran10000/piutang26000/stok17/nilai153000000000micro-minor. native-realme_integrity-pre-manual.log1PASS00:04/RunnerExit0. Actual cycles berikutnya membaca route/detail dan mengakui receipt ke draft baru; tidak mencatat sale/payment baru. Pemeriksaan setelah transaksi manual tetap pending, tidak dianggap lulus dari hasil sebelum manual.

## Sampel profile/release dan memori

Metode/sampel mentah: runtime-profile-before-pin-opt.json, runtime-profile.json, runtime-release.json, actual-release.json, metrics-summary.json. Cold berarti force-stop own process, bukan reboot/powerloss. Bandingkan tiga committed cold terakhir pada fixture/urutan pipeline sama; first cold setelah install disimpan terpisah. Pipeline mencakup unlock, DB, retry/reconcile dan lima query, bukan startup kasir normal atau waktu PIN murni. Warm menggunakan PID sama dan stage terakhir yang telah ada; bukan derivasi PIN ulang. Tanpa profiler/scrcpy/rekaman/forcedGC/mematikan aplikasi lain.

| Ukuran | Profile sebelum | Profile sesudah | Release sesudah |
| --- | --- | --- | --- |
'''
for label, key, div in [('Committed cold pipeline, median detik','cold',1),('Warm stage, median detik','warm',1)]:
    values = [metrics[n]['groups'][key]['stage_ready_seconds']['median'] for n in ['runtime-profile-before-pin-opt','runtime-profile','runtime-release']]
    text += '| '+label+' | '+' | '.join(f'{v:.3f}' for v in values)+' |\n'
text += '| PIN murni, median detik | Tidak dipisah baseline; Dart debug26,103s | '+f"{metrics['runtime-profile']['pin_us']['median']/1e6:.3f}"+' (n4) | '+f"{metrics['runtime-release']['pin_us']['median']/1e6:.3f}"+' (n4) |\n'
for label, field in [('Service exact-search, median ms','search_5_samples_us'),('Service report, median ms','report_5_samples_us')]:
    values = [metrics[n][field]['median']/1000 for n in ['runtime-profile-before-pin-opt','runtime-profile','runtime-release']]
    text += '| '+label+' | '+' | '.join(f'{v:.3f}' for v in values)+' |\n'
text += '| Provider search termasuk275ms debounce, median ms | Belum diukur | '+f"{metrics['runtime-profile']['debounced_search_us']['median']/1000:.3f}"+' (n5) | '+f"{metrics['runtime-release']['debounced_search_us']['median']/1000:.3f}"+' (n5) |\n'
text += '\nSemua query pada tabel smallfixture; raw ranges/samples tersimpan. Pencarian Provider bukan latensi keyboard/render. Benchmark medium terpisah di atas tidak diulang karena tidak ada perubahan SQL/domain. Tidak ada before/after checkout latency yang setara; timer awal tidak disimpan sebagai statistik yang cukup. Release checkout diukur terpisah satu warmup+lima sampel layanan submit/SQL: '+str(checkout['samples_us'])+'µs. Seed/persiapan cart/UI di luar stopwatch. Enam sale unik termasuk warmup direkonsiliasi (sales72000/HPP54000/profit18000/debt0/stock14); DBnonce dihapus helper pemilik, fixed manual DB tidak disentuh. Bukti checkout-release.json/pid-checkout-release.log; tidak mengarang SLA.\n\n'
text += 'Actual KasirApp release tanpa KDF otomatis: Activity TotalTime cold n3 '+str(actual['cold']['activity_total_ms']['samples'])+'ms, warm n3 '+str(actual['warm']['activity_total_ms']['samples'])+'ms. UIAutomator observation bound cold '+str([round(v,3) for v in actual['cold']['ui_observation_bound_seconds']['samples']])+'s, warm '+str([round(v,3) for v in actual['warm']['ui_observation_bound_seconds']['samples']])+'s; ini termasuk overhead alat.\n\n'
text += '| Snapshot route aktual release | PID | PSS KiB |\n| --- | --- | --- |\n'
for row in actual['memory']:
    text += f"| {row['tag']} | {row['pid']} | {row['pss_kib']} |\n"
text += '\nTiga siklus Gudang/Riwayat/Laporan, pembukaan detail yang tercatat pada actual-release.json, lalu kembali kasir; Home saat pengelolaan unlocked menampilkan managementLocked sesudah kembali. PSS sampel terbatas dengan heap/UI route berbeda, bukan peak/retained-heap profiler atau bukti tidak ada kebocoran. Tidak ada baseline before untuk routecycles yang setara; tidak mengklaim penghematan RAM.\n'
text += '''
## Build, log, isolasi, dan batas penutupan

Ordinary debug/release build PASS dan hanya disalin ke build/realme-c11-20261015, tidak dipasang. ID com.example.kasir_app/labelkasir_app/MainActivity, IntegrationActivity absent seluruhDEX, ketiga ABI/KDF/JNI/license verified. Fixture profile/release ARM32 memakai .integration/IntegrationActivity; APK actual release tersimpan immutable realme-cashier-release.apk dan apk-cashier-release-native-verification.json berisi hash. Release development signing; bukan Play/AAB/production signing. Release fixture tidak memiliki INTERNET permission; alur lokal dapat dijalankan tanpa izin jaringan, tetapi radio airplane/offline fisik belum diuji.

Sumber awal174fingerprints. Enam file lama sengaja diubah: Gradle, MainActivity, IntegrationActivity, PinHasher, managementUIhelper, wholesaleUIhelper; GeneratedPluginRegistrant dapat berubah otomatis mengikuti jenis build. File baru mencakup native/vendor/license/provenance, regression vectors, acceptance/integrity/performance probes dan helpers. Lihat source-check.json akhir; finance/schema/SPEC/pubspec tetap dibanding baseline. Vendor106file byte-identical resmi dan license asset identik. Format/analyze/gen-l10n/audit/guard/build akhir dicatat dalam log masing-masing; jangan menyamakan expected guard failure dengan test aplikasi gagal.

Log terbatas own PID/package: expected SQL migration/fault-injection/capability-probe error tidak ditafsirkan sebagai crash. Snapshot exit-info sebelumnya berisi USER REQUESTED akibat own force-stop; PID buffers parsial, tidak membuktikan seluruh sesi bebas error. Tidak ditemukan bukti baru kerusakan uang/stok/duplikasi/crash dalam assertions yang lulus. Tidak ada kasus diberi SKIPPED_SYSTEM berdasarkan umur HP. Sisa diagnosis internal pointer/first-frame historis tidak ditutup dengan dugaan OS.

Tidak ada reset/uninstall/open ordinary, perubahan firmware/system settings/root/aplikasi lain. Ordinary absent awal dan pemeriksaan akhir; bukan hash preservation DB yang tidak ada. Nonce fixtures dibersihkan oleh suite masing-masing; fixed realme_restart_20261015.db dan APK manual dipertahankan untuk review/uji pengguna (bukan sisa data pribadi). DV DBdir fixture kosong/ordinaryabsent akhir. Final read-only preflight ditempatkan subfolder final agar baseline174files tidak tertimpa. TalkBack awal disabled/font1,0; hasil akhir sebelum manual dan kebutuhan restore sesudah manual harus dibedakan.

Integritas diulang sesudah actual routecycles dan checkout probe: native-realme_integrity-after-cycles.log PASS1, sama kasusnya dengan pre-manual dan tidak ditambahkan ke163. Ini pemeriksaan penutup otomatis sebelum pengguna berinteraksi; pemeriksaan pascamanual belum dilakukan. APK actual cashier release dikembalikan melalui verifikasi hash/identity/JNI ulang dan direct install-r, tanpa uninstall. Screenshot cashier-release-ready.png dan launch-cashier-release-restored.log membuktikan kasir siap sebelum manual; bukan bukti input fisik.

Pengguna baru mengonfirmasi kesiapan perangkat dan panel ditutup, belum melaporkan PASS fisik. REALME_C11_MANUAL_TEST.md memuat langkah1–6; ketersediaan, screenshot, synthetic Flutter dan ADB bukan bukti Gboard/touch/TalkBack/lockscreen fisik. Setelah pengguna selesai: kumpulkan hasil per langkah, reproduksi failure aman bila ada, ulang integrity melalui safe runner lalu pulihkan APK release fixture yang telah diverifikasi. Jangan mengambil alih Realme selama interaksi manual.

M1–M4 dapat dilanjutkan untuk review berdasarkan regresi otomatis yang terbukti. Acceptance fisik tetap terbuka; reboot/powerloss, peakRAM/long-duration/leak analysis, runtimeARM64 terbaru, seluruh releaseflow, actualbackup/restore/printer/Drive M5 dan legal/productionrelease M6 belum terverifikasi atau di luar lingkup. Tidak memulai milestone berikutnya.
'''
report.write_text(text,encoding='utf-8')
print('Automatic report checkpoint written; physical acceptance remains pending.')
