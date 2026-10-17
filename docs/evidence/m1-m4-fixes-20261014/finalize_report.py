"""Finalize the interrupted audit report without deleting historical results."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent

def read(name):
    return (root / 'docs' / name).read_text(encoding='utf-8-sig')

def write(name, value):
    (root / 'docs' / name).write_text(value, encoding='utf-8', newline='\n')

def replace_once(value, old, new):
    assert value.count(old) == 1, (old[:80], value.count(old))
    return value.replace(old, new, 1)

report = read('M1_M4_BUGFIX_REPORT.md')
old = report.split('\n')[2]
report = replace_once(report, old, 'Status akhir 15 Oktober 2026: pekerjaan implementasi, regresi yang tersedia, dan pelaporan audit selesai. Lima kelompok bug aplikasi ditutup pada kasus yang direproduksi. Pengujian dilakukan 14 Oktober; finalisasi dokumen dan pemeriksaan statis terakhir dilakukan 15 Oktober. Windows173, Poco128, DV74 dan emulator30 kasus fungsi unik lulus; cakupan tiap perangkat berbeda dan retry tidak dijumlahkan. Gangguan transport/runner serta acceptance hardware yang belum terbukti tetap dicatat di bawah. Dokumen ini melengkapi, bukan mengganti, bukti historis. M5/M6 tidak dimulai; aturan bisnis, versi skema, nama aplikasi dan applicationId produksi dipertahankan.')
report = replace_once(report, '- Status: CLOSED pada kasus yang direproduksi; Windows/Poco/DV/emulator regresi baru lulus. Kasus management/IDR cashier yang dahulu gagal pada DV juga lulus di run baru.\n\n### FIX-03', '- Status: CLOSED pada race yang direproduksi; Windows/Poco/DV/emulator regresi competing instances lulus. Regresi PIN Poco14 kasus lulus; DV14 kasus unik tercakup melalui12 kasus run terputus dan dua retest terfokus, bukan satu runner penuh yang lulus.\n\n### FIX-03')
report = replace_once(report, 'Sesudah: retest dan regresi sedang berlangsung.', 'Sesudah: retest dan regresi selesai.')
report = replace_once(report, '- Status: CLOSED pada kasus service boundary yang direproduksi; Windows/Poco/DV lulus. Emulator suite ini belum menghasilkan reporter sebelum runner dihentikan, sehingga tidak dianggap lulus.', '- Status: CLOSED pada kasus service boundary yang direproduksi; Windows/Poco/DV/emulator lulus. Retest emulator independen1PASS/00:09 (`emulator-independent-protected_reads_test.log`) menggantikan status belum terverifikasi pada run handshake yang dihentikan; failure/interruption lama tetap disimpan.')
report = replace_once(report, '| Emulator | API37 Pixel_7: final regresi baru7PASS/01:20 (3SQL+4UI); protected-read suite berikutnya tertahan setelah install sebelum reporter, run dihentikan/RunnerExit130. VMResume/empty stack, Awake/focus fixture; bukan assertion aplikasi gagal. Main/journal ordinary hashes sama (`emulator-ordinary-before/after.log`) |', '| Emulator | API37 Pixel_7:30functionalPASS unik (15SQL/Provider+15UI): regresi7, database11, managementUI1, cashierUI2, localizationUI1, wholesaleUI1, M31gaps4, M4UI2, protected-read1. Retest independen, bukan satu all-pass runner. Cold minimal frame1PASS adalah diagnosis terpisah, tidak menambah30. Main/journal ordinary sama sebelum/sesudah/final |')
report = replace_once(report, '| DV native | ManagementUI1 +cashierUI2 +regresi baru7 +protected-read1 PASS (`dv-native.log`). ManagementSQL12 kasus selesai sebelum ADBoffline; ulang penuh terputus setelah3, tidak dijumlah ulang. Dua kasus belum selesai/remaining suites diulang independen. Build/log akhir pending |', '| DV native |74functionalPASS unik (59SQL/Provider+15UI): managementUI1, cashierUI2, regresi7, protected-read1, managementSQL14, cashierSQL30, database11, localizationUI1, wholesaleUI1, M31gaps4, M4UI2. Management14 diperoleh dari12 sebelum offline +pagination1 +migration1; retry3 tidak dihitung. Raw transport failures tetap, bukan satu all-pass runner |\n| DV benchmark |1mediumbenchmarkPASS/exit0/01:07,1kproduk/2kpenjualan; far catalog4,568ms/history9,809ms/report10,326ms/search65,545ms/monthsummary60,244ms. Debug/1warmup+5samples, bukan benchmark100k native/release/peakRAM. `dv-benchmark-final.log`, `dv-benchmark-data.json` |\n| Finalisasi statis |`format-final-6.log`:142files0changed/0,58s/exit0. `analyze-final-6.log`:hasil akhir dicatat setelah proses selesai. Audit localization367IDENkeys/287refs/244originalIDs; syntax Python tools dan PowerShell runner diperiksa |\n| Build biasa |DebugPASS17,5s; releasePASS38,0s/53,7MB. Salinan `build/bugfix-20261014/ordinary-debug.apk` dan `ordinary-release.apk`; aapt IDcom.example.kasir_app/labelkasir_app/version0.4.0+6/MainActivity. IntegrationActivity absent pada seluruhDEX keduanya, tidak diinstall pada perangkat (`ordinary-artifact-verification.json`) |\n| Guard negatif |Build entrypoint integration tanpa flagisolasi ditolak Gradle, expectedexit1, tanpa installattempt (`isolation-negative-build-result.json`). Ini build negatif terkontrol, bukan bare integration test pada package operasional |\n| Isolasi akhir |Poco main507904bytes SHA989aa556…/journal512 SHA076a27c7… tetap sebelum/sesudah128kasus. Emulator main471040 SHA bad683d0…/journal0 SHAe3b0c442… tetap sebelum/sesudah/final. OrdinaryPID absent/noWAL pada baseline. DVordinary package absent awal/akhir, bukan DBpreservation |\n| Cleanup/log |Hanya fixture milik run ini dalam sandbox.integration dibersihkan;8file emulator tepat tercatat `emulator-owned-cleanup.json`, inputfixtureDV tepat dibersihkan. DBdiruji DV/emulator kosong akhir, APKtestretained/PIDstopped.15snapshotPID:tanpa fatal pada rentang buffer yang diperiksa; bukan seluruhlogbebaswarning (`scoped-log-summary.json`) |')
report = replace_once(report, 'Kasus tersebut dan suite yang belum berjalan tetap UNVERIFIED sampai retest.', 'Retest independen protected-read1PASS/00:09 menyelesaikan kasus ini. Suite independen lainnya selesai sesuai tabel30kasus. Penyebab internal handshake belum dapat dipastikan; tidak diklaim sebagai bug aplikasi atau defect engine yang sudah diperbaiki.')
report += '''
**TEST-FRAME-02 — fixture UI lama dan frame starvation intermiten.** ManagementUI emulator semula timeout5menit; cashierUI timeout5menit lalu binding cascade. Fixture kini membuat surface pertama sebelum persiapan dan membungkus IO SQLite persiapan dalam `tester.runAsync`; management1PASS/00:33, cashier2PASS/00:34, localization1PASS/00:23. File terkait: `integration_test/management_ui_test.dart`, `cashier_ui_test.dart`, `localization_ui_test.dart`, `wholesale_packaging_ui_test.dart`; gate/KDF dan seluruh assertion bisnis tetap. Wholesale masih timeout7menit baik warm-only maupun warm+real-IO; diagnosis kelas widget menunjukkan ProductForm/Inventory sudah dibangun, sehingga failure itu tidak terbukti berhenti pada first pump. Phase markers aman ditambahkan untuk pump/wait/tap/fill. Kasus yang sama kemudian PASS/00:40 dan repeatPASS/00:41 (`emulator-wholesale-phase-repro.log`, `emulator-wholesale-repeat.log`), tetap dihitung satu kasus unik. Mitigasi urutan fixture dan dua repeat terbukti; penyebab internal frame starvation intermiten belum ditetapkan. Tidak menonaktifkan exception, mengubah validasi produk atau menyimpulkan GPU/engine rusak.

**ENV-ADB-02 — penyelesaian kasus DV.** Pagination dan migration retest terfokus masing-masing1PASS melengkapi14kasus management unik. CashierSQL30PASS/00:39 dan database11PASS/00:12 selesai. LocaleUI gagal missing Cari saat Dreaming (`dv-locale-ui-final.log`); pengguna mengaktifkan layar melalui remote, ownactivity uji dibawa ke depan tanpa mengganti sistem/screensaver. Retest1PASS/01:22 (`dv-locale-ui-retest.log`). Satu antrean sebelumnya kedaluwarsa20menit menunggu runner emulator sebelum build/install DV, bukan failed native assertion; requeue berhasil. WholesaleUI1, M31gaps4 dan M4UI2 lulus. Konfirmasi layar aktif hanya availability, bukan manual acceptance skenario.

## Cakupan akhir dan keputusan arsitektur

Tujuh file aplikasi pada FIX-01–05 berubah. Provider tetap memiliki state layar; commit dan otorisasi tetap di service/coordinator SQL. CAS menjaga credential race tanpa menahan transaksi selama KDF. Pembacaan terproteksi memeriksa akses di batas antrean dan sesudah IO. Slivers/dialog scrollable menjaga kontrol terlihat tanpa memuat seluruh katalog. Tidak ada perubahan skema, rumus uang/HPP, aturan stok, checkout/reversal, harga grosir/dus atau pagination; regresi memeriksa snapshot, integer precision, atomisitas, retry, saldo, FK dan cursor tetap. Baseline90file:81 sama,7filelib diperbaiki,2delta routing Android berasal dari pengujian DV sebelumnya (`source-change-audit.json`). `tools/test_android.ps1` hanya menambah NameFilter satu suite; isolasi package/flag/AAPT/--no-uninstall tetap.

Windows173kasus dan Poco128 mencakup suite fungsi lengkap yang tersedia pada masing-masing target. DV74 merupakan validasi baru terpilih, bukan pengulangan seluruh118PASS historis; reportsSQL24, wholesaleSQL14, localizationSQL6 dan storageSQL10 tidak diulang penuh pada DV dalam audit ini, tetapi diregresikan Windows/Poco. Emulator30 juga subset. Semua15kasus syntheticUI akhir tercakup pada Poco/DV/emulator. Angka lintas platform tidak dijumlah sebagai kasus unik produk; focused/repeat bukan tambahan kasus.

Masing-masing bukti waktu/exit/retry tercantum di `suite-evidence-index.json` dan README folder evidence. Log source/PID dibatasi dan jalur auth VM sementara disunting dari bukti baru; tidak ada PIN/token/data pengguna disalin ke laporan. Ordinary DB hanya dibaca metadata/hash; tidak direset, dihapus, diinstall ulang, dibuka atau diinisialisasi dalam audit ini. Hash cocok membuktikan byte retention pada baseline itu saja. Insiden kehilangan data lama M3.1 tetap missing/unrecovered; cleanup fixture bukan restore.

## Batas yang masih terbuka dan pekerjaan berikutnya

- MAN-USER-01: alur emulator/HP dilaporkan berjalan baik oleh pengguna sebelum audit, tanpa rincian skenario. Ini bukti manual historis, bukan hasil otomatis baru.
- UNVERIFIED: keyboard OEM/clipboard/scanner fisik, TalkBack (DV package absent/BLOCKED), seluruh alur runtime release, reboot/powerloss, peakRAM dan seluruh dataset/perangkat. Build release memakai signing pengembangan dan bukan acceptance Play/release.
- OPEN diagnosis lingkungan: penyebab ADBoffline DV dan frame starvation/handshake emulator intermiten belum terbukti. Retest kasus tersedia lulus; raw kegagalan tidak dihapus dan stabilitas semua kondisi tidak diklaim.
- OUT OF SCOPE: printer Bluetooth, Google Drive, backup/restore operasional dan pekerjaan M5/M6. Tidak ada keputusan produk baru yang diperlukan untuk lima perbaikan ini.

Audit/perbaikan yang dapat diverifikasi selesai; berhenti untuk review dan tambahan pengujian pengguna. Hardware atau acceptance yang belum diuji tetap memerlukan bukti terpisah sebelum dinyatakan lulus.
'''
write('M1_M4_BUGFIX_REPORT.md', report)

status = read('STATUS.md')
old = status.split('\n')[2]
status = replace_once(status, old, '''**Audit/perbaikan M1–M4 termasuk M3.1 selesai — finalisasi 15 Oktober 2026, pengujian 14 Oktober.** Lima kelompok bug diperbaiki: hasil pelunasan setelah Provider disposal, race rotasi PIN, header inventory/master pada viewport pendek, preview pelunasan, dan protected reads setelah sesi dicabut. Windows173fungsiPASS +2benchmarkPASS (dua opt-in SKIP pada run fungsi); Poco128fungsiPASS; DV74fungsiPASS +1benchmarkmenengahPASS; emulator30fungsiPASS. Angka adalah kasus unik pertarget, tanpa menjumlah retry; DV/emulator subset, bukan satu all-passrunner. Build biasa debug/releasePASS dan ID/launcher/DEXguard diverifikasi, APKtidak diinstall ordinary. Format142files0changed; analyze akhir dicatat pada laporan. Localization367keys/287refs/244stableIDs dan syntaxtoolsPASS. Main/journal ordinary Poco dan emulator sama sebelum/sesudah; DVordinaryabsent awal/akhir. Hanya fixture sandbox.integration dibersihkan, tanpa reset/uninstall/open ordinary, perubahan aturan bisnis/schema/identitas atau M5/M6. [Laporan akhir](M1_M4_BUGFIX_REPORT.md), [indeks bukti](evidence/m1-m4-fixes-20261014/README.md).

Bug yang direproduksi CLOSED; penyebab internal frame starvation/handshake emulator dan transportoffline DV masih belum pasti meski retest kasus lulus. Keyboard/scannerOEM, TalkBack, fullrelease, reboot/powerloss, peakRAM dan restore tetap UNVERIFIED/BLOCKED sesuai laporan. MAN-USER-01 tetap manual historis; layar/HP tersedia bukan acceptance. Berhenti untuk review/tambahan pengujian pengguna. **Riwayat di bawah mencatat hasil pada waktunya dan tidak menggantikan checkpoint akhir ini.**''')
write('STATUS.md', status)

requirements = read('REQUIREMENTS.md')
requirements = replace_once(requirements, '**Bukti aktif audit/perbaikan M1–M4 termasuk M3.1 — 14 Oktober2026.** Histori klausul/bukti tidak dihapus; FIX-* melengkapi requirement yang sama.', '**Bukti akhir audit/perbaikan M1–M4 termasuk M3.1 — finalisasi15Oktober2026, pengujian14Oktober.** Histori klausul/bukti tidak dihapus; FIX-* melengkapi requirement yang sama. Audit selesai pada cakupan yang tersedia; batas acceptance tetap dicatat.')
requirements = replace_once(requirements, 'seluruh regresi PIN Poco14PASS, DV transport partial/retry', 'regresi PIN Poco14PASS; DV14kasus unik via12partial+pagination1+migration1, bukan satu run penuh')
requirements = replace_once(requirements, 'CLOSED: Windows/Poco/DV PASS; emulator suite belum reporter/UNVERIFIED', 'CLOSED: Windows/Poco/DV/emulator PASS; emulator retestindependen1PASS/00:09, interruptedhandshakehistoris tetap disimpan')
requirements = replace_once(requirements, '| FND/M2/LC/M3/M31/M4 fungsi | Full Windows173PASS/2opt-in SKIP +2benchmark PASS; Poco128functionalPASS | Otomatis aktual, tanpa menjumlah retry/focused. DV/emulator coverage parsial sampai suite tersisa selesai |', '| FND/M2/LC/M3/M31/M4 fungsi | Windows173PASS/2opt-in SKIP +2benchmarkPASS; Poco128fungsiPASS; DV74fungsiPASS+1mediumbenchmark; emulator30fungsiPASS | Otomatis aktual tanpa retry/focused doublecount. DV/emulator subset selesai, bukan seluruhsuite/singleall-passrunner; batas per-suite pada laporan |')
requirements = replace_once(requirements, 'DV ordinary absent awal, akhir pending.', 'DV ordinary absent awal/akhir; DBdiruji DV/emulator kosong akhir, testAPKretained.')
requirements = replace_once(requirements, '| LC-09/M4-11 pemeriksaan kode | formatter141files0changed; analyzeNoissues7,2s;367IDENkeys/287refs/244stableIDs; PythonAST/PowerShellparse | PASS; finalordinary debug/release build dan identitas sedang berlangsung |', '| LC-09/M4-11 pemeriksaan kode | formatter142files0changed; analyze akhir15Oktober pada laporan;367IDENkeys/287refs/244stableIDs; PythonAST/PowerShellparse | PASS formatter/audit/syntax; ordinary debug17,5s/release38,0sPASS, IDcom.example.kasir_app/labelkasir_app/MainActivity dan IntegrationActivityabsent seluruhDEX; guardnegatif expectedbuildexit1/tanpainstall |')
requirements = replace_once(requirements, 'Bukti tambahan **DV8910 selesai dengan temuan,14Oktober2026**:', 'Histori sebelum perbaikan: bukti tambahan **DV8910 selesai dengan temuan,14Oktober2026**:')
write('REQUIREMENTS.md', requirements)

plan = read('PLAN.md')
plan = replace_once(plan, plan.split('\n')[2], '**Tahap audit/perbaikan M1–M4 termasuk M3.1 selesai, finalisasi15Oktober2026.** Lima kelompok bug direproduksi, diperbaiki dan diregresikan tanpa mengubah aturan bisnis/skema. Windows173/Poco128/DV74/emulator30fungsiPASS, benchmarkWindows2/DV1PASS, debug/releasebuild dan isolasi identitas/data diverifikasi. DV/emulator subset dan rawretry/failure tetap dicatat; hardware/acceptance belum terbukti serta diagnosis intermiten tetap terbuka. [Laporan akhir](M1_M4_BUGFIX_REPORT.md). Berhenti untuk review/tambahan pengujian pengguna; tidak memulai M5/M6. Milestone/instruksi historis di bawah tetap dipertahankan.')
write('PLAN.md', plan)

lessons = read('LESSONS-LEARNED.md')
lessons += '''

## Finalisasi audit — 15 Oktober 2026

40. Pada fixture native lama, tampilkan surface pertama sebelum seed dan jalankan IO nyata persiapan di `tester.runAsync`; regular setUp helper bersama dapat lebih tepat untuk autentikasi sebelum widget body. Jangan menerapkan satu pola secara buta. Management/cashier pulih, tetapi wholesale tetap sempat timeout7menit setelah kedua perubahan; diagnosis kelas widget membuktikan form sudah dibangun. Phase markers dan dua repeatPASS tidak membuktikan penyebab first-frame/GPU/engine. Pertahankan status diagnosis intermiten dan rawfailedruns.
41. Antrean serial native yang kedaluwarsa sebelum build/install bukan native assertion gagal. Catat timeout antrean terpisah, kemudian requeue suite independen. LocaleDV missingCari saat Dreaming juga bukan bukti terjemahan hilang; userwakeup hanya availability, retest1PASS memberi bukti kasus.
42. Setelah interupsi, cleanup memakai nama fixture/nonce/timestamp milik run yang sudah diverifikasi, package.integration dan ledger sebelum setiap penghapusan. Delapan file tepat emulator dibersihkan tanpa wildcard/pmclear/uninstall; ordinary hash tetap. Build guard negatif harus menolak sebelum install; APK biasa disalin dan package/launcher/seluruhDEX diperiksa. Bukti ini terbatas pada baseline/run yang diuji, bukan izin reset data masa depan atau klaim restore.
'''
write('LESSONS-LEARNED.md', lessons)

audit = json.loads((evidence / 'source-change-audit.json').read_text(encoding='utf-8-sig'))
audit['modified_native_test_fixtures'] = [
    'integration_test/management_ui_test.dart: first surface, real-IO language setup, phase markers',
    'integration_test/cashier_ui_test.dart: first surface, real-IO fixture seed, phase markers',
    'integration_test/localization_ui_test.dart: first surface before existing real-IO seed',
    'integration_test/wholesale_packaging_ui_test.dart: first surface, real-IO setup, pump/wait/tap/fill phase markers; business assertions retained',
]
(evidence / 'source-change-audit.json').write_text(json.dumps(audit, indent=2) + '\n', encoding='utf-8')
print('Finalized report, STATUS, REQUIREMENTS, PLAN, lessons and source audit; historical sections retained.')
