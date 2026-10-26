import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/management/application/management_service.dart';
import 'package:kasir_app/features/management/application/pin_hasher.dart';
import 'package:kasir_app/features/inventory/application/inventory_service.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/stock_rules.dart';
import 'package:kasir_app/features/inventory/domain/change_record.dart';
import 'package:kasir_app/features/settings/application/settings_service.dart';
import 'database_contract_suite.dart';

/// Native SQLite and real 600k-round crypto. Shared synthetic verifier fixture
/// saves setup hashing, but every unlock still verifies the production KDF.
void managementInventorySuite(
  DatabaseFactory factory,
  Future<String> Function() newPath,
) {
  late DatabaseCoordinator db;
  late String databasePath;
  late ManagementService access;
  late InventoryService inventory;
  late DateTime now;
  late StoreClock clock;
  late Map<String, Object?> verifier;
  const recovery = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  setUpAll(() async {
    const hasher = PinHasher();
    final salt = hasher.randomBytes(32);
    final timer = Stopwatch()..start();
    final hash = await hasher.derive('pin:0001', salt);
    // ignore: avoid_print
    print(
      'KDF 600000 rounds / 256 bits: ${timer.elapsedMilliseconds} ms (test target, non-release)',
    );
    verifier = {
      'id': 1,
      'pin_verifier': hash,
      'salt': salt,
      'recovery_verifier': await hasher.derive('recovery:$recovery', salt),
      'kdf_name': 'PBKDF2-HMAC-SHA256',
      'kdf_parameters': jsonEncode({
        'iterations': PinHasher.iterations,
        'bits': 256,
      }),
      'last_attempt_at': 0,
    };
  });
  setUp(() async {
    now = DateTime.utc(2026, 10, 12, 17, 0);
    clock = StoreClock(
      now: () => now,
      elapsedMilliseconds: () => now.millisecondsSinceEpoch,
    );
    databasePath = await newPath();
    db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
    access = ManagementService(db, clock);
    inventory = InventoryService(db, access);
    await db.transaction(
      (dbTxn) => dbTxn.insert('management_credentials', verifier),
    );
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(databasePath);
  });
  Future<void> unlock() => access.unlock('0001');
  ProductInput input({
    String name = 'Test barang',
    String? sku,
    String? barcode,
    bool expiry = false,
    EntityId? category,
  }) => ProductInput(
    name: name,
    sellingPrice: Rupiah(12000),
    sku: sku,
    barcode: barcode,
    expiryEnabled: expiry,
    categoryId: category,
    aliases: ['air', 'minum'],
  );
  Future<void> reconcile(EntityId id) async {
    await db.read((sql) async {
      final row = (await sql.query(
        'products',
        where: 'id=?',
        whereArgs: [id.value],
      )).single;
      final ledger = (await sql.rawQuery(
        'SELECT COALESCE(SUM(quantity_delta),0) qty,COALESCE(SUM(value_delta_micros),0) value FROM stock_history WHERE product_id=?',
        [id.value],
      )).single;
      final batches = (await sql.rawQuery(
        'SELECT COALESCE(SUM(remaining_quantity),0) qty FROM stock_batches WHERE product_id=?',
        [id.value],
      )).single;
      expect(ledger['qty'], row['stock_quantity']);
      expect(ledger['value'], row['inventory_value_micros']);
      expect(batches['qty'], row['stock_quantity']);
      expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });
  }

  test(
    'authorization is service-enforced, idle expiry and lock revoke queued writes',
    () async {
      await expectLater(inventory.create(input()), throwsA(isA<AppError>()));
      await unlock();
      await inventory.create(input());
      now = now.add(const Duration(minutes: 5));
      await expectLater(inventory.create(input()), throwsA(isA<AppError>()));
      await unlock();
      final blocked = db.exclusive((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      final pending = inventory.create(input());
      access.lock();
      await blocked;
      await expectLater(pending, throwsA(isA<AppError>()));
      expect(await db.read((sql) => sql.query('products')), hasLength(1));
    },
  );
  test(
    'session idle deadline uses monotonic time despite wall-clock changes',
    () async {
      var elapsed = 0;
      final monotonicClock = StoreClock(
        now: () => now,
        elapsedMilliseconds: () => elapsed,
      );
      final manager = ManagementService(db, monotonicClock);
      await manager.unlock('0001');
      now = now.add(const Duration(days: 400));
      expect(manager.isUnlocked, true);
      elapsed = 299999;
      expect(manager.isUnlocked, true);
      elapsed = 300000;
      expect(manager.isUnlocked, false);
    },
  );
  test(
    'leading-zero PIN and persisted progressive lockout survive reopen/clock rollback',
    () async {
      for (var i = 0; i < 3; i++) {
        await expectLater(access.unlock('9999'), throwsA(isA<AppError>()));
      }
      await expectLater(unlock(), throwsA(isA<AppError>()));
      await db.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      access = ManagementService(db, clock);
      now = now.subtract(const Duration(days: 1));
      await expectLater(access.unlock('0001'), throwsA(isA<AppError>()));
      now = DateTime.utc(2026, 10, 12, 17, 0, 6);
      await access.unlock('0001');
      expect(access.isUnlocked, true);
      await db.read((sql) async {
        final row = (await sql.query('management_credentials')).single;
        expect(row['failed_attempts'], 0);
        expect(row.values, isNot(contains('0001')));
      });
    },
  );
  test(
    'credential creation has no default PIN, salt random, confirmation and rotation/recovery',
    () async {
      await db.transaction((dbTxn) => dbTxn.delete('management_credentials'));
      await expectLater(
        access.configure('Toko', '0001', '0002'),
        throwsA(isA<AppError>()),
      );
      expect(await access.isConfigured, false);
      final code = await access.configure('Toko', '0001', '0001');
      expect(code.length, 32);
      expect(await access.isConfigured, true);
      await expectLater(
        access.configure('Toko', '0001', '0001'),
        throwsA(isA<AppError>()),
      );
      final row = await db.read(
        (sql) async => (await sql.query('management_credentials')).single,
      );
      expect(row['salt'], isNot(verifier['salt']));
      expect(row.values, isNot(contains(code)));
      final next = await access.changePin(
        code,
        '0002',
        '0002',
        useRecovery: true,
      );
      expect(next, isNot(code));
      await expectLater(access.unlock('0001'), throwsA(isA<AppError>()));
      await access.unlock('0002');
      await expectLater(
        access.changePin(code, '0003', '0003', useRecovery: true),
        throwsA(isA<AppError>()),
      );
      final rotated = await access.changePin('0002', '0003', '0003');
      expect(rotated, isNot(next));
      await access.unlock('0003');
    },
  );
  test(
    'master CRUD, nullable relations, generated unique SKU and archived barcode collision',
    () async {
      await unlock();
      final category = await inventory.saveMaster(
        MasterKind.category,
        'Minuman',
      );
      final supplier = await inventory.saveMaster(
        MasterKind.supplier,
        'Pemasok',
        contact: '081234567890',
      );
      final first = await inventory.create(
        input(barcode: '000009', category: category),
      );
      final second = await inventory.create(input());
      expect(
        (await inventory.detail(first)).sku,
        isNot((await inventory.detail(second)).sku),
      );
      await expectLater(
        inventory.archiveMaster(MasterKind.category, category),
        throwsA(isA<AppError>()),
      );
      final supplier2 = await inventory.saveMaster(
        MasterKind.supplier,
        'Pemasok kedua',
      );
      final supplied = await inventory.create(
        input(name: 'Barang bersupplier'),
      );
      await inventory.receive(
        supplied,
        1,
        CostAmount(1),
        operationKey: 'supplier-first',
        supplierId: supplier,
      );
      await inventory.receive(
        supplied,
        2,
        CostAmount(2),
        operationKey: 'supplier-second',
        supplierId: supplier2,
      );
      await inventory.archiveMaster(MasterKind.supplier, supplier);
      await expectLater(
        inventory.receive(
          supplied,
          1,
          CostAmount(1),
          operationKey: 'supplier-archived',
          supplierId: supplier,
        ),
        throwsA(isA<AppError>()),
      );
      await db.read((sql) async {
        final receipts = await sql.query(
          'stock_receipts',
          columns: ['supplier_id'],
        );
        expect(receipts.map((row) => row['supplier_id']).toSet(), {
          supplier.value,
          supplier2.value,
        });
      });
      await inventory.archive(first, (await inventory.detail(first)).revision);
      await expectLater(
        inventory.create(input(barcode: '000009')),
        throwsA(isA<AppError>()),
      );
      await inventory.archive(
        first,
        (await inventory.detail(first)).revision,
        restore: true,
      );
      expect((await inventory.detail(first)).barcode, '000009');
      final records = await inventory.masterPage(
        MasterKind.supplier,
        '',
        null,
        isDeleted: true,
      );
      expect(records.items.single.contact, '+6281234567890');
      await expectLater(
        inventory.create(input(), initialQuantity: 1),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'receipts are atomic/idempotent, supplier optional; weighted value/HPP example and no repricing cost',
    () async {
      await unlock();
      final id = await inventory.create(
        input(),
        initialQuantity: 10,
        unitCost: CostAmount.fromRupiah(Rupiah(8000)),
      );
      final cost = CostAmount.fromRupiah(Rupiah(10000));
      final receipt = await inventory.receive(
        id,
        10,
        cost,
        operationKey: 'receipt',
      );
      expect(
        await inventory.receive(id, 10, cost, operationKey: 'receipt'),
        receipt,
      );
      await expectLater(
        inventory.receive(id, 11, cost, operationKey: 'receipt'),
        throwsA(isA<AppError>()),
      );
      final product = await inventory.detail(id);
      expect(product.quantity, 20);
      expect(averageCost(product.quantity, product.valueMicros!), 9000000000);
      expect(
        removalCost(quantity: 20, valueMicros: product.valueMicros!, remove: 3),
        27000000000,
      );
      await inventory.edit(
        id,
        ProductInput(
          name: 'Nieuw',
          sellingPrice: Rupiah(15000),
          sku: product.sku,
        ),
        product.revision,
      );
      expect((await inventory.detail(id)).valueMicros, 180000000000);
      await reconcile(id);
      final old = await db.read((sql) => sql.query('stock_receipts'));
      expect(old.every((row) => row['supplier_id'] == null), true);
    },
  );
  test(
    'SQL failure rolls back receipt/item/batch/value/history/audit together',
    () async {
      await unlock();
      final id = await inventory.create(input());
      await db.read(
        (sql) => sql.execute(
          "CREATE TRIGGER fail_stock_history BEFORE INSERT ON stock_history BEGIN SELECT RAISE(ABORT,'test injected failure'); END",
        ),
      );
      await expectLater(
        inventory.receive(id, 2, CostAmount(100), operationKey: 'fault'),
        throwsA(isA<DatabaseException>()),
      );
      await db.read((sql) async {
        for (final table in [
          'stock_receipts',
          'stock_receipt_items',
          'stock_batches',
          'inventory_operations',
          'stock_history',
        ]) {
          expect(await sql.query(table), isEmpty);
        }
        expect((await sql.query('products')).single['stock_quantity'], 0);
        expect(
          await sql.query('audit_log', where: "action='stock_received'"),
          isEmpty,
        );
        await sql.execute('DROP TRIGGER fail_stock_history');
      });
      await inventory.receive(id, 2, CostAmount(100), operationKey: 'fault');
      await reconcile(id);
    },
  );
  test(
    'receipt reversal exact valuation, idempotent and rejects intervening stock dependencies',
    () async {
      await unlock();
      final id = await inventory.create(
        input(),
        initialQuantity: 3,
        unitCost: CostAmount(1),
      );
      final receipt = await inventory.receive(
        id,
        4,
        CostAmount(3),
        operationKey: 'r1',
      );
      var product = await inventory.detail(id);
      await inventory.edit(
        id,
        ProductInput(
          name: 'Updated',
          sellingPrice: Rupiah(13000),
          sku: product.sku,
        ),
        product.revision,
      );
      await inventory.reverseReceipt(
        receipt,
        operationKey: 'reverse',
        reason: 'Input salah',
      );
      await inventory.reverseReceipt(
        receipt,
        operationKey: 'reverse',
        reason: 'Input salah',
      );
      product = await inventory.detail(id);
      expect(product.quantity, 3);
      expect(product.valueMicros, 3);
      await reconcile(id);
      final receipt2 = await inventory.receive(
        id,
        2,
        CostAmount(7),
        operationKey: 'r2',
      );
      await inventory.receive(id, 1, CostAmount(8), operationKey: 'r3');
      await expectLater(
        inventory.reverseReceipt(
          receipt2,
          operationKey: 'wrong',
          reason: 'Salah',
        ),
        throwsA(isA<AppError>()),
      );
      await reconcile(id);
    },
  );
  test(
    'expiry calendar, undated, FEFO and expired stock remains physical until disposal',
    () async {
      // Enter the dated batches before they expire, then advance the clock.
      // M5.2 forbids entering an already expired new batch through the service.
      now = DateTime.utc(2026, 10, 10, 17);
      await unlock();
      final id = await inventory.create(input(expiry: true));
      await inventory.receive(
        id,
        2,
        CostAmount(100),
        operationKey: 'expired',
        expiry: CalendarDate('2026-10-13'),
      );
      await inventory.receive(
        id,
        3,
        CostAmount(100),
        operationKey: 'later',
        expiry: CalendarDate('2026-10-15'),
      );
      await inventory.receive(id, 4, CostAmount(100), operationKey: 'undated');
      now = DateTime.utc(2026, 10, 12, 17);
      await unlock();
      // UTC 17:00 Oct 12 is midnight Oct 13 in Jakarta.
      var product = await inventory.detail(id);
      expect(product.expired, 2);
      expect(product.saleable, 7);
      expect(product.quantity, 9);
      expect(product.undated, 4);
      expect(product.nearExpiry, 3);
      final batches = (await inventory.batches(id)).items;
      final allocations = allocateFefo(
        batches,
        4,
        clock.today('Asia/Jakarta'),
        expiryEnabled: true,
      );
      expect(
        batches
            .firstWhere((batch) => batch.id == allocations.first.batchId)
            .expiry
            ?.iso,
        '2026-10-15',
      );
      expect(allocations.first.quantity, 3);
      await expectLater(
        Future.sync(
          () => allocateFefo(
            batches,
            8,
            clock.today('Asia/Jakarta'),
            expiryEnabled: true,
          ),
        ),
        throwsA(isA<AppError>()),
      );
      final expired = batches.firstWhere(
        (batch) => batch.expiry?.iso == '2026-10-13',
      );
      await inventory.waste(
        expired.id,
        2,
        operationKey: 'waste',
        reason: 'Kedaluwarsa',
      );
      product = await inventory.detail(id);
      expect(product.expired, 0);
      expect(product.quantity, 7);
      await reconcile(id);
    },
  );
  test(
    'physical count and waste allocate rounding residue; zero quantity has zero value',
    () async {
      await unlock();
      final id = await inventory.create(
        input(),
        initialQuantity: 3,
        unitCost: CostAmount(1),
      );
      await inventory.receive(id, 1, CostAmount(2), operationKey: 'more');
      await inventory.adjust(
        id,
        2,
        operationKey: 'count1',
        reason: 'Hitung fisik',
      );
      expect((await inventory.detail(id)).valueMicros, 2);
      await reconcile(id);
      await inventory.adjust(
        id,
        0,
        operationKey: 'count0',
        reason: 'Semua keluar',
      );
      expect((await inventory.detail(id)).valueMicros, 0);
      await reconcile(id);
      await expectLater(
        inventory.adjust(id, 2, operationKey: 'gain', reason: 'Ditemukan'),
        throwsA(isA<AppError>()),
      );
      await inventory.adjust(
        id,
        2,
        operationKey: 'gain',
        reason: 'Ditemukan',
        unitCost: CostAmount(3),
      );
      final batch = (await inventory.batches(id)).items.single;
      await inventory.waste(
        batch.id,
        2,
        operationKey: 'clear',
        reason: 'Rusak',
      );
      await reconcile(id);
      expect((await inventory.detail(id)).valueMicros, 0);
    },
  );
  test(
    'price/archive undo does not overwrite later changes and logs reversal price',
    () async {
      await unlock();
      final id = await inventory.create(input());
      var product = await inventory.detail(id);
      final undo = await inventory.edit(
        id,
        ProductInput(
          name: product.name,
          sku: product.sku,
          sellingPrice: Rupiah(15000),
        ),
        product.revision,
      );
      await inventory.undo(undo!);
      expect((await inventory.detail(id)).price, 12000);
      product = await inventory.detail(id);
      final blocked = await inventory.edit(
        id,
        ProductInput(
          name: product.name,
          sku: product.sku,
          sellingPrice: Rupiah(16000),
        ),
        product.revision,
      );
      product = await inventory.detail(id);
      await inventory.edit(
        id,
        ProductInput(
          name: 'Later',
          sku: product.sku,
          sellingPrice: Rupiah(17000),
        ),
        product.revision,
      );
      await expectLater(inventory.undo(blocked!), throwsA(isA<AppError>()));
      expect((await inventory.detail(id)).price, 17000);
      product = await inventory.detail(id);
      final token = await inventory.archive(id, product.revision);
      await inventory.undo(token);
      expect((await inventory.detail(id)).isDeleted, false);
      product = await inventory.detail(id);
      final late = await inventory.archive(id, product.revision);
      now = now.add(const Duration(seconds: 6));
      await expectLater(inventory.undo(late), throwsA(isA<AppError>()));
      expect(await db.read((sql) => sql.query('price_history')), hasLength(4));
    },
  );
  test(
    'settings validated store zone/text, unchanged opt-in and protected saves',
    () async {
      final settings = SettingsService(db, access);
      await expectLater(settings.load(), throwsA(isA<AppError>()));
      await unlock();
      await settings.save(
        name: 'Toko',
        zone: 'Asia/Makassar',
        contact: '001234',
      );
      final values = await settings.load();
      expect(values['time_zone'], 'Asia/Makassar');
      expect(values['contact_number'], '001234');
      expect(values['backup_enabled'], 0);
      await expectLater(
        settings.save(name: 'Toko', zone: 'Fake/Zone'),
        throwsA(isA<AppError>()),
      );
      access.lock();
      await expectLater(
        settings.save(name: 'X', zone: 'Asia/Jakarta'),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'master, batch and ledger pagination handles same sort keys and literal prefixes',
    () async {
      await unlock();
      for (var i = 0; i < 5; i++) {
        await inventory.saveMaster(MasterKind.category, 'Air');
      }
      await inventory.saveMaster(MasterKind.category, 'Air% literal');
      final first = await inventory.masterPage(
        MasterKind.category,
        'air',
        null,
        pageSize: 2,
      );
      var cursor = first.nextCursor;
      final ids = first.items.map((item) => item.id).toList();
      while (cursor != null) {
        final page = await inventory.masterPage(
          MasterKind.category,
          'air',
          cursor,
          pageSize: 2,
        );
        ids.addAll(page.items.map((item) => item.id));
        cursor = page.nextCursor;
      }
      expect(ids.toSet(), hasLength(6));
      expect(
        (await inventory.masterPage(MasterKind.category, 'air%', null)).items,
        hasLength(1),
      );
      await expectLater(
        inventory.masterPage(MasterKind.category, 'other', first.nextCursor),
        throwsA(isA<AppError>()),
      );
      final id = await inventory.create(input());
      for (var i = 0; i < 54; i++) {
        await inventory.receive(id, 1, CostAmount(1), operationKey: 'page-$i');
      }
      final batches = await inventory.batches(id);
      expect(batches.items, hasLength(50));
      expect(batches.hasMore, true);
      final rest = await inventory.batches(id, after: batches.nextCursor);
      expect(rest.items, hasLength(4));
      expect(rest.hasMore, false);
      expect({
        ...batches.items.map((batch) => batch.id),
        ...rest.items.map((batch) => batch.id),
      }, hasLength(54));
      final changes = await inventory.history(id, ChangeKind.stock, null);
      expect(changes.items, hasLength(50));
      expect(
        (await inventory.history(
          id,
          ChangeKind.stock,
          changes.nextCursor,
        )).items,
        hasLength(4),
      );
      await expectLater(
        inventory.history(id, ChangeKind.price, changes.nextCursor),
        throwsA(isA<AppError>()),
      );
      await reconcile(id);
    },
  );

  test(
    'v2 to v3 preserves sale snapshots/relations and adds defaults non-destructively',
    () async {
      await db.close();
      await factory.deleteDatabase(databasePath);
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: databasePath,
        schemaVersion: 2,
      );
      await old.transaction((dbTxn) async {
        await dbTxn.insert('products', productRow(1, 'Old', barcode: '00001'));
        await seedSale(dbTxn, 10, 100);
      });
      await old.close();
      db = DatabaseCoordinator(factory: factory, databasePath: databasePath);
      await db.read((sql) async {
        expect(await sql.getVersion(), Schema.version);
        expect((await sql.query('products')).single['stock_revision'], 0);
        expect((await sql.query('products')).single['barcode'], '00001');
        expect(await sql.query('sale_transactions'), hasLength(1));
        expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      });
    },
  );
}
