import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/members/domain/member_models.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

/// Synthetic exploration data, exclusively in an owned shadow at real setup
/// completion. Uses domain writers and the user's currency/tracking/cost policy.
/// Historical clocks are injected; Android time and contacts are never touched.
final class SkybeeExplorationSeed {
  static Future<Map<String, int>> populate(
    AppServices app,
    ExplorationClock clock,
    String nonce,
  ) async {
    final policy = await app.settings.featurePolicy();
    final settings = await app.settings.load();
    final currency = CurrencyPolicy.forCode(
      settings['currency_code'] as String,
    );
    final zone = settings['time_zone'] as String;
    final anchor = clock.value;
    Money money(int value) => Money(value, currency.code, currency.scale);
    CostAmount cost(int value) => CostAmount.fromMoney(money(value));
    CalendarDate day(int offset) => clock.dateAt(
      anchor.add(Duration(days: offset)).millisecondsSinceEpoch,
      zone,
    );
    for (final table in ['products', 'sale_transactions', 'customers']) {
      if ((await app.database.read(
        (db) => db.query(table, limit: 1),
      )).isNotEmpty) {
        throw StateError('explorationSeedRequiresEmptyBusiness');
      }
    }
    final categories = <EntityId>[];
    for (final name in [
      'Sembako',
      'Minuman',
      'Makanan ringan',
      'Perawatan',
      'Kebersihan',
      'Perlengkapan',
    ]) {
      categories.add(
        await app.inventory.saveMaster(MasterKind.category, 'CONTOH $name'),
      );
    }
    final suppliers = <EntityId>[];
    for (var i = 1; i <= 4; i++) {
      suppliers.add(
        await app.inventory.saveMaster(
          MasterKind.supplier,
          'CONTOH Supplier $i',
        ),
      );
    }
    final members = <EntityId>[];
    for (var i = 1; i <= 8; i++) {
      final member = await app.members.create(
        MemberInput(
          name: 'CONTOH Pelanggan $i',
          phone: '0800000000$i',
          address: 'DATA SINTETIS — bukan alamat nyata',
        ),
      );
      members.add(member.id);
    }
    const names = [
      'Beras',
      'Minuman',
      'Biskuit',
      'Kopi',
      'Sabun',
      'Teh',
      'Buku',
      'Bumbu',
      'Susu',
      'Perlengkapan',
    ];
    final products = <EntityId>[];
    clock.value = anchor.subtract(const Duration(days: 30));
    for (var i = 0; i < 100; i++) {
      final group = i % 10, serial = (i + 1).toString().padLeft(3, '0');
      final tracked =
          policy.stockMode == StockMode.all ||
          (policy.stockMode == StockMode.partial && group != 7);
      final quantity = group == 0
          ? 0
          : group == 1
          ? 2
          : group == 8
          ? 999
          : 80;
      final unknown = !policy.cost && group == 2, free = group == 3;
      final expiry = group == 4 || group == 5;
      final purchase = unknown ? null : cost(free ? 0 : 500 + i * 25);
      final product = await app.inventory.create(
        ProductInput(
          name: 'CONTOH ${names[i ~/ 10]} $serial',
          sku: 'SB53-$serial',
          barcode: '000${(i + 1).toString().padLeft(10, '0')}',
          aliases: ['contoh $serial'],
          categoryId: categories[i % categories.length],
          masterSupplierId: i % 3 == 0 ? null : suppliers[i % 4],
          sellingPrice: money(1500 + i * 75),
          wholesalePrice: money(1400 + i * 75),
          packSize: 12,
          packLabel: 'dus',
          minStock: 5,
          expiryEnabled: expiry,
        ),
        initialQuantity: tracked ? quantity : 0,
        stockTracking: tracked,
        unitCost: tracked && quantity > 0 ? purchase : null,
        referenceCost: tracked ? null : purchase,
        confirmedFree: free,
        expiry: expiry ? day(-2) : null,
      );
      products.add(product);
      if (tracked && group == 5) {
        await app.inventory.receive(
          product,
          20,
          cost(600 + i * 25),
          expiry: day(60),
          supplierId: suppliers[i % 4],
          operationKey: 'exploration/$nonce/mixed/$i',
        );
      }
    }
    for (var i = 0; i < 50; i++) {
      clock.value = anchor.subtract(Duration(days: (49 - i) ~/ 4));
      final product = products[(i % 10) * 10 + 6];
      var draft = await app.cart.open();
      if (draft.completedId != null) draft = await app.cart.next(draft.id);
      draft = await app.cart.add(draft.id, product);
      final mode = i % 4;
      final tender = mode == 1
          ? draft.total.amountMinor ~/ 2
          : mode == 2
          ? 0
          : draft.total.amountMinor;
      final sale = await app.checkout.submit(
        draft.id,
        draft.revision,
        CheckoutInput(
          cash: true,
          tender: money(tender),
          tenderRaw: '$tender',
          mode: mode == 2
              ? PaymentMode.debt
              : mode == 1
              ? PaymentMode.partial
              : PaymentMode.paid,
          memberIntent: true,
          customer: CustomerChoice(id: members[i % members.length]),
        ),
      );
      if (i == 7 || i == 31) {
        await app.corrections.cancelSale(
          sale.id,
          operationKey: 'exploration/$nonce/reversal/$i',
          reason: 'CONTOH pembatalan sintetis',
          goodsReturned: true,
          moneyHandled: true,
        );
      }
      await app.cart.next(draft.id);
    }
    clock.value = anchor;
    for (var i = 95; i < 100; i++) {
      var product = await app.inventory.detail(products[i]);
      if (product.stockTracked && product.quantity > 0) {
        await app.inventory.adjust(
          product.id,
          0,
          operationKey: 'exploration/$nonce/archive/$i',
          reason: 'CONTOH barang arsip',
        );
        product = await app.inventory.detail(product.id);
      }
      await app.inventory.archive(product.id, product.revision);
    }
    await app.database.read(DatabaseValidation.integrity);
    if (!(await app.reports.reconcile()).consistent) {
      throw StateError('explorationSeedReconciliationFailed');
    }
    final counts = <String, int>{};
    for (final table in [
      'products',
      'suppliers',
      'categories',
      'customers',
      'sale_transactions',
      'sale_transaction_reversals',
    ]) {
      counts[table] =
          (await app.database.read(
                (db) => db.rawQuery('SELECT COUNT(*) AS n FROM $table'),
              )).single['n']
              as int;
    }
    if (counts['products'] != 100 ||
        counts['sale_transactions'] != 50 ||
        counts['customers'] != 8 ||
        counts['suppliers'] != 4) {
      throw StateError('explorationSeedCountsMismatch');
    }
    await app.database.transaction(
      (db) => app.management.audit(
        db,
        'skybee_m53_exploration_seed',
        entityId: nonce,
      ),
    );
    return counts;
  }
}

final class ExplorationClock extends StoreClock {
  ExplorationClock(this.value);
  DateTime value;
  @override
  DateTime get now => value.toUtc();
  @override
  int get elapsedMilliseconds => 0;
}
