import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:kasir_platform/kasir_platform.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/repositories/sqlite_reports_repository.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/reports/application/report_export_service.dart';
import 'package:kasir_app/features/reports/application/report_destination_service.dart';
import 'package:kasir_app/features/reports/domain/report_models.dart';
import 'package:kasir_app/features/reports/domain/report_profit.dart';

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
        customer: const CustomerChoice(
          name: 'PUBLIC customer',
          phone: '08000000001',
        ),
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
            132,
          ); //17 summary +3 sales +4 payments +2 items +106 inventory.
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
  test('M54 profit buckets seek indexed ranges and export all pages', () async {
    final zone = await app.reports.timeZone();
    final clock = app.management.clock;
    final today = clock.today(zone);
    final from = CalendarDate(
      DateTime.parse(
        today.iso,
      ).subtract(const Duration(days: 25)).toIso8601String().substring(0, 10),
    );
    final id = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC cost unknown',
        sellingPrice: Money(12000, 'IDR', 0),
      ),
      stockTracking: false,
      referenceCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
    );
    // Simulate a migrated untracked master that predates mandatory reference cost.
    await db.exclusive(
      (sql) => sql.update(
        'products',
        {'reference_cost_micros': null, 'cost_complete': 0},
        where: 'id=?',
        whereArgs: [id.value],
      ),
    );
    final cart = await app.cart.open();
    final filled = await app.cart.add(cart.id, id);
    await app.checkout.submit(
      filled.id,
      filled.revision,
      const CheckoutInput(),
    );
    final filter = await app.reports.period(from, today);
    final calendar = ReportProfitCalendar(
      filter,
      ReportProfitPeriod.day,
      clock,
      zone,
    );
    final initial = await app.reports.profit(filter, ReportProfitPeriod.day, 0);
    final tail = await app.reports.profit(filter, ReportProfitPeriod.day, 1);
    expect(initial.buckets, hasLength(24));
    expect(
      initial.buckets.every((b) => b.grossProfitMicros == BigInt.zero),
      isTrue,
    );
    expect(tail.buckets, hasLength(2));
    expect(tail.buckets.last.salesMinor, 12000);
    expect(tail.buckets.last.costMicros, isNull);
    expect(tail.buckets.last.grossProfitMicros, isNull);
    expect(tail.buckets.last.writeDownMicros, 0);
    expect((await app.reports.summary(filter)).grossProfitMicros, isNull);
    final query = reportSalesTotalsQuery(
      filter,
      tail.currency,
      buckets: calendar.page(1),
      costKnowledge: true,
      saleReturns: true,
    );
    final plan = await db.read(
      (sql) => sql.rawQuery('EXPLAIN QUERY PLAN ${query.sql}', query.arguments),
    );
    for (final alias in ['s', 'r']) {
      expect(
        plan.any((row) {
          final line = row['detail'].toString();
          return line.contains('SEARCH $alias USING') &&
              line.contains('created_at>? AND created_at<?');
        }),
        isTrue,
        reason: plan.toString(),
      );
    }
    for (final xlsx in [false, true]) {
      final result = await app.reportExport.create(
        filter,
        xlsx: xlsx,
        profitPeriod: ReportProfitPeriod.day,
        control: ReportExportControl(),
      );
      try {
        final bytes = await result.file.readAsBytes();
        if (xlsx) {
          final archive = ZipDecoder().decodeBytes(bytes);
          final sheet = archive.findFile('xl/worksheets/sheet2.xml')!;
          final text = utf8.decode(sheet.content);
          expect(RegExp(r'<row r=').allMatches(text), hasLength(27));
          expect(text, contains(today.iso));
          expect(text, contains('incomplete'));
        } else {
          final rows = const LineSplitter()
              .convert(utf8.decode(bytes))
              .where((line) => line.startsWith('"gross_profit",'))
              .toList();
          expect(rows, hasLength(26));
          expect(rows.first, contains('"0","0","0"'));
          expect(rows.last, contains('"12000","12000","","incomplete"'));
        }
      } finally {
        await result.dispose();
      }
    }
  });

  test('M54 calendar clips month and week at year and DST boundaries', () {
    final clock = app.management.clock;
    const zone = 'America/New_York';
    ReportFilter selection(String from, String through) => ReportFilter(
      start: clock.dayStart(CalendarDate(from), zone),
      end: clock.dayStart(CalendarDate(through), zone, nextDay: true),
    );
    final year = selection('2026-12-30', '2027-01-05');
    final monthly = ReportProfitCalendar(
      year,
      ReportProfitPeriod.month,
      clock,
      zone,
    );
    final weekly = ReportProfitCalendar(
      year,
      ReportProfitPeriod.week,
      clock,
      zone,
    );
    expect(monthly.page(0).map((r) => (r.first.iso, r.last.iso)), [
      ('2026-12-30', '2026-12-31'),
      ('2027-01-01', '2027-01-05'),
    ]);
    expect(weekly.page(0).map((r) => (r.first.iso, r.last.iso)), [
      ('2026-12-30', '2027-01-03'),
      ('2027-01-04', '2027-01-05'),
    ]);
    final spring = selection('2027-03-13', '2027-03-15');
    final daily = ReportProfitCalendar(
      spring,
      ReportProfitPeriod.day,
      clock,
      zone,
    );
    expect(
      daily
          .page(0)
          .map((r) => r.end.dateTime.difference(r.start.dateTime).inHours),
      [24, 23, 24],
    );
  });

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
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Future<Object?> destinationOnly(MethodCall call) async {
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
      }

      messenger.setMockMethodCallHandler(
        KasirPlatform.channel,
        destinationOnly,
      );
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
        // Native PIN verification/snapshot crypto must use their real channel.
        // Only the synthetic document destination is mocked by this fixture.
        messenger.setMockMethodCallHandler(KasirPlatform.channel, null);
        await app.management.unlock('0001');
        final bound = await app.reportExport.create(
          await app.reports.currentMonth(),
          xlsx: true,
          control: ReportExportControl(),
        );
        try {
          app.management.lock();
          await app.management.unlock('0001');
          messenger.setMockMethodCallHandler(
            KasirPlatform.channel,
            destinationOnly,
          );
          await expectLater(
            destination.write('PUBLIC-new-token', bound),
            throwsA(anything),
          );
          expect(writes, 0);
          expect(cancels, 2);
        } finally {
          messenger.setMockMethodCallHandler(KasirPlatform.channel, null);
          await bound.dispose();
        }
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KasirPlatform.channel, null);
      }
    },
  );
}
