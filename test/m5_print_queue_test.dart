import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/printer/application/print_queue_service.dart';
import 'package:kasir_app/features/printer/application/printer_transport.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';

final class Transport implements PrinterTransport {
  int connections = 0, writes = 0, bytes = 0;
  bool failConnect = false, partial = false;
  @override
  Future<void> connect(String id) async {
    connections++;
    if (failConnect) throw const SocketException('Synthetic unavailable');
  }

  @override
  Future<void> disconnect() async {}
  @override
  Future<void> write(Uint8List data) async {
    writes++;
    bytes += partial ? 1 : data.length;
    if (partial) throw const SocketException('Synthetic partial send');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseCoordinator db;
  late AppServices app;
  late String path;
  late Transport transport;
  late PrintQueueService queue;
  late EntityId sale;
  setUp(() async {
    path =
        '${Directory.systemTemp.path}/kasir_print_${DateTime.now().microsecondsSinceEpoch}.db';
    db = DatabaseCoordinator(factory: databaseFactoryFfi, databasePath: path);
    app = AppServices(db);
    await app.management.configure('Synthetic print store', '0001', '0001');
    await app.management.unlock('0001');
    await app.printers.save(
      '00:11:22:33:44:55',
      'Synthetic ESC/POS',
      const PrinterProfile(),
    );
    final product = await app.inventory.create(
      ProductInput(
        name: 'Synthetic long goods name 名称',
        sellingPrice: Money(12000, 'IDR', 0),
      ),
      initialQuantity: 5,
      unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
    );
    var draft = await app.cart.open();
    draft = await app.cart.add(draft.id, product);
    sale = (await app.checkout.submit(
      draft.id,
      draft.revision,
      const CheckoutInput(
        mode: PaymentMode.debt,
        customer: CustomerChoice(name: 'Synthetic print debtor'),
      ),
    )).id;
    transport = Transport();
    queue = PrintQueueService(db, app.checkout, app.management, transport);
  });
  tearDown(() async {
    await db.close();
    await databaseFactoryFfi.deleteDatabase(path);
  });
  Future<Map> financial() async {
    final all =
        (await db.read(DatabaseValidation.fingerprint))['tables'] as Map;
    return {
      for (final table in [
        'products',
        'stock_batches',
        'stock_history',
        'sale_transactions',
        'sale_transaction_items',
        'sale_batch_allocations',
        'payments',
        'payment_allocations',
        'customers',
        'cart_drafts',
      ])
        table: all[table],
    };
  }

  test(
    'duplicate print taps submit once and copy never changes financial facts',
    () async {
      final before = await financial();
      final preview = await queue.preview(sale, copy: true);
      expect(preview.layout.lines.first.text, 'SALINAN');
      final one = await queue.prepare(sale), two = await queue.prepare(sale);
      expect(two, one);
      await Future.wait([queue.send(one), queue.send(two)]);
      expect((await queue.job(one))['status'], 'submitted');
      expect(transport.connections, 1);
      expect(transport.bytes, greaterThan(2));
      final copy = await queue.prepare(sale, copy: true);
      expect(copy, isNot(one));
      expect(
        (jsonDecode((await queue.job(copy))['snapshot_json'] as String)
            as Map)['copy'],
        true,
      );
      expect(await queue.send(copy), 'submitted');
      expect(transport.connections, 2);
      expect(await financial(), before);
    },
  );
  test(
    'partial send and restart remain ambiguous with no automatic retry',
    () async {
      final before = await financial();
      transport.partial = true;
      final job = await queue.prepare(sale);
      expect(await queue.send(job), 'unknown');
      expect(transport.writes, 1);
      expect(await queue.send(job), 'unknown');
      expect(transport.writes, 1);
      final interrupted = await queue.prepare(sale, copy: true);
      await db.exclusive(
        (sql) => sql.update(
          'print_jobs',
          {'status': 'sending'},
          where: 'id=?',
          whereArgs: [interrupted],
        ),
      );
      final reopened = PrintQueueService(
        db,
        app.checkout,
        app.management,
        Transport(),
      );
      await reopened.recoverInterrupted();
      expect((await reopened.job(interrupted))['status'], 'unknown');
      expect(await reopened.send(interrupted), 'unknown');
      expect((reopened.transport as Transport).connections, 0);
      expect(await financial(), before);
    },
  );
  test(
    'failure before write is not-sent and later repayment does not rewrite receipt paid snapshot',
    () async {
      transport.failConnect = true;
      final before = await financial();
      final job = await queue.prepare(sale);
      expect(await queue.send(job), 'failed');
      expect(transport.writes, 0);
      expect(await financial(), before);
      final customer = (await app.receivables.customers()).items.single;
      await app.receivables.record(
        await app.receivables.preview(customer.id, Money(1000, 'IDR', 0)),
      );
      final copy = await queue.prepare(sale, copy: true);
      final snapshot =
          jsonDecode((await queue.job(copy))['snapshot_json'] as String) as Map;
      expect(snapshot['paid'], 0);
      expect(snapshot['debt'], 12000);
      expect(jsonEncode(snapshot), isNot(contains('cost_micros')));
      expect(
        ReceiptLayout.sale(
          Map<String, dynamic>.from(snapshot),
          const PrinterProfile(),
          copy: true,
        ).lines.first.text,
        'SALINAN',
      );
    },
  );
  for (final profile in [
    const PrinterProfile(),
    PrinterProfile.generic80,
    const PrinterProfile(left: 40, right: 8, shift: -32, font: 32),
  ]) {
    test(
      'raster profile ${profile.paperMm}/${profile.shift} wraps without monetary clipping',
      () async {
        final layout = ReceiptLayout(profile, [
          const ReceiptLine('A very long item name with unicode 名称 and 000123'),
          const ReceiptLine('-EUR 999.999.999.999,99'),
          const ReceiptLine('SALINAN', bold: true),
        ]);
        for (final line in layout.lines) {
          final painter = layout.painter(line);
          for (final metric in painter.computeLineMetrics()) {
            expect(
              metric.width,
              lessThanOrEqualTo(profile.effectiveDots + 0.01),
            );
          }
          painter.dispose();
        }
        var tiles = 0;
        await for (final image in layout.tiles()) {
          final command = await ReceiptLayout.encodeTile(image);
          expect(command.sublist(0, 4), [0x1d, 0x76, 0x30, 0]);
          expect(image.height, lessThanOrEqualTo(64));
          expect(command.length, 8 + ((image.width + 7) ~/ 8) * image.height);
          image.dispose();
          tiles++;
        }
        expect(tiles, greaterThan(0));
      },
    );
  }
  test('invalid margin shift cannot discard receipt pixels', () {
    expect(
      () => const PrinterProfile(shift: -32).validate(),
      throwsFormatException,
    );
  });
}
