import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/suppliers/application/supplier_service.dart';
import 'package:kasir_app/features/suppliers/application/supplier_reminder_service.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_invoice.dart';
import 'package:kasir_app/features/suppliers/domain/supplier_visit.dart';

final class RecordingSupplierReminders implements SupplierReminderSink {
  bool allowed = true, failSchedule = false, failShow = false;
  int scheduled = 0, resets = 0;
  final jobs = <String, Map<String, String>>{};
  final shown = <int>[], cancelled = <int>[];
  @override
  Future<bool> get permitted async => allowed;
  @override
  Future<void> schedule(
    String name,
    DateTime target,
    Map<String, String> input,
  ) async {
    if (failSchedule) throw StateError('PUBLIC SCHEDULER FAILURE');
    scheduled++;
    jobs[name] = Map.of(input);
  }

  @override
  Future<void> cancelWork(String name) async {
    jobs.remove(name);
  }

  @override
  Future<void> resetWork() async {
    resets++;
    jobs.clear();
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> show(
    int id, {
    required bool due,
    required String supplier,
    required bool english,
  }) async {
    if (failShow) throw StateError('PUBLIC NOTIFICATION FAILURE');
    shown.add(id);
  }
}

void m53SupplierSchedulesSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late EntityId supplier;
  late DateTime now;
  late RecordingSupplierReminders sink;
  late SupplierReminderService reminders;
  late Map<String, Object?> credential;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  StoreClock clock() =>
      StoreClock(now: () => now, elapsedMilliseconds: () => 0);
  CalendarDate day(String s) => CalendarDate(s);
  Money money(int n) => Money(n, 'IDR', 0);
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_schedule_');
    now = DateTime.utc(2026, 10, 29);
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
      clock: clock(),
    ).management.configure('PUBLIC PLANS', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 29);
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(db, clock: clock());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credential),
    );
    await app.management.unlock('0001');
    supplier = await app.inventory.saveMaster(
      MasterKind.supplier,
      'PUBLIC SUPPLIER',
    );
    await app.alerts.configure(enabled: true, days: 5);
    sink = RecordingSupplierReminders();
    reminders = SupplierReminderService(db, clock(), sink);
  });
  tearDown(() async {
    try {
      await db.read(SupplierScheduleValidation.validate);
      await db.read(SupplierFinanceValidation.validate);
    } finally {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
    }
  });
  tearDownAll(() async => root.delete());
  Future<SupplierVisit> plan(
    String date, {
    String status = 'planned',
    bool reminder = true,
  }) => app.suppliers.saveVisit(
    supplier,
    SupplierVisitInput(date: day(date), status: status, reminder: reminder),
    operationKey: 'PUBLIC PLAN ${serial++}',
  );
  Future<SupplierInvoice> bill(String due) async {
    final product = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC GOODS ${serial++}',
        sellingPrice: money(200000),
      ),
      initialQuantity: 0,
    );
    final receipt = await app.inventory.receive(
      product,
      1,
      CostAmount.fromMoney(money(100000)),
      supplierId: supplier,
      operationKey: 'PUBLIC BUY ${serial++}',
    );
    final terms = await app.suppliers.terms(supplier);
    if (!terms.allowsCredit) {
      await app.suppliers.saveTerms(
        supplier,
        terms.revision,
        allowsCredit: true,
      );
    }
    return app.suppliers.createInvoice(
      receipt,
      SupplierInvoiceInput(
        invoiceDate: day('2026-10-29'),
        terms: SupplierInvoiceTerms.credit,
        dueDate: day(due),
      ),
      operationKey: 'PUBLIC BILL ${serial++}',
    );
  }

  Future<SupplierInvoice> pay(SupplierInvoice invoice, int n) async {
    await app.suppliers.payInvoice(
      invoice.id,
      invoice.revision,
      SupplierPaymentInput(
        amount: money(n),
        date: day('2026-10-29'),
        source: SupplierPaymentSource.bank,
      ),
      operationKey: 'PUBLIC PAY ${serial++}',
    );
    return app.suppliers.invoice(invoice.id);
  }

  Future<List<Map<String, Object?>>> jobs() =>
      db.read((sql) => sql.query('supplier_reminder_jobs'));

  test(
    'M53 schedules next future date ignores past pages and respects supplier status and shop day',
    () async {
      for (var i = 0; i < 22; i++) {
        await plan('2026-10-28');
      }
      expect(await app.suppliers.nextVisitDay(supplier: supplier), isNull);
      await plan('2026-12-31');
      final nearest = await plan('2026-11-15', reminder: false);
      expect(
        (await app.suppliers.visits(
          supplier: supplier,
        )).items.every((v) => v.date.iso == '2026-10-28'),
        isTrue,
      );
      expect(
        (await app.suppliers.nextVisitDay(supplier: supplier))!.iso,
        '2026-11-15',
      );
      await app.suppliers.saveVisit(
        supplier,
        SupplierVisitInput(date: nearest.date, status: 'completed'),
        id: nearest.id,
        expectedRevision: 1,
        operationKey: 'PUBLIC NEXT COMPLETED',
      );
      expect(
        (await app.suppliers.nextVisitDay(supplier: supplier))!.iso,
        '2026-12-31',
      );
      final other = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC OTHER',
      );
      await app.suppliers.saveVisit(
        other,
        SupplierVisitInput(date: day('2026-11-01')),
        operationKey: 'PUBLIC OTHER VISIT',
      );
      expect((await app.suppliers.nextVisitDay())!.iso, '2026-11-01');
      expect(
        (await app.suppliers.nextVisitDay(supplier: supplier))!.iso,
        '2026-12-31',
      );
      now = DateTime.utc(2026, 11, 1, 12);
      await db.transaction(
        (sql) => sql.update('store_settings', {
          'time_zone': 'Pacific/Kiritimati',
        }, where: 'id=1'),
      );
      expect((await app.suppliers.nextVisitDay())!.iso, '2026-12-31');
    },
  );
  test(
    'M53 schedules only relevant successful transactions invalidate supplier jobs',
    () async {
      final events = <int>[];
      final subscription = db.supplierChanges.listen(events.add);
      try {
        await app.cart.open();
        await app.cart.open();
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);
        await plan('2026-11-20');
        await Future<void>.delayed(Duration.zero);
        expect(events.length, 1);
        await expectLater(
          db.transaction((sql) async {
            await sql.update('store_settings', {
              'receipt_footer': 'PUBLIC ROLLBACK',
            }, where: 'id=1');
            throw const FormatException('PUBLIC ROLLBACK');
          }, supplierChanged: true),
          throwsA(isA<FormatException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(events.length, 1);
        await app.alerts.configure(enabled: false, days: 5);
        await Future<void>.delayed(Duration.zero);
        expect(events.length, 2);
      } finally {
        await subscription.cancel();
      }
    },
  );

  test(
    'M53 schedules H-1 is previous shop calendar day at09 across year leap month and DST',
    () {
      expect(
        SupplierReminderService.target('2027-01-01', 'Asia/Jakarta'),
        DateTime.utc(2026, 12, 31, 2),
      );
      expect(
        SupplierReminderService.target('2028-03-01', 'Asia/Jakarta'),
        DateTime.utc(2028, 2, 29, 2),
      );
      expect(
        SupplierReminderService.target('2026-03-09', 'America/New_York'),
        DateTime.utc(2026, 3, 8, 13),
      );
      expect(
        SupplierReminderService.target('2026-11-02', 'America/New_York'),
        DateTime.utc(2026, 11, 1, 14),
      );
      expect(
        SupplierReminderService.target('2026-11-20', 'Pacific/Kiritimati'),
        DateTime.utc(2026, 11, 18, 19),
      );
    },
  );
  test(
    'M53 schedules visit revisions retry CAS and warehouse do not mutate receipt invoice payment',
    () async {
      final invoice = await bill('2026-11-25'), v = await plan('2026-11-20');
      final input = SupplierVisitInput(
        date: day('2026-11-22'),
        timeMinutes: 630,
        note: 'PUBLIC PLAN',
        status: 'completed',
      );
      var updated = await app.suppliers.saveVisit(
        supplier,
        input,
        id: v.id,
        expectedRevision: 1,
        operationKey: 'PUBLIC UPDATE',
      );
      expect(updated.revision, 2);
      expect(
        (await app.suppliers.saveVisit(
          supplier,
          input,
          id: v.id,
          expectedRevision: 1,
          operationKey: 'PUBLIC UPDATE',
        )).revision,
        2,
      );
      await expectLater(
        app.suppliers.saveVisit(
          supplier,
          input,
          id: v.id,
          expectedRevision: 1,
          operationKey: 'PUBLIC STALE',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.suppliers.invoice(invoice.id)).due!.iso, '2026-11-25');
      expect((await app.suppliers.invoice(invoice.id)).remaining, 100000);
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '0002',
        confirmation: '0002',
      );
      await app.management.unlock('0002', role: ManagementRole.warehouse);
      updated = await app.suppliers.saveVisit(
        supplier,
        SupplierVisitInput(date: updated.date, status: 'cancelled'),
        id: v.id,
        expectedRevision: 2,
        operationKey: 'PUBLIC WAREHOUSE CANCEL',
      );
      expect(updated.input.status, 'cancelled');
      await expectLater(
        app.suppliers.setInvoiceReminder(
          invoice.id,
          false,
          0,
          operationKey: 'PUBLIC DENIED',
        ),
        throwsA(isA<AppError>()),
      );
      expect(await db.read((sql) => sql.query('supplier_payments')), isEmpty);
      expect((await db.read((sql) => sql.query('stock_receipts'))).length, 1);
    },
  );
  test(
    'M53 schedules bounded visit cursor full history and forged projection rejected',
    () async {
      for (var i = 0; i < 22; i++) {
        await plan('2026-11-20');
      }
      final first = await app.suppliers.visits(supplier: supplier);
      expect(first.items.length, 20);
      expect(first.nextCursor, isNotNull);
      expect(
        (await app.suppliers.visits(
          supplier: supplier,
          after: first.nextCursor,
        )).items.length,
        2,
      );
      await expectLater(
        app.suppliers.visits(status: null, after: first.nextCursor),
        throwsA(isA<AppError>()),
      );
      await plan('2026-11-22');
      await expectLater(
        app.suppliers.visits(supplier: supplier, after: first.nextCursor),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        db.transaction((sql) async {
          await sql.execute('DROP TRIGGER supplier_visits_update');
          await sql.update(
            'supplier_visits',
            {'visit_date': '2026-11-23'},
            where: 'id=?',
            whereArgs: [first.items.first.id.value],
          );
          await SupplierScheduleValidation.validate(sql);
        }),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'M53 schedules visit and due jobs separate partial payment coalesces paid cancels stale worker',
    () async {
      await plan('2026-11-20');
      var invoice = await bill('2026-11-25');
      await reminders.refresh();
      expect(sink.jobs.length, 2);
      expect(sink.scheduled, 2);
      final pending = sink.jobs.values.firstWhere(
        (v) => v['key']!.startsWith('due/'),
      );
      final rows = await jobs();
      expect(rows.map((v) => v['reminder_day']).toSet(), {
        '2026-11-19',
        '2026-11-24',
      });
      invoice = await pay(invoice, 40000);
      await reminders.refresh();
      expect(sink.scheduled, 2);
      expect(sink.jobs.length, 2);
      invoice = await pay(invoice, 60000);
      await reminders.refresh();
      expect(invoice.remaining, 0);
      expect(sink.jobs.length, 1);
      now = DateTime.utc(2026, 11, 24, 2);
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      expect(sink.shown, isEmpty);
    },
  );
  test(
    'M53 schedules date zone identity preferences complete cancel reschedule idempotently',
    () async {
      var v = await plan('2026-11-20');
      final invoice = await bill('2026-11-25');
      await reminders.refresh();
      final oldNames = sink.jobs.keys.toSet();
      v = await app.suppliers.saveVisit(
        supplier,
        SupplierVisitInput(date: day('2026-12-02')),
        id: v.id,
        expectedRevision: 1,
        operationKey: 'PUBLIC REDATE',
      );
      await app.suppliers.amendDue(
        invoice.id,
        0,
        day('2027-01-01'),
        reason: 'PUBLIC DUE',
        operationKey: 'PUBLIC DUE',
      );
      await db.transaction(
        (sql) => sql.update('store_settings', {
          'time_zone': 'America/New_York',
          'name': 'PUBLIC RENAMED',
        }, where: 'id=1'),
      );
      await reminders.refresh();
      expect(sink.jobs.length, 2);
      expect(sink.jobs.keys.toSet().intersection(oldNames), isEmpty);
      expect(
        (await jobs()).where((j) => j['kind'] == 'due').single['reminder_day'],
        '2026-12-31',
      );
      await app.suppliers.setInvoiceReminder(
        invoice.id,
        false,
        0,
        operationKey: 'PUBLIC REMINDER OFF',
      );
      await reminders.refresh();
      expect(sink.jobs.length, 1);
      await app.suppliers.setInvoiceReminder(
        invoice.id,
        true,
        1,
        operationKey: 'PUBLIC REMINDER ON',
      );
      await reminders.refresh();
      expect(sink.jobs.length, 2);
      await app.suppliers.saveVisit(
        supplier,
        SupplierVisitInput(date: v.date, status: 'completed'),
        id: v.id,
        expectedRevision: v.revision,
        operationKey: 'PUBLIC COMPLETE',
      );
      await reminders.refresh();
      expect(sink.jobs.length, 1);
      final count = sink.scheduled;
      await reminders.refresh();
      expect(sink.scheduled, count);
    },
  );
  test(
    'M53 schedules synthetic H-1 worker delivers once resume reboot recheck partial does not redeliver',
    () async {
      var invoice = await bill('2026-11-25');
      await reminders.refresh();
      final pending = Map.of(sink.jobs.values.single);
      now = DateTime.utc(2026, 11, 24, 2);
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      expect(sink.shown.length, 1);
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      await reminders.refresh(resetPlatform: true);
      expect(sink.shown.length, 1);
      expect(sink.jobs, isEmpty);
      // Actual date is deliberately current for this later payment.
      await app.suppliers.payInvoice(
        invoice.id,
        invoice.revision,
        SupplierPaymentInput(
          amount: money(50000),
          date: day('2026-11-24'),
          source: SupplierPaymentSource.bank,
        ),
        operationKey: 'PUBLIC LATER PARTIAL',
      );
      invoice = await app.suppliers.invoice(invoice.id);
      await reminders.refresh();
      expect(sink.jobs, isEmpty);
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      expect(sink.shown.length, 1);
      expect(invoice.remaining, 50000);
    },
  );
  test(
    'M53 schedules denied and failed notification never blocks plans nor catches up past H-1',
    () async {
      await plan('2026-11-20');
      sink.allowed = false;
      await reminders.refresh();
      expect(sink.jobs, isEmpty);
      sink.allowed = true;
      sink.failSchedule = true;
      await reminders.refresh();
      expect((await jobs()).single['error_code'], 'm53ReminderUnavailable');
      expect(
        await app.suppliers.reminderUnavailable(supplier: supplier),
        isTrue,
      );
      sink.failSchedule = false;
      await reminders.refresh();
      expect(sink.jobs.length, 1);
      final pending = Map.of(sink.jobs.values.single);
      now = DateTime.utc(2026, 11, 19, 2);
      sink.failShow = true;
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      await reminders.refresh();
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      expect(sink.shown, isEmpty);
      expect((await jobs()).single['error_code'], 'm53ReminderUnavailable');
      now = DateTime.utc(2026, 12, 1, 3);
      await plan('2026-12-02');
      await plan('2026-12-01');
      await plan('2026-11-30');
      await reminders.refresh();
      expect(
        sink.jobs.isEmpty ||
            sink.jobs.values.every((v) => v['key'] == pending['key']),
        isTrue,
      );
      expect(
        (await app.suppliers.visitCalendar()).needsAttention(day('2026-12-02')),
        isTrue,
      );
    },
  );
  test(
    'M53 schedules delayed next-day worker skips and restored store cannot execute foreign pending job',
    () async {
      await plan('2026-11-20');
      await reminders.refresh();
      final pending = Map.of(sink.jobs.values.single);
      now = DateTime.utc(2026, 11, 20, 2);
      await reminders.execute(pending['key']!, pending['fingerprint']!);
      expect(sink.shown, isEmpty);
      now = DateTime.utc(2026, 10, 29);
      final restored = DatabaseCoordinator(
        factory: factory,
        databasePath: path(),
      );
      try {
        final other = AppServices(restored, clock: clock());
        await restored.transaction(
          (sql) => sql.insert('management_credentials', credential),
        );
        await other.management.unlock('0001');
        await other.alerts.configure(enabled: true, days: 5);
        final next = SupplierReminderService(restored, clock(), sink);
        await next.refresh(resetPlatform: true);
        expect(sink.jobs, isEmpty);
        await next.execute(pending['key']!, pending['fingerprint']!);
        expect(sink.shown, isEmpty);
      } finally {
        await restored.close();
        await factory.deleteDatabase(restored.databasePath);
      }
    },
  );
  test(
    'M53 schedules schema33 upgrade retains original stock and financial facts without inventing visits or reminders',
    () async {
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: path(),
        schemaVersion: 33,
      );
      // Keep each native fixture under the required path pattern and random key.
      final oldPath = old.databasePath;
      DatabaseCoordinator? upgraded;
      var oldClosed = false;
      try {
        final prior = AppServices(old, clock: clock());
        await old.transaction(
          (sql) => sql.insert('management_credentials', credential),
        );
        await prior.management.unlock('0001');
        final sid = await prior.inventory.saveMaster(
          MasterKind.supplier,
          'PUBLIC LEGACY SUPPLIER',
        );
        final p = await prior.inventory.create(
          ProductInput(name: 'PUBLIC LEGACY GOODS', sellingPrice: money(500)),
          initialQuantity: 0,
        );
        final receipt = await prior.inventory.receive(
          p,
          5,
          CostAmount.fromMoney(money(100)),
          supplierId: sid,
          operationKey: 'PUBLIC LEGACY BUY',
        );
        final invoice = await prior.suppliers.createInvoice(
          receipt,
          SupplierInvoiceInput(invoiceDate: day('2026-10-29')),
          operationKey: 'PUBLIC LEGACY INVOICE',
        );
        await prior.suppliers.payInvoice(
          invoice.id,
          0,
          SupplierPaymentInput(
            amount: money(200),
            date: day('2026-10-29'),
            source: SupplierPaymentSource.bank,
          ),
          operationKey: 'PUBLIC LEGACY PAY',
        );
        const tables = [
          'products',
          'stock_receipts',
          'stock_receipt_items',
          'supplier_invoices',
          'supplier_payments',
          'inventory_operations',
          'stock_history',
        ];
        final before = <String, List<Map<String, Object?>>>{};
        for (final table in tables) {
          before[table] = await old.read(
            (sql) => sql.query(table, orderBy: 'id'),
          );
        }
        await old.close();
        oldClosed = true;
        upgraded = DatabaseCoordinator(factory: factory, databasePath: oldPath);
        for (final table in tables) {
          expect(
            await upgraded.read((sql) => sql.query(table, orderBy: 'id')),
            before[table],
          );
        }
        expect(
          await upgraded.read((sql) => sql.query('supplier_visits')),
          isEmpty,
        );
        expect(
          await upgraded.read(
            (sql) => sql.query('supplier_invoice_reminder_events'),
          ),
          isEmpty,
        );
        await upgraded.read(SupplierScheduleValidation.validate);
        await upgraded.read(SupplierFinanceValidation.validate);
      } finally {
        if (!oldClosed) {
          await old.close();
        }
        await upgraded?.close();
        await factory.deleteDatabase(oldPath);
      }
    },
  );
}
