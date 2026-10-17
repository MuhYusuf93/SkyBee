# Initial import only. Never regenerate a reviewed matrix: preserve stable IDs,
# evidence and status when SPEC changes, then edit matching requirements in place.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $projectRoot 'docs/REQUIREMENTS.md'
if (Test-Path -LiteralPath $destination) { throw 'REQUIREMENTS already exists; update it in place.' }
$lines = Get-Content -LiteralPath (Join-Path $projectRoot 'docs/SPEC.md') -Encoding utf8
$result = [System.Collections.Generic.List[string]]::new()
$result.Add('# Matriks persyaratan')
$result.Add('')
$result.Add('Checkpoint M1, 12 Oktober 2026. ID Rss-nnn stabil mengikuti klausul sumber saat impor awal; jangan renumber saat SPEC berubah. Seluruh paragraf, bullet, langkah acceptance, dan baris kepemilikan Provider di SPEC disertakan, bukan hanya judul bagian. Satu klausul yang memuat beberapa kondisi harus memenuhi seluruh kondisinya sebelum verified. Kolom rencana bukan implementasi yang sudah tersedia.')
$result.Add('')
$result.Add('Status: pending = belum dikerjakan; partial = sebagian fondasi tersedia tetapi kebutuhan akhir belum terpenuhi; implemented = kode ada belum diverifikasi; verified = bukti pada lingkup yang dinyatakan; blocked/unverified = pemeriksaan belum dapat dibuktikan. Bukti Windows FFI dibedakan dari Android sqflite. Detail perintah/result: [VALIDATION-M1.md](VALIDATION-M1.md). M2–M6 tetap pending.')
$result.Add('')
$result.Add('## Bukti atomik fondasi M1')
$result.Add('')
$result.Add('| ID | SPEC | Persyaratan M1 | Implementasi | Bukti | Status |')
$result.Add('| --- | --- | --- | --- | --- | --- |')
foreach ($row in @(
  '| FND-01 | §1,2,17 | Flutter Android di folder utama, pertahankan dokumen | pubspec.yaml, android/, lib/main.dart | flutter create/doctor/build, VALIDATION-M1 | verified |',
  '| FND-02 | §2,16.21 | DI dan state scope; widget/Provider tanpa SQL/bisnis | lib/app/, features/foundation/, ARCHITECTURE.md | analyze, shell_test; inspeksi dependency | verified (shell M1) |',
  '| FND-03 | §5,10 | Integer rupiah/fixed-point biaya/overflow | core/domain/value_types.dart, SCHEMA.md | value_types_test, SQL integer CHECK | verified (value/storage, bukan moving average) |',
  '| FND-04 | §1,5 | UUID, quantity, UTC dan tanggal kalender | core/domain/value_types.dart | value_types_test | verified |',
  '| FND-05 | §2,14,16.22 | SaleTransaction/Item/tabel/FK konsisten | features/sale_history/domain/, data/database/schema.dart | database_contract_suite + items mapping | verified |',
  '| FND-06 | §8,14 | FK, constraint, snapshot, idempotency storage, rollback | data/database/, SCHEMA.md | database_contract_suite; bukan checkout service | verified (storage M1) |',
  '| FND-07 | §14,16.16 | Migration nyata v1→v2 tanpa kehilangan relasi | Schema.migrate, DatabaseCoordinator | reopen fixture disk + downgrade rejection | verified (versi proyek M1) |',
  '| FND-08 | §14,16.19 | Katalog composite keyset BINARY, 50+1, duplicate names | data/repositories/, catalog/domain/ | SQL suite nama duplikat/Unicode/prefix/final/filter | verified |',
  '| FND-09 | §14,16.19 | Riwayat keyset waktu/id, rentang, filter/batas atas sesi | data/repositories/, sale_history/domain/ | SQL suite timestamp duplikat/refresh/customer/[start,end) | verified |',
  '| FND-10 | §14,16.19 | Cache terbatas, load-more guard, reset dan async usang | core/pagination/paged_controller.dart | paged_controller_test; belum wiring layar M2/M4 | verified (helper) |',
  '| FND-11 | §14,16.20 | EXPLAIN query aktual tanpa OFFSET | keyset_queries.dart, schema index V2 | SQL suite first/continuation/prefix/customer; VALIDATION-M1 | verified (fixture kecil, bukan benchmark) |',
  '| FND-12 | §4,16.18 | Shell M3 dark/adaptive, pesan/error/retry, action pending | features/foundation/presentation/, app/theme.dart | shell_test ukuran sempit/tablet/landscape teks 2x + contrast | verified (shell, bukan UI final/TalkBack) |',
  '| FND-13 | §17 | Matriks, status, arsitektur, schema/setup/checkpoint | docs/, README.md | Dokumen dan perintah aktual di VALIDATION-M1 | verified |'
)) { $result.Add($row) }
$result.Add('')
$result.Add('## Klausul kebutuhan akhir SPEC')
$result.Add('')
$result.Add('| ID | Sumber | Persyaratan/kriteria penerimaan | Milestone | Implementasi atau lokasi rencana | Bukti aktual atau rencana pengujian | Status |')
$result.Add('| --- | --- | --- | --- | --- | --- | --- |')
$section = 0
$counters = @{}
$defaultMilestone = @{
  0='M1–M6'; 1='M1/M6'; 2='M1/M2–M6'; 3='M2/M6'; 4='M1/M2/M3/M6';
  5='M1/M2'; 6='M3'; 7='M3'; 8='M1/M3'; 9='M2'; 10='M2/M3/M4';
  11='M2/M3/M4'; 12='M5'; 13='M5'; 14='M1/M3/M4/M5'; 15='M6'; 16='M1–M6'; 17='M1–M6'
}
$plannedLocation = @{
  0='README.md; seluruh modul per PLAN'; 1='app/core/data; konfigurasi platform';
  2='app/; fitur/application, domain, presentation; docs/ARCHITECTURE';
  3='features/management; features/onboarding'; 4='presentation tiap fitur; app/theme';
  5='features/inventory; features/catalog; data/database'; 6='features/cashier/search, cart, draft';
  7='features/checkout; features/receivables'; 8='CheckoutService + repository executor dbTxn';
  9='InventoryService + batch/ledger repositories'; 10='Inventory/Checkout/ReportsService';
  11='ProtectedCorrectionService + append-only ledger'; 12='integrations/printer + ReceiptFormatter';
  13='integrations/backup + DatabaseCoordinator maintenance'; 14='paging/search/reports/notifications';
  15='legal assets/onboarding/settings + docs/release'; 16='unit/SQL/widget/integration/performance suites';
  17='docs/SPEC, PLAN, STATUS, REQUIREMENTS'
}
$plannedTest = @{
  0='Audit acceptance seluruh SPEC saat M6'; 1='Offline Android, konfigurasi/permission/platform target';
  2='Inspeksi dependency + test ownership/lifecycle/rebuild per fitur';
  3='PIN salt/KDF/rate limit/recovery/service auth/background/session + onboarding';
  4='Widget sempit/tablet/keyboard/text scale; manual TalkBack dan accessibility';
  5='CRUD unik/null/arsip/relasi/harga-stok; regression SQL';
  6='Scanner berulang/Enter, Le Minerale/alias/kategori, async usang, draft/undo';
  7='Mode pembayaran, pelanggan nama sama, saldo/alokasi/reversal piutang';
  8='Concurrent stok terakhir, fault tiap tahap, double submit/crash recovery';
  9='FEFO/tanggal kosong/batas hari, nonnegative, opname/ledger dan supplier NULL';
  10='Contoh §10, moving average/residu/snapshot + laporan seluruh periode';
  11='Undo intervening changes, dependency reversal, ledger/rekonsiliasi/arsip';
  12='Formatter/preview/failure/reprint + hardware Classic/BLE/58/80 sesuai pilihan';
  13='Snapshot WAL, isi/logo/checksum/archive invalid, fault restore/recovery, opt-in/OAuth';
  14='SQL plans + async/cache reset + FTS fallback + 10k/100k benchmark dan notifications denial';
  15='Offline legal/version/consent/backup OS/data controls; panduan resmi saat M6';
  16='Jalankan skenario acceptance klausul ini pada milestone pemilik';
  17='Audit dokumen checkpoint dan log perintah aktual, tanpa ekspansi milestone'
}
for ($i = 0; $i -lt $lines.Count; $i++) {
  $line = $lines[$i].Trim()
  if ($line -match '^## (\d+)\.') { $section = [int]$Matches[1]; continue }
  if (!$line -or $line.StartsWith('#') -or $line -match '^\|\s*-{2,}' -or $line -match '^\| State/controller') { continue }
  $clause = $line -replace '^(- |\d+\. )', ''
  if ($clause.StartsWith('|')) { $clause = ($clause.Trim('|').Split('|') | ForEach-Object { $_.Trim() }) -join ': ' }
  if (!$counters.ContainsKey($section)) { $counters[$section] = 0 }
  $counters[$section]++
  $id = 'R{0:D2}-{1:D3}' -f $section, $counters[$section]
  $source = '[§{0} L{1}](SPEC.md#L{1})' -f $section, ($i + 1)
  $milestone = $defaultMilestone[$section]
  $location = 'Rencana: ' + $plannedLocation[$section]
  $test = 'Rencana: ' + $plannedTest[$section]
  $status = 'pending'
  if ($section -eq 2 -or $section -eq 17) {
    $status = 'partial (M1)'
    $location = 'Fondasi: docs/ARCHITECTURE.md, SCHEMA.md, README.md; ' + $location
    $test = 'FND-02/05/13; ' + $test
  }
  if ($clause -match '^Siapkan kontrak repository') {
    $milestone='M1'; $location='catalog/domain, sale_history/domain, core/pagination';
    $test='FND-08/09/10'; $status='verified (M1)'
  }
  if ($clause -match '^Gunakan tabel `sale_transactions`') {
    $location='Fondasi FND-05; ' + $location; $test='FND-05; integrasi bisnis M3/M4 pending'; $status='partial (M1)'
  }
  if ($section -eq 14 -and $clause -match '^Aktifkan foreign key') {
    $milestone='M1'; $location='data/database, keyset_queries.dart';
    $test='FND-06/07; fixture v1→v2'; $status='verified (M1)'
  }
  if ($section -eq 14 -and $clause -match '^(Default halaman 50|Riwayat penjualan:|Katalog alfabetis:|Gunakan index komposit|SQL keyset dapat)') {
    $milestone='M1'; $location='data/repositories, schema V2';
    $test='FND-08/09/11 SQL suite'; $status='verified (query M1)'
  }
  if ($section -eq 14 -and $clause -match '^(Reset cursor|Untuk riwayat append-only|Gunakan cache halaman|Jangan memakai OFFSET)') {
    $status='partial (M1 helper/query)'; $test='FND-08/09/10/11; wiring fitur kelak pending';
    $location='core/pagination + data/repositories; ' + $location
  }
  if ($section -eq 16) {
    $number = 0
    if ($line -match '^(\d+)\.') { $number=[int]$Matches[1] }
    $milestone = switch ($number) {
      {$_ -in 1,3,5,6,7,9,10} {'M3'}
      {$_ -in 2,4,8,11,13} {'M2/M3'}
      12 {'M2/M3/M4'} 14 {'M5'} 15 {'M5'} 16 {'M1/M5'} 17 {'M2/M5/M6'}
      18 {'M1/M2/M3/M6'} 19 {'M1/M3/M4'} 20 {'M1/M4'} 21 {'M1–M4'} 22 {'M1–M4'}
      default {'M1–M6'}
    }
    if ($number -ge 18 -or $number -eq 16) {
      $status='partial (M1)'; $test='FND-02/05/07–12; skenario akhir pada klausul masih pending'
    }
  }
  $clause = $clause.Replace('|', '\|')
  $result.Add("| $id | $source | $clause | $milestone | $location | $test | $status |")
}
$result.Add('')
$result.Add('## Catatan coverage')
$result.Add('')
$result.Add('Klausul bertanda partial mempertahankan seluruh kebutuhan akhir. Fondasi struktur/schema tidak membuktikan CRUD, PIN, checkout, FEFO/HPP, piutang, agregat, hardware, backup, legal, ataupun rilis. Acceptance §16 tetap memiliki bukti baru pada milestone pemilik. Schema M1 menyediakan tempat data tahap berikutnya tanpa mengimplementasikan operasi tersebut. Koreksi status/bukti dilakukan setelah perintah aktual selesai; lihat STATUS untuk batas aktif dan hambatan.')
Set-Content -LiteralPath $destination -Value $result -Encoding utf8
Write-Output ('Imported {0} SPEC clauses with stable IDs.' -f (($counters.Values | Measure-Object -Sum).Sum))
