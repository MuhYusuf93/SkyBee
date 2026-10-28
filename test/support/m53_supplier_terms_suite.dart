import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_input.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/suppliers/application/supplier_terms_validation.dart';

void m53SupplierTermsSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late Map<String, Object?> credential;
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  StoreClock clock() => StoreClock(
    now: () => DateTime.utc(2026, 10, 29),
    elapsedMilliseconds: () => 0,
  );
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_supplier_terms_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
      clock: clock(),
    ).management.configure('PUBLIC SUPPLIER TERMS', '0001', '0001');
    credential = Map.of(
      (await seed.read((sql) => sql.query('management_credentials'))).single,
    );
    await seed.close();
    await factory.deleteDatabase(seed.databasePath);
  });
  setUp(() async {
    db = DatabaseCoordinator(factory: factory, databasePath: path());
    app = AppServices(db, clock: clock());
    await db.transaction(
      (sql) => sql.insert('management_credentials', credential),
    );
    await app.management.unlock('0001');
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => root.delete());
  test(
    'M53 supplier terms default off, owner CAS preserves receipts and toggling off retains immutable agreement history',
    () async {
      final id = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC TERMS A',
      );
      var terms = await app.suppliers.terms(id);
      expect(terms.allowsCredit, isFalse);
      expect(terms.revision, 0);
      expect(await db.read((sql) => sql.query('supplier_terms')), isEmpty);
      terms = await app.suppliers.saveTerms(id, 0, allowsCredit: false);
      expect(terms.revision, 0);
      terms = await app.suppliers.saveTerms(id, 0, allowsCredit: true);
      expect(terms.revision, 1);
      await expectLater(
        app.suppliers.saveTerms(id, 0, allowsCredit: false),
        throwsA(isA<AppError>()),
      );
      terms = await app.suppliers.saveTerms(id, 1, allowsCredit: false);
      expect(terms.revision, 2);
      expect(terms.allowsCredit, isFalse);
      final events = await db.read(
        (sql) => sql.query('supplier_terms_events', orderBy: 'revision'),
      );
      expect(events.map((e) => e['after_allowed']), [1, 0]);
      expect(events.every((e) => e['actor_role'] == 'owner'), isTrue);
      await expectLater(
        db.transaction(
          (sql) => sql.update('supplier_terms_events', {'after_allowed': 1}),
        ),
        throwsA(anything),
      );
      expect(await db.read((sql) => sql.query('stock_receipts')), isEmpty);
      expect(await db.read((sql) => sql.query('stock_history')), isEmpty);
      await db.read(SupplierTermsValidation.validate);
      await app.inventory.archiveMaster(MasterKind.supplier, id);
      terms = await app.suppliers.terms(id);
      expect(terms.archived, isTrue);
      expect(terms.revision, 2);
    },
  );
  test(
    'M53 supplier terms warehouse reads operational agreement but cannot edit; locked reads and stale caller writes are denied',
    () async {
      final id = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC TERMS B',
      );
      await app.suppliers.saveTerms(id, 0, allowsCredit: true);
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      expect((await app.suppliers.terms(id)).allowsCredit, isTrue);
      await expectLater(
        app.suppliers.saveTerms(id, 1, allowsCredit: false),
        throwsA(isA<AppError>()),
      );
      app.management.lock();
      expect(() => app.suppliers.terms(id), throwsA(isA<AppError>()));
      await expectLater(
        app.suppliers.saveTerms(id, 1, allowsCredit: false),
        throwsA(isA<AppError>()),
      );
      expect(
        (await db.read((sql) => sql.query('supplier_terms_events'))).length,
        1,
      );
    },
  );
  test(
    'M53 supplier terms event failure rolls back setting; backup rejects a forged materialized agreement',
    () async {
      final id = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC TERMS C',
      );
      await db.transaction(
        (sql) => sql.execute(
          "CREATE TRIGGER public_terms_failure BEFORE INSERT ON supplier_terms_events BEGIN SELECT RAISE(ABORT,'PUBLIC FAILURE'); END",
        ),
      );
      await expectLater(
        app.suppliers.saveTerms(id, 0, allowsCredit: true),
        throwsA(anything),
      );
      expect((await app.suppliers.terms(id)).revision, 0);
      await db.transaction(
        (sql) => sql.execute('DROP TRIGGER public_terms_failure'),
      );
      await app.suppliers.saveTerms(id, 0, allowsCredit: true);
      await db.read(SupplierTermsValidation.validate);
      await db.transaction(
        (sql) => sql.update(
          'supplier_terms',
          {'allows_credit': 0},
          where: 'supplier_id=?',
          whereArgs: [id.value],
        ),
      );
      await expectLater(
        db.read(SupplierTermsValidation.validate),
        throwsFormatException,
      );
    },
  );
  test(
    'M53 supplier terms migration29 preserves every existing column and leaves historical purchases unreconciled',
    () async {
      final oldPath = path();
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: oldPath,
        schemaVersion: 29,
      );
      final oldApp = AppServices(old, clock: clock());
      await old.transaction(
        (sql) => sql.insert('management_credentials', credential),
      );
      await oldApp.management.unlock('0001');
      final supplier = await oldApp.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC LEGACY SUPPLIER',
      );
      final goods = await oldApp.inventory.create(
        ProductInput(
          name: 'PUBLIC LEGACY GOODS',
          sellingPrice: Money(20000, 'IDR', 0),
        ),
        initialQuantity: 0,
      );
      await oldApp.inventory.receive(
        goods,
        100,
        CostAmount.fromMoney(Money(10000, 'IDR', 0)),
        operationKey: 'PUBLIC LEGACY RECEIPT',
        supplierId: supplier,
      );
      var count = await oldApp.inventory.createStocktake();
      count = await oldApp.inventory.includeStocktakeProduct(
        count.id,
        count.revision,
        goods,
      );
      final batch = (await oldApp.inventory.stocktakeObservations(
        count.lines.single.id,
      )).items.single;
      count = await oldApp.inventory.setStocktakeCount(
        count.id,
        count.revision,
        batch.id,
        StockInput(90),
      );
      await oldApp.inventory.confirmStocktake(
        count.id,
        count.revision,
        reason: 'PUBLIC LEGACY COUNT',
      );
      final before = <String, List<Map<String, Object?>>>{};
      await old.read((sql) async {
        final tables = await sql.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        );
        for (final table in tables) {
          final name = table['name'] as String;
          before[name] = await sql.query(name, orderBy: 'rowid');
        }
      });
      await old.close();
      old = DatabaseCoordinator(factory: factory, databasePath: oldPath);
      try {
        await old.read((sql) async {
          for (final name in before.keys) {
            expect(
              await sql.query(name, orderBy: 'rowid'),
              before[name],
              reason: name,
            );
          }
          expect(await sql.query('supplier_terms'), isEmpty);
          expect(await sql.query('supplier_terms_events'), isEmpty);
          await SupplierTermsValidation.validate(sql);
        });
      } finally {
        await old.close();
        await factory.deleteDatabase(oldPath);
      }
    },
  );
}
