import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/app/app_version.dart';
import 'package:kasir_app/data/database/schema.dart';
import 'package:kasir_app/features/backup/application/backup_validation.dart';
import 'package:kasir_app/features/backup/domain/backup_manifest.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/application/warehouse_query.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/inventory/domain/warehouse_filter.dart';
import 'database_contract_suite.dart' show fixtureId, productRow;

void m53WarehouseSuite(DatabaseFactory factory) {
  late Directory root;
  var serial = 0;
  late Map<String, Object?> credential;
  late DatabaseCoordinator db;
  late AppServices app;
  late DateTime now;
  String nextPath() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_warehouse_');
    final seed = DatabaseCoordinator(
      factory: factory,
      databasePath: nextPath(),
    );
    try {
      await AppServices(
        seed,
      ).management.configure('PUBLIC WAREHOUSE', '0001', '0001');
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
    db = DatabaseCoordinator(factory: factory, databasePath: nextPath());
    app = AppServices(db, clock: StoreClock(now: () => now));
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
    'M53 warehouse staged backup preserves archived master links and rejects forged dangling/oversized relations',
    () async {
      final supplier = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC BACKUP MASTER',
      );
      await app.inventory.create(
        ProductInput(
          name: 'PUBLIC BACKUP LINK',
          sellingPrice: Money(12000, 'IDR', 0),
          masterSupplierId: supplier,
        ),
      );
      await app.inventory.archiveMaster(MasterKind.supplier, supplier);
      final manifest = BackupManifest({
        'format': 1,
        'cipher': 'SQLCipher',
        'archiveCipher': 'Tink-AES256-GCM-HKDF-64KiB',
        'id': 'public-fixture',
        'storeId': 'public-store',
        'originId': 'public-origin',
        'schema': Schema.version,
        'createdAt': 1,
        'currency': 'IDR',
        'currencyScale': 0,
        'timeZone': 'Asia/Jakarta',
        'appVersion': appVersion,
        'files': {
          'database.db': {'bytes': 1, 'sha256': '0' * 64},
        },
      });
      await db.read((sql) async {
        await BackupValidation.validate(sql, manifest);
        // Disposable forged archive only: imported files cannot be trusted to
        // retain FK enforcement. No active application database uses this path.
        await sql.execute('PRAGMA foreign_keys=OFF');
        try {
          for (final forged in [fixtureId(999999), 'x' * 20000, 17]) {
            await sql.update('products', {'master_supplier_id': forged});
            await expectLater(
              BackupValidation.validate(sql, manifest),
              throwsA(isA<FormatException>()),
            );
          }
        } finally {
          await sql.update('products', {'master_supplier_id': supplier.value});
          await sql.execute('PRAGMA foreign_keys=ON');
        }
        await BackupValidation.validate(sql, manifest);
        expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      });
    },
  );
  Future<void> seedCatalogue() => db.transaction((sql) async {
    for (final id in [101, 102]) {
      await sql.insert('categories', {
        'id': fixtureId(id),
        'name': 'PUBLIC CAT $id',
        'created_at': 1,
        'normalized_name': 'public cat $id',
      });
      await sql.insert('suppliers', {
        'id': fixtureId(id + 100),
        'name': 'PUBLIC SUP $id',
        'created_at': 1,
        'normalized_name': 'public sup $id',
      });
      await sql.insert('shelves', {
        'id': fixtureId(id + 200),
        'name': 'PUBLIC SHELF $id',
        'created_at': 1,
        'normalized_name': 'public shelf $id',
      });
    }
    for (var id = 1; id <= 9; id++) {
      final untracked = id == 4 || id == 5;
      await sql.insert('products', {
        ...productRow(id, 'PUBLIC WARE $id'),
        'created_at': id == 1 ? 1 : 100,
        'stock_quantity': untracked || id == 8
            ? 999
            : id == 2
            ? 0
            : 10,
        'stock_tracking_enabled': untracked ? 0 : 1,
        'reference_cost_micros': untracked ? 1000000 : null,
        'expiry_enabled': 1,
        'category_id': fixtureId(id == 9 ? 102 : 101),
        'master_supplier_id': fixtureId(id == 9 ? 202 : 201),
        'shelf_id': fixtureId(id == 9 ? 302 : 301),
        'reference_expiry_date': id == 4 ? '2026-10-28' : null,
        'is_deleted': id == 7 ? 1 : 0,
      });
      if (untracked || id == 2 || id == 6) continue;
      await sql.insert('stock_batches', {
        'id': fixtureId(1000 + id),
        'product_id': fixtureId(id),
        'received_quantity': id == 8 ? 999 : 10,
        'remaining_quantity': id == 3
            ? 0
            : id == 1
            ? 4
            : id == 8
            ? 999
            : 10,
        'expiry_date': id == 1 || id == 3 ? '2026-10-28' : '2026-11-30',
        'received_at': 1,
      });
      if (id == 1) {
        await sql.insert('stock_batches', {
          'id': fixtureId(1100),
          'product_id': fixtureId(id),
          'received_quantity': 5,
          'remaining_quantity': 5,
          'expiry_date': '2026-11-30',
          'received_at': 1,
        });
      }
    }
  });
  test(
    'M53 warehouse ranks and filters before keyset limit, excludes sentinel stockout and keeps mixed stock saleable',
    () async {
      await seedCatalogue();
      final filter = WarehouseFilter();
      var page = await app.inventory.warehousePage(filter, null, pageSize: 2);
      final ids = <int>[];
      while (true) {
        ids.addAll(page.items.map((p) => int.parse(p.name.split(' ').last)));
        if (!page.hasMore) break;
        page = await app.inventory.warehousePage(
          filter,
          page.nextCursor,
          pageSize: 2,
        );
      }
      expect(ids, [4, 1, 2, 9, 8, 6, 5, 3]);
      final expired = (await app.inventory.warehousePage(
        WarehouseFilter(stock: WarehouseStockFilter.expired),
        null,
      )).items;
      expect(expired.map((p) => p.id.value), [fixtureId(4), fixtureId(1)]);
      expect(expired.first.expired, 0);
      expect(expired.first.referenceExpired, isTrue);
      expect(expired.first.saleable, 0);
      expect(expired.last.expired, 4);
      expect(
        expired.last.saleable,
        5,
      ); // Not physical10 minus expired4: one is unallocated.
      expect((await app.inventory.detail(EntityId(fixtureId(1)))).saleable, 5);
      expect((await app.inventory.detail(EntityId(fixtureId(6)))).saleable, 0);
      final empty = (await app.inventory.warehousePage(
        WarehouseFilter(stock: WarehouseStockFilter.empty),
        null,
      )).items;
      expect(empty.map((p) => p.id.value), [fixtureId(2)]);
      final combined = WarehouseFilter(
        namePrefix: 'PUBLIC WARE',
        categoryId: EntityId(fixtureId(102)),
        shelfId: EntityId(fixtureId(302)),
        supplierId: EntityId(fixtureId(202)),
      );
      expect(
        (await app.inventory.warehousePage(
          combined,
          null,
          pageSize: 1,
        )).items.single.id.value,
        fixtureId(9),
      );
      expect(
        (await app.inventory.warehousePage(
          combined.copyWith(stock: WarehouseStockFilter.expired),
          null,
        )).items,
        isEmpty,
      );
      expect(
        (await app.inventory.warehousePage(
          WarehouseFilter(isDeleted: true),
          null,
        )).items.single.id.value,
        fixtureId(7),
      );
      final query = warehouseQuery(filter, null, '2026-10-28', 2);
      expect(query.sql.toUpperCase(), isNot(contains('OFFSET')));
      final plans = await db.read(
        (sql) =>
            sql.rawQuery('EXPLAIN QUERY PLAN ${query.sql}', query.arguments),
      );
      expect(
        plans.map((r) => r['detail']).join(' '),
        contains('stock_batches_fefo'),
      );
    },
  );
  test(
    'M53 warehouse cursors bind filter/day/timezone/catalogue epoch and deny locked access',
    () async {
      await seedCatalogue();
      final filter = WarehouseFilter();
      final cursor = (await app.inventory.warehousePage(
        filter,
        null,
        pageSize: 1,
      )).nextCursor!;
      Future<void> changed(WarehouseFilter next, WarehouseCursor after) async {
        await expectLater(
          app.inventory.warehousePage(next, after, pageSize: 1),
          throwsA(isA<AppError>()),
        );
      }

      await changed(WarehouseFilter(namePrefix: 'OTHER'), cursor);
      now = now.add(const Duration(days: 1));
      await changed(filter, cursor);
      now = now.subtract(const Duration(days: 1));
      await db.transaction(
        (sql) => sql.update('store_settings', {'time_zone': 'Asia/Makassar'}),
      );
      await changed(filter, cursor);
      await db.transaction(
        (sql) => sql.update('store_settings', {'time_zone': 'Asia/Jakarta'}),
      );
      final fresh = (await app.inventory.warehousePage(
        filter,
        null,
        pageSize: 1,
      )).nextCursor!;
      await db.transaction(
        (sql) => sql.update(
          'products',
          {'created_at': 200},
          where: 'id=?',
          whereArgs: [fixtureId(9)],
        ),
      );
      await changed(filter, fresh);
      app.management.lock();
      expect(
        () => app.inventory.warehousePage(filter, null),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 warehouse master supplier differs from receipt supplier and archived lookup never offers duplicate creation',
    () async {
      final master = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC MASTER',
      );
      final receiptSupplier = await app.inventory.saveMaster(
        MasterKind.supplier,
        'PUBLIC RECEIPT',
      );
      ProductInput input() => ProductInput(
        name: 'PUBLIC LINK',
        barcode: '000001',
        sellingPrice: Money(12000, 'IDR', 0),
        masterSupplierId: master,
      );
      final id = await app.inventory.create(
        input(),
        initialQuantity: 1,
        unitCost: CostAmount.fromMoney(Money(1000, 'IDR', 0)),
      );
      await app.inventory.receive(
        id,
        1,
        CostAmount.fromMoney(Money(1000, 'IDR', 0)),
        operationKey: 'public-receipt-supplier',
        supplierId: receiptSupplier,
      );
      expect(
        (await app.inventory.detail(id)).row['master_supplier_id'],
        master.value,
      );
      expect(
        (await app.inventory.warehousePage(
          WarehouseFilter(supplierId: master),
          null,
        )).items.single.id,
        id,
      );
      expect(
        (await app.inventory.warehousePage(
          WarehouseFilter(supplierId: receiptSupplier),
          null,
        )).items,
        isEmpty,
      );
      await app.inventory.archiveMaster(MasterKind.supplier, master);
      final old = await app.inventory.detail(id);
      await app.inventory.edit(id, input(), old.revision);
      await app.inventory.adjust(
        id,
        0,
        operationKey: 'public-clear-before-archive',
        reason: 'PUBLIC COUNT',
      );
      await app.inventory.archive(
        id,
        (await app.inventory.detail(id)).revision,
      );
      expect((await app.inventory.lookupCode('000001'))!.isDeleted, isTrue);
      await expectLater(
        app.inventory.create(
          ProductInput(
            name: 'PUBLIC NEW',
            sellingPrice: Money(12000, 'IDR', 0),
            masterSupplierId: master,
          ),
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 warehouse populated25 migration never infers master supplier from old receipts and preserves ons',
    () async {
      final path = nextPath();
      var old = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 25,
      );
      try {
        await old.transaction((sql) async {
          await sql.insert('products', {
            ...productRow(1, 'PUBLIC OLD ONS'),
            'size_ons_milli': 1250,
          });
          await sql.insert('suppliers', {
            'id': fixtureId(101),
            'name': 'PUBLIC OLD',
            'created_at': 1,
            'normalized_name': 'public old',
          });
          await sql.insert('stock_receipts', {
            'id': fixtureId(102),
            'operation_key': 'public-old-receipt',
            'supplier_id': fixtureId(101),
            'created_at': 1,
          });
        });
        final before = await old.read(
          (sql) async => {
            for (final t in [
              'products',
              'suppliers',
              'stock_receipts',
              'management_credentials',
              'store_settings',
            ])
              t: await sql.query(t, orderBy: 'id COLLATE BINARY'),
          },
        );
        await old.close();
        old = DatabaseCoordinator(factory: factory, databasePath: path);
        await old.read((sql) async {
          for (final entry in before.entries) {
            final rows = await sql.query(
              entry.key,
              orderBy: 'id COLLATE BINARY',
            );
            expect(rows.length, entry.value.length);
            for (var i = 0; i < rows.length; i++) {
              expect({
                for (final key in entry.value[i].keys) key: rows[i][key],
              }, entry.value[i]);
            }
          }
          expect(
            (await sql.query('products')).single['master_supplier_id'],
            isNull,
          );
          expect((await sql.query('products')).single['size_ons_milli'], 1250);
          expect(await sql.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        });
      } finally {
        await old.close();
        await factory.deleteDatabase(path);
      }
    },
  );
}
