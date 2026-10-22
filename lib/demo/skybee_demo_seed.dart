import '../app/app_services.dart';
import '../core/domain/value_types.dart';
import '../core/time/store_clock.dart';
import '../data/database/database_coordinator.dart';
import '../data/database/database_validation.dart';
import '../data/repositories/sqlite_reports_repository.dart';
import '../features/cashier/domain/cashier_models.dart';
import '../features/inventory/domain/inventory_models.dart';
import '../features/inventory/domain/stock_input.dart';

/// Seeds only an empty, explicitly selected demonstration database through real
/// use cases. Never imported by main.dart and never resets an existing store.
final class SkybeeDemoSeed {
  static const storeName = 'toko skybee';
  static const publicDemoPin = '1111';

  static Future<Map<String, Object?>> populate(
    DatabaseCoordinator database, {
    DateTime? now,
  }) async {
    final clock = _DemoClock(now ?? DateTime.now());
    final app = AppServices(database, clock: clock);
    if (await app.management.isConfigured ||
        await database.read(
          (db) async =>
              (await db.rawQuery(
                'SELECT COUNT(*) AS n FROM products',
              )).single['n'] !=
              0,
        )) {
      throw StateError('skybeeDemoRequiresEmptyDatabase');
    }
    final anchor = clock.value;
    CalendarDate day(int offset) => clock.dateAt(
      anchor.add(Duration(days: offset)).millisecondsSinceEpoch,
      'Asia/Jakarta',
    );
    Money money(int amount) => Money(amount, 'IDR', 0);
    CostAmount cost(int amount) => CostAmount.fromMoney(money(amount));
    clock.value = anchor.subtract(const Duration(days: 30));
    // Returned management recovery is intentionally not logged or retained.
    await app.management.configure(storeName, publicDemoPin, publicDemoPin);
    await app.management.unlock(publicDemoPin);
    await app.settings.setLanguage('id');
    await app.settings.save(
      name: storeName,
      zone: 'Asia/Jakarta',
      address: 'Alamat toko contoh',
      footer: 'Terima kasih — data demo Skybee',
    );
    final categories = <EntityId>[];
    for (final name in [
      'Sembako',
      'Minuman',
      'Makanan ringan',
      'Bumbu',
      'Perawatan',
      'Kebersihan',
      'Alat tulis',
      'Perlengkapan',
    ]) {
      categories.add(await app.inventory.saveMaster(MasterKind.category, name));
    }
    final suppliers = <EntityId>[];
    for (var i = 1; i <= 4; i++) {
      suppliers.add(
        await app.inventory.saveMaster(
          MasterKind.supplier,
          'Supplier Demo $i',
          contact: null,
        ),
      );
    }
    const names = [
      'Beras',
      'Gula pasir',
      'Teh melati',
      'Kopi bubuk',
      'Susu kotak',
      'Biskuit',
      'Sabun mandi',
      'Minyak goreng',
      'Mi instan',
      'Buku tulis',
    ];
    const conditions = [
      'Stok kosong',
      'Stok rendah',
      'Kedaluwarsa',
      'Jatuh tempo hari ini',
      'Hampir kedaluwarsa',
      'Batch campuran',
      'Stok normal',
      'Catatan panjang',
      'Grosir dan dus',
      'Harga khusus',
    ];
    final products = <EntityId>[];
    for (var i = 0; i < 100; i++) {
      final group = i % 10;
      final serial = (i + 1).toString().padLeft(3, '0');
      final price = group == 9 && i < 50 ? 0 : 1500 + i * 750;
      final quantity = group == 0
          ? 0
          : group == 1
          ? 2
          : group == 5
          ? 10
          : 40 + i;
      final id = await app.inventory.create(
        ProductInput(
          name:
              '${names[(i ~/ 10) % names.length]} $serial — ${conditions[group]}',
          sku: 'SB-$serial',
          barcode: group == 7
              ? null
              : '000${(i + 1).toString().padLeft(10, '0')}',
          aliases: ['barang $serial', 'demo $serial'],
          categoryId: categories[i % categories.length],
          sellingPrice: money(price),
          wholesalePrice: group == 8 ? money(price - 500) : null,
          packLabel: group == 8 ? 'dus' : null,
          packSize: group == 8 ? 12 : null,
          minStock: 5,
          expiryEnabled: group >= 2 && group <= 5,
          attributes: i % 4 == 0
              ? null
              : ProductAttributes(
                  sizeMilli: [500000, 1500, 250000, 1000][i % 4],
                  unit: ['g', 'kg', 'ml', 'l'][i % 4],
                  shelf:
                      'Rak ${1 + i ~/ 10}-${String.fromCharCode(65 + group)}',
                  note: group == 7
                      ? 'Catatan internal demo, bukan untuk struk. '
                            '${List.filled(12, 'Periksa kemasan dan simpan di tempat kering.').join(' ')}'
                      : i % 3 == 0
                      ? null
                      : 'Keterangan dummy $serial',
                ),
        ),
        initialQuantity: quantity,
        unitCost: quantity == 0 ? null : cost(price == 0 ? 0 : 1000 + i * 400),
        expiry: switch (group) {
          2 || 5 => day(-2),
          3 => day(0),
          4 => day(7),
          _ => null,
        },
      );
      products.add(id);
      if (group == 5) {
        await app.inventory.receive(
          id,
          20,
          cost(1200 + i * 400),
          operationKey: 'skybee-mixed-$serial',
          supplierId: suppliers[i % 4],
          expiry: day(90),
        );
      }
      if (group == 8) {
        await app.inventory.receivePurchase(
          id,
          StockPurchase(
            StockInput(
              2,
              unit: StockInputUnit.pack,
              packSize: 12,
              packLabel: 'dus',
            ),
            cost((1100 + i * 400) * 12),
          ),
          operationKey: 'skybee-pack-$serial',
          supplierId: suppliers[i % 4],
        );
      }
    }
    // Spread real sale events over the last twenty days without changing the
    // device clock. Cash tender, debt and repayment remain production facts.
    for (var i = 0; i < 20; i++) {
      clock.value = anchor.subtract(Duration(days: 19 - i));
      final product = products[(i ~/ 4) * 10 + 6 + i % 4];
      var cart = await app.cart.open();
      cart = await app.cart.add(cart.id, product);
      cart = await app.cart.quantity(cart.id, product, 1 + i % 3);
      if (i % 4 == 2) {
        cart = await app.cart.pricing(cart.id, product, PricingMode.wholesale);
      }
      final mode = i % 4;
      final tender = mode == 0
          ? cart.total.amountMinor + 10000
          : mode == 1
          ? cart.total.amountMinor ~/ 2
          : mode == 2
          ? 0
          : cart.total.amountMinor;
      final receipt = await app.checkout.submit(
        cart.id,
        cart.revision,
        CheckoutInput(
          cash: true,
          tender: money(tender),
          tenderRaw: '$tender',
          customer: mode == 1 || mode == 2
              ? CustomerChoice(name: 'Pelanggan Demo ${i + 1}')
              : const CustomerChoice(),
        ),
      );
      if (i == 3 || i == 11) {
        await app.corrections.cancelSale(
          receipt.id,
          operationKey: 'skybee-cancel-$i',
          reason: 'Koreksi penjualan dummy',
          goodsReturned: true,
          moneyHandled: true,
        );
      }
      await app.cart.next(cart.id);
    }
    clock.value = anchor;
    final customers = (await app.receivables.customers(
      activeDebts: true,
    )).items;
    for (var i = 0; i < customers.length && i < 4; i++) {
      final balance = await app.receivables.balance(customers[i].id);
      final amount = i.isEven ? balance.amountMinor : balance.amountMinor ~/ 2;
      await app.receivables.record(
        await app.receivables.preview(customers[i].id, money(amount)),
      );
    }
    for (var i = 95; i < 100; i++) {
      var item = await app.inventory.detail(products[i]);
      if (item.quantity > 0) {
        await app.inventory.adjust(
          item.id,
          0,
          operationKey: 'skybee-archive-$i',
          reason: 'Barang demo dihentikan',
        );
        item = await app.inventory.detail(item.id);
      }
      await app.inventory.archive(item.id, item.revision);
    }
    await database.read(DatabaseValidation.integrity);
    if (!(await database.read(
      SqliteReportsRepository.reconcileDatabase,
    )).consistent) {
      throw StateError('skybeeDemoReconciliationFailed');
    }
    final summary = await database.read((db) async {
      final counts = <String, Object?>{};
      for (final table in [
        'products',
        'categories',
        'suppliers',
        'customers',
        'sale_transactions',
        'sale_transaction_reversals',
        'payments',
        'stock_receipts',
      ]) {
        counts[table] = (await db.rawQuery(
          'SELECT COUNT(*) AS n FROM $table',
        )).single['n'];
      }
      counts['activeProducts'] = (await db.rawQuery(
        'SELECT COUNT(*) AS n FROM products WHERE is_deleted=0',
      )).single['n'];
      if (counts['products'] != 100 || counts['activeProducts'] != 95) {
        throw StateError('skybeeDemoCountsMismatch');
      }
      if ((await db.rawQuery(
        'SELECT 1 FROM products WHERE stock_quantity<0 LIMIT 1',
      )).isNotEmpty) {
        throw StateError('skybeeDemoNegativeStock');
      }
      return counts;
    });
    app.management.lock();
    return {
      'seedVersion': 1,
      'status': 'complete',
      'schema': database.schemaVersion,
      'seededAt': anchor.toUtc().toIso8601String(),
      'counts': summary,
      'integrityAndForeignKeys': 'PASS',
      'businessReconciliation': 'PASS',
      'pinConfiguredAndVerified': true,
    };
  }
}

/// Fixture history uses an injected service clock; Android time is untouched.
final class _DemoClock extends StoreClock {
  _DemoClock(this.value);
  DateTime value;
  @override
  DateTime get now => value.toUtc();
}
