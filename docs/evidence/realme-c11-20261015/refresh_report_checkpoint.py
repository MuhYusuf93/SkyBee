"""Refresh observed progress without converting unfinished checks into PASS."""
from pathlib import Path

path = Path(__file__).resolve().parents[2] / 'REALME_C11_FINAL_M1_M4_TEST_REPORT.md'
text = path.read_text(encoding='utf-8')
updates = {
 'RC-01': '11 PASS sebelum/sesudah backend; post-pin-realme/database_test.log',
 'RC-02': '14 PASS sebelum/sesudah backend; post01:50; KDF asli600k/256, post-pin-realme/management_inventory_test.log',
 'RC-03': '30 PASS sebelum/sesudah backend; post00:52, post-pin-realme/cashier_sql_test.log',
 'RC-04': '14 PASS sebelum/sesudah backend; post01:17, post-pin-realme/wholesale_packaging_sql_test.log',
 'RC-05': '24 PASS sebelum backend; regresi pascaperubahan 24 PASS/02:08, post-pin-realme/reports_corrections_sql_test.log',
 'RC-06': '10 PASS sebelum dan sesudah backend; retest01:01, post-pin-realme/m4_storage_test.log',
 'RC-07': '6 PASS sebelum dan sesudah backend; retest02:16, post-pin-realme/locale_currency_test.log',
 'RC-08': '8 PASS sebelum/sesudah backend; bugfix7post02:07 +protected1post00:15',
 'RC-09': '4 PASS sesudah backend; management rawFAIL02:32, helper retestPASS01:09; cashier2/locale1PASS; bukan fisik',
 'RC-10': '7 PASS sesudah backend, grosir1/gaps4/laporan2; dua rawFAIL awal tetap disimpan',
 'RC-11': 'Windows/native suite2kasus PASS; retest native sesudah backend00:25; pelunasan tidak mengulang laba',
 'RC-12': 'Windows/native suite2kasus PASS sebelum/sesudah backend; exact333333+666667micros dan sold-out value0',
 'RC-13': '1 PASS/01:25; rawmetadata/plans/5samples di medium-benchmark.json; bukan release/SLA',
 'RC-14': 'Baseline profile serial PASS untuk draft/commit/retry/3cold+3warm; setelah backend dan release pending',
 'RC-15': 'KDF Dart26,10s vs native3,06–3,08s (5sampel); debugPSS209MiB satu snapshot; actual cycles pending',
 'RC-18': 'Process restart profile baseline PASS; lockscreen fisik dan release akhir belum diperiksa',
}
lines = text.splitlines()
for i, line in enumerate(lines):
    for key, actual in updates.items():
        if line.startswith('| '+key+' '):
            cells = line.split('|')
            cells[-2] = ' '+actual+' '
            lines[i] = '|'.join(cells)
text = '\n'.join(lines)+'\n'
text = text.replace('Source baseline/build configuration/lockfile dipertahankan.',
                    'Baseline sumber/build configuration/lockfile direkam; perubahan terbatas dicatat di bawah.')
