import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/app_error.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/core/domain/warranty_term.dart';
import 'package:kasir_app/core/time/store_clock.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/demo/skybee_upgrade_audit.dart';
import 'package:kasir_app/features/cashier/application/warranty_validation.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:kasir_app/features/printer/application/receipt_layout.dart';
import 'package:kasir_app/features/printer/domain/printer_profile.dart';
import 'package:kasir_app/features/settings/domain/store_feature_policy.dart';

void m54WarrantySuite(DatabaseFactory factory) {
  test(
    'M54 warranty calendar clamps leap years and validates whole months',
    () {
      for (final (start, months, end) in [
        ('2027-01-31', 1, '2027-02-28'),
        ('2028-01-31', 1, '2028-02-29'),
        ('2028-02-29', 12, '2029-02-28'),
        ('2027-12-31', 4, '2028-04-30'),
      ]) {
        expect(WarrantyTerm.endsOn(CalendarDate(start), months).iso, end);
      }
      for (final text in ['0', '1201', '-1', '1.5', '1e2', '1abc']) {
        expect(
          () => WarrantyTerm.parseOptional(text),
          throwsA(isA<AppError>()),
        );
      }
      expect(WarrantyTerm.parseOptional(' '), isNull);
      expect(WarrantyTerm.parseOptional(' 12 '), 12);
    },
  );

  test(
    'M54 warranty 38→39 and checkout snapshot survive edit, policy off, and retry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kasir_m54_warranty_',
      );
      final path = '${directory.path}/m5_regression_54.db';
      final clock = StoreClock(now: () => DateTime.utc(2028, 1, 30, 17, 1));
      var database = DatabaseCoordinator(
        factory: factory,
        databasePath: path,
        schemaVersion: 38,
      );
      var services = AppServices(database, clock: clock);
      ProductInput product({String? sku, int? months}) => ProductInput(
        name: 'PUBLIC WARRANTY ITEM',
        sku: sku,
        sellingPrice: Money(12000, 'IDR', 0),
        warrantyMonths: months,
      );
      Future<({SaleReceipt receipt, CartSnapshot draft})> sale(
        EntityId id,
      ) async {
        var draft = await services.cart.open();
        if (draft.completedId != null) {
          draft = await services.cart.next(draft.id);
        }
        draft = await services.cart.add(draft.id, id);
        final receipt = await services.checkout.submit(
          draft.id,
          draft.revision,
          const CheckoutInput(),
        );
        return (receipt: receipt, draft: draft);
      }

      Future<Map<String, dynamic>> printed(EntityId sale) =>
          database.read((db) async {
            final row = (await db.query(
              'print_receipts',
              columns: ['snapshot_json'],
              where: 'sale_transaction_id=?',
              whereArgs: [sale.value],
            )).single;
            return jsonDecode(row['snapshot_json'] as String)
                as Map<String, dynamic>;
          });
      Future<void> policy(bool value) async {
        final old = await services.settings.featurePolicy();
        await services.settings.saveFeaturePolicy(
          StoreFeaturePolicy(warranty: value, revision: old.revision),
        );
      }

      Future<void> edit(EntityId id, {int? months, bool clear = false}) async {
        final old = await services.inventory.detail(id);
        await services.inventory.edit(
          id,
          product(sku: old.sku, months: months),
          old.revision,
          clearWarranty: clear,
        );
      }

      try {
        await services.management.configure('PUBLIC WARRANTY', '0001', '0001');
        await services.management.unlock('0001');
        final id = await services.inventory.create(
          product(),
          initialQuantity: 4,
          unitCost: CostAmount.fromMoney(Money(5000, 'IDR', 0)),
        );
        final legacy = (await sale(id)).receipt;
        final oldPrint = await printed(legacy.id);
        final before = await database.read(SkybeeUpgradeAudit.capture);
        await database.close();
        database = DatabaseCoordinator(
          factory: factory,
          databasePath: path,
          schemaVersion: 39,
        );
        services = AppServices(database, clock: clock);
        final proof = await database.read(
          (db) => SkybeeUpgradeAudit.verify(db, before),
        );
        expect(proof['allExistingFactsMatch'], isTrue);
        expect(await printed(legacy.id), oldPrint);
        expect(
          (await services.checkout.receipt(
            legacy.id,
          )).items.single['warranty_until'],
          isNull,
        );

        await services.management.unlock('0001');
        await expectLater(
          edit(id, months: 1),
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'message',
              'm54WarrantyDisabled',
            ),
          ),
        );
        await policy(true);
        await expectLater(
          edit(id, months: 0),
          throwsA(
            isA<AppError>().having(
              (e) => e.message,
              'message',
              'm54WarrantyMonthsInvalid',
            ),
          ),
        );
        await edit(id, months: 1);
        final sold = await sale(id);
        final item = sold.receipt.items.single;
        expect(item['warranty_months_snapshot'], 1);
        expect(item['warranty_started_on'], '2028-01-31');
        expect(item['warranty_until'], '2028-02-29');
        expect(item['warranty_time_zone'], 'Asia/Jakarta');
        final snapshot = await printed(sold.receipt.id);
        expect(
          (snapshot['items'] as List).single['warrantyUntil'],
          '2028-02-29',
        );
        for (final (language, date) in [
          ('id', '29-Feb-2028'),
          ('en', 'Feb 29, 2028'),
        ]) {
          final layout = ReceiptLayout.sale({
            ...snapshot,
            'language': language,
          }, const PrinterProfile());
          expect(
            layout.lines.where((line) => line.text.contains(date)),
            hasLength(1),
          );
        }
        await edit(id, months: 12);
        expect(
          (await sale(id)).receipt.items.single['warranty_until'],
          '2029-01-31',
        );
        await policy(false);
        await edit(id);
        expect((await services.inventory.detail(id)).warrantyMonths, 12);
        expect((await sale(id)).receipt.items.single['warranty_until'], isNull);
        await policy(true);
        await edit(id, clear: true);
        expect((await services.inventory.detail(id)).warrantyMonths, isNull);
        final retry = await services.checkout.submit(
          sold.draft.id,
          sold.draft.revision,
          const CheckoutInput(),
        );
        expect(retry.id, sold.receipt.id);
        expect(retry.items.single, item);
        expect(await printed(retry.id), snapshot);
        await database.read(WarrantyValidation.validate);
        Future<int> forgeWarranty(DatabaseExecutor db) => db.update(
          'sale_transaction_items',
          {'warranty_until': '2028-03-01'},
          where: 'sale_transaction_id=?',
          whereArgs: [retry.id.value],
        );
        await expectLater(
          database.transaction(forgeWarranty),
          throwsA(isA<DatabaseException>()),
        );
        // Simulate an authenticated import with altered triggers on this
        // disposable fixture. The validator must still reject the wrong date.
        await database.transaction((db) async {
          await db.execute('DROP TRIGGER sale_transaction_items_no_update');
          expect(await forgeWarranty(db), 1);
        });
        await expectLater(
          database.read(WarrantyValidation.validate),
          throwsFormatException,
        );
      } finally {
        await database.close();
        await factory.deleteDatabase(path);
        await directory.delete();
      }
    },
  );
}
