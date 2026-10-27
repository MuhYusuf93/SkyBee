import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_validation.dart';
import 'package:kasir_app/features/cashier/application/cashier_store.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/tender_draft.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_service.dart';
import 'package:kasir_app/features/cash_drawer/application/cash_drawer_history_service.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_drawer_models.dart';
import 'package:kasir_app/features/cash_drawer/domain/cash_pieces.dart';
import 'database_contract_suite.dart' show fixtureId;

// Newly owned numeric fixtures only. Core cases complement financial coupling
// and backup/UI acceptance; they do not by themselves complete stage D.
void m53DrawerSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late CashDrawerService service;
  late DateTime now;
  late Map<String, Object?> credential;
  var serial = 0;
  final currency = CurrencyPolicy.forCode('IDR');
  CashPieces pieces(Map<int, int> values) => CashPieces(currency, values);
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'key', key);
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_drawer_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC DRAWER', '0001', '0001');
      credential = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 28, 10);
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credential),
    );
    app = AppServices(db, clock: StoreClock(now: () => now));
    service = CashDrawerService(
      db,
      app.management,
      CashierStore(app.management.clock, cashierAccess: app.cashierLock),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());
  Future<EntityId> open(CashPieces? opening, {bool pending = false}) async {
    final context = await service.context();
    return service.open(
      operationKey: fixtureId(100 + serial++),
      expected: context,
      opening: opening,
      reason: 'PUBLIC OPENING DECLARATION',
      acceptPending: pending,
    );
  }

  Future<void> notes() async {
    final context = await service.context();
    await service.setNotes(true, context.policy.revision);
  }

  Future<EntityId> stock() async {
    await app.management.unlock('0001');
    final id = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC CASH ITEM',
        sellingPrice: Money(93000, 'IDR', 0),
      ),
      initialQuantity: 4,
      unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
    );
    app.management.lock();
    return id;
  }

  CheckoutInput input(
    EntityId session,
    Map<int, int> received, {
    Map<int, int> change = const {},
    bool credit = false,
  }) {
    final tender = TenderDraft(currency)..replaceCounts(received);
    return CheckoutInput(
      cash: true,
      tender: tender.money,
      tenderRaw: tender.raw,
      tenderDetails: tender.snapshot,
      drawerSessionId: session,
      changePieces: pieces(change),
      memberIntent: credit,
      customer: credit
          ? const CustomerChoice(name: 'PUBLIC CREDIT', phone: '081234567890')
          : const CustomerChoice(),
    );
  }

  test(
    'M53 drawer known zero differs from unknown; canonical pieces currency overflow and malformed imports',
    () async {
      expect((await service.context()).policy.mode, CashDrawerMode.off);
      final zero = pieces({});
      expect(zero.total.amountMinor, 0);
      expect(
        CashPieces.decode(currency, zero.encode()).encode(),
        zero.encode(),
      );
      expect(() => pieces({1000: -1}), throwsFormatException);
      expect(() => pieces({93000: 1}), throwsFormatException);
      expect(
        () => pieces({1000: CashPieces.maxCount + 1}),
        throwsFormatException,
      );
      expect(
        () => CashPieces.decode(
          currency,
          '{"version":1,"currency":"IDR","scale":0,"counts":{"0100":1}}',
        ),
        throwsFormatException,
      );
      expect(
        () => zero.plus(CashPieces(CurrencyPolicy.forCode('USD'), {1: 1})),
        throwsA(anything),
      );
      await notes();
      final unknown = await open(null);
      final current = (await service.context()).session!;
      expect(current.id, unknown);
      expect(current.balance.known, isFalse);
      expect(current.balance.pieces.total.amountMinor, 0);
      expect(current.openingKnown, isFalse);
      await expectLater(
        service.journal(
          session: unknown,
          operationKey: fixtureId(1),
          pieces: pieces({1000: 1}),
          incoming: false,
          reason: 'PUBLIC OUT',
        ),
        throwsA(error('m53CashPiecesUnavailable')),
      );
      expect(
        (await service.context()).session!.balance.revision,
        current.balance.revision,
      );
    },
  );
  test(
    'M53 drawer journal retries and recount record actual composition without creating sales',
    () async {
      await notes();
      final id = await open(pieces({1000: 2}));
      final event = await service.journal(
        session: id,
        operationKey: fixtureId(1),
        pieces: pieces({10000: 1}),
        incoming: true,
        reason: 'PUBLIC TOPUP',
      );
      expect(
        await service.journal(
          session: id,
          operationKey: fixtureId(1),
          pieces: pieces({10000: 1}),
          incoming: true,
          reason: 'PUBLIC TOPUP',
        ),
        event,
      );
      await expectLater(
        service.journal(
          session: id,
          operationKey: fixtureId(1),
          pieces: pieces({5000: 1}),
          incoming: true,
          reason: 'PUBLIC TOPUP',
        ),
        throwsA(error('m3AttemptChanged')),
      );
      var state = (await service.context()).session!.balance;
      expect(state.pieces.total.amountMinor, 12000);
      await service.reconcile(
        session: id,
        revision: state.revision,
        operationKey: fixtureId(2),
        observed: pieces({5000: 2, 1000: 2}),
        reason: 'PUBLIC EXCHANGE COUNT',
      );
      state = (await service.context()).session!.balance;
      expect(state.known, isTrue);
      expect(state.pieces.total.amountMinor, 12000);
      await service.journal(
        session: id,
        operationKey: fixtureId(3),
        pieces: pieces({5000: 1}),
        incoming: false,
        handover: true,
        reason: 'PUBLIC HANDOVER',
      );
      state = (await service.context()).session!.balance;
      expect(state.pieces.total.amountMinor, 7000);
      await service.close(
        session: id,
        revision: state.revision,
        operationKey: fixtureId(4),
        observed: pieces({5000: 1, 1000: 2}),
        reason: '',
      );
      expect((await service.context()).session!.closed, isTrue);
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      expect(await db.read((sql) => sql.query('payments')), isEmpty);
      expect(
        (await db.read(
          (sql) => sql.query('cash_drawer_closures'),
        )).single['difference_minor'],
        0,
      );
    },
  );
  test(
    'M53 drawer midnight does not close old session or duplicate opening; rollback clock blocks new facts',
    () async {
      await notes();
      final first = await open(pieces({1000: 2}));
      now = now.add(const Duration(days: 1));
      var context = await service.context();
      expect(context.session, isNull);
      expect(context.unclosedOlder, 1);
      await expectLater(
        open(pieces({})),
        throwsA(error('m53CashPreviousUnclosed')),
      );
      final second = await open(pieces({}), pending: true);
      expect(second, isNot(first));
      context = await service.context();
      expect(context.unclosedOlder, 1);
      expect(context.session!.balance.pieces.total.amountMinor, 0);
      expect(
        await db.read((sql) => sql.query('cash_drawer_closures')),
        isEmpty,
      );
      now = now.subtract(const Duration(minutes: 1));
      await expectLater(
        service.journal(
          session: second,
          operationKey: fixtureId(9),
          pieces: pieces({1000: 1}),
          incoming: true,
          reason: 'PUBLIC',
        ),
        throwsA(error('m53CashClockChanged')),
      );
    },
  );

  test(
    'M53 drawer checkout atomically records 95000 tender minus 2000 change, retries once and refunds net with actual different pieces',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({1000: 5, 2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      final paid = input(
        session,
        {50000: 1, 20000: 2, 5000: 1},
        change: {2000: 1},
      );
      await app.cart.saveInput(cart.id, cart.revision, paid);
      final restored = await app.cart.read(cart.id);
      expect(restored.input.drawerSessionId, session);
      expect(
        restored.input.changePieces!.encode(),
        paid.changePieces!.encode(),
      );
      final sale = await app.checkout.submit(cart.id, cart.revision, paid);
      expect(sale.total.amountMinor, 93000);
      expect(sale.cashTender!.received.amountMinor, 95000);
      expect(sale.cashTender!.change.amountMinor, 2000);
      expect(
        (await service.context()).session!.balance.pieces.total.amountMinor,
        102000,
      );
      expect(
        (await app.checkout.submit(cart.id, cart.revision, paid)).id,
        sale.id,
      );
      expect(
        (await db.read((sql) => sql.query('cash_drawer_events'))).length,
        1,
      );
      final source = (await db.read(
        (sql) => sql.query('payment_cash_sources'),
      )).single;
      expect(source['in_minor'], 95000);
      expect(source['out_minor'], 2000);
      expect(source['policy_mode'], 'notes');
      await app.management.unlock('0001');
      final refund = CashPaymentIntent(
        source: CashPaymentSource.drawer,
        sessionId: session,
        outgoing: pieces({50000: 1, 20000: 2, 2000: 1, 1000: 1}),
      );
      final reversal = await app.corrections.cancelSale(
        sale.id,
        operationKey: 'PUBLIC-SALE-REFUND',
        reason: 'PUBLIC RETURN',
        goodsReturned: true,
        moneyHandled: true,
        cash: refund,
      );
      expect(
        await app.corrections.cancelSale(
          sale.id,
          operationKey: 'PUBLIC-SALE-REFUND',
          reason: 'PUBLIC RETURN',
          goodsReturned: true,
          moneyHandled: true,
          cash: refund,
        ),
        reversal,
      );
      expect(
        (await service.context()).session!.balance.pieces.total.amountMinor,
        9000,
      );
      final events = await db.read(
        (sql) => sql.query('cash_drawer_events', orderBy: 'sequence'),
      );
      expect(events.length, 2);
      expect(events.last['cash_out_minor'], 93000);
      expect(
        (await db.read(
          (sql) =>
              sql.query('products', where: 'id=?', whereArgs: [product.value]),
        )).single['stock_quantity'],
        4,
      );
    },
  );

  test(
    'M53 drawer active mode refuses manual/exact or incomplete change without touching stock or financial facts',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      final tender = TenderDraft(currency)..exact(Money(93000, 'IDR', 0));
      await expectLater(
        app.checkout.submit(
          cart.id,
          cart.revision,
          CheckoutInput(
            cash: true,
            tender: tender.money,
            tenderRaw: tender.raw,
            tenderDetails: tender.snapshot,
            drawerSessionId: session,
          ),
        ),
        throwsA(error('m53CashCompositionRequired')),
      );
      await expectLater(
        app.checkout.submit(
          cart.id,
          cart.revision,
          input(session, {50000: 1, 20000: 2, 5000: 1}),
        ),
        throwsA(error('m53CashCompositionMismatch')),
      );
      await expectLater(
        app.checkout.submit(cart.id, cart.revision, const CheckoutInput()),
        throwsA(error('m53CashCompositionRequired')),
      );
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      expect(await db.read((sql) => sql.query('payments')), isEmpty);
      expect(
        await db.read((sql) => sql.query('payment_cash_sources')),
        isEmpty,
      );
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
      expect((await app.cart.read(cart.id)).completedId, isNull);
      expect(
        (await db.read(
          (sql) =>
              sql.query('products', where: 'id=?', whereArgs: [product.value]),
        )).single['stock_quantity'],
        4,
      );
    },
  );

  test(
    'M53 drawer repayment records received and change once without a new sale HPP or visit; explicit external refund leaves drawer unchanged',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({1000: 5, 2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      final sale = await app.checkout.submit(
        cart.id,
        cart.revision,
        input(session, {20000: 1, 10000: 1}, credit: true),
      );
      final customer = EntityId(
        (await db.read((sql) => sql.query('customers'))).single['id'] as String,
      );
      final before = await db.read(
        (sql) async => [
          await sql.query('products'),
          await sql.query('sale_transaction_items'),
          await sql.query('stock_history'),
        ],
      );
      final plan = await app.receivables.preview(
        customer,
        Money(20000, 'IDR', 0),
      );
      final receipt = CashPaymentIntent(
        source: CashPaymentSource.drawer,
        sessionId: session,
        incoming: pieces({50000: 1}),
        outgoing: pieces({20000: 1, 10000: 1}),
      );
      final payment = await app.receivables.record(plan, cash: receipt);
      expect(await app.receivables.record(plan, cash: receipt), payment);
      expect(
        (await service.context()).session!.balance.pieces.total.amountMinor,
        59000,
      );
      expect(
        (await db.read((sql) => sql.query('customers'))).single['visit_count'],
        1,
      );
      expect(
        await db.read(
          (sql) async => [
            await sql.query('products'),
            await sql.query('sale_transaction_items'),
            await sql.query('stock_history'),
          ],
        ),
        before,
      );
      expect((await app.checkout.receipt(sale.id)).outstanding, 43000);
      await app.management.unlock('0001');
      const outside = CashPaymentIntent(source: CashPaymentSource.external);
      await app.corrections.cancelPayment(
        payment,
        operationKey: 'PUBLIC-OUTSIDE-REFUND',
        reason: 'PUBLIC OWNER FUNDS',
        moneyHandled: true,
        cash: outside,
      );
      expect(
        (await service.context()).session!.balance.pieces.total.amountMinor,
        59000,
      );
      expect((await app.checkout.receipt(sale.id)).outstanding, 63000);
      expect(
        (await db.read((sql) => sql.query('cash_drawer_events'))).length,
        2,
      );
    },
  );

  test(
    'M53 drawer post failure rolls the sale ledger provenance balances and durable input back together',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      final paid = input(
        session,
        {50000: 1, 20000: 2, 5000: 1},
        change: {2000: 1},
      );
      await app.cart.saveInput(cart.id, cart.revision, paid);
      final before = await db.read(
        (sql) async => [
          await sql.query('products'),
          await sql.query('stock_batches'),
          await sql.query('cash_drawer_balances'),
          await sql.query('cash_drawer_state'),
          await sql.query('cart_drafts'),
        ],
      );
      for (final stage in ['drawer', 'draft', 'audit']) {
        final failing = CheckoutService(
          db,
          service.store,
          testStage: (at) async {
            if (at == stage) throw StateError('PUBLIC CASH FAULT');
          },
        );
        await expectLater(
          failing.submit(cart.id, cart.revision, paid),
          throwsStateError,
        );
        expect(
          await db.read(
            (sql) async => [
              await sql.query('products'),
              await sql.query('stock_batches'),
              await sql.query('cash_drawer_balances'),
              await sql.query('cash_drawer_state'),
              await sql.query('cart_drafts'),
            ],
          ),
          before,
        );
        for (final table in [
          'sale_transactions',
          'payments',
          'payment_cash_sources',
          'cash_drawer_events',
        ]) {
          expect(await db.read((sql) => sql.query(table)), isEmpty);
        }
      }
      await app.checkout.submit(cart.id, cart.revision, paid);
      expect(
        (await db.read((sql) => sql.query('cash_drawer_events'))).length,
        1,
      );
    },
  );

  test(
    'M53 drawer backup reconstructs pieces and rejects forged cache, missing payment provenance and inconsistent change',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({1000: 5, 2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      await app.checkout.submit(
        cart.id,
        cart.revision,
        input(session, {50000: 1, 20000: 2, 5000: 1}, change: {2000: 1}),
      );
      Future<void> validate() => db.read(CashDrawerValidation.validate);
      await validate();
      final manifest = await db.read((sql) async {
        final settings = (await sql.query('store_settings')).single,
            shop = await sql.query('m5_store');
        return BackupManifest({
          'format': 1,
          'cipher': 'SQLCipher',
          'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
          'id': 'public-drawer',
          'storeId': shop.isEmpty ? 'public-store' : shop.single['store_id'],
          'originId': 'public-origin',
          'schema': Schema.version,
          'createdAt': 1,
          'currency': settings['currency_code'],
          'currencyScale': settings['currency_scale'],
          'timeZone': settings['time_zone'],
          'appVersion': '0.5.2+12',
          'files': {
            'database.db': {'bytes': 1, 'sha256': '0' * 64},
          },
        });
      });
      await db.read((sql) => BackupValidation.validate(sql, manifest));
      Future<void> rejects(
        Future<void> Function(Transaction sql) corrupt,
      ) async {
        final rollback = StateError('PUBLIC CORRUPTION ROLLBACK');
        await expectLater(
          db.transaction((sql) async {
            await corrupt(sql);
            await expectLater(
              CashDrawerValidation.validate(sql),
              throwsFormatException,
            );
            throw rollback;
          }),
          throwsA(same(rollback)),
        );
        await validate();
      }

      await rejects((sql) async {
        await sql.rawUpdate(
          'UPDATE cash_drawer_balances SET piece_count=piece_count+1 WHERE denomination=1000',
        );
      });
      await rejects((sql) async {
        await sql.execute('DROP TRIGGER payment_cash_sources_no_delete');
        await sql.delete('payment_cash_sources');
      });
      await rejects((sql) async {
        await sql.execute('DROP TRIGGER checkout_tenders_no_update');
        await sql.update('checkout_tenders', {
          'change_counts_json': pieces({1000: 1}).encode(),
        });
      });
      await rejects((sql) async {
        await sql.rawUpdate('UPDATE cash_drawer_state SET revision=revision+1');
      });
      final state = (await service.context()).session!.balance;
      await service.close(
        session: session,
        revision: state.revision,
        operationKey: fixtureId(99),
        observed: state.pieces,
        reason: '',
      );
      await validate();
      await rejects((sql) async {
        await sql.execute('DROP TRIGGER cash_drawer_closures_no_update');
        await sql.update('cash_drawer_closures', {'difference_minor': 1});
      });
      await db.read((sql) => BackupValidation.validate(sql, manifest));
    },
  );

  test(
    'M53 drawer populated23 migration preserves every original cell and legacy retry without inventing cash sessions or payment sources',
    () async {
      await db.close();
      await factory.deleteDatabase(db.databasePath);
      final legacy = DatabaseCoordinator(
        factory: factory,
        databasePath: db.databasePath,
        schemaVersion: 23,
      );
      await legacy.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      final old = AppServices(legacy, clock: StoreClock(now: () => now));
      await old.management.unlock('0001');
      final id = await old.inventory.create(
        ProductInput(
          name: 'PUBLIC LEGACY CASH',
          sellingPrice: Money(93000, 'IDR', 0),
        ),
        initialQuantity: 4,
        unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
      );
      var cart = await old.cart.open();
      cart = await old.cart.add(cart.id, id);
      final paid = CheckoutInput(
        cash: true,
        tender: Money(95000, 'IDR', 0),
        tenderRaw: '95000',
      );
      final original = await old.checkout.submit(cart.id, cart.revision, paid);
      final tables = [
        'products',
        'sale_transactions',
        'sale_transaction_items',
        'payments',
        'cart_drafts',
        'management_credentials',
        'store_settings',
      ];
      final columns = await legacy.read(
        (sql) async => {
          for (final table in tables)
            table: (await sql.rawQuery(
              'PRAGMA table_info($table)',
            )).map((r) => r['name'] as String).toList(),
        },
      );
      final before = await legacy.read(
        (sql) async => {
          for (final table in tables)
            table: await sql.query(table, columns: columns[table]),
        },
      );
      await legacy.close();
      db = DatabaseCoordinator(
        factory: factory,
        databasePath: legacy.databasePath,
      );
      expect(
        await db.read(
          (sql) async => {
            for (final table in tables)
              table: await sql.query(table, columns: columns[table]),
          },
        ),
        before,
      );
      expect(
        await db.read((sql) => sql.query('cash_drawer_sessions')),
        isEmpty,
      );
      expect(
        await db.read((sql) => sql.query('payment_cash_sources')),
        isEmpty,
      );
      expect(
        (await db.read(
          (sql) => sql.query('payments'),
        )).single['cash_provenance_version'],
        0,
      );
      expect(
        (await db.read(
          (sql) => sql.query('sale_transactions'),
        )).single['drawer_version'],
        0,
      );
      app = AppServices(db, clock: StoreClock(now: () => now));
      expect(
        (await app.checkout.submit(cart.id, cart.revision, paid)).id,
        original.id,
      );
      expect(
        await db.read((sql) => sql.query('payment_cash_sources')),
        isEmpty,
      );
      await db.read(CashDrawerValidation.validate);
    },
  );

  test(
    'M53 drawer audit requires a fresh owner action, cashier cannot disable it and late owner revocation rolls policy and audit back',
    () async {
      await expectLater(
        service.configure(CashDrawerMode.audit, 1),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      await app.management.reauthenticate('0001', 'security');
      await service.configure(CashDrawerMode.audit, 1);
      await expectLater(
        service.configure(CashDrawerMode.off, 2),
        throwsA(error('m51FreshAuthenticationRequired')),
      );
      app.management.lock();
      await expectLater(
        service.setNotes(false, 2),
        throwsA(error('m53CashAuditRequired')),
      );
      await app.management.reauthenticate('0001', 'security');
      final before = await db.read(
        (sql) async => [
          await sql.query('cash_drawer_policy'),
          await sql.query('audit_log'),
        ],
      );
      final late = CashDrawerService(
        db,
        app.management,
        service.store,
        testStage: (stage) async {
          if (stage == 'policy-written') app.management.lock();
        },
      );
      await expectLater(
        late.configure(CashDrawerMode.notes, 2),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      expect(
        await db.read(
          (sql) async => [
            await sql.query('cash_drawer_policy'),
            await sql.query('audit_log'),
          ],
        ),
        before,
      );
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '0002',
        confirmation: '0002',
      );
      await app.management.unlock('0002', role: ManagementRole.warehouse);
      await expectLater(
        service.configure(CashDrawerMode.off, 2),
        throwsA(error('m53OwnerRequired')),
      );
      expect((await service.context()).policy.mode, CashDrawerMode.audit);
    },
  );

  test(
    'M53 drawer late cashier lock rolls post and checkout back before result publication',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      final paid = input(
        session,
        {50000: 1, 20000: 2, 5000: 1},
        change: {2000: 1},
      );
      await app.cart.saveInput(cart.id, cart.revision, paid);
      await db.transaction(
        (sql) => sql.update('cashier_lock_policy', {
          'enabled': 1,
          'pin_source': 'owner',
          'revision': 2,
          'gate_epoch': 1,
        }, where: 'id=1'),
      );
      await app.cashierLock.load();
      await app.cashierLock.unlock('0001');
      final before = await db.read(
        (sql) async => [
          await sql.query('products'),
          await sql.query('stock_batches'),
          await sql.query('cash_drawer_balances'),
          await sql.query('cash_drawer_state'),
        ],
      );
      final failing = CheckoutService(
        db,
        service.store,
        testStage: (stage) async {
          if (stage == 'drawer') app.cashierLock.lock();
        },
      );
      await expectLater(
        failing.submit(cart.id, cart.revision, paid),
        throwsA(error('m53CashierLocked')),
      );
      expect(
        await db.read(
          (sql) async => [
            await sql.query('products'),
            await sql.query('stock_batches'),
            await sql.query('cash_drawer_balances'),
            await sql.query('cash_drawer_state'),
          ],
        ),
        before,
      );
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      expect(
        await db.read((sql) => sql.query('payment_cash_sources')),
        isEmpty,
      );
      expect(await db.read((sql) => sql.query('cash_drawer_events')), isEmpty);
      await app.cashierLock.unlock('0001');
      await app.checkout.submit(cart.id, cart.revision, paid);
      expect(
        (await db.read((sql) => sql.query('cash_drawer_events'))).length,
        1,
      );
      expect(app.management.isUnlocked, isFalse);
    },
  );

  test(
    'M53 drawer history keysets bound pages and scope; notes persist off and owner late revocation redacts audit',
    () async {
      await notes();
      EntityId? latest;
      for (var n = 0; n < 27; n++) {
        latest = await open(pieces({}));
        await service.close(
          session: latest,
          revision: 1,
          operationKey: fixtureId(1000 + n),
          observed: pieces({}),
          reason: 'PUBLIC CLOSE',
        );
      }
      await service.setNotes(false, (await service.context()).policy.revision);
      final first = await app.cashDrawerHistory.sessions();
      final second = await app.cashDrawerHistory.sessions(after: first.next);
      expect(first.items.length, 25);
      expect(second.items.length, 2);
      expect(second.next, isNull);
      expect(
        {
          ...first.items.map((s) => s.id),
          ...second.items.map((s) => s.id),
        }.length,
        27,
      );
      expect(
        first.items.every(
          (s) =>
              s.closed &&
              s.balance.known &&
              s.balance.pieces.total.amountMinor == 0,
        ),
        isTrue,
      );
      await app.management.reauthenticate('0001', 'security');
      await service.configure(
        CashDrawerMode.audit,
        (await service.context()).policy.revision,
      );
      final audit = await open(pieces({1000: 50}));
      for (var n = 0; n < 27; n++) {
        await service.journal(
          session: audit,
          operationKey: fixtureId(2000 + n),
          incoming: true,
          pieces: pieces({1000: 1}),
          reason: 'PUBLIC JOURNAL',
        );
      }
      expect(
        (await app.cashDrawerHistory.sessions()).items.any(
          (s) => s.id == audit,
        ),
        isFalse,
      );
      await expectLater(
        app.cashDrawerHistory.detail(audit),
        throwsA(error('m53CashSessionRequired')),
      );
      final one = await app.cashDrawerHistory.detail(audit, owner: true);
      final two = await app.cashDrawerHistory.detail(
        audit,
        owner: true,
        after: one.next,
      );
      expect(one.events.length, 25);
      expect(two.events.length, 2);
      expect(two.next, isNull);
      expect(
        [...one.events, ...two.events].map((e) => e['sequence']),
        List.generate(27, (n) => n + 1),
      );
      expect(one.session.balance.pieces.total.amountMinor, 77000);
      expect(
        () =>
            app.cashDrawerHistory.detail(latest!, owner: true, after: one.next),
        throwsA(error('m53CashSessionChanged')),
      );
      expect(
        () => app.cashDrawerHistory.sessions(owner: true, after: first.next),
        throwsA(error('m53CashSessionChanged')),
      );
      final revoking = CashDrawerHistoryService(
        CashDrawerService(
          db,
          app.management,
          service.store,
          testStage: (stage) async {
            if (stage == 'history-read') app.management.lock();
          },
        ),
      );
      await expectLater(
        revoking.sessions(owner: true),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      await expectLater(
        app.cashDrawerHistory.policy(),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      await db.read(CashDrawerValidation.validate);
    },
  );

  test(
    'M53 drawer owner sale audit reads applied cash separately and refund preview never uses larger tender',
    () async {
      final product = await stock();
      await notes();
      final session = await open(pieces({2000: 2}));
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      final paid = input(
        session,
        {50000: 1, 20000: 2, 5000: 1},
        change: {2000: 1},
      );
      final receipt = await app.checkout.submit(cart.id, cart.revision, paid);
      await expectLater(
        app.cashDrawerHistory.sale(receipt.id),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      await app.management.unlock('0001');
      final audit = await app.cashDrawerHistory.sale(receipt.id);
      expect(audit!['received_minor'], 95000);
      expect(audit['applied_minor'], 93000);
      expect(audit['change_minor'], 2000);
      expect(audit['session_id'], session.value);
      expect(
        (await app.corrections.refundAmount(
          receipt.id,
          sale: true,
        )).amountMinor,
        93000,
      );
      await app.corrections.cancelSale(
        receipt.id,
        operationKey: fixtureId(5000),
        reason: 'PUBLIC RETURN',
        goodsReturned: true,
        moneyHandled: true,
        cash: const CashPaymentIntent(source: CashPaymentSource.external),
      );
      expect(
        (await app.corrections.refundAmount(
          receipt.id,
          sale: true,
        )).amountMinor,
        0,
      );
      expect(
        (await app.cashDrawerHistory.sale(receipt.id))!['received_minor'],
        95000,
      );
    },
  );

  test(
    'M53 drawer old-day closure requires explicit owner exception and never fabricates a historical physical count',
    () async {
      await notes();
      final old = await open(pieces({2000: 2}));
      final oldState = (await service.context()).session!.balance;
      now = now.add(const Duration(days: 1));
      await open(pieces({}), pending: true);
      await expectLater(
        service.close(
          session: old,
          revision: oldState.revision,
          operationKey: fixtureId(500),
          observed: oldState.pieces,
          reason: 'PUBLIC LATE COUNT',
        ),
        throwsA(error('m53CashOldSession')),
      );
      await expectLater(
        service.close(
          session: old,
          revision: oldState.revision,
          operationKey: fixtureId(500),
          observed: null,
          reason: 'PUBLIC MISSED COUNT',
          ownerException: true,
        ),
        throwsA(error('managementSessionLockedEnterPinAgain')),
      );
      await app.management.reauthenticate('0001', 'security');
      await service.close(
        session: old,
        revision: oldState.revision,
        operationKey: fixtureId(500),
        observed: null,
        reason: 'PUBLIC MISSED COUNT',
        ownerException: true,
      );
      final close = (await db.read(
        (sql) => sql.query(
          'cash_drawer_closures',
          where: 'session_id=?',
          whereArgs: [old.value],
        ),
      )).single;
      expect(close['observed_counts_json'], isNull);
      expect(close['difference_minor'], isNull);
      expect(close['owner_exception'], 1);
      expect((await service.context()).unclosedOlder, 0);
      await db.read(CashDrawerValidation.validate);
    },
  );
}