start = text.index('## Temuan dan diagnosis')
end = text.index('## Batas dan pekerjaan berikutnya', start)
findings = '''## Temuan dan diagnosis

### RC-F01 — APP: verifikasi PIN terlalu lambat di ARM32

Gejala: KDF debug awal26.388ms; sampel referensi Dart terisolasi sesudahnya26.102.985µs. Pipeline profile committed-recovery sekitar39s mencakup KDF dan operasi lain (bukan waktu PIN murni). Setup profile pertama82,906s mencakup tiga derivasi dan seed. Fungsi tetap benar, tetapi jeda pengelolaan sangat panjang.

Penyebab yang dibuktikan: derivasi PBKDF2/HMAC sendiri memakan waktu besar pada implementasi Dart/target ini; stopwatch derivasi dipisahkan dari DB. Implementasi OS SecretKeyFactory dan loop JavaMac tetap sekitar18s/21s, sehingga tidak dipilih. Tidak menyimpulkan usia perangkat atau kerusakan OS sebagai penyebab.

Perbaikan: PinHasher memakai Mbed TLS3.6.7 terpin/checksum/lisensi melalui MethodChannel serial background queue dan satu JNI call untuk seluruh KDF. Hanya empat implementation units dikompilasi; parameter600k–2m/256bit, UTF8, random salt, domain PIN/recovery, verifier DB, CAS, lockout, session dan aturan uang tetap. Backend unavailable memakai Dart asli di isolate dengan parameter sama; error derivasi tidak menghasilkan dummy.

File aplikasi penting: `lib/features/management/application/pin_hasher.dart`; `android/app/src/main/kotlin/com/example/kasir_app/MainActivity.kt`; `android/app/build.gradle.kts`; `android/app/src/main/cpp/{CMakeLists.txt,pin_kdf.c,pin_crypto_config.h}` serta vendor/provenance/license. IntegrationActivity mewarisi MainActivity supaya pengujian memakai backend produksi yang sama. Tidak ada migration/schema/finance/source identity berubah.

Bukti sesudah: empat kontrak native PASS/01:04, backend available/mainThreadfalse, lima vektor hashlib independen (ASCII/recovery/UTF8/empty/long dengan600001rounds), parity Dart, penolakan parameter dan unlock verifier lama tanpa mengganti salt/verifier. Lima native sampelµs:3070947,3082258,3067709,3064156,3062998; unlock DB lama3203660µs. Log `native-pin-mbedtls-attempt3.log`. Windows179PASS/2opt-inSKIP/01:24. **Status: fungsi/kompatibilitas terbukti, regresi perangkat dan profile/release akhir masih berjalan.** Sekitar3s masih merupakan jeda nyata; tidak menjanjikan PIN instan atau SLA baru.

### RC-F02 — TEST/ENV: target tap UI M3.1 tidak menerima pointer

Gejala: original dan attempt2 FAIL pada tapcenter(180,405), checkbox grosir tidak berubah. Assert jumlah200/receive40/count200/biaya600000000000 micro-minor (IDR600.000) sudah tercapai; kegagalan bukan commit keuangan parsial.

Perbaikan di `integration_test/wholesale_packaging_ui_test.dart`: guard hitTestable, ensureVisible terpusat bila perlu, bounded realframe wait, assert mode segera sesudah tap dan tetap setelah scan. Tidak mengurangi invariant stok/biaya/harga. Attempt3 PASS02:05/exit0. Tidak ada markerM31_HIT_WAIT pada PASS; cabang tunggu/scroll tidak terbukti dieksekusi dan penyebab internal overlay/timing belum dipastikan. **Status: retest helper PASS, diagnosis internal terbatas; bukan klaim bug aplikasi atau OS telah diperbaiki.** Regresi akhir pada backend baru pending.

### RC-F03 — TEST/ENV: helper dan urutan instalasi

Helper acceptance Windows awal gagal import/dispose API dan mencoba membaca HPP dari DTO publik yang memang tidak mengeksposnya. Helper diperbaiki membaca snapshot SQL fixture terisolasi; DTO publik tidak dibuka. Retest dua kasus PASS Windows/native.

Probe profile pertama dimulai sebelum build/install selesai dan tidak menemukan ownPID; rawfailure/timestamp disimpan (`runtime-profile-too-early.json`, `runtime-install-overlap-times.json`). Retry serial profile PASS. Ini kesalahan urutan workflow yang terbukti, bukan bukti aplikasi crash. Dua build awal backend gagal header transitif sebelum instalasi; header resmi dilengkapi dan build/native tests kemudian PASS. Analyzer dua unnecessary_import diperbaiki; retest Noissues5,3s. **Status helper/build: diperbaiki; raw gagal tidak dihapus.**

Tidak ada SKIPPED_SYSTEM berdasarkan usia perangkat. Expected SQLite fault-injection error/migration rollback dipisahkan dari crash. UNKNOWN tetap UNVERIFIED_CAUSE/BLOCKED_ENVIRONMENT; hasil historis perangkat lain tidak membuktikan kesehatan Realme.

## Performa dataset menengah

SQLite3.28.0, journaltruncate,1827pages×4096byte.1000produk/2000sales/items/stockledger,600payments; seed62704ms dan index19915ms di luar query samples. Satu warmup/lima sampel; anchor primary-key, tanpa OFFSET. Median queryms: katalog awal10,984/lanjut10,850/jauh5,380; history13,056/12,583/jauh1500=12,097; reportdetail11,937/12,235/jauh1500=13,032; commonsearch85,224; monthlysummary84,908. Plans/rawsamples tersimpan `medium-benchmark.json`. Ini debug/service, belum latensi keyboard/render/debounce, release atau klaim100kRealme. Profile/release smallfixture dan pengamatan memori route sedang disiapkan.

'''
text = text[:start]+findings+text[end:]
path.write_text(text,encoding='utf-8')
print('Report progress refreshed; unfinished checks remain explicit.')
