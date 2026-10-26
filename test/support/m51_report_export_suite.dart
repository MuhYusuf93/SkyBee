import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/reports/application/report_export_service.dart';
import 'package:kasir_app/features/reports/application/report_destination_service.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';

void m51ReportExportSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kasir_export_');
    db = DatabaseCoordinator(
      factory: factory,
      databasePath: p.join(
        directory.path,
        'm5_regression_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    app = AppServices(db);
    await app.management.configure('PUBLIC report fixture', '0001', '0001');
    await app.management.unlock('0001');
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
    await directory.delete(recursive: true);
  });
  Future<ReportFilter> seed() async {
    final id = await app.inventory.create(
      ProductInput(
        name: '=SUM(1,2) "Barang"\nEnglish',
        barcode: '000123',
        sellingPrice: Money(12000, 'IDR', 0),
        packLabel: 'box',
        packSize: 40,
      ),
      initialQuantity: 10,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    var draft = await app.cart.open();
    draft = await app.cart.add(draft.id, id);
    final sale = await app.checkout.submit(
      draft.id,
      draft.revision,
      CheckoutInput(
        cash: true,
        tender: Money(10000, 'IDR', 0),
        tenderRaw: '10000',
        customer: const CustomerChoice(name: 'PUBLIC customer'),
      ),
    );
    final customer = (await app.receivables.customers()).items.single;
    await app.receivables.record(
      await app.receivables.preview(customer.id, Money(1000, 'IDR', 0)),
    );
    draft = await app.cart.next(draft.id);
    draft = await app.cart.add(draft.id, id);
    final cancelled = await app.checkout.submit(
      draft.id,
      draft.revision,
      const CheckoutInput(),
    );
    await app.corrections.cancelSale(
      cancelled.id,
      operationKey: 'PUBLIC-return',
      reason: 'PUBLIC returned',
      goodsReturned: true,
      moneyHandled: true,
    );
    expect(sale.total.amountMinor, 12000);
    await db.transaction((sql) async {
      final original = (await sql.query('products')).single;
      for (var n = 0; n < 105; n++) {
        await sql.insert('products', {
          ...original,
          'id': const Uuid().v4(),
          'sku': 'PUBLIC-$n',
          'barcode': '000${n + 200}',
          'name': 'PUBLIC $n',
          'normalized_name': 'public $n',
          'compact_name': 'public$n',
          'stock_quantity': 0,
          'inventory_value_micros': 0,
        });
      }
    });
    return ReportFilter(
      start: UtcInstant.fromMilliseconds(0),
      end: UtcInstant.fromMilliseconds(4102444800000),
    );
  }

  test(
    'export whole snapshot paginates, preserves exact data and changes no database facts',
    () async {
      final filter = await seed();
      final before = await db.read(DatabaseValidation.fingerprint);
      final outputs = <ReportArtifact>[];
      try {
        for (final xlsx in [false, true]) {
          var pages = 0;
          final control = ReportExportControl();
          final result = await app.reportExport.create(
            filter,
            xlsx: xlsx,
            control: control,
            progress: (_) => pages++,
          );
          outputs.add(result);
          expect(await result.file.length(), greaterThan(0));
          expect(pages, greaterThanOrEqualTo(5));
          expect(
            control.rows,
            131,
          ); //16 summary +3 sales +4 payments +2 items +106 inventory.
          if (Platform.isWindows) {
            final root = await Directory(
              'build/m51-report-reader',
            ).create(recursive: true);
            await result.file.copy(
              p.join(root.path, xlsx ? 'report.xlsx' : 'report.csv'),
            );
          }
        }
        expect(
          jsonEncode(await db.read(DatabaseValidation.fingerprint)),
          jsonEncode(before),
        );
        expect((await app.reports.reconcile()).consistent, true);
      } finally {
        for (final result in outputs) {
          await result.dispose();
        }
      }
    },
  );
  test(
    'cancel, IO fault and authorization revocation remove only own staged export',
    () async {
      final filter = await seed();
      for (final kind in ['cancel', 'io', 'lock']) {
        final control = ReportExportControl();
        await expectLater(
          app.reportExport.create(
            filter,
            xlsx: true,
            control: control,
            testPage: () async {
              if (kind == 'cancel') control.cancel();
              if (kind == 'io') {
                throw const FileSystemException('PUBLIC injected full');
              }
              if (kind == 'lock') app.management.lock();
            },
          ),
          throwsA(anything),
        );
        expect(
          await directory
              .list()
              .where((e) => p.basename(e.path).startsWith('m51_report_'))
              .length,
          0,
        );
        if (kind == 'lock') await app.management.unlock('0001');
      }
    },
  );
  test(
    'report destination selection is not a write; locked session cannot release report',
    () async {
      var writes = 0, cancels = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KasirPlatform.channel, (call) async {
            if (call.method == 'chooseReportExport') return 'PUBLIC-token';
            if (call.method == 'writeReportExport') {
              writes++;
              return true;
            }
            if (call.method == 'cancelReportExport') {
              cancels++;
              return true;
            }
            throw PlatformException(code: 'unexpected-public-call');
          });
      try {
        final destination = ReportDestinationService(app.management);
        final token = await destination.choose(xlsx: true);
        expect(writes, 0);
        final file = await File(
          p.join(directory.path, 'PUBLIC.xlsx'),
        ).writeAsString('PUBLIC');
        app.management.lock();
        await expectLater(
          destination.write(token!, ReportArtifact(directory, file)),
          throwsA(anything),
        );
        expect(writes, 0);
        expect(cancels, 1);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
      }
    },
  );
}
