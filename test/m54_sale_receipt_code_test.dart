import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/sale_receipt_code.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'M54 receipt codes resolve only one active committed local sale',
    () async {
      final dir = await Directory.systemTemp.createTemp('kasir_receipt_codes_');
      final path = '${dir.path}/m5_regression_54.db';
      var database = DatabaseCoordinator(
        factory: databaseFactoryFfi,
        databasePath: path,
        schemaVersion: 39,
      );
      var services = AppServices(database);
      Future<({CartSnapshot draft, SaleReceipt receipt})> sell(
        EntityId id,
      ) async {
        var draft = await services.cart.open();
        if (draft.completedId != null) {
          draft = await services.cart.next(draft.id);
        }
        draft = await services.cart.add(draft.id, id);
        return (
          draft: draft,
          receipt: await services.checkout.submit(
            draft.id,
            draft.revision,
            const CheckoutInput(),
          ),
        );
      }

      final unavailable = isA<AppError>().having(
        (e) => e.message,
        'message',
        'm3SaleUnavailable',
      );
      try {
        await services.management.configure(
          'PUBLIC RECEIPT TEST',
          '0001',
          '0001',
        );
        await services.management.unlock('0001');
        final id = await services.inventory.create(
          ProductInput(
            name: 'PUBLIC PRODUCT',
            sellingPrice: Money(12000, 'IDR', 0),
          ),
          initialQuantity: 3,
          unitCost: CostAmount.fromMoney(Money(6000, 'IDR', 0)),
        );
        final old = (await sell(id)).receipt;
        expect(old.code, isNull);
        expect(
          (await services.checkout.receiptFromReference(old.number)).id,
          old.id,
        );
        final before = await database.read(SkybeeUpgradeAudit.capture);
        await database.close();
        database = DatabaseCoordinator(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        services = AppServices(database);
        final proof = await database.read(
          (db) => SkybeeUpgradeAudit.verify(db, before),
        );
        expect(proof['allExistingFactsMatch'], isTrue);
        expect(
          (await services.checkout.receiptFromReference(old.number)).code,
          isNull,
        );
        final sale = await sell(id);
        final code = sale.receipt.code!;
        expect(code.token, matches(r'^91[0-9]{20}$'));
        final beforeLookup = database.revision;
        for (final input in [
          code.token,
          code.qr,
          sale.receipt.number.toLowerCase(),
        ]) {
          expect(
            (await services.checkout.receiptFromReference(input)).id,
            sale.receipt.id,
          );
        }
        final lastDigit = code.token.endsWith('1') ? '2' : '1';
        final other = SaleReceiptCode.issue(const IdGenerator().next());
        for (final input in [
          other.qr,
          code.qr.replaceFirst(':1:', ':2:'),
          code.qr.replaceFirst(code.store.value, other.store.value),
          '${code.token.substring(0, 21)}$lastDigit',
          'https://example.invalid/${code.token}',
          sale.draft.id.value,
        ]) {
          await expectLater(
            services.checkout.receiptFromReference(input),
            throwsA(unavailable),
          );
        }
        await expectLater(
          services.search.scan(code.qr),
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'message',
              'm54SaleReceiptOnly',
            ),
          ),
        );
        expect(database.revision, beforeLookup);
        final again = await services.checkout.submit(
          sale.draft.id,
          sale.draft.revision,
          const CheckoutInput(),
        );
        expect(again.code!.qr, code.qr);
        final later = (await sell(id)).receipt;
        expect(later.code!.token, isNot(code.token));
        final snapshot = await database.read((db) async {
          final row = (await db.query(
            'print_receipts',
            where: 'sale_transaction_id=?',
            whereArgs: [sale.receipt.id.value],
          )).single;
          return jsonDecode(row['snapshot_json'] as String)
              as Map<String, dynamic>;
        });
        expect(snapshot['receiptCode'], code.token);
        expect(snapshot['receiptCodeQr'], code.qr);
        await services.management.unlock('0001');
        await services.corrections.cancelSale(
          sale.receipt.id,
          operationKey: 'public-cancel',
          reason: 'PUBLIC REVERSAL',
          goodsReturned: true,
          moneyHandled: true,
        );
        await expectLater(
          services.checkout.receiptFromReference(code.qr),
          throwsA(unavailable),
        );
        expect(
          (await services.checkout.receipt(sale.receipt.id)).code!.token,
          code.token,
        );
        expect(
          (await services.checkout.receipt(sale.receipt.id)).reversed,
          isTrue,
        );
      } finally {
        await database.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await dir.delete();
      }
    },
  );
}
