import '../app/app_services.dart';
import '../core/domain/value_types.dart';
import '../core/time/store_clock.dart';
import '../data/database/database_coordinator.dart';
import '../data/database/database_validation.dart';
import '../data/repositories/sqlite_reports_repository.dart';
import '../features/cashier/domain/cashier_models.dart';
import '../features/inventory/domain/inventory_models.dart';
import '../features/inventory/domain/stock_input.dart';
import '../features/members/domain/member_models.dart';

/// Seeds only an empty, explicitly selected demonstration database through real
/// use cases. Never imported by main.dart and never resets an existing store.
final class GeminiDemoSeed {
  static const storeName = 'Toko Gemini Kasir';
  static const publicDemoPin = '1111';

  static Future<Map<String, Object?>> populate(
    DatabaseCoordinator database, {
    DateTime? now,
  }) async {
    final clock = _GeminiClock(now ?? DateTime.now());
    final app = AppServices(database, clock: clock);
    if (await app.management.isConfigured ||
        await database.read(
          (db) async =>
              (await db.rawQuery(
                'SELECT COUNT(*) AS n FROM products',
              )).single['n'] !=
              0,
        )) {
      throw StateError('geminiDemoRequiresEmptyDatabase');
    }
    final anchor = clock.value;
    CalendarDate day(int offset) => clock.dateAt(
      anchor.add(Duration(days: offset)).millisecondsSinceEpoch,
      'Asia/Jakarta',
    );
    Money money(int amount) => Money(amount, 'IDR', 0);
    CostAmount cost(int amount) => CostAmount.fromMoney(money(amount));

    clock.value = anchor.subtract(const Duration(days: 30));
    await app.management.configure(storeName, publicDemoPin, publicDemoPin);
    await app.management.unlock(publicDemoPin);
    await app.settings.setLanguage('id');
    await app.settings.save(
      name: storeName,
      zone: 'Asia/Jakarta',
      address: 'Jl. Percobaan No. 88, Jakarta',
      footer: 'Terima kasih — Toko Uji Mandiri Gemini',
    );

    // 1. Kategori
    final categories = <EntityId>[];
    for (final name in [
      'Sembako & Beras',
      'Minuman Segar',
      'Makanan Ringan',
      'Bumbu Dapur',
      'Perawatan Tubuh',
      'Kebersihan Rumah',
      'Alat Tulis Kantor',
      'Kebutuhan Harian',
    ]) {
      categories.add(await app.inventory.saveMaster(MasterKind.category, name));
    }

    // 2. Supplier
    final suppliers = <EntityId>[];
    final supplierNames = [
      'PT Sumber Pangan Sejahtera',
      'CV Tirta Segar Abadi',
      'PT Harum Jaya Distribusi',
      'CV Berkah Tani Makmur',
      'UD Nusantara Retail',
    ];
    for (final name in supplierNames) {
      suppliers.add(
        await app.inventory.saveMaster(
          MasterKind.supplier,
          name,
          contact: '0812999900${suppliers.length + 1}',
        ),
      );
    }

    // 3. Pelanggan Terdaftar (Members)
    final members = <MemberProfile>[];
    final memberInputs = [
      const MemberInput(name: 'Budi Santoso', phone: '08123456701', address: 'Jl. Melati No. 12'),
      const MemberInput(name: 'Siti Rahma', phone: '08123456702', address: 'Jl. Mawar No. 45'),
      const MemberInput(name: 'Hendra Wijaya', phone: '08123456703', address: 'Jl. Kenanga No. 8'),
      const MemberInput(name: 'Dewi Lestari', phone: '08123456704', address: 'Jl. Anggrek No. 23'),
      const MemberInput(name: 'Agus Pratama', phone: '08123456705', address: 'Jl. Dahlia No. 17'),
      const MemberInput(name: 'Rina Marlina', phone: '08123456706', address: 'Jl. Cempaka No. 9'),
    ];
    for (final input in memberInputs) {
      members.add(await app.members.create(input));
    }

    // 4. 100 Produk Berbagai Kondisi
    const names = [
      'Beras Pandan Wangi',
      'Gula Pasir Kristal',
      'Teh Melati Celup',
      'Kopi Robusta Bubuk',
      'Susu UHT Cokelat',
      'Biskuit Gandum',
      'Sabun Mandi Cair',
      'Minyak Goreng Sawit',
      'Mi Instan Kuah Kari',
      'Buku Tulis Bergaris',
    ];
    const conditions = [
      'Stok kosong',
      'Stok rendah',
      'Kedaluwarsa',
      'Jatuh tempo hari ini',
      'Hampir kedaluwarsa',
      'Batch campuran',
      'Stok melimpah',
      'Catatan panjang',
      'Grosir dan dus',
      'Harga promo',
    ];

    final products = <EntityId>[];
    for (var i = 0; i < 100; i++) {
      final group = i % 10;
      final serial = (i + 1).toString().padLeft(3, '0');
      final price = 2500 + i * 500;
      final quantity = group == 0
          ? 0
          : group == 1
          ? 2
          : group == 5
          ? 10
          : 50 + i;

      final id = await app.inventory.create(
        ProductInput(
          name: '${names[(i ~/ 10) % names.length]} $serial — ${conditions[group]}',
          sku: 'GM-$serial',
          barcode: group == 7
              ? null
              : '899${(i + 1).toString().padLeft(10, '0')}',
          aliases: ['barang $serial', 'gemini $serial'],
          categoryId: categories[i % categories.length],
          sellingPrice: money(price),
          wholesalePrice: group == 8 ? money(price > 500 ? price - 500 : price) : null,
          packLabel: group == 8 ? 'dus' : null,
          packSize: group == 8 ? 12 : null,
          minStock: 5,
          expiryEnabled: group >= 2 && group <= 5,
          attributes: i % 4 == 0
              ? null
              : ProductAttributes(
                  sizeMilli: [500000, 1500, 250000, 1000][i % 4],
                  unit: ['g', 'kg', 'ml', 'l'][i % 4],
                  shelf: 'Rak ${1 + i ~/ 10}-${String.fromCharCode(65 + group)}',
                  note: group == 7
                      ? 'Catatan operasional pengujian mandiri Gemini. '
                            '${List.filled(10, 'Kemasan rapat, simpan di tempat sejuk dan kering.').join(' ')}'
                      : i % 3 == 0
                      ? null
                      : 'Keterangan produk dummy $serial',
                ),
        ),
        initialQuantity: quantity,
        unitCost: quantity == 0 ? null : cost(1500 + i * 350),
        expiry: switch (group) {
          2 || 5 => day(-5),
          3 => day(0),
          4 => day(3),
          _ => null,
        },
      );
      products.add(id);

      // Multi-batch campuran
      if (group == 5) {
        await app.inventory.receive(
          id,
          25,
          cost(1800 + i * 350),
          operationKey: 'gemini-batch-mixed-$serial',
          supplierId: suppliers[i % suppliers.length],
          expiry: day(90),
        );
      }

      // Pembelian grosir kemasan dus
      if (group == 8) {
        await app.inventory.receivePurchase(
          id,
          StockPurchase(
            StockInput(
              3,
              unit: StockInputUnit.pack,
              packSize: 12,
              packLabel: 'dus',
            ),
            cost((1600 + i * 350) * 12),
          ),
          operationKey: 'gemini-pack-purchase-$serial',
          supplierId: suppliers[i % suppliers.length],
        );
      }
    }

    // 5. 50 Transaksi Penjualan Beragam
    for (var i = 0; i < 50; i++) {
      final dayOffset = 24 - (i ~/ 2);
      final hour = i.isEven ? 10 : 15;
      final minute = (i * 11) % 60;
      clock.value = anchor.subtract(Duration(days: dayOffset)).copyWith(hour: hour, minute: minute);

      var cart = await app.cart.open();
      // Pilih produk bukan arsip (0 s.d. 94)
      final prod1 = products[(i * 3 + 6) % 95];
      cart = await app.cart.add(cart.id, prod1);
      cart = await app.cart.quantity(cart.id, prod1, 1 + (i % 3));

      // Tambah item kedua pada sebagian transaksi
      if (i % 2 == 1) {
        final prod2 = products[(i * 5 + 18) % 95];
        cart = await app.cart.add(cart.id, prod2);
        cart = await app.cart.quantity(cart.id, prod2, 1 + ((i + 1) % 2));
      }

      // Varian harga grosir khusus produk group 8 yang memiliki harga grosir
      if (i % 5 == 2) {
        final wholesaleProd = products[((i ~/ 5) % 9) * 10 + 8];
        cart = await app.cart.add(cart.id, wholesaleProd);
        cart = await app.cart.quantity(cart.id, wholesaleProd, 2);
        cart = await app.cart.pricing(cart.id, wholesaleProd, PricingMode.wholesale);
      }

      final mode = i % 5;
      final member = members[i % members.length];
      final customer = (mode == 2 || mode == 3 || mode == 4)
          ? CustomerChoice(
              id: member.id,
              name: member.name,
              phone: member.phone ?? '',
              address: member.address,
            )
          : const CustomerChoice();

      final total = cart.total.amountMinor;
      final tender = mode == 0
          ? total // Uang pas
          : mode == 1
          ? total + 10000 // Kembalian tunai
          : mode == 2
          ? total ~/ 2 // Piutang sebagian (kasbon)
          : mode == 3
          ? 0 // Piutang penuh
          : total; // Uang pas member

      final receipt = await app.checkout.submit(
        cart.id,
        cart.revision,
        CheckoutInput(
          cash: true,
          tender: money(tender),
          tenderRaw: '$tender',
          customer: customer,
        ),
      );

      // Reversal / pembatalan sah untuk 3 transaksi (audit bukti pengembalian barang & laci)
      if (i == 7 || i == 23 || i == 41) {
        await app.corrections.cancelSale(
          receipt.id,
          operationKey: 'gemini-cancel-$i',
          reason: i == 7
              ? 'Barang kemasan cacat fisik'
              : i == 23
              ? 'Salah input nominal kasir'
              : 'Pelanggan membatalkan pesanan',
          goodsReturned: true,
          moneyHandled: true,
        );
      }
      await app.cart.next(cart.id);
    }

    clock.value = anchor;

    // 6. Pelunasan Sebagian Piutang Pelanggan
    final activeReceivables = (await app.receivables.customers(
      activeDebts: true,
    )).items;
    for (var i = 0; i < activeReceivables.length && i < 4; i++) {
      final balance = await app.receivables.balance(activeReceivables[i].id);
      if (balance.amountMinor > 0) {
        final payAmount = i.isEven ? balance.amountMinor : balance.amountMinor ~/ 2;
        if (payAmount > 0) {
          await app.receivables.record(
            await app.receivables.preview(activeReceivables[i].id, money(payAmount)),
          );
        }
      }
    }

    // 7. Arsipkan 5 Produk (indeks 95-99) untuk pengujian filter arsip
    for (var i = 95; i < 100; i++) {
      var item = await app.inventory.detail(products[i]);
      if (item.quantity > 0) {
        await app.inventory.adjust(
          item.id,
          0,
          operationKey: 'gemini-archive-$i',
          reason: 'Barang uji dinonaktifkan',
        );
        item = await app.inventory.detail(item.id);
      }
      await app.inventory.archive(item.id, item.revision);
    }

    // 8. Validasi Integritas & Rekonsiliasi Bisnis
    await database.read(DatabaseValidation.integrity);
    if (!(await database.read(
      SqliteReportsRepository.reconcileDatabase,
    )).consistent) {
      throw StateError('geminiDemoReconciliationFailed');
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
        throw StateError('geminiDemoCountsMismatch');
      }
      if ((await db.rawQuery(
        'SELECT 1 FROM products WHERE stock_quantity<0 LIMIT 1',
      )).isNotEmpty) {
        throw StateError('geminiDemoNegativeStock');
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
      'defaultPin': publicDemoPin,
    };
  }
}

/// Fixture clock allows historical timestamp simulation without OS clock manipulation.
final class _GeminiClock extends StoreClock {
  _GeminiClock(this.value);
  DateTime value;
  @override
  DateTime get now => value.toUtc();
}
