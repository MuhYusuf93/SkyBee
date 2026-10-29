import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/labels/domain/product_label.dart';
import 'package:kasir_app/features/labels/application/product_label_validation.dart';
import 'package:kasir_app/features/management/domain/management_role.dart';
import 'package:kasir_app/features/printer/application/print_queue_service.dart';
import 'package:kasir_app/features/printer/application/printer_transport.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

final class LabelTransport implements PrinterTransport {
  int connects = 0, writes = 0, finishes = 0;
  bool unavailable = false, partial = false;
  void Function()? afterWrite;
  @override
  Future<void> connect(String id) async {
    connects++;
    if (unavailable) throw const SocketException('synthetic unavailable');
  }

  @override
  Future<void> write(Uint8List data) async {
    writes++;
    afterWrite?.call();
    if (partial) throw const SocketException('synthetic partial');
  }

  @override
  Future<void> finish() async {
    finishes++;
  }

  @override
  Future<void> disconnect() async {}
}

/// Labels reuse the persistent post-commit queue. Transport is synthetic; these
/// assertions establish no paper delivery or physical scanner compatibility.
void m53QrLabelQueueSuite(DatabaseFactory factory) {
  late Directory root;
  late DatabaseCoordinator db;
  late AppServices app;
  late EntityId product;
  late Map<String, Object?> credential;
  late LabelTransport transport;
  late PrintQueueService queue;
  const device = '00:11:22:33:44:55';
  const media = ProductLabelProfile(protocol: PrinterProtocol.escPosRaster);
  var serial = 0;
  String path() =>
      '${root.path}/m5_regression_${DateTime.now().microsecondsSinceEpoch}_${serial++}.db';
  Money money(int n) => Money(n, 'IDR', 0);
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('kasir_m53_label_queue_');
    final seed = DatabaseCoordinator(factory: factory, databasePath: path());
    await AppServices(
      seed,
    ).management.configure('PUBLIC QR LABEL', '0001', '0001');
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
    await app.printers.save(
      device,
      'PUBLIC LABEL PRINTER',
      const PrinterProfile(),
    );
    product = await app.inventory.create(
      ProductInput(
        name: 'PUBLIC QR GOODS',
        sku: 'LABEL-SKU',
        sellingPrice: money(12000),
      ),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(money(1000)),
    );
    transport = LabelTransport();
    queue = PrintQueueService(db, app.checkout, app.management, transport);
  });
  tearDown(() async {
    await db.close();
    await factory.deleteDatabase(db.databasePath);
  });
  tearDownAll(() async => root.delete());
  test(
    'M53 long legacy master text is bounded in label output without rewriting master or QR identity',
    () async {
      final previous = await app.labels.snapshot(product);
      final name = 'PUBLIC ${List.filled(240, 'X').join()}',
          sku = '0000${List.filled(140, 'S').join()}';
      await app.inventory.edit(
        product,
        ProductInput(name: name, sku: sku, sellingPrice: money(12000)),
        previous.productRevision,
      );
      final snap = await app.labels.snapshot(product);
      expect(snap.name.length, 200);
      expect(snap.sku.length, 120);
      expect(snap.code, previous.code);
      final current = await app.inventory.detail(product);
      expect(current.name, name);
      expect(current.sku, sku);
      final id = await app.labels.prepare(
        product,
        snap.productRevision,
        device,
        media,
        1,
        operationKey: 'long-master',
      );
      expect(await queue.send(id), 'submitted');
    },
  );
  test(
    'M53 new zero-stock product revision zero is valid for labels',
    () async {
      final id = await app.inventory.create(
        ProductInput(name: 'PUBLIC ZERO STOCK', sellingPrice: money(12000)),
      );
      final snap = await app.labels.snapshot(id, language: 'en');
      expect(snap.productRevision, 0);
      final job = await app.labels.prepare(
        id,
        0,
        device,
        media,
        1,
        operationKey: 'zero-stock',
        language: 'en',
      );
      expect(await queue.send(job), 'submitted');
      expect((await app.inventory.detail(id)).quantity, 0);
    },
  );
  Future<String> prepare({
    String key = 'one',
    int copies = 1,
    int? revision,
    ProductLabelProfile profile = media,
  }) async => app.labels.prepare(
    product,
    revision ?? (await app.labels.snapshot(product)).productRevision,
    device,
    profile,
    copies,
    operationKey: key,
  );
  Future<Map<String, Object?>> facts() => db.read(
    (sql) async => {
      for (final name in [
        'products',
        'stock_batches',
        'stock_history',
        'stock_receipts',
        'sale_transactions',
        'sale_transaction_items',
        'payments',
        'printer_profiles',
      ])
        name: await sql.query(
          name,
          orderBy: name == 'printer_profiles' ? 'device_id' : 'id',
        ),
    },
  );
  test(
    'M53 label copies and idempotent preparation never change stock sale HPP or receipt settings',
    () async {
      final before = await facts();
      final id = await prepare(copies: 2);
      expect(await prepare(copies: 2), id);
      await expectLater(prepare(copies: 3), throwsA(isA<AppError>()));
      final job = await queue.job(id);
      expect(job['sale_transaction_id'], isNull);
      expect(await queue.send(id), 'submitted');
      final writes = transport.writes;
      expect(writes, greaterThan(2));
      expect(transport.finishes, 1);
      expect(await queue.send(id), 'submitted');
      expect(transport.writes, writes);
      expect(await facts(), before);
    },
  );
  test(
    'M53 label stale product and invalid media fail before queue insert or connection',
    () async {
      final snap = await app.labels.snapshot(product);
      await app.inventory.edit(
        product,
        ProductInput(name: 'PUBLIC UPDATED', sellingPrice: money(13000)),
        snap.productRevision,
      );
      await expectLater(
        prepare(revision: snap.productRevision),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        prepare(
          profile: const ProductLabelProfile(
            protocol: PrinterProtocol.escPosRaster,
            widthMm: 24,
            heightMm: 24,
          ),
        ),
        throwsFormatException,
      );
      expect(await db.read((sql) => sql.query('print_jobs')), isEmpty);
      expect(transport.connects, 0);
    },
  );
  test(
    'M53 prepared label preserves public name price and profile after master edit',
    () async {
      final id = await prepare();
      final before = await queue.job(id);
      final snap = await app.labels.snapshot(product);
      await app.inventory.edit(
        product,
        ProductInput(name: 'PUBLIC RENAMED', sellingPrice: money(17000)),
        snap.productRevision,
      );
      await app.printers.save(
        device,
        'PUBLIC UPDATED PRINTER',
        const PrinterProfile(feed: 8),
      );
      expect((await queue.job(id))['snapshot_json'], before['snapshot_json']);
      expect((await queue.job(id))['profile_json'], before['profile_json']);
      expect(await queue.send(id), 'submitted');
      final snapshot = jsonDecode(before['snapshot_json'] as String) as Map;
      expect(snapshot['productLabel']['name'], 'PUBLIC QR GOODS');
      expect(snapshot['productLabel']['price'], 12000);
    },
  );
  for (final partial in [false, true]) {
    test(
      'M53 label ${partial ? 'partial delivery stays unknown' : 'connect failure stays failed'} without automatic retry',
      () async {
        final before = await facts();
        final id = await prepare();
        transport.partial = partial;
        transport.unavailable = !partial;
        final expected = partial ? 'unknown' : 'failed';
        expect(await queue.send(id), expected);
        expect(await queue.send(id), expected);
        expect(transport.connects, 1);
        expect(transport.finishes, 0);
        expect(await facts(), before);
      },
    );
  }
  test(
    'M53 label locked capability cannot claim or expose protected prepared job',
    () async {
      final id = await prepare();
      app.management.lock();
      await expectLater(queue.send(id), throwsA(isA<AppError>()));
      await expectLater(queue.job(id), throwsA(isA<AppError>()));
      expect(transport.connects, 0);
      expect(
        (await db.read((sql) => sql.query('print_jobs'))).single['status'],
        'prepared',
      );
    },
  );
  test(
    'M53 label lock during output stops further writes and keeps ambiguous status',
    () async {
      final id = await prepare();
      transport.afterWrite = app.management.lock;
      expect(await queue.send(id), 'unknown');
      expect(transport.writes, 1);
      expect(transport.finishes, 0);
    },
  );
  test(
    'M53 label profile CAS keeps receipt settings separate and validates gap explicitly',
    () async {
      final before = await facts();
      expect(await app.labels.saveProfile(device, media, 0), 1);
      await expectLater(
        app.labels.saveProfile(device, media, 0),
        throwsA(isA<AppError>()),
      );
      await expectLater(
        app.labels.saveProfile(
          device,
          const ProductLabelProfile(
            protocol: PrinterProtocol.cpcl,
            gap: true,
            gapConfirmed: true,
          ),
          1,
        ),
        throwsFormatException,
      );
      expect((await app.labels.printer(device)).revision, 1);
      expect(await facts(), before);
    },
  );
  test(
    'M53 warehouse can prepare labels while public cashier printer access grants no inventory authority',
    () async {
      await app.management.reauthenticate('0001', 'security');
      await app.management.setTaskPattern(
        3,
        warehousePin: '1234',
        confirmation: '1234',
      );
      await app.management.unlock('1234', role: ManagementRole.warehouse);
      final id = await prepare();
      expect(await queue.send(id), 'submitted');
      app.management.lock();
      await expectLater(app.labels.snapshot(product), throwsA(isA<AppError>()));
      await expectLater(app.labels.printers(), throwsA(isA<AppError>()));
      await expectLater(
        app.labels.saveProfile(device, media, 0),
        throwsA(isA<AppError>()),
      );
      expect(await queue.prepareCalibration(publicPrinter: true), isNotEmpty);
      await expectLater(
        app.labels.prepare(
          product,
          1,
          device,
          media,
          1,
          operationKey: 'cashier',
        ),
        throwsA(isA<AppError>()),
      );
    },
  );
  test(
    'M53 portable label preferences survive missing local hardware and reject forged typed settings',
    () async {
      await app.labels.saveProfile(device, media, 0);
      await db.transaction((sql) => sql.delete('printer_profiles'));
      await db.read(ProductLabelValidation.validate);
      expect(
        (await db.read((sql) => sql.query('product_label_profiles'))).length,
        1,
      );
      expect(await app.labels.printers(), isEmpty);
      await expectLater(prepare(), throwsA(isA<AppError>()));
      await db.transaction(
        (sql) => sql.update('product_label_profiles', {
          'settings_json': jsonEncode({...media.toJson(), 'moduleDots': '4'}),
        }),
      );
      await expectLater(
        db.read(ProductLabelValidation.validate),
        throwsFormatException,
      );
    },
  );
  test(
    'M53 additive schema34 to35 preserves every original table row and never invents labels',
    () async {
      final old = DatabaseCoordinator(
        factory: factory,
        databasePath: path(),
        schemaVersion: 34,
      );
      DatabaseCoordinator? upgraded;
      bool closed = false;
      try {
        final prior = AppServices(old);
        await old.transaction(
          (sql) => sql.insert('management_credentials', credential),
        );
        await prior.management.unlock('0001');
        await prior.printers.save(
          device,
          'PUBLIC LEGACY PRINTER',
          const PrinterProfile(feed: 8, topFeed: 0),
        );
        await prior.inventory.create(
          ProductInput(
            name: 'PUBLIC LEGACY STOCK',
            barcode: '0000123456789',
            sellingPrice: money(500),
          ),
          initialQuantity: 999,
          unitCost: CostAmount.fromMoney(money(100)),
        );
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
          schemaVersion: 35,
        );
        for (final entry in before.entries) {
          expect(
            await upgraded.read((sql) => sql.query(entry.key)),
            entry.value,
            reason: entry.key,
          );
        }
        expect(
          await upgraded.read((sql) => sql.query('product_label_profiles')),
          isEmpty,
        );
        expect(
          (await upgraded.read(
            (sql) => sql.rawQuery('PRAGMA user_version'),
          )).single.values.single,
          35,
        );
      } finally {
        if (!closed) await old.close();
        await upgraded?.close();
        await factory.deleteDatabase(old.databasePath);
      }
    },
  );
}
