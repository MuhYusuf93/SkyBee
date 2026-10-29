import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier_lock/domain/cashier_lock_policy.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/labels/domain/product_label.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/printer/application/print_queue_service.dart';
import 'package:kasir_app/features/printer/application/receipt_policy_service.dart';
import 'package:kasir_app/features/printer/application/receipt_policy_validation.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'm53_qr_label_queue_suite.dart' show LabelTransport;

/// Same real writers on host FFI and native disposable SQLCipher. A synthetic
/// transport never establishes physical paper output, even after finish().
void m53ReceiptPolicySuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late EntityId product;
  late LabelTransport transport;
  late PrintQueueService queue;
  late Map<String, Object?> credential;
  var serial = 0;
  const device = '00:11:22:33:44:55';
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Money money(int n) => Money(n, 'IDR', 0);
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_receipt_policy_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC RECEIPT POLICY', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(db);
    await db.transaction(
      (sql) => sql.insert('management_credentials', credential),
    );
    await app.management.unlock('0001');
    product = await app.inventory.create(
      ProductInput(name: 'PUBLIC GOODS', sellingPrice: money(12000)),
      initialQuantity: 20,
      unitCost: CostAmount.fromMoney(money(1000)),
    );
    await app.printers.save(device, 'PUBLIC PRINTER', const PrinterProfile());
    transport = LabelTransport();
    queue = PrintQueueService(db, app.checkout, app.management, transport);
  });
  tearDown(() async {
    try {
      await db.read(ReceiptPolicyValidation.validate);
    } finally {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
    }
  });
  tearDownAll(() async => root.delete());
  Future<(CartSnapshot, SaleReceipt)> sale() async {
    var draft = await app.cart.open();
    draft = await app.cart.add(draft.id, product);
    return (
      draft,
      await app.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      ),
    );
  }

  Future<Map<String, Object?>> facts() => db.read(
    (sql) async => {
      for (final table in [
        'products',
        'stock_batches',
        'stock_history',
        'stock_receipts',
        'sale_transactions',
        'sale_transaction_items',
        'payments',
        'payment_allocations',
        'print_receipts',
      ])
        table: await sql.query(
          table,
          orderBy: table == 'print_receipts' ? 'sale_transaction_id' : 'id',
        ),
    },
  );
  Future<String> print(SaleReceipt value) async {
    final id = await queue.prepare(value.id);
    await queue.send(id);
    return id;
  }

  Future<void> enable() async {
    final current = await app.receiptPolicy.policy();
    await app.receiptPolicy.savePolicy(true, current.revision);
  }

  for (final language in ['id', 'en']) {
    test(
      'M53 consumer receipt $language omits automatic near-expiry warning while inventory reminders and sellability remain',
      () async {
        await app.settings.setLanguage(language);
        final today = app.management.clock.today('Asia/Jakarta');
        final tomorrow = CalendarDate(
          DateTime.parse(
            today.iso,
          ).add(const Duration(days: 1)).toIso8601String().substring(0, 10),
        );
        final dated = await app.inventory.create(
          ProductInput(
            name: 'PUBLIC DATED GOODS',
            sellingPrice: money(12000),
            expiryEnabled: true,
          ),
          initialQuantity: 2,
          unitCost: CostAmount.fromMoney(money(1000)),
          expiry: tomorrow,
        );
        expect((await app.inventory.detail(dated)).nearExpiry, 2);
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, dated);
        final receipt = await app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        );
        final snapshot =
            jsonDecode(
                  (await db.read(
                        (sql) => sql.query(
                          'print_receipts',
                          where: 'sale_transaction_id=?',
                          whereArgs: [receipt.id.value],
                        ),
                      )).single['snapshot_json']
                      as String,
                )
                as Map<String, dynamic>;
        final text = ReceiptLayout.sale(
          snapshot,
          const PrinterProfile(),
        ).lines.map((line) => line.text.toLowerCase()).join('\n');
        expect(text, contains('public dated goods'));
        expect(text, isNot(contains('hampir kedaluwarsa')));
        expect(text, isNot(contains('expiring soon')));
        expect(text, isNot(contains('near expiry')));
        expect(
          snapshot.keys.any((key) => key.toLowerCase().contains('expiry')),
          false,
        );
        expect((await app.inventory.detail(dated)).nearExpiry, 1);
        expect((await app.inventory.detail(dated)).saleable, 1);
      },
    );
  }

  test(
    'M53 receipt exception consumes fresh claim even when reason or operation validation fails',
    () async {
      await enable();
      final value = await sale();
      for (final invalidReason in [true, false]) {
        await app.management.reauthenticate(
          '0001',
          ReceiptPolicyService.exceptionPurpose,
        );
        final claim = app.management.claimFresh(
          ReceiptPolicyService.exceptionPurpose,
        );
        await expectLater(
          app.receiptPolicy.ownerException(
            value.$2.id,
            invalidReason ? '' : 'PUBLIC REASON',
            claim,
            operationKey: invalidReason ? 'bad-reason' : '',
          ),
          throwsA(isA<AppError>()),
        );
        expect(
          () => app.management.requireClaim(
            claim,
            ReceiptPolicyService.exceptionPurpose,
          ),
          throwsA(isA<AppError>()),
        );
      }
      expect((await app.receiptPolicy.status(value.$2.id)).pending, true);
    },
  );
  test(
    'M53 receipt confirmation obeys cashier lock and protected history rejects stale owner context',
    () async {
      await enable();
      final value = await sale();
      final job = await print(value.$2);
      app.management.lock();
      await expectLater(
        app.receiptPolicy.confirmPaper(
          value.$2.id,
          job,
          operationKey: 'stale-history',
          management: true,
        ),
        throwsA(isA<AppError>()),
      );
      await app.management.reauthenticate('0001', 'security');
      await app.cashierLock.configure(
        enabled: true,
        screenLock: false,
        source: CashierPinSource.owner,
        revision: app.cashierLock.policy.revision,
      );
      await expectLater(
        app.receiptPolicy.confirmPaper(
          value.$2.id,
          job,
          operationKey: 'locked-cashier',
        ),
        throwsA(isA<AppError>()),
      );
      await app.cashierLock.unlock('0001');
      await app.receiptPolicy.confirmPaper(
        value.$2.id,
        job,
        operationKey: 'unlocked-cashier',
      );
      expect((await app.receiptPolicy.status(value.$2.id)).pending, false);
    },
  );
  test(
    'M53 a real receipt for another sale cannot fulfill the current obligation',
    () async {
      final first = await sale(),
          job = await print(
            (await app.checkout.receipt((await app.cart.open()).completedId!)),
          );
      await app.cart.next(first.$1.id);
      await enable();
      final second = await sale();
      final before = await facts();
      await expectLater(
        app.receiptPolicy.confirmPaper(
          second.$2.id,
          job,
          operationKey: 'wrong-sale',
        ),
        throwsA(isA<AppError>()),
      );
      expect((await app.receiptPolicy.status(second.$2.id)).pending, true);
      expect(await facts(), before);
    },
  );
  test(
    'M53 additive schema35 to36 preserves every original row and does not infer paper obligations from legacy jobs',
    () async {
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: path(),
        schemaVersion: 35,
      );
      DatabaseCoordinator? upgraded;
      bool closed = false;
      try {
        final previous = AppServices(old);
        await old.transaction(
          (sql) => sql.insert('management_credentials', credential),
        );
        await previous.management.unlock('0001');
        await previous.printers.save(
          device,
          'PUBLIC LEGACY PRINTER',
          const PrinterProfile(feed: 8),
        );
        final p = await previous.inventory.create(
          ProductInput(name: 'PUBLIC LEGACY GOODS', sellingPrice: money(1000)),
          initialQuantity: 10,
          unitCost: CostAmount.fromMoney(money(100)),
        );
        var draft = await previous.cart.open();
        draft = await previous.cart.add(draft.id, p);
        final receipt = await previous.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        );
        final oldQueue = PrintQueueService(
          old,
          previous.checkout,
          previous.management,
          LabelTransport(),
        );
        await oldQueue.send(await oldQueue.prepare(receipt.id));
        final before = await old.read((sql) async {
          final tables = await sql.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
          );
          return {
            for (final row in tables)
              row['name'] as String: await sql.query(row['name'] as String),
          };
        });
        await old.close();
        closed = true;
        upgraded = DatabaseCoordinator(
          factory: factory,
          databasePath: old.databasePath,
          schemaVersion: 36,
        );
        for (final entry in before.entries) {
          expect(
            await upgraded.read((sql) => sql.query(entry.key)),
            entry.value,
            reason: entry.key,
          );
        }
        expect(
          await upgraded.read((sql) => sql.query('sale_receipt_requirements')),
          isEmpty,
        );
        expect(
          (await upgraded.read(
            (sql) => sql.query('receipt_print_policy'),
          )).single['required'],
          0,
        );
        await upgraded.read(ReceiptPolicyValidation.validate);
      } finally {
        if (!closed) await old.close();
        await upgraded?.close();
        await factory.deleteDatabase(old.databasePath);
      }
    },
  );

  test(
    'M53 receipt policy defaults off and printer failure cannot block an optional next basket',
    () async {
      expect((await app.receiptPolicy.policy()).required, false);
      final value = await sale();
      transport.unavailable = true;
      expect(await queue.send(await queue.prepare(value.$2.id)), 'failed');
      expect((await app.receiptPolicy.status(value.$2.id)).pending, false);
      expect((await app.cart.next(value.$1.id)).completedId, isNull);
      expect(
        await db.read((sql) => sql.query('sale_receipt_requirements')),
        isEmpty,
      );
    },
  );
  test(
    'M53 required receipt survives checkout retry lost pointer and a forged second active draft',
    () async {
      await enable();
      final value = await sale(), before = await facts();
      expect(
        (await app.checkout.submit(
          value.$1.id,
          value.$1.revision,
          const CheckoutInput(),
        )).id,
        value.$2.id,
      );
      await expectLater(app.cart.next(value.$1.id), throwsA(isA<AppError>()));
      final other = const IdGenerator().next();
      await db.transaction((sql) async {
        await sql.insert('cart_drafts', {
          'id': other.value,
          'currency_code': 'IDR',
          'currency_scale': 0,
          'created_at': 1,
          'updated_at': 1,
        });
        await sql.update('cashier_state', {'draft_id': null}, where: 'id=1');
      });
      final second = await app.cart.add(other, product);
      await expectLater(
        app.checkout.submit(second.id, second.revision, const CheckoutInput()),
        throwsA(isA<AppError>()),
      );
      expect((await app.cart.open()).completedId, value.$2.id);
      expect(await facts(), before);
      expect(
        (await db.read((sql) => sql.query('sale_receipt_requirements'))).length,
        1,
      );
    },
  );
  test(
    'M53 requirement insertion failure rolls back sale stock payment receipt and completed draft',
    () async {
      await enable();
      var draft = await app.cart.open();
      draft = await app.cart.add(draft.id, product);
      final before = await facts();
      await db.exclusive(
        (sql) => sql.execute(
          "CREATE TRIGGER fixture_receipt_failure BEFORE INSERT ON sale_receipt_requirements BEGIN SELECT RAISE(ABORT,'synthetic_failure'); END",
        ),
      );
      try {
        await expectLater(
          app.checkout.submit(draft.id, draft.revision, const CheckoutInput()),
          throwsA(isA<DatabaseException>()),
        );
      } finally {
        await db.exclusive(
          (sql) => sql.execute('DROP TRIGGER fixture_receipt_failure'),
        );
      }
      expect(await facts(), before);
      expect((await app.cart.read(draft.id)).completedId, isNull);
      final committed = await app.checkout.submit(
        draft.id,
        draft.revision,
        const CheckoutInput(),
      );
      expect((await app.receiptPolicy.status(committed.id)).pending, true);
    },
  );
  test(
    'M53 sent bytes do not fulfill required receipt and manual paper confirmation is idempotent without financial changes',
    () async {
      await enable();
      final value = await sale(), before = await facts();
      final job = await print(value.$2);
      expect((await app.receiptPolicy.status(value.$2.id)).pending, true);
      await expectLater(app.cart.next(value.$1.id), throwsA(isA<AppError>()));
      app.management
          .lock(); // Confirmation is a cashier action, not an owner bypass.
      await app.receiptPolicy.confirmPaper(
        value.$2.id,
        job,
        operationKey: 'paper-one',
      );
      await app.receiptPolicy.confirmPaper(
        value.$2.id,
        job,
        operationKey: 'paper-one',
      );
      expect(
        (await app.receiptPolicy.status(value.$2.id)).resolution,
        'operator_confirmation',
      );
      expect(await facts(), before);
      expect(
        (await db.read((sql) => sql.query('receipt_print_resolutions'))).length,
        1,
      );
      expect((await app.cart.next(value.$1.id)).completedId, isNull);
    },
  );
  test(
    'M53 pending prepared failed calibration wrong-sale and QR label jobs cannot be paper confirmations',
    () async {
      await enable();
      final value = await sale(), before = await facts();
      final prepared = await queue.prepare(value.$2.id);
      await expectLater(
        app.receiptPolicy.confirmPaper(
          value.$2.id,
          prepared,
          operationKey: 'prepared',
        ),
        throwsA(isA<AppError>()),
      );
      transport.unavailable = true;
      expect(await queue.send(prepared), 'failed');
      await expectLater(
        app.receiptPolicy.confirmPaper(
          value.$2.id,
          prepared,
          operationKey: 'failed',
        ),
        throwsA(isA<AppError>()),
      );
      transport.unavailable = false;
      final calibration = await queue.prepareCalibration();
      expect(await queue.send(calibration), 'submitted');
      await expectLater(
        app.receiptPolicy.confirmPaper(
          value.$2.id,
          calibration,
          operationKey: 'calibration',
        ),
        throwsA(isA<AppError>()),
      );
      final p = await app.labels.snapshot(product);
      final label = await app.labels.prepare(
        product,
        p.productRevision,
        device,
        const ProductLabelProfile(protocol: PrinterProtocol.escPosRaster),
        1,
        operationKey: 'not-a-receipt',
      );
      expect(await queue.send(label), 'submitted');
      await expectLater(
        app.receiptPolicy.confirmPaper(
          value.$2.id,
          label,
          operationKey: 'label',
        ),
        throwsA(isA<AppError>()),
      );
      expect(
        (await app.receiptPolicy.status(value.$2.id)).confirmableJob,
        isNull,
      );
      expect(await facts(), before);
    },
  );
  test(
    'M53 unknown delivery may be confirmed only after operator inspection and latest failed copy does not hide earlier eligible job',
    () async {
      await enable();
      final value = await sale();
      transport.partial = true;
      final job = await print(value.$2);
      expect((await queue.job(job))['status'], 'unknown');
      transport.partial = false;
      transport.unavailable = true;
      expect(
        await queue.send(await queue.prepare(value.$2.id, copy: true)),
        'failed',
      );
      final status = await app.receiptPolicy.status(value.$2.id);
      expect(status.latestStatus, 'failed');
      expect(status.confirmableJob, job);
      await app.receiptPolicy.confirmPaper(
        value.$2.id,
        job,
        operationKey: 'inspected-unknown',
      );
      expect((await app.cart.next(value.$1.id)).completedId, isNull);
    },
  );
  test(
    'M53 disabling future policy does not erase a committed paper obligation and owner exception needs fresh purpose reason and owner role',
    () async {
      await enable();
      final value = await sale(), before = await facts();
      await app.receiptPolicy.savePolicy(false, 2);
      expect((await app.receiptPolicy.status(value.$2.id)).pending, true);
      await app.management.reauthenticate('0001', 'security');
      final wrong = app.management.claimFresh('security');
      await expectLater(
        app.receiptPolicy.ownerException(
          value.$2.id,
          'PUBLIC PAPER EMPTY',
          wrong,
          operationKey: 'wrong-purpose',
        ),
        throwsA(isA<AppError>()),
      );
      await app.management.reauthenticate(
        '0001',
        ReceiptPolicyService.exceptionPurpose,
      );
      final claim = app.management.claimFresh(
        ReceiptPolicyService.exceptionPurpose,
      );
      await app.receiptPolicy.ownerException(
        value.$2.id,
        'PUBLIC PAPER EMPTY',
        claim,
        operationKey: 'exception',
      );
      expect(
        (await app.receiptPolicy.status(value.$2.id)).resolution,
        'owner_exception',
      );
      await expectLater(
        app.receiptPolicy.ownerException(
          value.$2.id,
          'PUBLIC PAPER EMPTY',
          claim,
          operationKey: 'exception',
        ),
        throwsA(isA<AppError>()),
      );
      expect(await facts(), before);
      expect((await app.cart.next(value.$1.id)).completedId, isNull);
      final next = await sale();
      expect((await app.receiptPolicy.status(next.$2.id)).required, false);
    },
  );
  test(
    'M53 warehouse cannot change required receipt policy and stale policy CAS cannot overwrite owner settings',
    () async {
      await enable();
      await expectLater(
        app.receiptPolicy.savePolicy(false, 1),
        throwsA(isA<AppError>()),
      );
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      await expectLater(app.receiptPolicy.policy(), throwsA(isA<AppError>()));
      await expectLater(
        app.receiptPolicy.savePolicy(false, 2),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 paper witnesses survive portable queue sanitization and projection tampering is rejected',
    () async {
      await enable();
      final value = await sale();
      final job = await print(value.$2);
      await app.receiptPolicy.confirmPaper(
        value.$2.id,
        job,
        operationKey: 'portable-witness',
      );
      await db.transaction((sql) async {
        await sql.delete('print_jobs');
        await sql.delete('printer_profiles');
      });
      await db.read(ReceiptPolicyValidation.validate);
      expect(
        (await app.receiptPolicy.status(value.$2.id)).resolution,
        'operator_confirmation',
      );
      await expectLater(
        db.transaction(
          (sql) =>
              sql.update('receipt_print_resolutions', {'reason': 'forged'}),
        ),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        db.transaction((sql) => sql.delete('receipt_print_resolutions')),
        throwsA(isA<DatabaseException>()),
      );
      await db.transaction(
        (sql) => sql.update('receipt_print_gate', {
          'pending_sale': value.$2.id,
        }, where: 'id=1'),
      );
      await expectLater(
        db.read(ReceiptPolicyValidation.validate),
        throwsFormatException,
      );
      await db.transaction(
        (sql) => sql.update('receipt_print_gate', {
          'pending_sale': null,
        }, where: 'id=1'),
      );
    },
  );
}
