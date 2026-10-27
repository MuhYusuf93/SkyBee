import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/features/cashier/application/checkout_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/cashier/domain/tender_draft.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';

/// Mixed manual/count amounts remain explicitly incomplete physical evidence.
/// These fixtures never open an ordinary or exploration package database.
void m53TenderSuite(DatabaseFactory factory) {
  late Directory directory;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credentials;
  var serial = 0;
  final idr = CurrencyPolicy.forCode('IDR');
  Money m(int n) => Money(n, 'IDR', 0);
  String path() =>
      '${directory.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Matcher error(String key) =>
      isA<AppError>().having((e) => e.message, 'message', key);
  Future<BackupManifest> manifest() => db.read((sql) async {
    final settings = (await sql.query('store_settings')).single;
    final shop = await sql.query('m5_store');
    return BackupManifest({
      'format': 1,
      'cipher': 'SQLCipher',
      'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
      'id': 'public-tender',
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
  Future<EntityId> product() => app.inventory.create(
    ProductInput(name: 'PUBLIC TENDER', sellingPrice: m(93000)),
    initialQuantity: 3,
    unitCost: CostAmount.fromMoney(m(50000)),
  );
  CheckoutInput input(TenderSnapshot snapshot) => CheckoutInput(
    cash: true,
    mode: PaymentMode.paid,
    tender: snapshot.money,
    tenderRaw: snapshot.raw,
    tenderDetails: snapshot,
  );
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('kasir_m53_tender_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC TENDER', '0001', '0001');
      credentials = Map.of(
        (await seed.read((sql) => sql.query('management_credentials'))).single,
      );
    } finally {
      await seed.close();
      await factory.deleteDatabase(seed.databasePath);
    }
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credentials),
    );
    app = AppServices(db);
    await app.management.unlock('0001');
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => directory.delete());

  test(
    'M53 tender adds denominations, reverses counts and retains immutable prior snapshots',
    () async {
      final draft = TenderDraft(idr);
      for (final amount in [50000, 20000, 10000, 10000, 5000]) {
        draft.receive(m(amount));
      }
      expect(draft.money!.amountMinor, 95000);
      expect(draft.counts[10000], 2);
      expect(draft.completeComposition, isTrue);
      final first = draft.snapshot;
      expect(draft.remove(10000), isTrue);
      expect(draft.money!.amountMinor, 85000);
      expect(draft.counts[10000], 1);
      expect(first.money!.amountMinor, 95000);
      expect(first.counts[10000], 2);
      expect(() => first.counts[10000] = 4, throwsUnsupportedError);
      expect(draft.remove(2000), isFalse);
      expect(draft.money!.amountMinor, 85000);
    },
  );
  test(
    'M53 tender exact replaces on the first digit and clear resets only the editor',
    () async {
      final draft = TenderDraft(idr)..exact(m(93000));
      final saved = TenderSnapshot.decode(idr, draft.snapshot.encode());
      final resumed = TenderDraft.restore(idr, saved)..key('5');
      expect(resumed.raw, '5');
      resumed.key('000');
      expect(resumed.money!.amountMinor, 5000);
      resumed.receive(m(10000));
      expect(resumed.money!.amountMinor, 15000);
      expect(resumed.unclassifiedMinor, 5000);
      expect(resumed.completeComposition, isFalse);
      resumed.key('back');
      expect(resumed.money!.amountMinor, 1500);
      expect(resumed.counts, isEmpty);
      resumed.clear();
      expect(resumed.money, isNull);
      expect(resumed.counts, isEmpty);
      expect(draft.money!.amountMinor, 93000);
    },
  );
  test(
    'M53 tender 000 obeys each currency precision and exact decimal input does not append',
    () async {
      for (final code in ['USD', 'MYR', 'EUR']) {
        final currency = CurrencyPolicy.forCode(code);
        final draft = TenderDraft(currency, '93.5')..key('000');
        expect(draft.raw, '93.50');
        expect(draft.money!.amountMinor, 9350);
        draft.exact(Money(9300, code, 2));
        draft.key('.');
        draft.key('5');
        expect(draft.money!.amountMinor, 50);
        draft.key('000');
        expect(draft.raw, '0.50');
      }
    },
  );
  test(
    'M53 tender codec rejects forged totals, counts and unknown fields without changing old intent',
    () async {
      final draft = TenderDraft(idr)..receive(m(50000));
      final map = jsonDecode(draft.snapshot.encode()) as Map<String, dynamic>;
      map['unclassified'] = 1;
      expect(
        () => TenderSnapshot.decode(idr, jsonEncode(map)),
        throwsFormatException,
      );
      map['unclassified'] = 0;
      map['counts'] = {'50000': 0};
      expect(
        () => TenderSnapshot.decode(idr, jsonEncode(map)),
        throwsFormatException,
      );
      map['counts'] = {'50000': 1};
      map['ownerPin'] = '0001';
      expect(
        () => TenderSnapshot.decode(idr, jsonEncode(map)),
        throwsFormatException,
      );
      expect(draft.money!.amountMinor, 50000);
      expect(() => draft.receive(Money(1, 'USD', 2)), throwsFormatException);
      expect(draft.money!.amountMinor, 50000);
    },
  );
  test(
    'M53 tender persists counts through cart reopen and checkout atomically snapshots declared composition',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final draft = TenderDraft(idr)
        ..receive(m(50000))
        ..receive(m(20000))
        ..receive(m(10000))
        ..receive(m(10000))
        ..receive(m(5000));
      final intent = input(draft.snapshot);
      await app.cart.saveInput(cart.id, cart.revision, intent);
      final restored = await app.cart.read(cart.id);
      expect(restored.input.tenderDetails!.counts[10000], 2);
      final receipt = await app.checkout.submit(cart.id, cart.revision, intent);
      expect(receipt.cashTender!.change.amountMinor, 2000);
      final row = (await db.read(
        (sql) => sql.query('checkout_tenders', columns: ['details_json']),
      )).single;
      expect(
        TenderSnapshot.decode(idr, row['details_json'] as String).counts[10000],
        2,
      );
      expect(
        (await app.checkout.submit(cart.id, cart.revision, intent)).id,
        receipt.id,
      );
      final changed = TenderDraft(idr)..receive(m(95000));
      await expectLater(
        app.checkout.submit(cart.id, cart.revision, input(changed.snapshot)),
        throwsA(error('m3AttemptChanged')),
      );
      expect(
        (await db.read((sql) => sql.query('sale_transactions'))).length,
        1,
      );
    },
  );
  test(
    'M53 tender cosmetic source differences do not change a committed financial payload',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final exact = TenderDraft(idr)..exact(m(93000));
      final receipt = await app.checkout.submit(
        cart.id,
        cart.revision,
        input(exact.snapshot),
      );
      final manual = TenderDraft(idr, '93000');
      expect(
        (await app.checkout.submit(
          cart.id,
          cart.revision,
          input(manual.snapshot),
        )).id,
        receipt.id,
      );
      final row = (await db.read(
        (sql) => sql.query('checkout_tenders', columns: ['details_json']),
      )).single;
      expect(
        TenderSnapshot.decode(idr, row['details_json'] as String).origin,
        TenderOrigin.exact,
      );
    },
  );
  test(
    'M53 tender old cash-v1 retries remain valid without rich metadata',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final legacy = CheckoutInput(
        cash: true,
        mode: PaymentMode.paid,
        tender: m(95000),
        tenderRaw: '95000',
      );
      final receipt = await app.checkout.submit(cart.id, cart.revision, legacy);
      expect(
        (await app.checkout.submit(cart.id, cart.revision, legacy)).id,
        receipt.id,
      );
      expect(
        (await db.read(
          (sql) => sql.query('checkout_tenders', columns: ['details_json']),
        )).single['details_json'],
        isNull,
      );
    },
  );
  test(
    'M53 public quick amount edit grants no management access and strictly rejects duplicate or nonpositive values',
    () async {
      app.management.lock();
      await app.quickCash.saveForCashier('IDR', [5000, 10000, 20000]);
      expect(await app.quickCash.read('IDR'), [5000, 10000, 20000]);
      expect(app.management.isUnlocked, isFalse);
      await expectLater(
        app.quickCash.saveForCashier('IDR', [5000, 5000]),
        throwsA(error('m53QuickAmountsInvalid')),
      );
      await expectLater(
        app.quickCash.saveForCashier('IDR', [0, 10000]),
        throwsA(error('m53QuickAmountsInvalid')),
      );
      await expectLater(
        app.quickCash.saveForCashier('USD', [100]),
        throwsA(error('currencyMismatch')),
      );
      expect(await app.quickCash.read('IDR'), [5000, 10000, 20000]);
    },
  );
  test(
    'M53 completed rich tender retains entered zeros and backup rejects inconsistent composition',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final intent = input(TenderDraft(idr, '093000').snapshot);
      await app.checkout.submit(cart.id, cart.revision, intent);
      final completed = (await db.read(
        (sql) => sql.query('cart_drafts'),
      )).single;
      expect(completed['tender_raw'], '093000');
      final metadata = await manifest();
      await db.read((sql) => BackupValidation.validate(sql, metadata));
      await expectLater(
        db.transaction(
          (sql) => sql.update('cart_drafts', {'tender_raw': '93000'}),
        ),
        throwsA(isA<DatabaseException>()),
      );
      // An authenticated imported DB may have lost its triggers. Only this newly
      // owned fixture drops guards to exercise the defensive restore validator.
      await db.transaction((sql) async {
        await sql.execute('DROP TRIGGER completed_draft_guard');
        await sql.execute('DROP TRIGGER checkout_tenders_no_update');
      });
      await db.transaction(
        (sql) => sql.update('cart_drafts', {'tender_raw': '93000'}),
      );
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, metadata)),
        throwsFormatException,
      );
      await db.transaction((sql) async {
        await sql.update('cart_drafts', {'tender_raw': '093000'});
        await sql.update('checkout_tenders', {
          'details_json': input(
            TenderDraft(idr, '93001').snapshot,
          ).tenderDetails!.encode(),
        });
      });
      await expectLater(
        db.read((sql) => BackupValidation.validate(sql, metadata)),
        throwsFormatException,
      );
    },
  );
  test(
    'M53 decimal raw precision persists in completed tender and validates for portable backup',
    () async {
      await db.transaction(
        (sql) => sql.update('store_settings', {
          'currency_code': 'USD',
          'currency_scale': 2,
        }),
      );
      final id = await app.inventory.create(
        ProductInput(name: 'PUBLIC USD', sellingPrice: Money(9350, 'USD', 2)),
        initialQuantity: 2,
        unitCost: CostAmount.fromMoney(Money(5000, 'USD', 2)),
      );
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final snapshot = TenderDraft(
        CurrencyPolicy.forCode('USD'),
        '93.5',
      ).snapshot;
      final intent = input(snapshot);
      await app.checkout.submit(cart.id, cart.revision, intent);
      expect(
        (await db.read((sql) => sql.query('cart_drafts'))).single['tender_raw'],
        '93.5',
      );
      final metadata = await manifest();
      await db.read((sql) => BackupValidation.validate(sql, metadata));
    },
  );
  test(
    'M53 rich tender rolls back alongside sale stock and draft when checkout fails after tender insertion',
    () async {
      final id = await product();
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, id);
      final draft = TenderDraft(idr)..receive(m(100000));
      final intent = input(draft.snapshot);
      await app.cart.saveInput(cart.id, cart.revision, intent);
      final failing = CheckoutService(
        db,
        app.checkout.store,
        testStage: (stage) async {
          if (stage == 'draft') throw StateError('PUBLIC FAULT');
        },
      );
      await expectLater(
        failing.submit(cart.id, cart.revision, intent),
        throwsStateError,
      );
      expect(await db.read((sql) => sql.query('checkout_tenders')), isEmpty);
      expect(await db.read((sql) => sql.query('sale_transactions')), isEmpty);
      expect(
        (await app.cart.read(cart.id)).input.tenderDetails!.counts[100000],
        1,
      );
      expect(
        (await db.read(
          (sql) => sql.query('products'),
        )).single['stock_quantity'],
        3,
      );
      await app.checkout.submit(cart.id, cart.revision, intent);
      expect((await db.read((sql) => sql.query('checkout_tenders'))).length, 1);
    },
  );
}
