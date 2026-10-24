import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/contact_validation.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/alerts/application/android_stock_notifications.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/reports/application/report_export_service.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';

const _nonce = String.fromEnvironment('REALME_RELEASE_NONCE');
void _require(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

/// AOT checks on two fresh synthetic products, never the retained manual DB.
/// No account, permission request, notification post or printer transfer occurs.
/// A release failure preserves its fixture; there is no reset/reseed fallback.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _require(
    const bool.fromEnvironment('KASIR_INTEGRATION_TEST') &&
        kReleaseMode &&
        RegExp(r'^[0-9]{10,20}$').hasMatch(_nonce),
    'isolatedReleaseOnly',
  );
  final status = ValueNotifier('UJI Realme release — data sintetis');
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
  final root = await getDatabasesPath();
  final path = '$root/realme_release_$_nonce.db';
  final marker = File('$root/realme_release_$_nonce.result.json');
  // Reject reused namespaces before entering the result-writing path. Even a
  // failure marker must never overwrite evidence from an earlier probe.
  _require(
    !await File(path).exists() && !await marker.exists(),
    'releaseFixtureAlreadyExists',
  );
  final platform = KasirPlatform(fixtureNamespace: 'test-m51-$_nonce');
  final database = DatabaseCoordinator(
    factory: databaseFactory,
    databasePath: path,
    gate: AndroidDatabaseGate(platform),
    encryption: EncryptedDatabase(
      path,
      keyName: 'test-release-db-$_nonce',
      platform: platform,
    ),
  );
  var stage = 'freshFixture';
  final result = <String, Object?>{
    'nonce': _nonce,
    'release': kReleaseMode,
    'schema': Schema.version,
    'pid': pid,
  };
  Money money(int value) => Money(value, 'IDR', 0);
  CostAmount cost(int value) => CostAmount.fromMoney(money(value));
  try {
    final app = AppServices(database);
    stage = 'pinAndPhone';
    await app.management.configure('PUBLIC Realme AOT', '0001', '0001');
    await app.management.unlock('0001');
    _require(
      ContactValidation.phone('081234567890') == '+6281234567890',
      'releasePhoneMetadata',
    );
    stage = 'productsAndPromotion';
    final real = await app.inventory.create(
      ProductInput(name: 'PUBLIC tracked AOT', sellingPrice: money(10000)),
      initialQuantity: 25,
      unitCost: cost(5000),
    );
    final reference = await app.inventory.create(
      ProductInput(name: 'PUBLIC untracked AOT', sellingPrice: money(10000)),
      stockTracking: false,
      referenceCost: cost(7000),
    );
    await app.promotions.save(
      product: reference,
      name: 'PUBLIC AOT promo',
      minimum: 3,
      basisPoints: 1250,
      active: true,
    );
    var cart = await app.cart.open();
    cart = await app.cart.add(cart.id, real);
    cart = await app.cart.quantity(cart.id, real, 3);
    cart = await app.cart.add(cart.id, reference);
    cart = await app.cart.quantity(cart.id, reference, 1000);
    _require(cart.total.amountMinor == 8780000, 'releaseExactPromoTotal');
    stage = 'atomicCheckout';
    final input = CheckoutInput(
      cash: true,
      tender: money(8800000),
      tenderRaw: '8800000',
    );
    final receipt = await app.checkout.submit(cart.id, cart.revision, input);
    _require(receipt.cashTender?.change.amountMinor == 20000, 'releaseChange');
    final retry = await app.checkout.submit(cart.id, cart.revision, input);
    _require(retry.id.value == receipt.id.value, 'releaseIdempotency');
    _require(
      (await app.inventory.detail(real)).quantity == 22,
      'releaseTrackedStock',
    );
    _require(
      (await app.inventory.detail(reference)).quantity == 999,
      'releaseReferenceStock',
    );
    await database.read((sql) async {
      _require(
        (await sql.query('sale_transactions')).length == 1,
        'releaseOneSale',
      );
      _require(
        (await sql.rawQuery(
              'SELECT SUM(cost_micros) AS n FROM sale_transaction_items',
            )).single['n'] ==
            7015000000000,
        'release64BitCostSnapshot',
      );
      await DatabaseValidation.integrity(sql);
      await EncryptedDatabase.requireCipher(sql);
    });
    _require(
      (await app.reports.reconcile()).consistent,
      'releaseFinancialReconciliation',
    );
    stage = 'reportExports';
    final filter = ReportFilter(
      start: UtcInstant.fromMilliseconds(0),
      end: UtcInstant.fromMilliseconds(4102444800000),
    );
    final exportBytes = <String, int>{};
    for (final xlsx in [false, true]) {
      final report = await app.reportExport.create(
        filter,
        xlsx: xlsx,
        control: ReportExportControl(),
      );
      try {
        exportBytes[xlsx ? 'xlsx' : 'csv'] = await report.file.length();
        _require(exportBytes.values.every((n) => n > 0), 'releaseExportBytes');
        if (!xlsx) {
          _require(
            (await report.file.readAsString()).contains('"8780000"'),
            'releaseExportNetTotal',
          );
        }
      } finally {
        await report.dispose();
      }
    }
    stage = 'portableBackup';
    final code = BackupService.newRecoveryCode();
    final backups = BackupService(database, app.management, platform: platform);
    final archive = await backups.create(headless: true, code: code);
    final inspection = await backups.inspect(archive.file, code);
    try {
      _require(
        inspection.manifest.id == archive.manifest.id,
        'releaseArchiveInspection',
      );
    } finally {
      await inspection.dispose();
    }
    stage = 'notificationPlugin';
    await AndroidStockNotifications(
      FlutterLocalNotificationsPlugin(),
    ).initialize(() {});
    app.management.lock();
    result.addAll({
      'status': 'PASS',
      'products': 2,
      'sales': 1,
      'totalMinor': 8780000,
      'costMicros': 7015000000000,
      'trackedQuantity': 22,
      'referenceQuantity': 999,
      'phoneMetadata': true,
      'idempotency': true,
      'integrityCipherReconciliation': true,
      'exports': exportBytes,
      'archiveBytes': await archive.file.length(),
      'notificationPluginInitialized': true,
      'notificationPosted': false,
      'permissionRequested': false,
      'accountAccessed': false,
      'printerTransfer': false,
    });
    status.value = 'UJI Realme release selesai';
  } catch (error) {
    result.addAll({
      'status': 'FAIL',
      'stage': stage,
      'errorType': error.runtimeType.toString(),
    });
    status.value = 'UJI Realme release berhenti; data dipertahankan';
  } finally {
    await database.close();
  }
  await marker.writeAsString(jsonEncode(result), flush: true);
  // Metadata only: no PIN, recovery code, key, SQL arguments or user rows.
  // ignore: avoid_print
  print('REALME_M52_RELEASE ${jsonEncode(result)}');
}
