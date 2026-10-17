import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/repositories/sqlite_product_repository.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/catalog/domain/product_repository.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';

// Runnable profile/release fixture, built only through test_android PrepareOnly.
// Both backends start from the exact same financial dataset. This is a modest
// latency comparison, not the historical 10k/100k capacity benchmark.
const nonce = String.fromEnvironment('M5_PERF_NONCE');
String id(int number) =>
    '00000000-0000-4000-8000-${number.toRadixString(16).padLeft(12, '0')}';
void check(bool condition) {
  if (!condition) throw StateError('performanceFixtureInvariant');
}

Future<Map<String, Object>> samples(Future<void> Function() operation) async {
  await operation();
  final values = <int>[];
  for (var n = 0; n < 5; n++) {
    final watch = Stopwatch()..start();
    await operation();
    values.add(watch.elapsedMicroseconds);
  }
  final sorted = [...values]..sort();
  return {'samples_us': values, 'median_us': sorted[2], 'max_us': sorted.last};
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KASIR_INTEGRATION_TEST') ||
      !RegExp(r'^[0-9]{1,20}$').hasMatch(nonce)) {
    throw StateError('isolatedPerformanceOnly');
  }
  final status = ValueNotifier<String>(
    'UJI COBA M5 — pengukuran data sintetis',
  );
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (_, value, _) => Text(value),
          ),
        ),
      ),
    ),
  );
  final root = await getDatabasesPath(), base = '$root/m5_perf_$nonce';
  final plainPath = '$base.plain.db',
      cipherPath = '$base.cipher.db',
      keyName = 'test-perf-$nonce';
  final resultFile = File('$base.result.json');
  DatabaseCoordinator coordinator(String path, {bool cipher = false}) =>
      DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        encryption: cipher ? EncryptedDatabase(path, keyName: keyName) : null,
      );
  final clock = StoreClock(now: () => DateTime.utc(2026, 10, 16, 3));
  try {
    check(!await File(plainPath).exists() && !await File(cipherPath).exists());
    final source = coordinator(plainPath);
    final seedApp = AppServices(source, clock: clock);
    await seedApp.management.configure(
      'Synthetic comparable performance',
      '0001',
      '0001',
    );
    await seedApp.management.unlock('0001');
    for (var first = 0; first < 1000; first += 100) {
      await source.transaction((dbTxn) async {
        final batch = dbTxn.batch();
        for (var n = first; n < first + 100; n++) {
          final name =
              'Synthetic performance item ${n.toString().padLeft(4, '0')}';
          batch.insert('products', {
            'id': id(n + 1),
            'sku': 'M5-PERF-$n',
            'name': name,
            'normalized_name': name.toLowerCase(),
            'compact_name': name.toLowerCase().replaceAll(' ', ''),
            'selling_price_rupiah': 12000,
            'stock_quantity': 1000,
            'inventory_value_micros': 9000000000000,
            'created_at': clock.milliseconds - 1,
            'updated_at': clock.milliseconds - 1,
          });
          batch.insert('stock_batches', {
            'id': id(10000 + n),
            'product_id': id(n + 1),
            'received_quantity': 1000,
            'remaining_quantity': 1000,
            'received_at': clock.milliseconds - 1,
          });
          batch.insert('stock_history', {
            'id': id(20000 + n),
            'product_id': id(n + 1),
            'kind': 'initial',
            'quantity_delta': 1000,
            'value_delta_micros': 9000000000000,
            'created_at': clock.milliseconds - 1,
            'reason': 'Synthetic performance initial',
          });
        }
        await batch.commit(noResult: true);
      });
    }
    var draft = await seedApp.cart.open();
    for (var n = 0; n < 250; n++) {
      draft = await seedApp.cart.add(draft.id, EntityId(id(1)));
      await seedApp.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(mode: PaymentMode.paid),
      );
      draft = await seedApp.cart.next(draft.id);
    }
    check((await seedApp.reports.reconcile()).consistent);
    await seedApp.search.suggest('synthetic performance');
    await source.close();
    final key = await const KasirPlatform().key(keyName, allowCreate: true);
    final exportSource = await EncryptedDatabase.openFile(plainPath, null);
    try {
      await EncryptedDatabase.quiesce(exportSource);
      await EncryptedDatabase.export(exportSource, cipherPath, key);
      final exported = await EncryptedDatabase.openFile(
        cipherPath,
        key,
        readOnly: true,
      );
      try {
        check(
          jsonEncode(await DatabaseValidation.fingerprint(exportSource)) ==
              jsonEncode(await DatabaseValidation.fingerprint(exported)),
        );
      } finally {
        await exported.close();
      }
    } finally {
      await exportSource.close();
    }
    final results = <String, Object?>{};
    for (final encrypted in [false, true]) {
      final path = encrypted ? cipherPath : plainPath;
      final metrics = <String, Object?>{};
      metrics['open'] = await samples(() async {
        final db = coordinator(path, cipher: encrypted);
        try {
          await db.read((db) => db.query('store_settings'));
        } finally {
          await db.close();
        }
      });
      final active = coordinator(path, cipher: encrypted);
      final service = AppServices(active, clock: clock);
      try {
        await service.management.unlock(
          '0001',
        ); // KDF excluded from query samples.
        final filter = CatalogFilter(),
            repository = SqliteProductRepository(active);
        final cursor = CatalogCursor(
          normalizedName: 'synthetic performance item 0899',
          id: EntityId(id(900)),
          filter: filter,
        );
        final period = await service.reports.period(
          CalendarDate('2026-10-01'),
          CalendarDate('2026-10-31'),
        );
        metrics['catalog_first'] = await samples(() async {
          check((await repository.page(filter: filter)).items.length == 50);
        });
        metrics['catalog_deep'] = await samples(() async {
          check(
            (await repository.page(
                  filter: filter,
                  after: cursor,
                )).items.length ==
                50,
          );
        });
        metrics['search'] = await samples(() async {
          check(
            (await service.search.suggest('synthetic performance')).isNotEmpty,
          );
        });
        metrics['summary'] = await samples(() async {
          check((await service.reports.summary(period)).saleCount == 250);
        });
        var next = await service.cart.open();
        metrics['checkout'] = await samples(() async {
          next = await service.cart.add(next.id, EntityId(id(1)));
          await service.checkout.submit(
            next.id,
            next.revision,
            const CheckoutInput(mode: PaymentMode.paid),
          );
          next = await service.cart.next(next.id);
        });
        check((await service.reports.reconcile()).consistent);
        if (encrypted) {
          final watch = Stopwatch()..start();
          final archive = await BackupService(
            active,
            service.management,
          ).create(headless: true, code: BackupService.newRecoveryCode());
          metrics['portable_snapshot_ms'] = watch.elapsedMilliseconds;
          metrics['portable_archive_bytes'] = await archive.file.length();
        }
        metrics['database_bytes'] = await File(path).length();
      } finally {
        await active.close();
      }
      results[encrypted ? 'SQLCipher' : 'SQLite'] = metrics;
    }
    final result = {
      'nonce': nonce,
      'pid': pid,
      'mode': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'products': 1000,
      'initialSales': 250,
      'policy':
          'same exported dataset; one warmup plus five timed operations; PIN KDF excluded; checkout includes cart transitions; SQLite then SQLCipher order',
      'cumulative_process_max_rss': ProcessInfo.maxRss,
      'results': results,
    };
    await resultFile.writeAsString(jsonEncode(result), flush: true);
    // Metadata/timings only. This channel permits profile verification even on
    // devices whose package manager disallows run-as for profile APKs.
    // ignore: avoid_print
    print('M5_PERFORMANCE ${jsonEncode(result)}');
    status.value = 'UJI COBA M5 selesai — hasil tersimpan';
  } catch (error) {
    final detail = error is DatabaseException
        ? error
              .toString()
              .split(RegExp(r' args |arguments:|parameters:'))
              .first
              .replaceAll(RegExp(r'[a-fA-F0-9]{64}'), '[redacted-hex]')
        : error.runtimeType.toString();
    await File('$base.failure.json').writeAsString(
      jsonEncode({
        'nonce': nonce,
        'type': error.runtimeType.toString(),
        'detail': detail,
      }),
      flush: true,
    );
    // ignore: avoid_print
    print('M5_PERFORMANCE_FAILURE $detail');
    status.value = 'UJI COBA M5 gagal — periksa bukti';
  }
}
