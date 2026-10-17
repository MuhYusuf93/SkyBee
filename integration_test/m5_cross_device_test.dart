import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kasir_app/app/app_services.dart';
import 'package:kasir_app/core/domain/value_types.dart';
import 'package:kasir_app/data/database/database_coordinator.dart';
import 'package:kasir_app/data/database/database_gate.dart';
import 'package:kasir_app/data/database/database_validation.dart';
import 'package:kasir_app/data/database/encrypted_database.dart';
import 'package:kasir_app/features/backup/application/backup_service.dart';
import 'package:kasir_app/features/cashier/domain/cashier_models.dart';
import 'package:kasir_app/features/inventory/domain/inventory_models.dart';
import 'package:sqflite/sqflite.dart';

/// Physical-device transfer fixture. Only the authenticated archive and hashes
/// of synthetic facts leave the source sandbox; Keystore secrets never do.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const nonce = String.fromEnvironment('M5_CROSS_DEVICE_ID');
  const role = String.fromEnvironment('M5_CROSS_DEVICE_ROLE');
  const code =
      'abababababababababababababababababababababababababababababababab';
  const tables = [
    'products',
    'categories',
    'suppliers',
    'product_aliases',
    'price_history',
    'stock_receipts',
    'stock_receipt_items',
    'stock_batches',
    'stock_history',
    'sale_transactions',
    'sale_transaction_items',
    'sale_batch_allocations',
    'payments',
    'payment_allocations',
    'customers',
    'cart_drafts',
    'cart_draft_items',
    'print_receipts',
  ];
  test(
    'physical cross-device $role validates portable data and independent installation keys',
    () async {
      expect(const bool.fromEnvironment('KASIR_INTEGRATION_TEST'), true);
      expect(RegExp(r'^[0-9]{10,20}$').hasMatch(nonce), true);
      expect(['source', 'target'], contains(role));
      final base = await getDatabasesPath();
      final transfer = Directory('$base/m5_cross_$nonce');
      final path = '$base/m5_cross_${role}_$nonce.db';
      final database = DatabaseCoordinator(
        factory: databaseFactory,
        databasePath: path,
        gate: const AndroidDatabaseGate(),
        encryption: EncryptedDatabase(path, keyName: 'test-cross-$role-$nonce'),
      );
      final app = AppServices(database);
      final backups = BackupService(database, app.management);
      BackupInspection? inspection;
      PortableBackup? archive, safety;
      try {
        if (role == 'source') {
          await transfer.create();
          await app.management.configure(
            'Synthetic physical source',
            '0001',
            '0001',
          );
          await app.management.unlock('0001');
          final category = await app.inventory.saveMaster(
            MasterKind.category,
            'Synthetic cross category',
          );
          final supplier = await app.inventory.saveMaster(
            MasterKind.supplier,
            'Synthetic cross supplier',
          );
          final product = await app.inventory.create(
            ProductInput(
              name: 'Synthetic physical goods',
              barcode: 'M5-CROSS',
              sellingPrice: Money(12000, 'IDR', 0),
              wholesalePrice: Money(10000, 'IDR', 0),
              packSize: 40,
              packLabel: 'dus',
              categoryId: category,
              aliases: ['synthetic cross alias'],
            ),
            initialQuantity: 10,
            unitCost: CostAmount.fromMoney(Money(9000, 'IDR', 0)),
          );
          await app.inventory.receive(
            product,
            2,
            CostAmount.fromMoney(Money(8000, 'IDR', 0)),
            supplierId: supplier,
            operationKey: 'cross-restock-$nonce',
          );
          var draft = await app.cart.open();
          draft = await app.cart.add(draft.id, product);
          draft = await app.cart.pricing(
            draft.id,
            product,
            PricingMode.wholesale,
          );
          await app.checkout.submit(
            draft.id,
            draft.revision,
            const CheckoutInput(
              mode: PaymentMode.debt,
              customer: CustomerChoice(name: 'Synthetic physical debtor'),
            ),
          );
          final customer = (await app.receivables.customers()).items.single;
          await app.receivables.record(
            await app.receivables.preview(customer.id, Money(1000, 'IDR', 0)),
          );
          var next = await app.cart.next(draft.id);
          next = await app.cart.add(next.id, product);
          expect((await app.reports.reconcile()).consistent, true);
          final facts =
              (await database.read(DatabaseValidation.fingerprint))['tables']
                  as Map;
          await backups.confirmRecovery(code, code);
          archive = await backups.create();
          await archive.file.copy('${transfer.path}/archive.kasirbackup');
          await File('${transfer.path}/expected.json').writeAsString(
            jsonEncode({
              'nonce': nonce,
              'tables': {for (final table in tables) table: facts[table]},
              'sourceKeyDigest': sha256
                  .convert(utf8.encode(database.encryption!.key))
                  .toString(),
            }),
            flush: true,
          );
          // This marker contains no recovery/key/fact values and is safe for logs.
          debugPrint('M5_CROSS_SOURCE_READY=$nonce');
        } else {
          final expected =
              jsonDecode(
                    await File('${transfer.path}/expected.json').readAsString(),
                  )
                  as Map<String, dynamic>;
          expect(expected['nonce'], nonce);
          await app.management.configure(
            'Synthetic physical target',
            '0002',
            '0002',
          );
          await app.management.unlock('0002');
          expect(
            sha256.convert(utf8.encode(database.encryption!.key)).toString(),
            isNot(expected['sourceKeyDigest']),
          );
          inspection = await backups.inspect(
            File('${transfer.path}/archive.kasirbackup'),
            code,
          );
          safety = await backups.restore(
            inspection,
            confirmReplaceAndDrafts: true,
          );
          expect(app.management.isUnlocked, false);
          await app.management.unlock('0001');
          expect((await app.reports.reconcile()).consistent, true);
          final facts =
              (await database.read(DatabaseValidation.fingerprint))['tables']
                  as Map;
          for (final table in tables) {
            expect(facts[table], expected['tables'][table], reason: table);
          }
          expect(
            (await app.receivables.customers())
                .items
                .single
                .balance
                .amountMinor,
            9000,
          );
          final product = (await database.read(
            (db) => db.query(
              'products',
              columns: ['stock_quantity', 'wholesale_price_minor', 'pack_size'],
            ),
          )).single;
          expect(product['stock_quantity'], 11);
          expect(product['wholesale_price_minor'], 10000);
          expect(product['pack_size'], 40);
          expect(await safety.file.exists(), true);
          debugPrint(
            'M5_CROSS_TARGET_VERIFIED=$nonce tables=${tables.length} distinctKeys=true',
          );
        }
      } finally {
        await inspection?.dispose();
        await database.close();
        await deleteDatabase(path);
        for (final backup in [archive, safety]) {
          if (backup != null && await backup.file.parent.exists()) {
            await backup.file.parent.delete(recursive: true);
          }
        }
        // Transfer files remain until the orchestrator verifies both endpoints;
        // deletion is scoped to this exact nonce, never another app/database.
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
