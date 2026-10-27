import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'support/database_contract_suite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('exact localized contents, nullable pair, lengths and all units', () {
    expect(ProductAttributes.parseSize('0,5', language: 'id'), 500);
    expect(ProductAttributes.parseSize('1.500', language: 'en'), 1500);
    expect(ProductAttributes.parseSize('', language: 'id'), isNull);
    for (final unit in ProductAttributes.units) {
      final value = ProductAttributes(
        sizeMilli: 500,
        unit: unit,
        shelf: ' A-01 ',
        note: ' first\nsecond ',
      );
      expect(
        ProductAttributes.fromRow(value.toRow(extended: true)).sizeText('id'),
        '0,5',
      );
      expect(value.shelf, 'A-01');
      expect(value.note, 'first\nsecond');
    }
    for (final invalid in [
      '0',
      '-1',
      'NaN',
      '1e3',
      '1.2345',
      '1,5',
      '1000000000',
      '1,000.5',
      '1.',
    ]) {
      expect(
        () => ProductAttributes.parseSize(invalid, language: 'en'),
        throwsA(anything),
        reason: invalid,
      );
    }
    expect(() => ProductAttributes(sizeMilli: 500), throwsA(anything));
    expect(() => ProductAttributes(unit: 'kg'), throwsA(anything));
    expect(
      () => ProductAttributes(sizeMilli: 1, unit: 'lb'),
      throwsA(anything),
    );
    expect(() => ProductAttributes(shelf: 'x' * 81), throwsA(anything));
    expect(() => ProductAttributes(note: 'x' * 1001), throwsA(anything));
    expect(ProductAttributes(shelf: ' ', note: '\n').isEmpty, true);
  });

  late Directory directory;
  var counter = 0;
  setUpAll(
    () async => directory = await Directory.systemTemp.createTemp(
      'kasir_m51_attributes_',
    ),
  );
  tearDownAll(() async {
    if (!p.isWithin(Directory.systemTemp.path, directory.path) ||
        !p.basename(directory.path).startsWith('kasir_m51_attributes_')) {
      throw StateError('Unsafe cleanup');
    }
    await directory.delete(recursive: true);
  });
  test(
    'schema8 migration retains old values and leaves missing metadata null',
    () async {
      final path = p.join(directory.path, '${counter++}.db');
      var db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
        schemaVersion: 8,
      );
      await db.transaction((sql) async {
        await sql.insert(
          'products',
          productRow(1, 'Legacy 000123', barcode: '000123'),
        );
        await seedSale(sql, 2, 1000);
      });
      final before = await db.read((sql) => sql.query('products'));
      await db.close();
      db = DatabaseCoordinator(factory: databaseFactoryFfi, databasePath: path);
      try {
        final migrated = await db.read((sql) => sql.query('products'));
        for (final entry in before.single.entries) {
          expect(migrated.single[entry.key], entry.value, reason: entry.key);
        }
        expect(ProductAttributes.fromRow(migrated.single).isEmpty, true);
        await expectLater(
          db.transaction((sql) => sql.update('products', {'size_milli': 500})),
          throwsA(anything),
        );
        final stable = await db.read((sql) => sql.query('products'));
        expect(stable, migrated);
      } finally {
        await db.close();
      }
    },
  );
  test(
    'create edit clear, reopened draft and immutable sale metadata leave money/HPP unchanged',
    () async {
      final path = p.join(directory.path, '${counter++}.db');
      var db = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      var app = AppServices(db);
      try {
        await app.management.configure('Synthetic M51', '0001', '0001');
        await app.management.unlock('0001');
        ProductInput input(ProductAttributes? attrs) => ProductInput(
          name: 'Synthetic M51 goods',
          barcode: '000123',
          sellingPrice: Money(12000, 'IDR', 0),
          attributes: attrs,
        );
        final attrs = ProductAttributes(
          sizeMilli: 500,
          unit: 'kg',
          shelf: ' A-1 ',
          note: 'Internal\nnot for receipt',
        );
        final id = await app.inventory.create(
          input(attrs),
          initialQuantity: 3,
          unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
        );
        var draft = await app.cart.open();
        draft = await app.cart.add(draft.id, id);
        await db.close();
        db = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        app = AppServices(db);
        draft = await app.cart.open();
        expect(draft.lines.single.product.attributes.toRow(), attrs.toRow());
        final receipt = await app.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        );
        expect(receipt.total.amountMinor, 12000);
        expect(
          ProductAttributes.fromRow(
            receipt.items.single,
            suffix: '_snapshot',
          ).toRow(),
          attrs.toRow(),
        );
        await app.management.unlock('0001');
        final old = await app.inventory.detail(id);
        await app.inventory.edit(
          id,
          input(ProductAttributes(sizeMilli: 1500, unit: 'l', shelf: 'B-2')),
          old.revision,
        );
        final edited = await app.inventory.detail(id);
        expect(edited.attributes.sizeMilli, 1500);
        await app.inventory.edit(id, input(null), edited.revision);
        expect((await app.inventory.detail(id)).attributes.isEmpty, true);
        expect(
          ProductAttributes.fromRow(
            (await app.checkout.receipt(receipt.id)).items.single,
            suffix: '_snapshot',
          ).toRow(),
          attrs.toRow(),
        );
        await db.read((sql) async {
          expect(
            (await sql.query('sale_transaction_items')).single['cost_micros'],
            9000000000,
          );
          expect((await sql.query('products')).single['stock_quantity'], 2);
          final printed =
              (await sql.query('print_receipts')).single['snapshot_json']
                  as String;
          expect(printed.contains('Internal'), false);
          expect(printed.contains('shelf'), false);
          expect((await sql.query('products')).single['barcode'], '000123');
        });
        expect((await app.reports.reconcile()).consistent, true);
      } finally {
        await db.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
